#!/usr/bin/env bash
set -euo pipefail

export CUDA_HOME=/usr/local/cuda
export PATH=/opt/conda/envs/wham/bin:/opt/conda/bin:$PATH

if [ -d /workspace/WHAM ]; then
  cd /workspace/WHAM
else
  cd /workspace
fi

exec "$@"
