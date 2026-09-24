#!/usr/bin/env bash
# Dump device partitions over adb (root via Magisk) into the project's backups dir.
# Each image is verified by comparing on-device sha256 with host sha256.
# Resumable: already-verified images are skipped. On a USB drop the partial
# file is discarded and the partition is retried after the device reappears.
# Usage: tools/backup_partitions.sh [partition ...]   (default: all except super/userdata)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/backups/stock/partitions"
SUMS="$ROOT/backups/stock/SHA256SUMS"
LOG="$ROOT/backups/stock/backup.log"
SKIP_RE='^(super|userdata|sd[a-f])$'
RETRIES=3
mkdir -p "$OUT"
rm -f "$OUT"/*.part

if [ $# -gt 0 ]; then
  parts=("$@")
else
  adb wait-for-device
  mapfile -t parts < <(adb shell 'su -c "ls /dev/block/by-name/"' | tr -d '\r' | grep -Ev "$SKIP_RE" | sort)
  [ ${#parts[@]} -gt 0 ] || { echo "could not list partitions"; exit 1; }
fi

dump_one() {
  local p=$1 dst="$OUT/$1.img" dev_sum host_sum
  adb wait-for-device
  adb exec-out "su -c 'dd if=/dev/block/by-name/$p bs=4M 2>/dev/null'" > "$dst.part" || return 1
  dev_sum=$(adb shell "su -c 'sha256sum /dev/block/by-name/$p'" | tr -d '\r' | awk '{print $1}') || return 1
  host_sum=$(sha256sum "$dst.part" | awk '{print $1}')
  if [ -z "$dev_sum" ] || [ "$dev_sum" != "$host_sum" ]; then
    echo "MISMATCH $p dev=${dev_sum:-none} host=$host_sum" | tee -a "$LOG"
    return 1
  fi
  mv "$dst.part" "$dst"
  echo "$host_sum  $p.img" >> "$SUMS"
  echo "ok $p $(stat -c%s "$dst") $host_sum" | tee -a "$LOG"
}

failed=()
for p in "${parts[@]}"; do
  if [ -s "$OUT/$p.img" ] && grep -q "  $p.img\$" "$SUMS" 2>/dev/null; then
    echo "skip $p (already verified)"; continue
  fi
  ok=0
  for try in $(seq 1 $RETRIES); do
    if dump_one "$p"; then ok=1; break; fi
    rm -f "$OUT/$p.img.part"
    echo "retry $p ($try/$RETRIES) $(date -Is)" | tee -a "$LOG"
    sleep 3
  done
  [ $ok -eq 1 ] || failed+=("$p")
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "FAILED: ${failed[*]}" | tee -a "$LOG"; exit 1
fi
echo "all partitions verified"
