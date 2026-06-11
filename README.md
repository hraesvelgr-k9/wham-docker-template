# WHAM Docker Template

[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-multi--file-blue?logo=docker)](#using-multiple-compose-files)
[![NVIDIA GPU](https://img.shields.io/badge/GPU-NVIDIA-76B900?logo=nvidia)](#requirements)
[![Linux](https://img.shields.io/badge/Host-Linux-FCC624?logo=linux&logoColor=black)](#requirements)
[![Environment File](https://img.shields.io/badge/config-.env-important)](#configuration)
[![Makefile](https://img.shields.io/badge/workflow-Makefile-6C63FF)](#common-commands)

A Docker + Docker Compose template for working with **WHAM** in both development and production-like workflows.

This template uses a two-mode setup:

- **Development mode**: bind-mount the host-side `workspace/WHAM` source tree so code changes are reflected immediately inside the container.
- **Production-like mode**: copy the source tree into the image to improve reproducibility and reduce dependency on host-side mounts.

---

## Table of Contents

- [Features](#features)
- [Directory Layout](#directory-layout)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Common Commands](#common-commands)
- [Configuration](#configuration)
- [Using Multiple Compose Files](#using-multiple-compose-files)
- [Development vs Production-like](#development-vs-production-like)
- [Troubleshooting](#troubleshooting)
- [Recommended Repository Practice](#recommended-repository-practice)
- [License / Upstream](#license--upstream)

---

## Features

- Development workflow with host-side source editing
- Production-like workflow with image-baked source code
- `.env`-based configuration for container name, GPU architecture, paths, and image settings
- `Makefile` shortcuts for common Docker Compose tasks
- `.dockerignore` to reduce unnecessary build context

## Directory Layout

```text
.
├─ README.md
├─ .env.example
├─ .gitignore
├─ .dockerignore
├─ Dockerfile
├─ Makefile
├─ compose.yml
├─ compose.dev.yml
├─ compose.prod.yml
├─ entrypoint.dev.sh
├─ entrypoint.prod.sh
└─ workspace/
   └─ WHAM/
```

## Requirements

- Linux host
- Docker Engine
- Docker Compose plugin
- NVIDIA driver and Docker GPU runtime support if GPU execution is required
- A cloned WHAM repository under `workspace/WHAM`

## Quick Start

### 1. Create your environment file

```bash
cp .env.example .env
```

### 2. Clone WHAM

```bash
make init
```

This command clones the repository into `workspace/WHAM` if it does not already exist.

### 3. Start development mode

```bash
make dev-build
make dev-up
make dev-shell
```

## Common Commands

### Development mode

```bash
make dev-build
make dev-up
make dev-shell
make dev-logs
make dev-config
make dev-down
```

### Production-like mode

```bash
make prod-build
make prod-up
make prod-shell
make prod-logs
make prod-config
make prod-down
```

### Utility commands

```bash
make env-init
make init
make ps
make clean
```

## Configuration

Main settings are defined in `.env.example`.

Typical values include:

- `CONTAINER_NAME`
- `SERVICE_NAME`
- `HOST_WHAM_DIR`
- `CONTAINER_WHAM_DIR`
- `TORCH_CUDA_ARCH_LIST`
- `IMAGE_NAME`
- `IMAGE_TAG`

Copy `.env.example` to `.env`, then adjust the values for your environment.

## Using Multiple Compose Files

This template uses a base Compose file plus mode-specific override files:

- `compose.yml`
- `compose.dev.yml`
- `compose.prod.yml`

Docker Compose merges files in the order they are specified on the command line. Later files override or extend earlier ones, and paths are resolved relative to the base file.

Examples:

```bash
docker compose --env-file .env -f compose.yml -f compose.dev.yml up -d --build
docker compose --env-file .env -f compose.yml -f compose.prod.yml up -d --build
```

## Development vs Production-like

### Development mode

Use development mode when:

- You want to edit WHAM source code on the host machine
- You want source changes to appear immediately in the container
- You want faster iteration with fewer rebuilds

### Production-like mode

Use production-like mode when:

- You want to verify reproducibility for a specific source state
- You want to run a container without depending on a host bind mount
- You want behavior closer to a distributable image

## Troubleshooting

### 1. My changes are not visible in the container

Check that `HOST_WHAM_DIR` in `.env` points to the correct host directory and that the service is running in **development mode**. In development mode, the bind-mounted host directory should take precedence over image-baked files.

### 2. Files that existed in the image disappeared after startup

This is expected with bind mounts. When a bind mount is attached to a non-empty directory in the container, the existing contents are obscured by the mounted directory.

### 3. `${VAR}` is not expanding in Compose

Compose interpolation uses `.env` or `--env-file`, not `env_file:`. If variables are not expanding, verify that `.env` exists in the project root or explicitly pass `--env-file .env`.

### 4. Development mode works, but production-like mode fails

Make sure `workspace/WHAM` is present in the build context and not accidentally excluded by `.dockerignore`. The production-like image depends on `COPY workspace/WHAM /workspace/WHAM` during build.

### 5. GPU is not available inside the container

Check the host NVIDIA driver installation and Docker GPU runtime configuration first. Then confirm that the container is started with the expected GPU-related environment settings from `.env`.

### 6. I want to inspect the final merged Compose configuration

Use:

```bash
make dev-config
make prod-config
```

This helps verify merged settings, interpolated values, and resolved paths before debugging runtime behavior.

## Recommended Repository Practice

For public or team distribution:

- Commit `.env.example`, not `.env`
- Commit `.gitignore` and `.dockerignore`
- Keep large datasets, checkpoints, outputs, and model files out of Git
- Keep `workspace/WHAM` as a user-provided clone target unless you intentionally vendor the source
- Document expected GPU architecture values in `.env.example`
- Keep badges relevant and limited in number so the README stays readable

## License / Upstream

This template is intended for managing the containerized development and reproducibility workflow around WHAM.

Please check the upstream WHAM repository for the actual project license, usage conditions, and model-specific requirements.
