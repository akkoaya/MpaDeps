# MpaDeps

Project-owned dependency foundation for MpaFrameWork.

## Purpose

`MpaDeps` is the project-owned replacement for the current borrowed dependency
flow that previously pointed at MaaFramework-owned dependency outputs.

This repository is intentionally modeled after the structure of
`MaaXYZ/MaaDeps`, but it is implemented as a standalone, MpaFrameWork-owned
dependency repository and is scoped to the project's immediate needs:

* FastDeploy PPOCR
* ONNXRuntime
* OpenCV

The repository keeps `vcpkg` as a Git submodule, matching the upstream
`MaaDeps` layout, while publishing project-owned `MpaDeps-*` release assets.

## Status

This is an initial scaffold. It defines the layout and integration contract so
the main project can stop treating MaaFramework's dependency root as the
preferred default.

The first implementation wave does not attempt to reproduce every reference
repo feature. It establishes:

* triplet detection
* CMake prefix injection
* runtime install helper
* Windows MSBuild integration skeleton
* a manifest for the owned OCR + shared utility dependency subset
* release packaging for `devel` and `runtime` archives

## Layout

```text
MpaDeps/
  README.md
  .gitignore
  .gitmodules
  .github/workflows/build.yml
  mpadeps.cmake
  build.py
  vcpkg.json
  vcpkg-configuration.json
  msbuild/
  vcpkg/
  vcpkg-overlay/
  runtime/
```

`build.py` uses the checked-out `vcpkg/` submodule and produces `runtime/`,
`debug/`, `logs/`, `tarball/`, `src/`, and `x-tools/` as local working
outputs. Those directories are intentionally ignored and are not part of the
authored source tree.

The intended release contract is:

* `MpaDeps-<triplet>-devel.tar.xz`
* `MpaDeps-<triplet>-runtime.tar.xz`

MpaFrameWork consumes those assets by downloading and extracting them into a
repo-local `MpaDeps/` directory before configure/build.

## Release Workflow

Typical local release preparation:

```powershell
python build.py --target mpa-x64-windows --tarball
```

This produces:

* `tarball/MpaDeps-mpa-x64-windows-devel.tar.xz`
* `tarball/MpaDeps-mpa-x64-windows-runtime.tar.xz`

GitHub Actions automatically builds tarballs on `push` and `workflow_dispatch`.
Pushing a tag such as `v0.1.0` also creates or updates the matching GitHub
release and uploads the generated tarballs.

The `devel` archive carries the CMake/MSBuild metadata plus
`vcpkg/installed/<triplet>` and the required buildsystem helpers. If
repo-local debug symbols were staged under `debug/<triplet>`, those files are
also included. To keep the release asset size practical, bulk `.pdb` files
inside `vcpkg/installed/<triplet>` are stripped from the `devel` archive. The
`runtime` archive carries the deployable runtime DLL layout under
`runtime/<triplet>`.

## Current Integration Contract

MpaFrameWork prefers this local dependency root when present:

* `MpaDeps/` under the repo root
* or `MPADEPS_DIR` if explicitly provided

## Next Steps

* publish release artifacts from `https://github.com/akkoaya/MpaDeps`
* keep FastDeploy pinned to the owned `akkoaya/FastDeploy` fork
* generate runtime/devel artifacts for the supported Windows triplet
