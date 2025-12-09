#!/bin/bash
# Minimal provisioning script – NO big model downloads unless you explicitly add them
# Put this in your own GitHub repo, e.g.:
# https://raw.githubusercontent.com/yourusername/your-repo/main/default.sh

printf "\n=== Minimal ComfyUI provisioning (no heavy models) ===\n\n"

# Optional: install ComfyUI-Manager (highly recommended)
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    # add any other nodes you actually want here
)

# Only download tiny things or nothing at all
CHECKPOINT_MODELS=()        # leave empty → no SD1.5 / SDXL / Flux etc.
VAE_MODELS=()
LORA_MODELS=()
CONTROLNET_MODELS=()
ESRGAN_MODELS=()

# ──────── DO NOT EDIT BELOW THIS LINE ────────
source /opt/ai-dock/etc/environment.sh
source /opt/ai-dock/bin/venv-set.sh comfyui

provisioning_print_header() {
    printf "\nMinimal provisioning – only custom nodes, no large models\n\n"
}

provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        if [[ -d "$path" ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                echo "Updating $dir ..."
                (cd "$path" && git pull)
            fi
        else
            echo "Cloning $repo ..."
            git clone --depth 1 "$repo" "$path"
        fi
        [[ -f "$path/requirements.txt" ]] && "$COMFYUI_VENV_PIP" install -r "$path/requirements.txt"
    done
}

provisioning_print_header
provisioning_get_nodes
printf "\nProvisioning complete – starting ComfyUI\n\n"