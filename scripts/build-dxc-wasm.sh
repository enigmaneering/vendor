#!/bin/bash
set -e

# Build script for DXC (DirectX Shader Compiler) — WebAssembly target
# Clones upstream DXC, applies Emscripten compatibility fixes, and builds
# a dxc.js + dxc.wasm pair that can be invoked via Node.js.
#
# Requires: Emscripten SDK (emcmake/emmake on PATH)
#
# The Emscripten fixes (patches/dxc-emscripten.patch) address five categories:
#   1. Host triple detection — teach CMake that Emscripten is wasm32
#   2. Cross-compilation — let the build bootstrap native TableGen tools
#   3. Dynamic loading — Emscripten can't dlopen; bind DXC symbols directly
#   4. C++ stdlib — skip std::is_nothrow_constructible specialization
#   5. Linker flags — add -sNODERAWFS=1 for Node.js filesystem access

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/../build}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/../output}"
PLATFORM="wasm"

# Query GitHub for latest stable DXC release if version not specified
if [ -z "$DXC_VERSION" ]; then
    echo "Querying GitHub for latest DXC release..."
    DXC_VERSION=$(curl -s https://api.github.com/repos/microsoft/DirectXShaderCompiler/releases/latest \
        | grep '"tag_name"' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    if [ -z "$DXC_VERSION" ]; then
        echo "Warning: Could not determine latest version, falling back to v1.8.2407"
        DXC_VERSION="v1.8.2407"
    fi
fi

echo "Building DXC $DXC_VERSION for WebAssembly..."

# Verify Emscripten is available
if ! command -v emcmake &> /dev/null; then
    echo "Error: emcmake not found. Install the Emscripten SDK first."
    exit 1
fi

# Verify patch file exists
PATCH_FILE="$SCRIPT_DIR/../patches/dxc-emscripten.patch"
if [ ! -f "$PATCH_FILE" ]; then
    echo "Error: Emscripten patch not found at $PATCH_FILE"
    exit 1
fi

# DXC/LLVM is massive — limit parallelism to avoid OOM
NCPU=2

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clone DXC
if [ ! -d "dxc-wasm-src" ]; then
    echo "Cloning DirectXShaderCompiler $DXC_VERSION..."
    git clone --depth 1 --branch "$DXC_VERSION" \
        https://github.com/microsoft/DirectXShaderCompiler.git dxc-wasm-src
fi

cd dxc-wasm-src

# Initialize submodules
if [ ! -f "external/SPIRV-Headers/README.md" ]; then
    echo "Initializing submodules..."
    GIT_TERMINAL_PROMPT=0 git submodule update --init --recursive --depth 1
fi

# Verify license exists (fail fast)
echo "Verifying license file..."
if [ ! -f "LICENSE.TXT" ] && [ ! -f "LICENSE.txt" ] && [ ! -f "LICENSE" ]; then
    echo "Error: LICENSE not found in DXC repository"
    exit 1
fi
echo "License file verified"

# Patch CMakeLists.txt for newer CMake compatibility (same as native build)
echo "Patching for CMake compatibility..."
sed -i.bak '/cmake_policy(SET CMP0051 OLD)/d' CMakeLists.txt
if [ -f tools/clang/CMakeLists.txt ]; then
    sed -i.bak 's/cmake_minimum_required(VERSION [0-9.]*)/cmake_minimum_required(VERSION 3.5)/' tools/clang/CMakeLists.txt
fi
find . -name "*.bak" -delete

# Apply Emscripten compatibility fixes
echo "Applying Emscripten compatibility patches..."
git apply "$PATCH_FILE"
echo "Emscripten patches applied successfully"

# Configure DXC for WebAssembly
mkdir -p build
cd build

echo "Configuring DXC for WebAssembly..."
emcmake cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_USE_HOST_TOOLS=OFF \
    -DLLVM_ENABLE_EH=ON \
    -DLLVM_ENABLE_RTTI=ON \
    -DENABLE_SPIRV_CODEGEN=ON \
    -DSPIRV_BUILD_TESTS=OFF \
    -DCLANG_ENABLE_ARCMT=OFF \
    -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_TARGETS_TO_BUILD="" \
    -DHLSL_ENABLE_ANALYZE=OFF \
    -DHLSL_BUILD_DXILCONV=OFF \
    -DHLSL_INCLUDE_TESTS=OFF \
    -DCLANG_INCLUDE_TESTS=OFF \
    -DHAVE_CXX_ATOMICS_WITHOUT_LIB=TRUE \
    -DHAVE_CXX_ATOMICS64_WITHOUT_LIB=TRUE

echo "Building DXC for WebAssembly (this may take 20-40 minutes)..."
emmake cmake --build . --config Release --target dxc -j$NCPU

# Package output
PACKAGE_DIR="$OUTPUT_DIR/dxc-$PLATFORM"
mkdir -p "$PACKAGE_DIR/bin"

echo "Packaging DXC WASM..."
# Emscripten produces a .js loader and .wasm binary
find bin -name "dxc.js" -exec cp {} "$PACKAGE_DIR/bin/" \; 2>/dev/null || true
find bin -name "dxc.wasm" -exec cp {} "$PACKAGE_DIR/bin/" \; 2>/dev/null || true

# Verify we got the outputs
if [ ! -f "$PACKAGE_DIR/bin/dxc.js" ] || [ ! -f "$PACKAGE_DIR/bin/dxc.wasm" ]; then
    echo "Error: Expected dxc.js and dxc.wasm not found in build output"
    echo "Build output contents:"
    find bin -type f -name "dxc*" 2>/dev/null || echo "  (no dxc files found in bin/)"
    ls -la bin/ 2>/dev/null || true
    exit 1
fi

# Copy licenses - preserve structure from source repo
echo "Packaging licenses..."
cd "$BUILD_DIR/dxc-wasm-src"
mkdir -p "$PACKAGE_DIR/licenses/dxc/LICENSES"

# Main license
if [ -f "LICENSE.TXT" ]; then
    cp "LICENSE.TXT" "$PACKAGE_DIR/licenses/dxc/LICENSE.TXT"
elif [ -f "LICENSE.txt" ]; then
    cp "LICENSE.txt" "$PACKAGE_DIR/licenses/dxc/LICENSE.txt"
else
    cp "LICENSE" "$PACKAGE_DIR/licenses/dxc/LICENSE"
fi

# Additional component licenses
if [ -f "lib/DxilCompression/LICENSE.TXT" ]; then
    cp "lib/DxilCompression/LICENSE.TXT" "$PACKAGE_DIR/licenses/dxc/LICENSES/DxilCompression-LICENSE.TXT"
fi

# Create archive
cd "$OUTPUT_DIR"
tar -czf "dxc-${PLATFORM}.tar.gz" "dxc-$PLATFORM"
echo "Created: dxc-${PLATFORM}.tar.gz"

echo "Build complete!"
