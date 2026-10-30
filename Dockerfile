FROM python:3.12-slim

ARG COMFYUI_VERSION=v0.43.2
ARG TORCH_INDEX=https://download.pytorch.org/whl/cu130
ARG UID=1000
ARG GID=1000

# Root filesystem is read-only at runtime; point HOME and caches at the tmpfs.
# Custom-node dependencies go to a host-mounted dir via `pip install --user`.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HOME=/tmp/home \
    XDG_CACHE_HOME=/tmp/cache \
    TORCH_HOME=/tmp/cache/torch \
    HF_HOME=/tmp/cache/huggingface \
    TRITON_CACHE_DIR=/tmp/cache/triton \
    MPLCONFIGDIR=/tmp/cache/matplotlib \
    PYTHONUSERBASE=/data/python \
    PATH=/data/python/bin:$PATH

RUN apt-get update \
 && apt-get install -y --no-install-recommends git libgl1 libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${GID}" comfy \
 && useradd --uid "${UID}" --gid "${GID}" --no-create-home --shell /usr/sbin/nologin comfy

# App code stays owned by root so the running process cannot modify it
RUN git clone --depth 1 --branch "${COMFYUI_VERSION}" \
      https://github.com/comfyanonymous/ComfyUI.git /opt/comfyui \
 && rm -rf /opt/comfyui/.git

WORKDIR /opt/comfyui

RUN pip install torch torchvision torchaudio --index-url "${TORCH_INDEX}" \
 && pip install -r requirements.txt

COPY extra_model_paths.yaml /opt/comfyui/extra_model_paths.yaml

RUN mkdir -p /data/models /data/output /data/input /data/user /data/custom_nodes /data/python \
 && chown -R comfy:comfy /data

USER comfy

EXPOSE 8188

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8188/', timeout=4)" || exit 1

ENTRYPOINT ["python", "main.py", \
  "--listen", "0.0.0.0", \
  "--port", "8188", \
  "--disable-auto-launch", \
  "--extra-model-paths-config", "/opt/comfyui/extra_model_paths.yaml", \
  "--output-directory", "/data/output", \
  "--input-directory", "/data/input", \
  "--user-directory", "/data/user", \
  "--temp-directory", "/tmp/comfy"]
