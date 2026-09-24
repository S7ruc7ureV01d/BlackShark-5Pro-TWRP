#!/usr/bin/env bash
# Fetch AOSP host tools used for image analysis (unpack_bootimg, avbtool).
set -euo pipefail
cd "$(dirname "$0")"
[ -d mkbootimg ] || git clone --depth 1 https://android.googlesource.com/platform/system/tools/mkbootimg mkbootimg
[ -d avb ] || git clone --depth 1 https://android.googlesource.com/platform/external/avb avb
