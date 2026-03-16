# License Information

All shader compilation tools distributed by this repository include their complete license information directly within each package.

## License Structure

Licenses are automatically extracted from the upstream source repositories during the build process to ensure they remain current and accurate.

### In Distributed Packages

Each tool package includes its licenses preserved from the original source:

- **glslang**: Main `LICENSE.txt` plus `LICENSES/` directory with dependency licenses (SPIRV-Tools, SPIRV-Headers)
- **SPIRV-Cross**: Main `LICENSE` plus `LICENSES/` directory with additional license texts
- **DXC**: Main `LICENSE.TXT` plus `LICENSES/` directory with component licenses (DxilCompression, LLVM)
- **Naga**: Main `LICENSE` plus `LICENSES/` directory if present

### Upstream Sources

Licenses are pulled directly from:

- **glslang**: https://github.com/KhronosGroup/glslang
- **SPIRV-Cross**: https://github.com/KhronosGroup/SPIRV-Cross
- **DXC**: https://github.com/microsoft/DirectXShaderCompiler (or Microsoft NuGet for Windows)
- **Naga**: https://github.com/gfx-rs/naga

## License Types

- **glslang**: BSD-3-Clause
- **SPIRV-Tools**: Apache-2.0
- **SPIRV-Headers**: MIT-style
- **SPIRV-Cross**: Apache-2.0
- **DXC**: University of Illinois/NCSA Open Source License
- **DxilCompression**: RAD Game Tools/Valve Software
- **LLVM**: Apache-2.0 with LLVM Exceptions
- **Naga**: Apache-2.0 / MIT

All licenses permit redistribution of precompiled binaries.

## Reference Copies

The `LICENSES/` directory in this repository contains reference copies of the licenses for quick review. The authoritative license files are those included in each distributed package, which are extracted during the build process.
