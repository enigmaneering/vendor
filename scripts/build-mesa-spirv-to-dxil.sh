#!/bin/bash
set -e

# Build script for Mesa's spirv-to-dxil library.
#
# Mesa's spirv-to-dxil is a standalone, MIT-licensed SPIR-V → DXIL
# compiler used by Mesa Dozen (Vulkan-on-D3D12) and microsoft-clc
# (OpenCL on D3D12).  It's NIR-based — no LLVM dependency — and
# exposes a clean C API (spirv_to_dxil.h) suitable for embedding.
#
# We use it on the libmental side as the SPIR-V → DXIL stage of the
# D3D12 backend, replacing the old DXC subprocess invocation.  Result:
# D3D12 works without bringing DXC back as a separate runtime
# dependency, AND we skip the spirv-cross HLSL roundtrip entirely.
#
# Output: spirv-to-dxil-{platform}.tar.gz with libspirv_to_dxil.a +
# spirv_to_dxil.h + license.
#
# Platform coverage: D3D12 is Windows-only at runtime, so we ship for
# Windows amd64 + arm64 (Surface Pro X / Snapdragon X Elite are
# first-class D3D12 hosts on ARM64).  Linux amd64 + arm64 also build
# this as build-validation cover — the same code that compiles on
# Windows-MinGW also compiles on Linux glibc, and a green Linux build
# catches portability regressions before the Windows runner gets to
# them.  macOS and WASM are skipped — Mesa's microsoft/compiler
# subtree includes <malloc.h> (a Linux/Windows-ism) that doesn't
# exist on Apple, and there's no D3D12 on Apple/WASM anyway.

. "$(dirname "$0")/common.sh"

case "$PLATFORM" in
    darwin-*|wasm)
        echo "Skipping spirv-to-dxil for $PLATFORM —"
        echo "  Mesa's microsoft/compiler subtree isn't macOS-portable, and"
        echo "  D3D12 (the only consumer) is Windows-only at runtime."
        echo "  This is intentional: produce no artifact for this platform."
        exit 0
        ;;
esac

echo "Building Mesa spirv-to-dxil for $PLATFORM ($NCPU jobs)..."

# Pin to a recent stable Mesa release.  Bump after testing — Mesa's
# spirv-to-dxil API has been stable across 24.x → 26.x; bumps mostly
# bring NIR optimizer improvements + DXIL feature coverage updates.
MESA_VERSION="${MESA_VERSION:-mesa-26.0.6}"

# Tool discovery: meson and ninja are required.  Mesa's Python build-
# helpers also need mako + pyyaml.  CI runners typically pre-install
# meson/ninja; we pip-install the python modules defensively.
if ! command -v meson >/dev/null 2>&1; then
    echo "Error: meson is required (apt: meson, pacman: mingw-w64-x86_64-meson)"
    exit 1
fi
if ! command -v ninja >/dev/null 2>&1; then
    echo "Error: ninja is required (apt: ninja-build, pacman: mingw-w64-x86_64-ninja)"
    exit 1
fi
if [ -z "$PYTHON" ]; then
    echo "Error: python3 not found"
    exit 1
fi

# Mesa's meson scripts require three Python packages even with all
# drivers disabled:
#   mako       — templating (clc / nir-isa generators)
#   pyyaml     — Intel ISA table parser, ICD JSON generation
#   packaging  — load-bearing for Mesa's version comparisons.  Mesa's
#                meson.build tries `from packaging.version import Version`
#                with `from distutils.version import StrictVersion` as
#                fallback — but distutils was REMOVED from the Python
#                stdlib in 3.12, so on any modern Python (Ubuntu 24.04
#                ships 3.12, MSYS2 ships 3.14) the fallback fails and
#                the whole meson configure aborts unless `packaging`
#                is installed.
# --break-system-packages is needed on Debian/Ubuntu post-PEP-668;
# --user keeps it scoped to the runner.  The MSYS2/CI workflow
# pre-installs the equivalent pacman packages so this pip call is a
# no-op on Windows; the install here is the safety net for Linux and
# manual local invocations.
$PYTHON -m pip install --user --break-system-packages mako pyyaml packaging \
    >/dev/null 2>&1 || \
    $PYTHON -m pip install --user mako pyyaml packaging >/dev/null 2>&1 || \
    echo "(pip install of mako/pyyaml/packaging may have failed — meson configure will tell us)"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clone Mesa.  Shallow + tag-pinned — we don't need history.
if [ ! -d "mesa-$MESA_VERSION" ]; then
    echo "Cloning Mesa $MESA_VERSION..."
    git clone --depth 1 --branch "$MESA_VERSION" \
        https://gitlab.freedesktop.org/mesa/mesa.git "mesa-$MESA_VERSION"
fi
cd "mesa-$MESA_VERSION"

# Verify license is in the source tree before we waste time building
# (fail fast — same pattern as build-glslang.sh / build-clspv.sh /
# build-spirv-llvm-translator.sh).  If Mesa ever moves docs/license.rst
# we want to know at the start of the build, not after the configure /
# compile time has been spent.
if [ ! -f "docs/license.rst" ]; then
    echo "Error: docs/license.rst not found in Mesa $MESA_VERSION source tree"
    exit 1
