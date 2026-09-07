#!/usr/bin/env bash
set -Eeuo pipefail

: "${PORT:=8080}"
: "${HOST:=0.0.0.0}"
: "${API_KEY:=}"
: "${MODEL_ALIAS:=}"
: "${MODEL_PATH:=}"
: "${MODEL_DIR:=/models}"
: "${MODEL_REPO:=}"
: "${MODEL_FILE:=}"
: "${MODEL_REVISION:=main}"
: "${HF_TOKEN:=}"
: "${DOWNLOAD_MODEL:=true}"
: "${CPU_THREADS:=2}"
: "${CPU_THREADS_BATCH:=${CPU_THREADS}}"
: "${CONTEXT_SIZE:=2048}"
: "${BATCH_SIZE:=256}"
: "${UBATCH_SIZE:=128}"
: "${PARALLEL:=1}"
: "${LOG_VERBOSITY:=3}"
: "${CORS_ORIGINS:=}"
: "${LLAMA_SERVER_BIN:=}"
: "${LLAMA_SERVER_ARGS:=}"
: "${ENABLE_WEBUI:=true}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${MODEL_PATH}" && -f "${MODEL_PATH}" ]]; then
  echo "Using model from MODEL_PATH: ${MODEL_PATH}"
elif [[ "${DOWNLOAD_MODEL}" == "true" ]]; then
  if [[ -z "${MODEL_REPO}" || -z "${MODEL_FILE}" ]]; then
    echo "No model configured. Set MODEL_REPO and MODEL_FILE to the exact model to download, or set MODEL_PATH to an existing GGUF file." >&2
    exit 2
  fi
  MODEL_PATH="${MODEL_PATH:-${MODEL_DIR}/${MODEL_FILE}}"
  export MODEL_DIR MODEL_REPO MODEL_FILE MODEL_REVISION HF_TOKEN MODEL_PATH
  "${SCRIPT_DIR}/download-model.sh"
else
  echo "No usable model configured. Set MODEL_PATH to an existing GGUF file or set MODEL_REPO and MODEL_FILE with DOWNLOAD_MODEL=true." >&2
  exit 2
fi

if [[ ! -f "${MODEL_PATH}" ]]; then
  echo "Model file not found at ${MODEL_PATH}." >&2
  exit 1
fi

# Resolve llama-server across the official llama.cpp container layouts.
if [[ -n "${LLAMA_SERVER_BIN}" ]]; then
  if [[ ! -x "${LLAMA_SERVER_BIN}" ]] && ! command -v "${LLAMA_SERVER_BIN}" >/dev/null 2>&1; then
    echo "ERROR: LLAMA_SERVER_BIN='${LLAMA_SERVER_BIN}' was not found or is not executable." >&2
    exit 127
  fi
elif command -v llama-server >/dev/null 2>&1; then
  LLAMA_SERVER_BIN="$(command -v llama-server)"
elif [[ -x /app/llama-server ]]; then
  LLAMA_SERVER_BIN=/app/llama-server
elif [[ -x /usr/local/bin/llama-server ]]; then
  LLAMA_SERVER_BIN=/usr/local/bin/llama-server
elif [[ -x /usr/bin/llama-server ]]; then
  LLAMA_SERVER_BIN=/usr/bin/llama-server
else
  echo "ERROR: llama-server executable not found." >&2
  exit 127
fi

echo "Using llama-server: ${LLAMA_SERVER_BIN}"
if [[ -x "${LLAMA_SERVER_BIN}" ]]; then
  "${LLAMA_SERVER_BIN}" --version 2>/dev/null || true
fi

echo "Starting llama-server on ${HOST}:${PORT} with model ${MODEL_PATH}"

args=(
  --model "${MODEL_PATH}"
  --host "${HOST}"
  --port "${PORT}"
  --threads "${CPU_THREADS}"
  --threads-batch "${CPU_THREADS_BATCH}"
  --ctx-size "${CONTEXT_SIZE}"
  --batch-size "${BATCH_SIZE}"
  --ubatch-size "${UBATCH_SIZE}"
  --parallel "${PARALLEL}"
  --log-verbosity "${LOG_VERBOSITY}"
)

if [[ "${ENABLE_WEBUI}" != "true" ]]; then
  args+=(--no-webui)
fi

if [[ -n "${MODEL_ALIAS}" ]]; then
  args+=(--alias "${MODEL_ALIAS}")
fi

if [[ -n "${CORS_ORIGINS}" ]]; then
  args+=(--cors-origins "${CORS_ORIGINS}")
fi

if [[ -n "${API_KEY}" ]]; then
  args+=(--api-key "${API_KEY}")
fi

if [[ -n "${LLAMA_SERVER_ARGS}" ]]; then
  read -r -a extra_args <<< "${LLAMA_SERVER_ARGS}"
  args+=("${extra_args[@]}")
fi

exec "${LLAMA_SERVER_BIN}" "${args[@]}"
