# ComfyUI LoRAs

Weights are **not** stored in git.

| File | When | Notes |
| --- | --- | --- |
| `minimax_h3_fl2v_turbo_8step_…` | Docker bake | T2V/I2V turbo |
| `minimax_h3_ref2v_turbo_4step_…` | Docker bake | R2V turbo |
| MysticXXX / Myst style | Job runtime | `lora_url` → Hugging Face resolve URL + optional `hf_token` / `HF_TOKEN` |
| Realism People | Job runtime | `realism_lora: true` → Hub download |

**Do not** bake style LoRAs into Hub builds. **Do** bake MiniMax base weights (see root Dockerfile). Never ship a slim image that downloads the multi‑GB H3 stack on worker start.

Example resolve URL:

`https://huggingface.co/lynaNSFW/mysticxxx_MM_H3/resolve/main/MysticXXX_MMH3-V4.safetensors`
