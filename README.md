# BlackShark-5Pro-TWRP

TWRP recovery for the **Xiaomi Black Shark 5 Pro** (`katyusha`, SM8450).

**Status:** Phase 1 — stock backups & analysis done. No image built or flashed yet.

## Goals
- Boot reliably from the dedicated `recovery_a` partition (ramdisk-only image, stock GKI kernel)
- Mount all partitions safely (dynamic partitions in `super`, persist, firmware, metadata, data)
- USB OTG storage
- Flash `.zip` and `.img` to partitions
- Touch, display, battery, adb/MTP

## Docs
- [docs/DEVICE_ANALYSIS.md](docs/DEVICE_ANALYSIS.md) — hardware, boot chain, AVB, encryption, stock recovery
- [docs/BACKUPS.md](docs/BACKUPS.md) — backup layout and restore procedure
- `device-info/` — raw data captured from the device

## Safety rules
1. Stock partition backups are in `backups/` (never `/tmp`), verified by sha256.
2. Raw images are never committed.
3. Only `recovery_a` is touched during testing; slot B still enforces AVB.
