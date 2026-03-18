#!/bin/bash
set -e

VENV_PATH="/app/venv"
export PATH="$VENV_PATH/bin:$PATH"
export CC=clang-18
export CXX=clang++-18

MODEL_DIR="${MODEL_DIR:-/app/models/BitNet-b1.58-2B-4T}"
MODEL_FILE="${MODEL_FILE:-$MODEL_DIR/ggml-model-i2_s.gguf}"
QUANT_TYPE="${QUANT_TYPE:-i2_s}"
HF_REPO="${HF_REPO:-microsoft/BitNet-b1.58-2B-4T-gguf}"
THREADS="${THREADS:-4}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"

MODE="${1:-server}"

log() { echo -e "\033[1;36m[BitNet]\033[0m $*"; }
error() { echo -e "\033[1;31m[BitNet ERROR]\033[0m $*" >&2; exit 1; }

# ---------------------------------------------------
download_model() {
    log "Baixando modelo: $HF_REPO -> $MODEL_DIR"
    huggingface-cli download "$HF_REPO" --local-dir "$MODEL_DIR"
    log "Download concluído!"
}

# ---------------------------------------------------
build_project() {
    if [ ! -f "$MODEL_DIR/ggml-model-${QUANT_TYPE}.gguf" ]; then
        log "Modelo não encontrado. Executando download primeiro..."
        download_model
    fi

    log "Compilando BitNet (quant: $QUANT_TYPE)..."
    cd /app
    python setup_env.py -md "$MODEL_DIR" -q "$QUANT_TYPE"
    log "Build concluído!"
}

# ---------------------------------------------------
ensure_built() {
    if [ ! -f "$MODEL_FILE" ]; then
        log "Modelo não encontrado em $MODEL_FILE"
        build_project
    else
        log "Modelo encontrado: $MODEL_FILE"
    fi
}

# ---------------------------------------------------
case "$MODE" in
    download)
        download_model
        ;;

    build)
        build_project
        ;;

    server)
        ensure_built
        log "Iniciando servidor de inferência em $HOST:$PORT ..."
        cd /app
        python run_inference_server.py \
            -m "$MODEL_FILE" \
            --host "$HOST" \
            --port "$PORT" \
            -t "$THREADS"
        ;;

    chat)
        ensure_built
        SYSTEM_PROMPT="${SYSTEM_PROMPT:-You are a helpful assistant.}"
        log "Iniciando modo chat interativo..."
        cd /app
        python run_inference.py \
            -m "$MODEL_FILE" \
            -p "$SYSTEM_PROMPT" \
            -cnv \
            -t "$THREADS"
        ;;

    benchmark)
        ensure_built
        log "Executando benchmark..."
        cd /app
        python utils/e2e_benchmark.py \
            -m "$MODEL_FILE" \
            -p 512 \
            -n 128 \
            -t "$THREADS"
        ;;

    bash)
        exec /bin/bash
        ;;

    *)
        echo "Uso: docker run bitnet [download|build|server|chat|benchmark|bash]"
        echo ""
        echo "Variáveis de ambiente disponíveis:"
        echo "  MODEL_DIR    Diretório do modelo   (default: /app/models/BitNet-b1.58-2B-4T)"
        echo "  MODEL_FILE   Caminho do .gguf       (default: MODEL_DIR/ggml-model-i2_s.gguf)"
        echo "  QUANT_TYPE   Tipo de quantização    (default: i2_s)"
        echo "  HF_REPO      Repo Hugging Face      (default: microsoft/BitNet-b1.58-2B-4T-gguf)"
        echo "  THREADS      Número de threads      (default: 4)"
        echo "  HOST         Host do servidor       (default: 0.0.0.0)"
        echo "  PORT         Porta do servidor      (default: 8080)"
        exit 1
        ;;
esac
