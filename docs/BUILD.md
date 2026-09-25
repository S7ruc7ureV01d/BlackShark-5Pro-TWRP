# Build Environment

## Source tree location

The TWRP source lives **outside** this repo at `~/Projects/twrp-12.1`, because the
AOSP build system fails on paths containing spaces (this project directory has them).
The device tree developed here will be symlinked/copied into
`~/Projects/twrp-12.1/device/blackshark/katyusha`.

## Sync

```bash
cd ~/Projects/twrp-12.1
"<project>/tools/repo" init --depth=1 --no-repo-verify \
  -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-12.1
"<project>/tools/repo" sync -c -j8 --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune
```

`tools/repo` is Google's repo launcher (v2.65), downloaded from
`https://storage.googleapis.com/git-repo-downloads/repo` (git-ignored).
Sync output goes to `~/Projects/twrp-12.1/sync.log`.

## Host

| | |
|---|---|
| OS | Arch Linux, kernel 7.1.6 |
| CPU | 8 threads |
| RAM | 15 GB (tight for AOSP; may need swap or `-j` reduction) |
| Disk | ~173 GB free on `/` before sync |
| Python | 3.14 |
- Decryption is experimental and off by default. Build with `KATYUSHA_DECRYPT=true tools/build.sh` to include it.
