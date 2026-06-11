FROM nvidia/cuda:11.3.1-cudnn8-devel-ubuntu20.04 AS base

ARG PYTHON_VERSION=3.9

# Install system prerequisites
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      wget git unzip build-essential curl ca-certificates ninja-build libglib2.0-0 libsm6 libxrender-dev libxext6 libgl1-mesa-glx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Install Miniforge (conda-forge based)
RUN curl -L -o /tmp/miniforge.sh \
      https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh && \
    bash /tmp/miniforge.sh -b -p /opt/conda && \
    rm /tmp/miniforge.sh

ENV PATH=/opt/conda/bin:$PATH

# Restrict channels to conda-forge
RUN conda config --remove-key channels || true && \
    conda config --add channels conda-forge && \
    conda config --set channel_priority strict && \

RUN conda create -y -n wham python=${PYTHON_VERSION} \
    pip setuptools==59.5.0 \
    && conda clean -afy

ENV CONDA_DEFAULT_ENV=wham
ENV PATH=/opt/conda/envs/wham/bin:/opt/conda/bin:$PATH
ENV FORCE_CUDA=1
ENV CUDA_HOME=/usr/local/cuda

# CUDA 11.3 supports up to Ampere (8.0 / 8.6)
ENV TORCH_CUDA_ARCH_LIST="6.0;6.1;7.0;7.5;8.0;8.6+PTX"

# Install the base PyTorch stack
RUN conda install -y -n wham \
    mkl==2024.0.* \
    pytorch==1.11.0 torchvision==0.12.0 torchaudio==0.11.0 cudatoolkit=11.3 -c pytorch && \
    conda clean -afy

# Install PyTorch3D prerequisites and wheel
RUN /opt/conda/envs/wham/bin/pip install fvcore iopath && \
    /opt/conda/envs/wham/bin/pip install --no-index --no-cache-dir pytorch3d \
      -f https://dl.fbaipublicfiles.com/pytorch3d/packaging/wheels/py39_cu113_pyt1110/download.html

# -------------------------
# Development image
# -------------------------
FROM base AS dev

COPY entrypoint.dev.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace/WHAM
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]

# -------------------------
# Production-like image
# -------------------------
FROM base AS prod

COPY workspace/WHAM /workspace/WHAM
COPY entrypoint.prod.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace/WHAM

# Install WHAM dependencies into the image
RUN pip install -r requirements.txt && \
    pip install -v -e third-party/ViTPose && \
    cd third-party/DPVO && \
    wget https://gitlab.com/libeigen/eigen/-/archive/3.4.0/eigen-3.4.0.zip && \
    unzip eigen-3.4.0.zip -d thirdparty && \
    rm -f eigen-3.4.0.zip && \
    conda install -y -n wham pytorch-scatter=2.0.9 -c rusty1s && \
    conda clean -afy && \
    conda install -y -n wham gxx=9.5 -c conda-forge && \
    conda clean -afy && \
    pip install .

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
