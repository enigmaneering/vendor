# Redistributables

Pre-built shader compilation and GPU compute toolchain for [libmental](https://git.enigmaneering.org/enigmaneering/mental). All tools are built from source across 7 targets (6 native + WebAssembly).

## Tools

| Tool | Purpose | Source |
|------|---------|--------|
| **glslang** | GLSL/ESSL to SPIR-V (includes SPIRV-Tools) | [Khronos](https://github.com/KhronosGroup/glslang) |
| **SPIRV-Cross** | SPIR-V to GLSL/HLSL/MSL | [Khronos](https://github.com/KhronosGroup/SPIRV-Cross) |
| **Naga** | WGSL to/from SPIR-V (shared library via FFI) | [gfx-rs](https://github.com/gfx-rs/wgpu) |
| **wgpu-native** | WebGPU runtime (Metal/Vulkan/D3D12/OpenGL) | [gfx-rs](https://github.com/gfx-rs/wgpu-native) |
| **llvm-mlvm** | LLVM + Clang (NVPTX, AMDGPU backends) | [LLVM](https://github.com/llvm/llvm-project) |
| **clspv-mlvm** | OpenCL C to Vulkan SPIR-V (built against llvm-mlvm) | [Google](https://github.com/google/clspv) |
| **spirv-llvm-translator-mlvm** | SPIR-V ↔ LLVM IR bridge (built against llvm-mlvm) | [Khronos](https://github.com/KhronosGroup/SPIRV-LLVM-Translator) |

The `-mlvm` suffix indicates tools built as part of the MLVM toolchain against a shared LLVM.

## Platforms

All tools are provided for:
- macOS ARM64 / x86_64
- Linux x86_64 / ARM64
- Windows x86_64 / ARM64
- WebAssembly

## License

All components are Apache 2.0 or dual MIT/Apache 2.0. Licenses are verified on every build and packaged alongside each artifact.
