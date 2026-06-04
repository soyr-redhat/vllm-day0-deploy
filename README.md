# vllm-day0-deploy

Deploy any model on OpenShift with vLLM for day-0 support showcases. Point at a config, get a running endpoint.

## Usage

```bash
# Deploy Gemma 4 12B (fits in a single MIG slice, ~35GB VRAM)
./deploy configs/gemma4-12b.env

# Deploy with external route
./deploy configs/gemma4-12b.env --expose

# Dry run to preview YAML
./deploy configs/nemotron-ultra-550b-nvfp4.env --dry-run

# Check status
./status --name vllm-gemma-4-12b-it

# Tear down (keeps model cache PVC by default)
./teardown --name vllm-gemma-4-12b-it --keep-pvc
```

## Adding a new model

Create a file in `configs/`:

```bash
# configs/my-model.env
MODEL="org/model-name"
VRAM_GB=80                    # required — drives GPU selection
IMAGE="vllm/vllm-openai:latest"
MAX_MODEL_LEN=8192
```

GPU resources are auto-selected from `VRAM_GB`:

| VRAM | Resource | Tensor Parallel |
|------|----------|-----------------|
| ≤18 GB | `mig-1g.18gb` | 1 |
| ≤35 GB | `mig-3g.71gb` | 1 |
| ≤80 GB | `gpu x1` | 1 |
| ≤160 GB | `gpu x2` | 2 |
| ≤320 GB | `gpu x4` | 4 |
| ≤640 GB | `gpu x8` | 8 |

For models needing extra vLLM flags or env vars (like Nemotron), see `configs/nemotron-ultra-550b-nvfp4.env` as an example.

## Configs included

- `gemma4-12b.env` — Google Gemma 4 12B IT
- `gemma4-31b-fp8.env` — RedHatAI Gemma 4 31B FP8 quantized
- `nemotron-ultra-550b-nvfp4.env` — NVIDIA Nemotron 3 Ultra 550B NVFP4 (8×GPU)
- `mistral-7b.env` — Mistral 7B Instruct v0.3

## Cluster defaults

Defaults in `lib/defaults.sh` are set for the rhai-tmm OpenShift cluster. Update these for other environments:
- Kueue queue: `unreserved`
- Storage class: `ibmc-vpc-block-10iops-tier`
- HF token secret: `speed-showdown-secrets`
