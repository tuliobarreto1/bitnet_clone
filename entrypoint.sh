#!/bin/bash
set -e

export PATH="/app/venv/bin:$PATH"
export CC=clang-18
export CXX=clang++-18

MODEL_DIR="${MODEL_DIR:-/app/models/BitNet-b1.58-2B-4T}"
MODEL_FILE="${MODEL_FILE:-$MODEL_DIR/ggml-model-i2_s.gguf}"
HF_REPO="${HF_REPO:-microsoft/BitNet-b1.58-2B-4T-gguf}"
QUANT_TYPE="${QUANT_TYPE:-i2_s}"
THREADS="${THREADS:-4}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"

BUILD_DIR="${BUILD_DIR:-/app/volume/build}"
BINARY_SERVER="$BUILD_DIR/bin/llama-server"
BINARY_CLI="$BUILD_DIR/bin/llama-cli"
BUILD_STAMP="$BUILD_DIR/.build_done"

MODE="${1:-server}"

log()     { echo -e "\033[1;36m[BitNet]\033[0m $*"; }
success() { echo -e "\033[1;32m[BitNet]\033[0m $*"; }
error()   { echo -e "\033[1;31m[BitNet ERROR]\033[0m $*" >&2; exit 1; }

download_model() {
    log "Baixando modelo: $HF_REPO -> $MODEL_DIR"
    mkdir -p "$MODEL_DIR"
    hf download "$HF_REPO" --local-dir "$MODEL_DIR" 2>/dev/null || \
    huggingface-cli download "$HF_REPO" --local-dir "$MODEL_DIR"
    success "Download concluído!"
}

ensure_model() {
    if [ ! -f "$MODEL_FILE" ]; then
        log "Modelo não encontrado. Iniciando download..."
        download_model
    else
        log "Modelo ok: $MODEL_FILE"
    fi
}

ensure_build() {
    if [ -f "$BUILD_STAMP" ] && [ -f "$BINARY_SERVER" ]; then
        success "Build já existe em $BUILD_DIR — pulando compilação."
        return 0
    fi

    ensure_model

    log "=========================================="
    log "PRIMEIRA INICIALIZAÇÃO: compilando BitNet."
    log "Isso leva ~15-20 min. Aguarde..."
    log "=========================================="

    cd /app
    python setup_env.py -md "$MODEL_DIR" -q "$QUANT_TYPE" 2>&1

    mkdir -p "$BUILD_DIR/bin"
    cp -r /app/build/bin/. "$BUILD_DIR/bin/"

    echo "$(date -u)" > "$BUILD_STAMP"
    success "Build concluído e salvo em $BUILD_DIR"
}

case "$MODE" in
    download)
        download_model
        ;;
    build)
        rm -f "$BUILD_STAMP"
        ensure_build
        ;;
    server)
        ensure_build
        log "Iniciando servidor em $HOST:$PORT (threads: $THREADS)..."
        exec "$BINARY_SERVER" \
            -m "$MODEL_FILE" \
            --host "$HOST" \
            --port "$PORT" \
            -t "$THREADS"
        ;;
    chat)
        ensure_build
        SYSTEM_PROMPT="${SYSTEM_PROMPT:-You are a helpful assistant.}"
        log "Iniciando chat interativo..."
        exec "$BINARY_CLI" \
            -m "$MODEL_FILE" \
            -p "$SYSTEM_PROMPT" \
            --conversation \
            -t "$THREADS"
        ;;
    benchmark)
        ensure_build
        log "Executando benchmark..."
        cd /app
        python utils/e2e_benchmark.py -m "$MODEL_FILE" -p 512 -n 128 -t "$THREADS"
        ;;
    bash)
        exec /bin/bash
        ;;
    *)
        echo "Uso: [download|build|server|chat|benchmark|bash]"
        exit 1
        ;;
esac
