#!/usr/bin/env python3
"""Pull vendor blobs (and their missing shared-library dependencies) from the device.

Each file is read as root over adb and verified against an on-device sha256. Libraries
already present in the TWRP recovery ramdisk (system/lib64) are not copied. Missing
libraries are searched on the device in /vendor/lib64, /odm/lib64 and the VNDK apex,
and copied to recovery/root/vendor/lib64.

Usage: tools/pull_blobs.py <device path to binary/lib> ...
"""
import hashlib
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TREE = os.path.join(ROOT, "device/blackshark/katyusha/recovery/root")
RAMDISK = os.path.expanduser("~/Projects/twrp-12.1/out/target/product/katyusha/recovery/root")
SEARCH = ["/vendor/lib64", "/odm/lib64", "/apex/com.android.vndk.v31/lib64", "/system/lib64"]


def sh(cmd):
    return subprocess.run(["adb", "shell", f"su -c '{cmd}'"], capture_output=True, text=True).stdout.strip()


def pull(dev_path, dest_dir):
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, os.path.basename(dev_path))
    data = subprocess.run(["adb", "exec-out", f"su -c 'cat {dev_path}'"], capture_output=True).stdout
    dev_sum = sh(f"sha256sum {dev_path}").split()[0]
    if hashlib.sha256(data).hexdigest() != dev_sum:
        sys.exit(f"checksum mismatch for {dev_path}")
    with open(dest, "wb") as f:
        f.write(data)
    return dest


def needed(path):
    out = subprocess.run(["readelf", "-d", path], capture_output=True, text=True).stdout
    return [l.split("[")[1].split("]")[0] for l in out.splitlines() if "(NEEDED)" in l]


def have(lib):
    return any(os.path.exists(os.path.join(d, lib)) for d in (
        os.path.join(RAMDISK, "system/lib64"), os.path.join(TREE, "vendor/lib64"),
        os.path.join(TREE, "system/lib64")))


def main():
    queue = []
    for dev_path in sys.argv[1:]:
        sub = "system/bin" if "/bin/" in dev_path else "vendor/lib64"
        local = pull(dev_path, os.path.join(TREE, sub))
        os.chmod(local, 0o755 if sub == "system/bin" else 0o644)
        print(f"ok   {dev_path} -> {sub}")
        queue.append(local)
    seen = set()
    while queue:
        for lib in needed(queue.pop()):
            if lib in seen or have(lib):
                continue
            seen.add(lib)
            src = next((f"{d}/{lib}" for d in SEARCH if sh(f"test -f {d}/{lib} && echo y") == "y"), None)
            if not src:
                print(f"MISSING {lib} (not found on device)")
                continue
            queue.append(pull(src, os.path.join(TREE, "vendor/lib64")))
            print(f"dep  {src} -> vendor/lib64")


if __name__ == "__main__":
    main()