fi
# Sanity check: spirv_to_dxil sources must also be present at the
# expected location — otherwise the meson target name we ninja-build
# below won't exist.
if [ ! -f "src/microsoft/spirv_to_dxil/spirv_to_dxil.h" ]; then
    echo "Error: src/microsoft/spirv_to_dxil/spirv_to_dxil.h not found"
    echo "       Mesa $MESA_VERSION may have relocated the spirv-to-dxil tree"
    exit 1
fi

# Configure with EVERYTHING off except spirv-to-dxil.  Each disabled
# option below is one thing we don't want pulling in transitive deps:
#
#   vulkan-drivers / gallium-drivers — full graphics drivers, MB of code
#   microsoft-clc                    — OpenCL-on-D3D12 (uses spirv-to-dxil
#                                       as a building block, but we want
#                                       to call spirv-to-dxil directly)
#   gles1 / gles2 / opengl           — OpenGL state trackers
#   shared-glapi                     — GL dispatch
#   vulkan-layers                    — Vulkan validation/etc layers
#   video-codecs                     — H.264/265/VP9/AV1 codec hooks
#   platforms                        — windowing system integration
#   build-tests                      — Mesa's test suite
#   default_library=static           — we want libspirv_to_dxil.a
#
# Mesa still has implicit deps (zlib, pthread, etc.) that meson finds
# from the host toolchain — those come from the OS (linux/mingw) and
# don't need explicit handling here.
mkdir -p build
meson setup build \
    --buildtype=release \
    -Dspirv-to-dxil=true \
    -Dvulkan-drivers= \
    -Dgallium-drivers= \
    -Dmicrosoft-clc=disabled \
    -Dvideo-codecs= \
    -Dplatforms= \
    -Dgles1=disabled \
    -Dgles2=disabled \
    -Dopengl=false \
    -Dshared-glapi=disabled \
    -Dvulkan-layers= \
    -Dlmsensors=disabled \
    -Dvalgrind=disabled \
    -Dzstd=disabled \
    -Dbuild-tests=false \
    -Ddefault_library=static

# Build only the static archive target.  ninja will pull in just its
# transitive deps (libnir.a, libvtn.a, libdxil_compiler.a, etc.) and
# none of the unrelated Mesa code.
ninja -C build -j"$NCPU" src/microsoft/spirv_to_dxil/libspirv_to_dxil.a

# Package
PACKAGE_DIR="$OUTPUT_DIR/spirv-to-dxil-$PLATFORM"
mkdir -p "$PACKAGE_DIR/lib" "$PACKAGE_DIR/include"

echo "Packaging spirv-to-dxil (static archive)..."

# The actual library — a single .a containing spirv-to-dxil's code
# AND its meson-bundled dependencies (libnir.a, libvtn.a,
# libdxil_compiler.a, etc., merged into the archive).
cp build/src/microsoft/spirv_to_dxil/libspirv_to_dxil.a "$PACKAGE_DIR/lib/"

# Public header — the only thing libmental's CMakeLists needs to
# include.  spirv_to_dxil.h is self-contained and pulls in its own
# small dependency surface (stdint, stdbool).
cp src/microsoft/spirv_to_dxil/spirv_to_dxil.h "$PACKAGE_DIR/include/"

# Mesa's primary license text — preserved with its original .rst
# extension so consumers can match it against the upstream file we
# verify in the verify-licenses workflow step.  spirv_to_dxil itself
# is MIT (per the SPDX header in spirv_to_dxil.c), but Mesa's
# umbrella docs/license.rst enumerates the per-component licenses
# including MIT for spirv-to-dxil.  The fail-fast guard at the top
# of this script ensures docs/license.rst exists before we get here.
cp docs/license.rst "$PACKAGE_DIR/LICENSE.rst"

# Sanity check — fail loud if the static archive is missing.
if [ ! -f "$PACKAGE_DIR/lib/libspirv_to_dxil.a" ]; then
    echo "Error: libspirv_to_dxil.a was not produced by Mesa's build."
    echo "Build tree contents under microsoft/spirv_to_dxil:"
    find build/src/microsoft/spirv_to_dxil -type f 2>/dev/null
    exit 1
fi
if [ ! -f "$PACKAGE_DIR/include/spirv_to_dxil.h" ]; then
    echo "Error: spirv_to_dxil.h is missing from the package"
    exit 1
fi

# Report archive size — size verification is informational; libmental's
# build doesn't gate on a particular figure.  Range we expect: ~5-15 MB.
SIZE=$(stat -f%z "$PACKAGE_DIR/lib/libspirv_to_dxil.a" 2>/dev/null || \
       stat -c%s "$PACKAGE_DIR/lib/libspirv_to_dxil.a" 2>/dev/null || \
       echo "unknown")
echo "libspirv_to_dxil.a: $SIZE bytes"

cd "$OUTPUT_DIR"
tar -czf "spirv-to-dxil-${PLATFORM}.tar.gz" "spirv-to-dxil-$PLATFORM"
echo "Created: spirv-to-dxil-${PLATFORM}.tar.gz"
echo "Build complete!"
