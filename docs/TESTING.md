# Testing & Flashing

## Build #1 (2026-09-24)

`out/twrp-katyusha-20260924-*.img` (git-ignored), built from twrp-12.1.

Checks done on the host before any flashing:
| Check | Result |
|---|---|
| Header | v4, `kernel_size: 0` (same layout as stock recovery) |
| Ramdisk | LZ4, 30.5 MB (stock 27.0 MB) |
| AVB footer | SHA256_RSA4096 (AOSP test key), partition size 104857600 = `recovery_a` size |
| Device files in ramdisk | recovery.fstab, twrp.flags, touch firmware, charger_fstab.qti, DSP modules, QTI boot HAL + deps, init.recovery.qcom.rc |
| Boot HAL deps | all NEEDED libs present in ramdisk |
| Props | `ro.product.device=katyusha`, `ro.build.ab_update=true`, `ro.virtual_ab.enabled=true` |

Known build-host issue: the final step (`vendor/etc/recovery-resource.dat`, not used by
us) fails because the host lacks `zip` (`sudo pacman -S zip`). recovery.img is built
before that step.

## Flash procedure (slot A only)

Because the USB link has been unreliable, the image is written **on the phone** from a
verified local copy, so a USB drop cannot interrupt the actual partition write:

1. `adb push out/twrp-….img /data/local/tmp/twrp.img`
2. Compare `sha256sum` on the phone with the host.
3. On the phone (root): `dd if=/data/local/tmp/twrp.img of=/dev/block/by-name/recovery_a bs=4M conv=fsync`
4. Read back `recovery_a` and compare sha256 with the image.
5. `adb reboot recovery`

Only `recovery_a` is written. `boot`, `vendor_boot`, `vbmeta*` and slot B are untouched,
so normal Android boot is unaffected even if TWRP fails to start.

## Rollback

* If Android boots: restore via root dd from `backups/stock/partitions/recovery_a.img`
  (same procedure as above, sha256 `7f31fed1…6d9a`).
* If stuck in a failed recovery boot: hold power to force reboot → Android boots normally,
  or from bootloader: `fastboot flash recovery_a backups/stock/partitions/recovery_a.img`.

## Test checklist
- [x] TWRP boots, display correct (build #1+)
- [x] Touch works (build #4; needs Black Shark htd daemon)
- [x] adb shell works, MTP enumerates (build #4)
- [x] Battery % correct (build #4)
- [x] Mount/unmount via TWRP (build #6): system_root (ext4, ro), system_ext/product/vendor/odm/vendor_dlkm (erofs, ro), firmware (vfat, ro), metadata/persist (ext4, rw)
- [x] Slot A detected; QTI boot HAL loads and registers IBootControl (auto-started from build #7)
- [x] USB OTG drive detected and mounted at /usb_otg (sdg1, fuseblk) — user test
- [x] Install Image via GUI → Recovery wrote recovery_a (slot-aware), content verified, other partitions untouched (build #7)
- [x] Zip install (harmless test zip, out/katyusha-testzip.zip): RC=0 (build #6)
- [x] adb sideload: installs and USB returns to mtp,adb without reboot (build #7; deadlocked on #6)
- [x] Reboot to recovery / bootloader / fastboot — user test
- [x] fastbootd (TWRP Reboot → Fastboot): detected by `fastboot`, is-userspace yes — fixed in v1.0.1 (health HAL); broken in v1.0
- [x] Reboot to system: Android 16 GSI boots; recovery_a still TWRP #7 afterwards (not overwritten)
- [x] Vibration (verified live on #4, built into #5)
- [x] Screen timeout: backlight goes to 0 and the OLED turns off by itself (TW_NO_SCREEN_BLANK only skips the fb blank ioctl) — user test, build #7
- [x] Backup to USB OTG (Boot + Recovery) and restore (Recovery): restored recovery_a byte-identical (sha256 59fe7d28); TWRP MD5s of boot.emmc.win / recovery.emmc.win match boot_a / recovery_a (build #7)
- [x] CPU temperature source readable (thermal_zone49 cpu-0-0)
- [~] MTP: protocol works (host reads device info), but no storage is exposed until /data is decrypted; OTG and PC cannot be connected at the same time (single USB-C port)
- [ ] Full ROM / OTA zip with payload.bin (not tested)
- [ ] Actual slot switch A→B→A (HAL verified; switch not performed: slot B enforces AVB and has no system)
- [ ] /data: expected NOT to mount (encrypted, phase 2)

## Build history

| Build | Image | Result | Root causes found |
|---|---|---|---|
| #1 | 20260924-2046 | Boots, display OK; no touch, no USB, battery 100% | (pstore log, device-info/twrp-boot-1) |
| #2 | 20260924-2056-debug | not flashed (superseded) | added rescue-partition log dumper |
| #3 | 20260924-2108-debug | same symptoms | modem fw mount failed on SELinux `context=` → ADSP down; touch needs htd daemon; vendor libs not in linker path |
| #4 | 20260924-2121 | **touch, USB adb+MTP, battery OK** | htd needed main VINTF manifest; adbd root-restart race on `ffs.ready`; no `mtp,adb` configfs rules; health HAL absent → 100% |
| #5 | 20260924-2129 | not flashed (superseded by #6) | aw86907 RAM waveform missing; vibrator not at `/sys/class/leds/vibrator` |
| #6 | 20260924-2132 | **touch, USB, battery, vibration, blue back light** | back light: green must be cleared first |
| #7 | 20260924-2205 | **all phase-1 tests pass** | sideload deadlock: TWRP waits on sys.usb.state; boot HAL service not started |
| v1.0 | 20260925-0105 (released as `twrp-katyusha-v1.0.img`) | **all phase-1 tests + RGB light animation during operations, credit string** | decryption gated off (`KATYUSHA_DECRYPT`) |
| v1.0.1 | 20260925-1632 | v1.0 + fastbootd fixed | fastbootd blocked on health HAL getService (VINTF declares it, no service ran) |
