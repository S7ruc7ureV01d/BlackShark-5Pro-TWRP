#!/usr/bin/env bash
# Build TWRP recovery.img for katyusha. Output copied to out/ in this project.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${TWRP_SRC:-$HOME/Projects/twrp-12.1}"
JOBS="${JOBS:-6}"
"$ROOT/tools/sync_tree.sh" "$SRC"
cd "$SRC"
export ALLOW_MISSING_DEPENDENCIES=true LC_ALL=C
set +u
source build/envsetup.sh
lunch twrp_katyusha-eng || { echo 'lunch failed'; exit 1; }
[ "${TARGET_PRODUCT:-}" = twrp_katyusha ] || { echo 'lunch did not select twrp_katyusha'; exit 1; }
set -u
# Incremental builds keep files deleted from the tree in out/.../recovery/root and
# do not repack recovery.img for deletions; clear them so the image matches the tree.
P="$SRC/out/target/product/katyusha"
rm -rf "$P/recovery/root" "$P/recovery.img" "$P"/ramdisk-recovery*
m -j"$JOBS" recoveryimage || [ -s "$P/recovery.img" ] || { echo 'build failed'; exit 1; }  # zip-less hosts fail only on recovery-resource.dat
mkdir -p "$ROOT/out"
cp "$SRC/out/target/product/katyusha/recovery.img" "$ROOT/out/twrp-katyusha-$(date +%Y%m%d-%H%M).img"
ls -la "$ROOT/out"
