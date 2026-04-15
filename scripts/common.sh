#!/bin/bash
# Common setup shared by all build scripts.
# Source this, don't execute it: . "$(dirname "$0")/common.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/../build}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/../output}"

# Platform detection
IS_WASM=0
if command -v emcmake &> /dev/null && [ "${WASM_BUILD:-0}" = "1" ]; then
    IS_WASM=1
    PLATFORM="wasm"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    ARCH=$(uname -m)
    if [ -n "$MACOS_ARCH" ]; then ARCH="$MACOS_ARCH"; fi
    PLATFORM="darwin-$ARCH"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux-$(uname -m)"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    # MSYS2 uname -m reports x86_64 even on ARM64 (runs under emulation).
    # Use PROCESSOR_ARCHITECTURE to detect the real hardware.
    if [ "${PROCESSOR_ARCHITECTURE}" = "ARM64" ] || [ "${PROCESSOR_ARCHITEW6432}" = "ARM64" ]; then
        PLATFORM="windows-aarch64"
    else
        PLATFORM="windows-$(uname -m)"
    fi
    export PATH="/mingw64/bin:/ucrt64/bin:$PATH"
fi
PLATFORM=$(echo "$PLATFORM" | sed 's/x86_64/amd64/g' | sed 's/aarch64/arm64/g')

# Parallelism
if [[ "$OSTYPE" == "darwin"* ]]; then
    NCPU=$(($(sysctl -n hw.ncpu) / 2))
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    NCPU=2
else
    NCPU=2
fi
if [ "$NCPU" -lt 1 ]; then NCPU=1; fi

# Find cmake
CMAKE=$(command -v cmake 2>/dev/null || true)
if [ -z "$CMAKE" ]; then
    for p in /ucrt64/bin/cmake.exe /mingw64/bin/cmake.exe; do
        if [ -x "$p" ]; then CMAKE="$p"; break; fi
    done
fi

# Find python
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)
if [ -z "$PYTHON" ]; then
    for p in /ucrt64/bin/python3.exe /ucrt64/bin/python.exe /mingw64/bin/python3.exe /mingw64/bin/python.exe; do
        if [ -x "$p" ]; then PYTHON="$p"; break; fi
    done
fi

# Architecture flags for cmake
CMAKE_OSX_ARCH_FLAG=""
CMAKE_GENERATOR=""
if [ -n "$MACOS_ARCH" ]; then
    CMAKE_OSX_ARCH_FLAG="-DCMAKE_OSX_ARCHITECTURES=$MACOS_ARCH"
fi
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    CMAKE_GENERATOR="-G Ninja"
fi

# Namespace flags — all LLVM-based builds use these
NS_FLAGS="-Dllvm=mlvm -Dclang=mlang"
