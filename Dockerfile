# MiniMax H3 Text-to-Video (ComfyUI) for RunPod Serverless
FROM wlsdml1114/engui_genai-base_blackwell:1.1 AS runtime

# HF_TOKEN: required at build for Hub model + turbo LoRA bakes.
# Do NOT hardcode tokens. Pass: docker build --build-arg HF_TOKEN=hf_xxx ...
# Style + realism LoRAs are runtime-only via job lora_url / loras + hf_token.
ARG HF_TOKEN
ENV HF_TOKEN=${HF_TOKEN}
ENV HUGGING_FACE_HUB_TOKEN=${HF_TOKEN}
ENV BFL_READ_TOKEN=${HF_TOKEN}

RUN apt-get update && apt-get install -y wget curl aria2 \
    && rm -rf /var/lib/apt/lists/*

# hf_xet = parallel chunked Hub downloads (required for large MiniMax / Qwen weights)
RUN pip install -U --no-cache-dir "huggingface_hub[hf_xet]" hf_xet hf_transfer
RUN pip install --no-cache-dir runpod websocket-client Pillow

ENV HF_HUB_DISABLE_XET=0
ENV HF_XET_HIGH_PERFORMANCE=1
ENV HF_HUB_ENABLE_HF_TRANSFER=0
ENV HF_HUB_DISABLE_TELEMETRY=1
# Scratch cache only — fetch_model.sh purges after every file so layers aren't 2× size
ENV HF_HOME=/tmp/hf_home
ENV HUGGINGFACE_HUB_CACHE=/tmp/hf_home/hub
ENV HF_HUB_CACHE=/tmp/hf_home/hub

WORKDIR /

# Latest ComfyUI required for MiniMaxH3ImageToVideo + ResolutionSelector
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git && \
    cd /ComfyUI && \
    pip install --no-cache-dir -r requirements.txt && \
    rm -rf /ComfyUI/.git

RUN cd /ComfyUI/custom_nodes && \
    git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager.git && \
    cd ComfyUI-Manager && pip install --no-cache-dir -r requirements.txt && \
    rm -rf /ComfyUI/custom_nodes/ComfyUI-Manager/.git

# R2V output (VHS_VideoCombine) + PathchSageAttentionKJ used by reference workflows
RUN cd /ComfyUI/custom_nodes && \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    (cd ComfyUI-VideoHelperSuite && pip install --no-cache-dir -r requirements.txt || true) && \
    rm -rf /ComfyUI/custom_nodes/ComfyUI-VideoHelperSuite/.git && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git && \
    (cd ComfyUI-KJNodes && pip install --no-cache-dir -r requirements.txt || true) && \
    rm -rf /ComfyUI/custom_nodes/ComfyUI-KJNodes/.git && \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git && \
    rm -rf /ComfyUI/custom_nodes/rgthree-comfy/.git

RUN mkdir -p \
    /ComfyUI/models/diffusion_models \
    /ComfyUI/models/text_encoders \
    /ComfyUI/models/vae \
    /ComfyUI/models/loras \
    /ComfyUI/input \
    /ComfyUI/output

COPY scripts/fetch_model.sh /usr/local/bin/fetch_model.sh
RUN chmod +x /usr/local/bin/fetch_model.sh

COPY extra_model_paths.yaml /ComfyUI/extra_model_paths.yaml

# Hub builds time out baking multi‑GB MiniMax/Qwen weights.
# Do NOT download models during `docker build` — entrypoint.sh resolve_model
# fetches (or links from /runpod-volume) at worker start. Local/dev builds can
# still pre-warm by running fetch_model.sh manually or attaching a volume.

# Final scrub — keep baked /ComfyUI/models only
RUN rm -rf /tmp/hf_home /root/.cache/huggingface /root/.cache/pip /var/tmp/* \
    && find /ComfyUI -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true

COPY . .
RUN chmod +x /entrypoint.sh \
    && cp -f scripts/fetch_model.sh /usr/local/bin/fetch_model.sh \
    && chmod +x /usr/local/bin/fetch_model.sh

CMD ["/entrypoint.sh"]
