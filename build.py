#!/usr/bin/env python3
from __future__ import annotations

import shutil
import sys
import tarfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from mpadeps import basedir, runtime, session, vcpkg


def _ensure_dirs() -> None:
    for relative in (
        "runtime",
        "debug",
        "tarball",
        "vcpkg-overlay",
        "msbuild",
        "cmake",
    ):
        (ROOT / relative).mkdir(parents=True, exist_ok=True)


def clean() -> None:
    for relative in ("runtime", "debug", "tarball"):
        shutil.rmtree(ROOT / relative, ignore_errors=True)


def _iter_files(path: Path) -> list[Path]:
    if not path.exists():
        return []
    if path.is_file():
        return [path]
    return [candidate for candidate in sorted(path.rglob("*")) if candidate.is_file()]


def _add_to_archive(archive: tarfile.TarFile, path: Path, *, skip_pdb: bool = False) -> None:
    for candidate in _iter_files(path):
        if skip_pdb and candidate.suffix.lower() == ".pdb":
            continue
        archive.add(candidate, arcname=candidate.relative_to(ROOT).as_posix())


def package_release_assets() -> None:
    tarball_dir = ROOT / "tarball"
    tarball_dir.mkdir(parents=True, exist_ok=True)

    triplet = vcpkg.triplet
    host_triplet = vcpkg.host_triplet
    installed_root = ROOT / "vcpkg" / "installed" / triplet
    host_tools_root = ROOT / "vcpkg" / "installed" / host_triplet / "tools"
    host_share_root = ROOT / "vcpkg" / "installed" / host_triplet / "share"
    runtime_root = ROOT / "runtime" / triplet

    missing = [str(path) for path in (installed_root, runtime_root) if not path.exists()]
    if missing:
        raise FileNotFoundError(
            "release packaging requires populated dependency outputs:\n  "
            + "\n  ".join(missing)
        )

    for archive in (
        tarball_dir / f"MpaDeps-{triplet}-devel.tar.xz",
        tarball_dir / f"MpaDeps-{triplet}-runtime.tar.xz",
    ):
        archive.unlink(missing_ok=True)

    runtime_archive = tarball_dir / f"MpaDeps-{triplet}-runtime.tar.xz"
    with tarfile.open(runtime_archive, "w:xz") as archive:
        _add_to_archive(archive, runtime_root)

    devel_archive = tarball_dir / f"MpaDeps-{triplet}-devel.tar.xz"
    with tarfile.open(devel_archive, "w:xz") as archive:
        _add_to_archive(archive, installed_root, skip_pdb=True)
        _add_to_archive(archive, host_tools_root, skip_pdb=True)
        _add_to_archive(archive, host_share_root)
        _add_to_archive(archive, ROOT / "debug" / triplet)
        for path in (
            ROOT / "mpadeps.cmake",
            ROOT / "README.md",
            ROOT / "msbuild",
            ROOT / "cmake",
            ROOT / "linux-toolchain-download.py",
            ROOT / "vcpkg" / "scripts" / "buildsystems" / "msbuild",
            ROOT / "vcpkg" / "scripts" / "buildsystems" / "vcpkg.cmake",
        ):
            _add_to_archive(archive, path)

    print("release assets prepared:")
    print(f"  {devel_archive}")
    print(f"  {runtime_archive}")


def main() -> int:
    _ensure_dirs()
    session.parse_args(sys.argv)

    if session.extra_cmake_args and session.extra_cmake_args[0] == "clean":
        clean()
        shutil.rmtree(ROOT / "vcpkg" / "installed", ignore_errors=True)
        return 0

    vcpkg.bootstrap(session.target)
    clean()
    vcpkg.install_manifest(basedir)
    runtime.sdk_ready()
    runtime.install_runtime()
    if session.enable_tarball:
        package_release_assets()

    print(f"MpaDeps is ready for {vcpkg.triplet}")
    print(f"  Prefix : {ROOT / 'vcpkg' / 'installed' / vcpkg.triplet}")
    print(f"  Runtime: {ROOT / 'runtime' / vcpkg.triplet}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
