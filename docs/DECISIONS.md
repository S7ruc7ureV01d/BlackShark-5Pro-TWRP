# Project Decisions

| Date | Decision | Rationale |
|---|---|---|
| 2026-09-24 | Base on **twrp-12.1** minimal manifest | Most mature branch for SM8450/GKI devices; matches stock Android 12 vendor |
| 2026-09-24 | **Build locally** on the dev machine | 181 GB free; faster iteration than CI. Source tree kept out of git |
| 2026-09-24 | **Ramdisk-only recovery image** (no kernel) | Matches stock layout (kernel_size=0); stock GKI kernel from `boot` is reused, so no kernel risk |
| 2026-09-24 | **/data decryption deferred to Phase 2** | Data is FBE v2 + metadata encryption with HW-wrapped keys, created by an Android 16 GSI; uncertain. Phase 1 target: boot, touch, OTG, zip/img flashing, sideload, all non-data mounts |
| 2026-09-24 | Test only on **slot A** (`recovery_a`) | `vbmeta_a` has verification disabled; `vbmeta_b` still enforces AVB |
| 2026-09-24 | Flash via bootloader `fastboot flash recovery_a` | User confirmed bootloader fastboot flashing works on this unit; stock restore path is `fastboot flash recovery_a backups/stock/partitions/recovery_a.img` |
