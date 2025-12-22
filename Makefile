# Makefile for ComfyUI Docker Image
# Docker Hub repository
PYTORCH_VERSION ?= 2.9.1
COMFYUI_VERSION ?= v0.3.76
DOCKER_REPO = danielfarpoint/comfyui
DOCKER_TAG = latest
IMAGE_NAME = $(DOCKER_REPO):$(DOCKER_TAG)

# Additional tags
PYTORCH_TAG = pytorch-$(PYTORCH_VERSION)
COMFYUI_TAG = comfyui-$(COMFYUI_VERSION)
FULL_TAG = $(DOCKER_REPO):$(PYTORCH_TAG)-$(COMFYUI_TAG)

.PHONY: help build build-no-cache push pull run stop clean test all

help:
	@echo "ComfyUI Docker Management"
	@echo "========================="
	@echo "make build         - Build the Docker image"
	@echo "make build-no-cache- Build without using cache"
	@echo "make push          - Push image to Docker Hub"
	@echo "make pull          - Pull image from Docker Hub"
	@echo "make run           - Run the container"
	@echo "make stop          - Stop the container"
	@echo "make clean         - Remove container and image"
	@echo "make login         - Login to Docker Hub"
	@echo "make test          - Test the built image"
	@echo "make all           - Build, tag, and push"
	@echo ""
	@echo "Current image: $(IMAGE_NAME)"

build:
	@echo "Building Docker image: $(IMAGE_NAME)"
	docker build \
		--build-arg PYTORCH_VERSION=$(PYTORCH_VERSION) \
		--build-arg COMFYUI_VERSION=$(COMFYUI_VERSION) \
		-t $(IMAGE_NAME) .
	@echo "Tagging with additional tags..."
	docker tag $(IMAGE_NAME) $(FULL_TAG)
	@echo "Build complete!"

build-no-cache:
	@echo "Building Docker image without cache: $(IMAGE_NAME)"
	docker build --no-cache \
		--build-arg PYTORCH_VERSION=$(PYTORCH_VERSION) \
		--build-arg COMFYUI_VERSION=$(COMFYUI_VERSION) \
		-t $(IMAGE_NAME) .
	docker tag $(IMAGE_NAME) $(FULL_TAG)
	@echo "Build complete!"

push:
	@echo "Pushing $(IMAGE_NAME) to Docker Hub..."
	@echo $$DOCKERHUB_READ_WRITE_ONLY_PAT | docker login docker.io -u $$DOCKERHUB_USERNAME --password-stdin && docker push $(IMAGE_NAME)
	@echo "Pushing $(FULL_TAG) to Docker Hub..."
	@echo $$DOCKERHUB_READ_WRITE_ONLY_PAT | docker login docker.io -u $$DOCKERHUB_USERNAME --password-stdin && docker push $(FULL_TAG)
	docker push $(FULL_TAG)
	@echo "Push complete!"

pull:
	@echo "Pulling $(IMAGE_NAME) from Docker Hub..."
	docker pull $(IMAGE_NAME)

run:
	@echo "Starting ComfyUI container with image: $(IMAGE)"
	IMAGE=$(FULL_TAG) docker compose up -d
	@echo "Container started! Access ComfyUI at http://localhost:8188"

stop:
	@echo "Stopping ComfyUI container..."
	IMAGE=$(FULL_TAG) docker compose down

restart:
	@echo "Restarting ComfyUI container..."
	IMAGE=$(FULL_TAG) docker compose restart

logs:
	@echo "Showing container logs..."
	IMAGE=$(FULL_TAG) docker compose logs -f

clean:
	@echo "Stopping and removing container..."
	IMAGE=$(FULL_TAG) docker compose down -v
	@echo "Removing Docker image..."
	docker rmi $(IMAGE_NAME) $(FULL_TAG) || true
	@echo "Cleanup complete!"

test:
	@echo "Testing Docker image..."
	docker run --rm --gpus all $(IMAGE_NAME) python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}')"

# Build directories if they don't exist
setup:
	@echo "Creating workspace directories..."
	mkdir -p workspace models/checkpoints models/vae models/loras models/controlnet input output
	@echo "Directories created!"

# Complete workflow: build, push, and run
all: build push
	@echo "Build and push complete!"
	@echo "Run 'make run' to start the container"

# Development workflow
dev: build run
	@echo "Development environment started!"

# Show running containers
ps:
	IMAGE=$(FULL_TAG) docker compose ps

# Execute shell in running container
shell:
	IMAGE=$(FULL_TAG) docker compose exec comfyui /bin/bash

# Update to latest versions and rebuild
update:
	@echo "Pulling latest changes and rebuilding..."
	git pull
	$(MAKE) build-no-cache
	@echo "Update complete!"