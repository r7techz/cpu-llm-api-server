FROM ghcr.io/ggml-org/llama.cpp:server

WORKDIR /app
COPY scripts/start.sh /app/scripts/start.sh
COPY scripts/download-model.sh /app/scripts/download-model.sh
COPY scripts/healthcheck.sh /app/scripts/healthcheck.sh
RUN chmod +x /app/scripts/start.sh /app/scripts/download-model.sh /app/scripts/healthcheck.sh \
    && mkdir -p /models

ENV HOST=0.0.0.0 \
    MODEL_DIR=/models \
    DOWNLOAD_MODEL=true \
    ENABLE_WEBUI=true \
    CPU_THREADS=2 \
    CPU_THREADS_BATCH=2 \
    CONTEXT_SIZE=2048 \
    BATCH_SIZE=256 \
    UBATCH_SIZE=128 \
    PARALLEL=1 \
    LOG_VERBOSITY=3

VOLUME ["/models"]
ENTRYPOINT ["/app/scripts/start.sh"]
