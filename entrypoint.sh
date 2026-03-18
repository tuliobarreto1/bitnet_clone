#!/bin/bash
set -e

export PATH="/app/venv/bin:$PATH"

MODEL_DIR="${MODEL_DIR:-/app/models/BitNet-b1.58-2B-4T}"
MODEL_FILE="${MODEL_FILE:-$MODEL_DIR/ggml-model-i2_s.gguf}"
HF_REPO="${HF_REPO:-microsoft/BitNet-b1.58-2B-4T-gguf}"
THREADS="${THREADS:-4}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"

MODE="${1:-server}"

log()   { echo -e "\033[1;36m[BitNet]\033[0m $*"; }
error() { echo -e "\033[1;31m[BitNet ERROR]\033[0m $*" >&2; exit 1; }

# ---------------------------------------------------
download_model() {
    log "Baixando modelo: $HF_REPO -> $MODEL_DIR"
    mkdir -p "$MODEL_DIR"
    hf download "$HF_REPO" --local-dir "$MODEL_DIR" 2>/dev/null || \
    huggingface-cli download "$HF_REPO" --local-dir "$MODEL_DIR"
    log "Download concluído!"
}

# ---------------------------------------------------
ensure_model() {
    if [ ! -f "$MODEL_FILE" ]; then
        log "Modelo não encontrado em $MODEL_FILE"
        download_model
    else
        log "Modelo encontrado: $MODEL_FILE"
    fi
}

# ---------------------------------------------------
ensure_binary() {
    if [ ! -f "/app/build/bin/llama-server" ]; then
        error "Binário não encontrado em /app/build/bin/llama-server. O build do Dockerfile falhou."
    fi
}

# ---------------------------------------------------
case "$MODE" in
    download)
        download_model
        ;;

    server)
        ensure_binary
        ensure_model
        log "Iniciando servidor de inferência em $HOST:$PORT ..."
        exec /app/build/bin/llama-server \
            -m "$MODEL_FILE" \
            --host "$HOST" \
            --port "$PORT" \
            -t "$THREADS"
        ;;

    chat)
        ensure_binary
        ensure_model
        SYSTEM_PROMPT="${SYSTEM_PROMPT:-You are a helpful assistant.}"
        log "Iniciando modo chat interativo..."
        exec /app/build/bin/llama-cli \
            -m "$MODEL_FILE" \
            -p "$SYSTEM_PROMPT" \
            --conversation \
            -t "$THREADS"
        ;;

    benchmark)
        ensure_binary
        ensure_model
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
        echo "Uso: docker run bitnet [download|server|chat|benchmark|bash]"
        echo ""
        echo "Variáveis de ambiente:"
        echo "  HF_REPO      Repo Hugging Face      (default: microsoft/BitNet-b1.58-2B-4T-gguf)"
        echo "  MODEL_DIR    Diretório do modelo     (default: /app/models/BitNet-b1.58-2B-4T)"
        echo "  MODEL_FILE   Caminho do .gguf        (default: MODEL_DIR/ggml-model-i2_s.gguf)"
        echo "  THREADS      Número de threads       (default: 4)"
        echo "  HOST         Host do servidor        (default: 0.0.0.0)"
        echo "  PORT         Porta do servidor       (default: 8080)"
        exit 1
        ;;
esac
