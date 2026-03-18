FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV CC=clang-18
ENV CXX=clang++-18

# --- Dependências base ---
RUN apt-get update && apt-get install -y \
    git cmake wget curl \
    lsb-release software-properties-common gnupg \
    build-essential \
    python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

# --- Clang 18 ---
RUN wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key \
      | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc > /dev/null \
    && echo "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-18 main" \
      >> /etc/apt/sources.list.d/llvm.list \
    && apt-get update \
    && apt-get install -y clang-18 llvm-18 \
    && update-alternatives --install /usr/bin/clang   clang   /usr/bin/clang-18   100 \
    && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-18 100 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# --- Clona BitNet ---
RUN git clone --recursive https://github.com/microsoft/BitNet.git .

# --- Python venv ---
RUN python3 -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

RUN pip install --upgrade pip \
    && pip install -r requirements.txt \
    && pip install huggingface_hub

# Volume para modelos (não faz parte da imagem)
RUN mkdir -p /app/models

EXPOSE 8080

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["server"]
