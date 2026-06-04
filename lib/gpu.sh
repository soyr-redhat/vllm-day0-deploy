#!/usr/bin/env bash
# GPU resource selection logic

select_gpu() {
  local vram_gb="$1"
  local override_resource="${2:-}"
  local override_count="${3:-}"

  if [[ -n "$override_resource" ]]; then
    GPU_RESOURCE="$override_resource"
    GPU_COUNT="${override_count:-1}"
    TP_SIZE="$GPU_COUNT"
    return
  fi

  if (( vram_gb <= 18 )); then
    GPU_RESOURCE="nvidia.com/mig-1g.18gb"
    GPU_COUNT=1
    TP_SIZE=1
  elif (( vram_gb <= 35 )); then
    GPU_RESOURCE="nvidia.com/mig-3g.71gb"
    GPU_COUNT=1
    TP_SIZE=1
  elif (( vram_gb <= 80 )); then
    GPU_RESOURCE="nvidia.com/gpu"
    GPU_COUNT=1
    TP_SIZE=1
  elif (( vram_gb <= 160 )); then
    GPU_RESOURCE="nvidia.com/gpu"
    GPU_COUNT=2
    TP_SIZE=2
  elif (( vram_gb <= 320 )); then
    GPU_RESOURCE="nvidia.com/gpu"
    GPU_COUNT=4
    TP_SIZE=4
  elif (( vram_gb <= 640 )); then
    GPU_RESOURCE="nvidia.com/gpu"
    GPU_COUNT=8
    TP_SIZE=8
  else
    echo "Error: VRAM requirement ${vram_gb}GB exceeds maximum supported (640GB / 8 GPUs)" >&2
    return 1
  fi
}
