# ComfyUI Docker Image with PyTorch
FROM nvidia/cuda:13.0.2-cudnn-runtime-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTORCH_VERSION=2.9.1 \
    COMFYUI_VERSION=v0.5.1 \
    WORKSPACE=/opt \
    PROVISIONING_SCRIPT=

# Container metadata
LABEL org.opencontainers.image.source=https://github.com/danielfarpoint/comfyui
LABEL org.opencontainers.image.description="ComfyUI with PyTorch $PYTORCH_VERSION"
LABEL maintainer="Daniel Farpoint"

# Install system dependencies including SSH
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    rclone \
    unzip \
    vim \
    tree \
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH for root passwordless login
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Create workspace directory
RUN mkdir -p ${WORKSPACE}
WORKDIR ${WORKSPACE}

# Create Python virtual environment
RUN python3.10 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install PyTorch 2.9.1 with CUDA 12.1 support
RUN pip install --no-cache-dir \
    torch==${PYTORCH_VERSION} \
    torchvision==0.24.1 \
    torchaudio==2.9.1 \
    --index-url https://download.pytorch.org/whl/cu126

# Clone ComfyUI at specific tag
RUN git clone --depth 1 --branch ${COMFYUI_VERSION} \
    https://github.com/comfyanonymous/ComfyUI.git ${WORKSPACE}/ComfyUI

# Install ComfyUI requirements
RUN pip install --no-cache-dir -r ${WORKSPACE}/ComfyUI/requirements.txt

# Reinstall tqdm to fix potential corruption
RUN pip install --no-cache-dir --force-reinstall --no-deps tqdm

# Create custom_nodes directory
RUN mkdir -p ${WORKSPACE}/ComfyUI/custom_nodes

# Install ComfyUI-Manager (tag 3.39)
RUN cd ${WORKSPACE}/ComfyUI/custom_nodes && \
    git clone --depth 1 --branch 3.39 \
    https://github.com/Comfy-Org/ComfyUI-Manager.git && \
    cd ComfyUI-Manager && \
    if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi

# Install ComfyUI-Login (main branch HEAD)
RUN cd ${WORKSPACE}/ComfyUI/custom_nodes && \
    git clone --depth 1 https://github.com/liusida/ComfyUI-Login.git && \
    cd ComfyUI-Login && \
    if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi

# Create models directories
RUN mkdir -p ${WORKSPACE}/ComfyUI/models/checkpoints \
    ${WORKSPACE}/ComfyUI/models/vae \
    ${WORKSPACE}/ComfyUI/models/loras \
    ${WORKSPACE}/ComfyUI/models/controlnet \
    ${WORKSPACE}/ComfyUI/models/clip \
    ${WORKSPACE}/ComfyUI/models/unet \
    ${WORKSPACE}/ComfyUI/input \
    ${WORKSPACE}/ComfyUI/output

# Expose ComfyUI and SSH ports
EXPOSE 8188 22

# Set working directory to ComfyUI
WORKDIR ${WORKSPACE}/ComfyUI

# Create startup script
RUN echo '#!/bin/bash\n\
# Start SSH daemon in background\n\
/usr/sbin/sshd -D &\n\
\n\
# Handle provisioning script if provided\n\
PROVISIONING_SCRIPT="${PROVISIONING_SCRIPT:-}"\n\
\n\
if [ -n "$PROVISIONING_SCRIPT" ]; then\n\
    echo "================================================="\n\
    echo "Provisioning script URL detected: $PROVISIONING_SCRIPT"\n\
    echo "================================================="\n\
    \n\
    # Try to download the script\n\
    if curl -f -L -o /tmp/provisioning.sh "$PROVISIONING_SCRIPT" 2>/dev/null; then\n\
        echo "✓ Successfully downloaded provisioning script"\n\
        chmod +x /tmp/provisioning.sh\n\
        echo "Running provisioning script..."\n\
        if bash /tmp/provisioning.sh; then\n\
            echo "✓ Provisioning script completed successfully"\n\
        else\n\
            echo "⚠ WARNING: Provisioning script failed with exit code $?"\n\
            echo "⚠ Continuing anyway..."\n\
        fi\n\
        rm -f /tmp/provisioning.sh\n\
    elif wget -q -O /tmp/provisioning.sh "$PROVISIONING_SCRIPT" 2>/dev/null; then\n\
        echo "✓ Successfully downloaded provisioning script (via wget)"\n\
        chmod +x /tmp/provisioning.sh\n\
        echo "Running provisioning script..."\n\
        if bash /tmp/provisioning.sh; then\n\
            echo "✓ Provisioning script completed successfully"\n\
        else\n\
            echo "⚠ WARNING: Provisioning script failed with exit code $?"\n\
            echo "⚠ Continuing anyway..."\n\
        fi\n\
        rm -f /tmp/provisioning.sh\n\
    else\n\
        echo "================================================="\n\
        echo "❌ ERROR: Failed to download provisioning script!"\n\
        echo "❌ URL: $PROVISIONING_SCRIPT"\n\
        echo "❌ "\n\
        echo "❌ Possible reasons:"\n\
        echo "❌   - URL is incorrect or malformed"\n\
        echo "❌   - File does not exist (404)"\n\
        echo "❌   - Network/DNS issues"\n\
        echo "❌   - Server is down or unreachable"\n\
        echo "❌   - Requires authentication"\n\
        echo "❌ "\n\
        echo "❌ CONTINUING WITHOUT PROVISIONING..."\n\
        echo "================================================="\n\
    fi\n\
else\n\
    echo "No provisioning script specified, skipping..."\n\
fi\n\
\n\
# Start the main application\n\
exec python main.py --listen 0.0.0.0 --port 8188' > /start.sh && \
    chmod +x /start.sh

# Default command to start SSH and ComfyUI
CMD ["/start.sh"]