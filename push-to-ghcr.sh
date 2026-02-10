#!/bin/bash

# Push image to GitHub Container Registry (ghcr.io)
# Usage: ./push-to-ghcr.sh [version]
# Example: ./push-to-ghcr.sh 1.0.0

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Read version number
if [ -f "version.txt" ]; then
    VERSION=$(cat version.txt | tr -d '[:space:]')
else
    echo -e "${RED}Error: version.txt file not found${NC}"
    exit 1
fi

# If parameter provided, use it as version
if [ ! -z "$1" ]; then
    VERSION=$1
fi

echo -e "${GREEN}=== Push Image to GitHub Container Registry ===${NC}"
echo -e "${YELLOW}Version: ${VERSION}${NC}"

# Check ghcr.io login status
echo -e "${YELLOW}Checking ghcr.io login status...${NC}"
if ! docker info 2>/dev/null | grep -q "ghcr.io"; then
    echo -e "${YELLOW}Please login to ghcr.io first:${NC}"
    echo -e "${YELLOW}docker login ghcr.io -u <GITHUB_USERNAME> -p <GITHUB_TOKEN>${NC}"
    read -p "Login now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter GitHub username: " GITHUB_USERNAME
        read -sp "Enter GitHub Token (PAT): " GITHUB_TOKEN
        echo
        echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
    else
        echo -e "${RED}Push cancelled${NC}"
        exit 1
    fi
fi

# Get GitHub username and repository name
read -p "Enter GitHub username [openclaw]: " GITHUB_USERNAME
GITHUB_USERNAME=${GITHUB_USERNAME:-openclaw}

read -p "Enter repository name [openclaw-gateway]: " REPO_NAME
REPO_NAME=${REPO_NAME:-openclaw-gateway}

# Clean input and convert to lowercase (ghcr.io requires lowercase)
GITHUB_USERNAME_LOWER=$(echo "$GITHUB_USERNAME" | xargs | tr 'A-Z' 'a-z')
REPO_NAME_LOWER=$(echo "$REPO_NAME" | xargs | tr 'A-Z' 'a-z')

# Image name
IMAGE_NAME="ghcr.io/${GITHUB_USERNAME_LOWER}/${REPO_NAME_LOWER}"

echo -e "${YELLOW}Image name: ${IMAGE_NAME}${NC}"

# Ask if image needs to be built
read -p "Build image? (y/n, default n): " BUILD_IMAGE
BUILD_IMAGE=$(echo "$BUILD_IMAGE" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

if [ "$BUILD_IMAGE" = "y" ] || [ "$BUILD_IMAGE" = "yes" ]; then
    # Build image
    echo -e "${GREEN}Building image...${NC}"
    docker build -t "${IMAGE_NAME}:${VERSION}" -t "${IMAGE_NAME}:latest" .
else
    # Ask for local image name
    read -p "Enter local image name [openclaw-gateway:latest]: " LOCAL_IMAGE
    LOCAL_IMAGE=${LOCAL_IMAGE:-openclaw-gateway:latest}
    # Remove whitespace
    LOCAL_IMAGE=$(echo "$LOCAL_IMAGE" | xargs)
    
    # Check if local image exists
    if ! docker image inspect "$LOCAL_IMAGE" > /dev/null 2>&1; then
        echo -e "${RED}Error: Local image ${LOCAL_IMAGE} not found${NC}"
        echo -e "${YELLOW}Available images:${NC}"
        docker images
        exit 1
    fi
    
    # Tag image
    echo -e "${GREEN}Tagging local image...${NC}"
    docker tag "$LOCAL_IMAGE" "${IMAGE_NAME}:${VERSION}"
    docker tag "$LOCAL_IMAGE" "${IMAGE_NAME}:latest"
fi

# Push image
echo -e "${GREEN}Pushing version tag: ${VERSION}${NC}"
docker push "${IMAGE_NAME}:${VERSION}"

echo -e "${GREEN}Pushing latest tag${NC}"
docker push "${IMAGE_NAME}:latest"

echo -e "${GREEN}=== Push Complete ===${NC}"
echo -e "${GREEN}Image URLs:${NC}"
echo -e "  ${IMAGE_NAME}:${VERSION}"
echo -e "  ${IMAGE_NAME}:latest"
echo -e "${GREEN}Pull commands:${NC}"
echo -e "  docker pull ${IMAGE_NAME}:${VERSION}"
echo -e "  docker pull ${IMAGE_NAME}:latest"
