import sys
import os
import shutil
from .common import basedir, host_triplet
import subprocess
from .runner import task

_this_module = sys.modules[__name__]


root = os.path.join(basedir, "vcpkg")
install_prefix: str
triplet: str
cross_compiling = False


def _is_vcpkg_checkout(path: str) -> bool:
    return (
        os.path.exists(os.path.join(path, "bootstrap-vcpkg.bat"))
        or os.path.exists(os.path.join(path, "bootstrap-vcpkg.sh"))
    )


def _remove_checkout(path: str) -> None:
    if os.path.isdir(path):
        shutil.rmtree(path)
    elif os.path.exists(path):
        os.remove(path)


def _checkout_candidates():
    for env_name in ("MPADEPS_VCPKG_ROOT", "VCPKG_ROOT"):
        candidate = os.environ.get(env_name, "").strip()
        if not candidate:
            continue
        candidate = os.path.abspath(candidate)
        if candidate == os.path.abspath(root):
            continue
        yield env_name, candidate


def _copy_vcpkg_checkout(source_root: str) -> None:
    print(f"copying vcpkg checkout from {source_root} -> {root}")
    _remove_checkout(root)
    shutil.copytree(
        source_root,
        root,
        ignore=shutil.ignore_patterns(
            "buildtrees",
            "downloads",
            "installed",
            "packages",
        ),
    )


def _clone_vcpkg_checkout() -> None:
    if os.path.exists(root):
        _remove_checkout(root)
    subprocess.check_call(
        [
            "git",
            "clone",
            "--depth",
            "1",
            "https://github.com/microsoft/vcpkg.git",
            root,
        ],
        cwd=basedir,
    )


def _ensure_vcpkg_checkout() -> None:
    if _is_vcpkg_checkout(root):
        return
    for env_name, candidate in _checkout_candidates():
        if _is_vcpkg_checkout(candidate):
            print(f"using {env_name}={candidate} as the seed vcpkg checkout")
            _copy_vcpkg_checkout(candidate)
            return
    _clone_vcpkg_checkout()

@task
def bootstrap(target_triplet=None):
    if target_triplet is None:
        target_triplet = "mpa-" + host_triplet
    print("host triplet for vcpkg:", host_triplet)
    print("target triplet for vcpkg:", target_triplet)

    global triplet, cross_compiling, install_prefix
    triplet = target_triplet
    cross_compiling = host_triplet != target_triplet.removeprefix("mpa-")
    install_prefix = os.path.join(root, "installed", target_triplet)

    os.environ["VCPKG_OVERLAY_TRIPLETS"] = os.path.join(basedir, "vcpkg-overlay", "triplets")
    os.environ["VCPKG_OVERLAY_PORTS"] = os.path.join(basedir, "vcpkg-overlay", "ports")

    _ensure_vcpkg_checkout()

    if os.name == "nt":
        script_name = "bootstrap-vcpkg.bat"
        executable_name = "vcpkg.exe"
    else:
        script_name = "bootstrap-vcpkg.sh"
        executable_name = "vcpkg"
    executable_path = os.path.join(root, executable_name)
    if not os.path.exists(executable_path):
        subprocess.check_call([os.path.join(root, script_name), "-disableMetrics"], cwd=root)

def install(*ports, triplet=None):
    if triplet is None:
        triplet = _this_module.triplet
    executable_name = "vcpkg.exe" if os.name == "nt" else "vcpkg"
    cmd = [os.path.join(root, executable_name), "install"]
    cmd.extend(port + ":" + triplet for port in ports)
    subprocess.check_call(cmd, cwd=root)

def install_manifest(manifest_root, triplet=None):
    if triplet is None:
        triplet = _this_module.triplet
    executable_name = "vcpkg.exe" if os.name == "nt" else "vcpkg"
    cmd = [os.path.join(root, executable_name), "install", "--x-install-root=" + os.path.join(root, "installed"), "--triplet", triplet]
    if sys.platform == "win32":
        cmd.append("--clean-buildtrees-after-build")
    subprocess.check_call(cmd, cwd=manifest_root)
