#!/bin/bash
set -e

# Build SPIRV-LLVM-Translator against llvm-mlvm (namespaced LLVM).
# Bridges SPIR-V ↔ LLVM IR.
# Requires: llvm-mlvm artifact (set LLVM_MLVM_DIR)

. "$(dirname "$0")/common.sh"

echo "Building spirv-llvm-translator-mlvm for $PLATFORM ($NCPU jobs)..."

if [ -z "$CMAKE" ]; then echo "Error: cmake not found"; exit 1; fi

LLVM_MLVM="${LLVM_MLVM_DIR:-$BUILD_DIR/llvm-project/build}"
if [ ! -d "$LLVM_MLVM/lib/cmake/llvm" ]; then
    echo "Error: llvm-mlvm not found at $LLVM_MLVM"
    exit 1
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [ ! -d "SPIRV-LLVM-Translator" ]; then
    echo "Cloning SPIRV-LLVM-Translator..."
    git clone --depth 1 https://github.com/KhronosGroup/SPIRV-LLVM-Translator.git
fi

cd SPIRV-LLVM-Translator
if [ ! -f "LICENSE.TXT" ]; then echo "Error: LICENSE.TXT not found"; exit 1; fi

mkdir -p build
cd build

if [ "$IS_WASM" -eq 1 ]; then
    CMAKE_CMD="emcmake $CMAKE"
    MAKE_CMD="emmake $CMAKE"
    SHARED=OFF
else
    CMAKE_CMD="$CMAKE"
    MAKE_CMD="$CMAKE"
    SHARED=ON
fi

$CMAKE_CMD .. \
    $CMAKE_GENERATOR \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_C_FLAGS="$NS_FLAGS" \
    -DCMAKE_CXX_FLAGS="$NS_FLAGS" \
    -DLLVM_DIR="$LLVM_MLVM/lib/cmake/llvm" \
    -DBUILD_SHARED_LIBS=$SHARED \
    -DLLVM_INCLUDE_TESTS=OFF

$MAKE_CMD --build . --config Release -j$NCPU

# Package
PACKAGE_DIR="$OUTPUT_DIR/spirv-llvm-translator-mlvm-$PLATFORM"
mkdir -p "$PACKAGE_DIR/lib" "$PACKAGE_DIR/include"

echo "Packaging spirv-llvm-translator-mlvm..."
if [ "$IS_WASM" -eq 1 ]; then
    find lib -name "*.a" | while read f; do cp "$f" "$PACKAGE_DIR/lib/"; done
elif [[ "$OSTYPE" == "darwin"* ]]; then
    find lib -name "libLLVMSPIRVLib*.dylib" | while read f; do cp "$f" "$PACKAGE_DIR/lib/"; done
else
    find lib -name "libLLVMSPIRVLib*.so*" | while read f; do cp -P "$f" "$PACKAGE_DIR/lib/"; done
fi

cp -r ../include/LLVMSPIRVLib.h "$PACKAGE_DIR/include/" 2>/dev/null || true
cp -r ../include/LLVMSPIRVLib "$PACKAGE_DIR/include/" 2>/dev/null || true

cp ../LICENSE.TXT "$PACKAGE_DIR/LICENSE.TXT"

cd "$OUTPUT_DIR"
tar -czf "spirv-llvm-translator-mlvm-${PLATFORM}.tar.gz" "spirv-llvm-translator-mlvm-$PLATFORM"
echo "Created: spirv-llvm-translator-mlvm-${PLATFORM}.tar.gz"
echo "Build complete!"
