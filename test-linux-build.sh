#!/bin/bash
set -e

# Test script to build DXC locally in a Docker container matching GitHub runners
# This mimics the ubuntu-latest GitHub runner environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building in Ubuntu 22.04 container (matches ubuntu-latest runner)..."

docker run --rm \
  -v "$SCRIPT_DIR:/workspace" \
  -w /workspace \
  ubuntu:22.04 \
  bash -c '
    set -e

    echo "Installing dependencies..."
    apt-get update
    apt-get install -y gcc-11 g++-11 cmake git curl tar python3

    # Set GCC-11 as default
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 100
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 100

    echo "Running DXC build script..."
    chmod +x scripts/build-dxc.sh

    BUILD_DIR="/tmp/build" \
    OUTPUT_DIR="/tmp/output" \
    bash scripts/build-dxc.sh

    echo ""
    echo "Build completed successfully!"
    ls -lh /tmp/output/
  '

echo ""
echo "Local test complete!"
