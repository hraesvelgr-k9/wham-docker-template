# WHAM Docker テンプレート

このリポジトリは、[WHAM](https://github.com/yohanshin/WHAM) を GPU 対応の Docker + Docker Compose 環境で動かすためのテンプレートです。

WHAM のソースコードはホスト側の `workspace/WHAM` に配置し、コンテナ起動時に bind mount します。一方で Conda 環境は named volume `wham_env` に保存し、コンテナの作り直し (`docker compose down` / `up`) を挟んでも依存パッケージが失われない構成になっています。

## 特徴

- NVIDIA GPU 対応の WHAM コンテナ構成。
- ホスト側 `workspace/WHAM` を bind mount して開発しやすいワークフロー。
- Conda 環境を named volume `wham_env` に永続化し、再起動やコンテナ再作成でも依存を維持。
- base 用 `compose.yml` と dev/prod 用のオーバーレイ (`compose.dev.yml`, `compose.prod.yml`) によるマルチファイル構成。
- `entrypoint.dev.sh` による初回起動時の WHAM 依存インストール処理。
- `CUDA_HOME=/usr/local/cuda` をコンテナ側で固定して CUDA 環境を安定化。
- `Makefile` によるビルド・起動・シェル・ログ・環境リセットのショートカット。

## ディレクトリ構成

```text
.
├─ .env.example
├─ .env              # .env.example から作成
├─ compose.yml
├─ compose.dev.yml
├─ compose.prod.yml
├─ Dockerfile
├─ entrypoint.dev.sh
├─ entrypoint.prod.sh
├─ Makefile
├─ README.md
├─ README-ja.md
└─ workspace/
   └─ WHAM/
```

## 前提条件

- Docker Engine
- Docker Compose プラグイン
- ホスト側に NVIDIA ドライバ
- NVIDIA Container Toolkit など、GPU を Docker から利用できる環境
- Linux 環境推奨（GPU 開発用途）
- `workspace/WHAM` に WHAM を clone 済みであること

## 各ファイルの役割

### `.env.example` / `.env`

`.env.example` はサンプル設定ファイルです。まず次のようにコピーして `.env` を作成します。

```bash
cp .env.example .env
```

`.env` には次のような値を設定します。

- `COMPOSE_PROJECT_NAME` — Compose プロジェクト名（コンテナ名やボリューム名のプレフィックス）。
- `CONTAINER_NAME` — WHAM コンテナの名前（任意）。
- `HOST_WHAM_DIR` / `CONTAINER_WHAM_DIR` — ホスト／コンテナ内の WHAM ディレクトリパス。
- `NVIDIA_VISIBLE_DEVICES`, `NVIDIA_DRIVER_CAPABILITIES` — GPU 関連の設定。
- `TORCH_CUDA_ARCH_LIST`, `FORCE_CUDA` — PyTorch の CUDA 設定。
- `IMAGE_NAME`, `IMAGE_TAG`, `PYTHON_VERSION` — イメージ名や Python バージョン。
- `RESTART_POLICY` — 本番相当サービスの再起動ポリシー。

### `compose.yml`

共通の base 設定です。`wham` サービスの基本定義、GPU 関連の環境変数、TTY 設定などを持ちます。また、CUDA のパスを次のように固定しています。

```yaml
CUDA_HOME: /usr/local/cuda
```

これにより、ホスト側の CUDA インストールに引きずられず、コンテナ内の CUDA ツールキットを確実に使えます。

### `compose.dev.yml`

開発用のオーバーレイです。主な内容は次の通りです。

- `dev` ステージを使ったイメージビルド設定。
- ソースコードの bind mount:

  ```yaml
  - type: bind
    source: ${HOST_WHAM_DIR}
    target: ${CONTAINER_WHAM_DIR}
  ```

- Conda 環境と Conda パッケージキャッシュ用の named volume:

  ```yaml
  - type: volume
    source: wham_env
    target: /opt/conda/envs/wham
  - type: volume
    source: conda_pkgs
    target: /opt/conda/pkgs
  ```

`wham_env` には Conda の仮想環境と、インストール済み判定用のスタンプファイルが格納されます。そのため `docker compose down` / `up` を繰り返しても、`wham_env` を削除しない限り依存パッケージは再インストール不要です。

### `compose.prod.yml`

本番再現用（production-like）オーバーレイです。

- `prod` ビルドステージの指定
- `RESTART_POLICY` の設定
- 必要に応じて `wham_env` / `conda_pkgs` を prod でも再利用できますし、完全にイメージ内に依存を焼き込む構成にすることもできます。

### `Dockerfile`

CUDA 11.3 ベースイメージの上で、Miniforge のインストール、`wham` Conda 環境の作成、PyTorch 1.11 + CUDA 11.3 のインストール、`dev` / `prod` の 2 ステージ構成を定義しています。

- **dev ステージ**: `/workspace/WHAM` に bind mount される前提で、依存インストールは `entrypoint.dev.sh` に任せます。
- **prod ステージ**: `workspace/WHAM` をイメージに `COPY` し、依存をすべてビルド時にインストールしておくことで、本番コンテナ起動時の作業を減らします。

### `demo.py` 実行用の OpenCV 系ライブラリ

WHAM の `demo.py` を実行する際、OpenCV 関連の共有ライブラリ不足で `libGL.so.1` などの実行時エラーが発生することがあります。その対策として、Ubuntu ベースのイメージでは次のシステムパッケージを追加するのが有効です。[web:448][web:453][web:450]

```dockerfile
libglib2.0-0 libsm6 libxrender-dev libxext6 libgl1-mesa-glx
```

これらは OpenCV の描画・画像処理系ランタイム依存を満たすためによく使われる組み合わせです。[web:446][web:456]

### `entrypoint.dev.sh`

開発コンテナ初回起動時に WHAM の依存インストールを行うエントリポイントです。処理の流れは次の通りです。

1. `/workspace/WHAM` の存在確認。
2. `requirements.txt` から Python 依存のインストール。
3. ViTPose のインストールと DPVO のビルド。
4. `/opt/conda/envs/wham/wham_state/.deps_installed` にスタンプファイルを作成。
5. `exec "$@"` により、指定されたコマンドを PID 1 として実行。

Conda 環境と `wham_state` の両方が `wham_env` ボリューム上にあるため、「スタンプがあるのに依存が無い」といった不整合が起きません。

## クイックスタート

### 1. このリポジトリを clone

```bash
git clone <your-repository-url>
cd <your-repository-directory>
```

### 2. `.env` を作成

```bash
cp .env.example .env
```

必要に応じて GPU の指定やイメージ名などを編集します。

### 3. WHAM を clone

```bash
mkdir -p workspace
git clone --recursive https://github.com/yohanshin/WHAM.git workspace/WHAM
```

### 4. 開発用イメージをビルド

```bash
docker compose --env-file .env -f compose.yml -f compose.dev.yml build
```

### 5. 開発コンテナを起動

```bash
docker compose --env-file .env -f compose.yml -f compose.dev.yml up -d
```

初回起動時に `entrypoint.dev.sh` が実行され、`wham_env` ボリューム上に Conda 環境と WHAM 依存がインストールされます。

### 6. コンテナに入る

```bash
docker compose --env-file .env -f compose.yml -f compose.dev.yml exec wham bash
```

## Makefile を使った運用

Makefile を使うと、よく使うコマンドを短く呼び出せます。

```bash
make env-init   # .env が無ければ .env.example から作成
make init       # workspace/WHAM に WHAM を clone
make dev-build
make dev-up
make dev-shell
```

主なターゲット:

- `make env-init` — `.env` が無ければ `.env.example` から作成。
- `make init` — `workspace/WHAM` に WHAM を clone。
- `make dev-config` — dev 用のマージ済み Compose 設定を表示。
- `make dev-build` — 開発用イメージのビルド。
- `make dev-up` / `make dev-down` — 開発コンテナの起動・停止。
- `make dev-shell` — 開発コンテナ内にシェルで入る。
- `make prod-build` / `make prod-up` / `make prod-shell` — 本番再現用ワークフロー。
- `make reset-env` — `wham_env` ボリュームを削除して、開発環境をゼロから再構築。
- `make reset-all` — コンテナと named volume（`wham_env`, `conda_pkgs` など）をまとめて削除。

## Compose 設定の確認

Compose ファイルを編集した際は、実際に適用されるマージ結果を確認しておくと安全です。

```bash
docker compose --env-file .env -f compose.yml -f compose.dev.yml config
docker compose --env-file .env -f compose.yml -f compose.prod.yml config
```

## サービス名とコンテナ名

コンテナに入るときは、サービス名 `wham` を使って:

```bash
docker compose exec wham bash
```

とします。`wham-gpu` は `container_name` であり、`docker compose exec` はサービス名を取る点に注意してください。

## ボリュームの挙動（`wham_env` / `conda_pkgs`）

- `wham_env`
  - `/opt/conda/envs/wham` にマウントされる Conda 環境用の named volume です。
  - `docker compose down` でコンテナを削除しても、ボリュームは残ります。
  - 再度 `up` すると同じ環境とスタンプファイルが使われるため、インストール済みの依存がそのまま再利用されます。

- `conda_pkgs`
  - `/opt/conda/pkgs` にマウントされる Conda パッケージキャッシュ用の named volume です。
  - 再ビルド時に同じパッケージを再ダウンロードせずに済むため、ビルド時間を短縮できます。

環境を完全にリセットしたい場合は、次のようにします。

```bash
make reset-env
```

## メンテナンスのヒント

- 公開リポジトリとして配布しやすいよう、コメントやドキュメントは英語ベースにしてありますが、日本語メモは別ファイルに追加しても構いません。
- サービス名 `wham` を変える場合は、Compose ファイル・Makefile・README のコマンド例をすべて一括で置き換えてください。
- Compose ファイルを編集したら `docker compose ... config` でマージ結果を確認してから `up` するのがおすすめです。
- GitHub ではルートの README が自動表示されるので、英語版 README と合わせて `README-ja.md` を置いておくと、英語・日本語どちらのユーザにも親切です。
