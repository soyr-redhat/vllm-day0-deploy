#!/usr/bin/env bash
# Default configuration values

IMAGE="vllm/vllm-openai:latest"
MAX_MODEL_LEN="8192"
MAX_BATCH_TOKENS="16384"
MAX_SEQS="256"
GPU_UTIL="0.95"
QUEUE="unreserved"
HF_SECRET="speed-showdown-secrets"
HF_SECRET_KEY="hf-token"
PVC_SIZE="120Gi"
STORAGE_CLASS="ibmc-vpc-block-10iops-tier"
EXPOSE=false
DRY_RUN=false
EXTRA_ARGS=""
EXTRA_ENV=()
SERVED_MODEL_NAME=""

derive_name() {
  local model="$1"
  echo "$model" \
    | sed 's|.*/||' \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9-]/-/g' \
    | sed 's/--*/-/g' \
    | sed 's/^-//;s/-$//'
}
