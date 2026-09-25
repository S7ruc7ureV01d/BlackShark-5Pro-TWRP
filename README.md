# BlackShark-5Pro-TWRP

TWRP recovery for the **Xiaomi Black Shark 5 Pro** (`katyusha`, SM8450).

**Status:** Phase 1 complete — TWRP build #7 (`twrp-katyusha-20260924-2205.img`, sha256 `59fe7d28…9eb6`) passes all phase-1 tests on-device. Next: phase 2 (/data decryption). See docs/TESTING.md.

## Goals
- Boot reliably from the dedicated `recovery_a` partition (ramdisk-only image, stock GKI kernel)
- Mount all partitions safely (dynamic partitions in `super`, persist, firmware, metadata, data)
- USB OTG storage
- Flash `.zip` and `.img` to partitions
- Touch, display, battery, adb/MTP

## Docs
- [docs/DEVICE_ANALYSIS.md](docs/DEVICE_ANALYSIS.md) — hardware, boot chain, AVB, encryption, stock recovery
- [docs/BACKUPS.md](docs/BACKUPS.md) — backup layout and restore procedure
- [docs/DECISIONS.md](docs/DECISIONS.md) — decisions log
- [docs/BUILD.md](docs/BUILD.md) — build environment and source sync
- [docs/TESTING.md](docs/TESTING.md) — flash procedure, rollback, test checklist
- `device-info/` — raw data captured from the device

## Safety rules
1. Stock partition backups are in `backups/` (never `/tmp`), verified by sha256.
2. Raw images are never committed.
3. Only `recovery_a` is touched during testing; slot B still enforces AVB.
