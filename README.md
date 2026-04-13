# Redistributables

Pre-built shader compilation and GPU compute toolchain for The Enigmaneering Guild. All tools are built from source across 6 native platforms + WebAssembly.

## Tools

| Tool | Purpose                                    | Source |
|------|--------------------------------------------|--------|
| **[glslang](https://github.com/KhronosGroup/glslang)** | GLSL/ESSL to SPIR-V (includes SPIRV-Tools) | Khronos |
| **[SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross)** | SPIR-V to GLSL/HLSL/MSL                    | Khronos |
| **[DXC](https://github.com/microsoft/DirectXShaderCompiler)** | HLSL to SPIR-V                             | Microsoft |
| **[Naga](https://github.com/gfx-rs/wgpu/tree/trunk/naga)** | WGSL to/from SPIR-V                        | gfx-rs |
| **[clspv](https://github.com/google/clspv)** | OpenCL C to Vulkan SPIR-V (shared library) | Google |
| **[wgpu-native](https://github.com/gfx-rs/wgpu-native)** | WebGPU runtime (Metal/Vulkan/D3D12/OpenGL) | gfx-rs |

## Platforms

All tools are provided for:
- macOS ARM64 / x86_64
- Linux x86_64 / ARM64
- Windows x86_64 / ARM64
- WebAssembly (glslang, SPIRV-Cross, DXC, Naga, clspv)

## License

Each tool carries its own license (Apache 2.0, MIT, or similar). Licenses are verified on every build and packaged alongside each binary. No binaries are stored in this repository — only build scripts and CI configuration.
