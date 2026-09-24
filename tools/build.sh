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
m -j"$JOBS" recoveryimage || { echo 'build failed'; exit 1; }
mkdir -p "$ROOT/out"
cp "$SRC/out/target/product/katyusha/recovery.img" "$ROOT/out/twrp-katyusha-$(date +%Y%m%d-%H%M).img"
ls -la "$ROOT/out"
