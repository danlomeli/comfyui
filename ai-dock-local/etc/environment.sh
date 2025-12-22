# BUILDTIME INSTRUCTIONS
if [[ ! -f ~/.gitconfig ]]; then
    git config --global --add safe.directory "*"
fi

# RUNTIME INSTRUCTIONS


export SYNCTHING_VERSION='1.27.10'
export NVM_DIR='/opt/nvm'
source /opt/nvm/nvm.sh
source /opt/nvm/bash_completion
export CUDA_VERSION='12.1.1'
export CUDA_LEVEL='base'
