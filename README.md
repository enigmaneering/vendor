<picture>
    <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/enigmaneering/assets/refs/heads/main/redistributables/redistributables_light.png">
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/enigmaneering/assets/refs/heads/main/redistributables/redistributables_dark.png">
    <img alt="redistributables logo" src="https://raw.githubusercontent.com/enigmaneering/assets/refs/heads/main/redistributables/redistributables_light.png" >
</picture>

This repository releases pre-built tools for [libmental](https://git.enigmaneering.org/mental). All tools are as faithful of upstream builds as possible
across 7 targets (6 native + WebAssembly).

## Tools

| Tool | Purpose | Source |
|------|---------|--------|
| **glslang** | GLSL/ESSL to SPIR-V (includes SPIRV-Tools) | [Khronos](https://github.com/KhronosGroup/glslang) |
| **SPIRV-Cross** | SPIR-V to GLSL/HLSL/MSL | [Khronos](https://github.com/KhronosGroup/SPIRV-Cross) |
| **spirv-to-dxil** | SPIR-V to DXIL (D3D12 backend; carve-out of Mesa) | [Mesa](https://gitlab.freedesktop.org/mesa/mesa) |
| **Naga** | WGSL to/from SPIR-V (shared library via FFI) | [gfx-rs](https://github.com/gfx-rs/wgpu) |
| **wgpu-native** | WebGPU runtime (Metal/Vulkan/D3D12/OpenGL) | [gfx-rs](https://github.com/gfx-rs/wgpu-native) |
| **LLVM** | LLVM + Clang (NVPTX, AMDGPU, SPIRV experimental backends) | [LLVM](https://github.com/llvm/llvm-project) |
| **clspv** | OpenCL C to Vulkan SPIR-V | [Google](https://github.com/google/clspv) |
| **SPIRV-LLVM-Translator** | SPIR-V ↔ LLVM IR bridge | [Khronos](https://github.com/KhronosGroup/SPIRV-LLVM-Translator) |

`spirv-to-dxil` is a carve-out of Mesa: we build only the
`src/microsoft/spirv_to_dxil` library + its NIR / `dxil_compiler`
dependencies, not the full driver stack.  MIT-licensed, NIR-based
(no LLVM dependency), used by Mesa's Dozen driver (Vulkan-on-D3D12)
and `microsoft-clc` (OpenCL on D3D12).  libmental's D3D12 backend
feeds SPIR-V directly to it, replacing the older HLSL → DXIL via
DXC subprocess path.  Shipped only for **Linux and Windows** targets:
macOS doesn't have a D3D12 backend at runtime, and Mesa's
`microsoft/compiler` headers (`<malloc.h>`, etc.) aren't
macOS-portable anyway.

## Platforms

All tools except `spirv-to-dxil` are provided for:
- macOS ARM64 / x86_64
- Linux x86_64 / ARM64
- Windows x86_64 / ARM64
- WebAssembly

`spirv-to-dxil` ships for **Linux x86_64 / ARM64 and Windows
x86_64 / ARM64** — D3D12 is Windows-only at runtime, so it has no
consumer on macOS or WASM, and Mesa's microsoft/compiler subtree
isn't portable to those platforms anyway.  Windows ARM64 builds
natively on the `windows-11-arm` GitHub runner via MSYS2's
CLANGARM64 subsystem.

## License

All artifacts have open source licenses, which are verified on every build and packaged alongside each.

If any of the licenses change underneath us, a nightly check will alert us to address it at that time.

## Windows Note

Our Windows artifacts are PE/COFF DLLs built via MSYS2 UCRT64 (GCC / MinGW-w64 family), not MSVC — they
link against ucrtbase.dll (the Universal CRT) and ship with GCC-style .dll.a import libraries rather than
MSVC .lib files. Consumers need a UCRT-family toolchain (MSYS2, MinGW-w64 UCRT, or clang in UCRT mode);
plain MSVC can't link them directly due to the CRT coupling and import-lib format differences.

There are so many reasons for this, mostly from interoperability perspectives.