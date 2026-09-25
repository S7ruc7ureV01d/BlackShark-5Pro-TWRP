# TWRP for Black Shark 5 Pro (katyusha)

Unofficial TWRP 3.7.1 (twrp-12.1) for the **Xiaomi Black Shark 5 Pro** (`katyusha`, Snapdragon 8 Gen 1 / SM8450).

**Latest release:** [v1.0](../../releases/tag/v1.0-phase1) (`twrp-katyusha-20260924-2205.img`, sha256 `59fe7d28…9eb6`)

## Status

| Works | Notes |
|---|---|
| Boot, display, touch | Touch uses Black Shark's host-touch daemon (`htd`) |
| adb, MTP, `adb sideload` | USB returns to adb/MTP after sideload |
| USB OTG | FAT32/exFAT/NTFS, mounted at `/usb_otg` |
| Install `.zip` / Install Image `.img` | Image flashing is slot-aware; persist/EFS/bootloader partitions are backup-only |
| Backup / restore | Verified byte-identical round trip (boot, recovery) to OTG |
| Mount system, vendor, odm, product, system_ext, vendor_dlkm, metadata, persist, firmware | Logical partitions are read-only |
| Battery %, vibration, screen timeout | Back RGB light turns blue while TWRP is running |
| Reboot to system / recovery / bootloader / fastboot | |

**Not working: `/data` decryption.** Internal storage stays encrypted, so install from USB OTG or with `adb sideload`, and back up to OTG. Details: [docs/DEVICE_ANALYSIS.md](docs/DEVICE_ANALYSIS.md#decryption-investigation-phase-2-2026-09-25).

Tested on JOYUI V11.0.4.0 (`KTUS2208100OS00MP2`, Android 12) and with an Android 16 GSI, slot A.

## Requirements
- Unlocked bootloader
- `vbmeta` on the active slot with verification disabled (flags 3), as tested
- Stock GKI kernel in `boot` (the image contains only a ramdisk, like the stock recovery)

## Install
The phone has a separate `recovery_a`/`recovery_b` partition. Back up your stock recovery first.
```
fastboot flash recovery_a twrp-katyusha-20260924-2205.img
```
Or from a root shell in Android:
```
dd if=twrp-katyusha-20260924-2205.img of=/dev/block/by-name/recovery_a bs=4M && sync
```
Boot it with `adb reboot recovery` (verified). Inside TWRP, Reboot → Recovery/Bootloader/Fastboot also works.

**Before installing:**
- Only install to the slot you boot from. Check it with `adb shell getprop ro.boot.slot_suffix`.
- The phone has one USB-C port, so OTG and a PC connection can't be used at the same time.
- Don't switch to a slot whose `vbmeta` still enforces verification, or that has no system installed.

## Uninstall
Flash your stock `recovery_a` backup the same way.

## Building
See [docs/BUILD.md](docs/BUILD.md). In short: sync the twrp-12.1 minimal manifest to a path without spaces, then run `tools/build.sh`. The device tree is in `device/blackshark/katyusha`.

## Docs
- [docs/DEVICE_ANALYSIS.md](docs/DEVICE_ANALYSIS.md): hardware, boot chain, AVB, encryption, bring-up findings
- [docs/TESTING.md](docs/TESTING.md): test checklist and build history
- [docs/BACKUPS.md](docs/BACKUPS.md), [docs/DECISIONS.md](docs/DECISIONS.md), [docs/BUILD.md](docs/BUILD.md)

## Disclaimer
Use at your own risk. Always keep verified backups of your partitions, especially `persist`, `modemst1/2`, `fsg`, `fsc` and `devinfo`.
