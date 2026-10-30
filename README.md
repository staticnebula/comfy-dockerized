# ComfyUI in Docker

ComfyUI in a locked-down container with NVIDIA GPU access. The host only shares the directories listed below.

## Prerequisites

- Docker with Compose v2
- An NVIDIA driver that supports CUDA 13 (driver 580 or newer) and `nvidia-container-toolkit`

## Usage

```sh
cp .env.example .env      # optional: change UID/GID, port or host paths
docker compose up -d --build
```

Then open http://127.0.0.1:8188. Logs: `docker compose logs -f`. Stop: `docker compose down`.

## Host directories

| Host                | Container             | Purpose                                     |
|---------------------|-----------------------|---------------------------------------------|
| `./models`          | `/data/models`        | Checkpoints, LoRAs, VAEs, etc. (`checkpoints/`, `loras/`, ...) |
| `./output`          | `/data/output`        | Generated images                            |
| `./input`           | `/data/input`         | Uploaded input images                       |
| `./user`            | `/data/user`          | Saved workflows and settings                |
| `./custom_nodes`    | `/data/custom_nodes`  | Custom nodes                                |
| `./python-packages` | `/data/python`        | pip packages that custom nodes need         |

Set `MODELS_DIR`, `OUTPUT_DIR` or `CUSTOM_NODES_DIR` in `.env` to use folders you already have. The model subfolders are mapped in `extra_model_paths.yaml`.

## Custom nodes

Clone a node into `./custom_nodes` on the host. If it has dependencies, install them from inside the container, then restart:

```sh
git clone https://github.com/<author>/<node> custom_nodes/<node>
docker compose exec comfyui pip install --user -r /data/custom_nodes/<node>/requirements.txt
docker compose restart
```

The image's own site-packages are read-only, so packages go to `./python-packages` and stay there across rebuilds. Delete that folder to reset them.

**Custom nodes run arbitrary Python code.** The container limits what that code can reach, but it still has network access and can read and write every mounted directory, models and outputs included. Only install nodes you trust.

## Isolation

- Runs as an unprivileged user (UID/GID match the host user, so output files belong to you)
- Read-only root filesystem; the ComfyUI code belongs to root and cannot be changed while it runs
- Writes are limited to the mounted directories and a tmpfs at `/tmp`
- All Linux capabilities are dropped and `no-new-privileges` is set
- The port is bound to `127.0.0.1` only
- ComfyUI is pinned to a release tag (`COMFYUI_VERSION` in the `Dockerfile`)

To also block internet access, put the service on an `internal: true` network behind a reverse proxy. Without network access, model downloads and pip installs won't work from inside the container.

## Updating

Change `COMFYUI_VERSION` (and `TORCH_INDEX` if you need to) in the `Dockerfile`, then run `docker compose up -d --build`.

## AMD GPUs

Set `TORCH_INDEX` to a ROCm wheel index. In `compose.yaml`, replace the `deploy.resources` block with `devices: [/dev/kfd, /dev/dri]` and `group_add: [video, render]`.
