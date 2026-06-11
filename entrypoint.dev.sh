#!/usr/bin/env bash
set -euo pipefail

export CUDA_HOME=/usr/local/cuda
export PATH=/opt/conda/envs/wham/bin:/opt/conda/bin:$PATH
STATE_DIR=/var/lib/wham
STAMP_FILE="${STATE_DIR}/.deps_installed"

mkdir -p "${STATE_DIR}"

if [ ! -d /workspace/WHAM ]; then
  echo "[ERROR] /workspace/WHAM was not found."
  echo "Please run the following on the host:"
  echo "  mkdir -p workspace"
  echo "  git clone --recursive https://github.com/yohanshin/WHAM.git workspace/WHAM"
  exit 1
fi

cd /workspace/WHAM

if [ ! -f "${STAMP_FILE}" ]; then
  echo "[INFO] Running first-time development bootstrap..."

  pip install -r requirements.txt
  pip install -v -e third-party/ViTPose

  cd third-party/DPVO

  if [ ! -f eigen-3.4.0.zip ] && [ ! -d thirdparty/eigen-3.4.0 ]; then
    wget https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.zip
  fi

  if [ ! -d thirdparty/eigen-3.4.0 ]; then
    mkdir -p thirdparty
    unzip -o eigen-3.4.0.zip -d thirdparty
  fi

  rm -f eigen-3.4.0.zip

  conda install -y -n wham pytorch-scatter=2.0.9 -c rusty1s
  conda clean -afy

  # Pin GCC for legacy extension compatibility when needed
  conda install -y -n wham gxx=9.5 -c conda-forge
  conda clean -afy

  pip install .

  touch "${STAMP_FILE}"
  echo "[INFO] Development bootstrap completed."
else
  echo "[INFO] Dependencies already installed. Skipping bootstrap."
fi

cd /workspace/WHAM
exec "$@"
