# Black Shark 5 Pro (katyusha) — Device & Stock Recovery Analysis

Collected 2026-09-24 from the live device over adb (Magisk root). Raw outputs are in
`device-info/`.

## Device identity

| Item | Value |
|---|---|
| Codename | `katyusha` (model `SHARK KTUS-A0`, product `KTUS-H0`) |
| SoC | Snapdragon 8 Gen 1, SM8450, platform `taro` (kernel names: `waipio`) |
| RAM | ~11 GB visible (12 GB SKU) |
| Storage | UFS, `1d84000.ufshc`, 4096-byte sectors, 6 LUNs (`sda`–`sdf`) |
| Display | 1080x2400, 440 dpi, AMOLED DSC command-mode panel `mdss_dsi_k3_38_08_0a_mp_dsc_cmd`, up to 144 Hz |
| Backlight | `/sys/class/backlight/panel0-backlight`, max 4095 |
| Touch | FocalTech `fts_ht` on SPI (`spi0.0`, `990000.spi`) via `hbp_touch.ko`, needs `xiaomi_touch.ko`, `touch_aw8680x.ko`, `cs_press.ko`, `pressure.ko`, `heye.ko`, `hwid.ko`, `panel_event_notifier.ko`; firmware `focaltech_ts_fw_hbp_k3.bin` (from `/vendor/firmware`) |
| Other input | `gpio-keys`, `pmic_pwrkey`, `pmic_resin`, shoulder triggers `slide-keys-shark_*` |
| Battery | `/sys/class/power_supply/battery` (pmic_glink / `qti_battery_charger.ko`) |
| CPU temp | `thermal_zone49` = `cpu-0-0` |
| USB | DWC3 `a600000.dwc3` (`dwc3-msm.ko`), Type-C via `ucsi_glink.ko`, redriver `ssusb-redriver-nb7vpq904m.ko` |
| SD card | None physically (fstab references `8804000.sdhci`, not present) |
| Stock vendor | JOYUI 11.0.4.0 `KTUS2208100OS00MP2`, Android 12, SPL 2022-06-01 |
| Running system | Android 16 GSI (props spoofed to stock fingerprint), SELinux enforcing |

## Boot architecture

* **A/B device** with **Virtual A/B** (`ro.virtual_ab.enabled=true`, no compression). Currently on slot `_a`.
* **GKI** kernel `5.10.66-android12-9`, launched with Android 12 (API 31).
* Boot image header **v4**; `vendor_boot` header v4 with a single vendor ramdisk
  (type 1 / platform) + DTB + bootconfig.
* **Dedicated `recovery_a/_b` partitions (100 MiB)** exist. The stock recovery image is a
  v4 boot image with **kernel_size = 0** — it contains only a ramdisk (~27 MB, LZ4).
  The bootloader boots recovery as: kernel from `boot` + `vendor_boot` ramdisk + `recovery` ramdisk.
  → Our TWRP image will also be ramdisk-only (`BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE`),
  so we never ship or modify a kernel. This is the safest possible setup.
* `vendor_boot` ramdisk ships `lib/modules/modules.load.recovery` (list of modules the
  kernel loads in recovery mode) — it already includes touch, DRM, USB, charger modules.
* `boot_a` is **Magisk-patched** (contains `.backup/`); `boot_b` is stock.

### Dynamic partitions (`super`, 12 GiB on `sda31`)
Group `qti_dynamic_partitions_{a,b}`: `system`, `system_ext`, `product`, `vendor`,
`vendor_dlkm`, `odm`. Only `_a` has extents (Virtual A/B). Filesystems: **erofs** (vendor,
vendor_dlkm, odm confirmed; fstab allows erofs or ext4 for all).

### AVB state (important for safety)
| Image | Flags | Notes |
|---|---|---|
| `vbmeta_a` | **3** (verity + verification disabled) | From MP1 firmware; chains `recovery` and `vbmeta_system` |
| `vbmeta_b` | **0** (verification enforced) | From MP2 firmware |
| `recovery_a` | signed (RSA4096, chain) | MP1 (`KTUS2206170OS00MP1`), SPL 2022-05 |
| `recovery_b` | signed | MP2 (`KTUS2208100OS00MP2`), SPL 2022-06 |

* On slot A, verification is disabled, so an unsigned TWRP in `recovery_a` should boot.
* **Slot B still enforces AVB.** Do not flash TWRP to `recovery_b` or switch to slot B
  without first flashing a disabled vbmeta to `vbmeta_b`.
* Bootconfig reports `androidboot.verifiedbootstate=orange`, while userspace props show
  `green`/`flash.locked=1` (spoofed by GSI/Magisk).

## Encryption

* `/data`: **f2fs**, FBE v2 `aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0`,
  **metadata encryption** `aes-256-xts:wrappedkey_v0`, keys in `/metadata/vold/metadata_encryption`,
  `checkpoint=fs`.
* Hardware-wrapped keys → decryption in TWRP needs the QTI TEE stack from vendor:
  `qseecomd`, `android.hardware.keymaster@4.1-service-qti`,
  `android.hardware.security.keymint-service-qti`, `android.hardware.gatekeeper@1.0-service-qti`
  and modules `qseecom-mod.ko`, `smcinvoke_mod.ko`, `hwkm.ko`, `crypto-qti-*.ko`.
* The userdata was formatted/encrypted by the **Android 16 GSI**'s vold, which is newer
  than any official TWRP decryption code (twrp-12.1 / twrp-14.1). Decryption is the
  highest-risk / least-certain feature.

## Stock recovery ramdisk (recovery_a)

Copies of key files are in `device-info/stock-recovery/`.

* Standard AOSP recovery + `fastbootd`, `update_engine_sideload`, `mke2fs`, `make_f2fs`, `sgdisk`.
* `init.recovery.qcom.rc`: loads audio DSP modules (`q6_pdr`, `q6_notifier`, `snd_event`,
  `gpr`, `spf_core`, `adsp_loader`), sets backlight 200, configures USB configfs + dwc3
  peripheral mode, bind-mounts modem firmware from `charger_fstab.qti`, boots ADSP
  (required for the battery/charger stack on this SoC).
* `recovery.fstab` also mounts `/cache` from the `rescue` partition (ext4, 128 MiB).
* Extra modules in the recovery ramdisk: `nvme`, `nvme-core`, `md-mod`, `raid0`, `pci-msm-drv`.
  Bootconfig has `androidboot.fstabtype=raid` and `dmcacheswitch=enable` and there is a
  `soc:blackshark_nvme` node — Black Shark's "hybrid storage" feature. `/proc/mdstat`
  shows no active arrays, `/data` is plain `sda41` → not in use on this unit.

## Partition backups

See `docs/BACKUPS.md`.
