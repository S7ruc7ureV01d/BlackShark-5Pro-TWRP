# Stock Backups

All backups live **inside the project** (`backups/`), never in `/tmp`.
Raw images are git-ignored (size + device-unique data); only checksums are committed.

## Layout

```
backups/stock/partitions/<name>.img   raw dd dump of /dev/block/by-name/<name>
backups/stock/SHA256SUMS              sha256 of every image (verified against on-device sha256 at dump time)
backups/stock/backup.log              dump log
backups/stock/gpt/gpt_main_sdX.bin    primary GPT (LBA 0-5, 4096 B sectors) per UFS LUN
backups/stock/gpt/gpt_backup_sdX.bin  backup GPT (last 5 LBAs) per LUN
backups/extracted/                    unpacked recovery/boot/vendor_boot images + ramdisks
```

## What is backed up

Every partition under `/dev/block/by-name/` **except** `super` (12 GiB, holds the GSI + stock
vendor; reproducible from firmware) and `userdata` (encrypted, user data).

Dumped with `tools/backup_partitions.sh`, which reads each partition via
`adb exec-out su -c dd`, then compares the host sha256 with a sha256 computed on the
device. A mismatch aborts.

### Irreplaceable partitions (keep extra copies off-machine!)
`persist`, `persistbak`, `modemst1`, `modemst2`, `fsg`, `fsc` (IMEI / radio calibration),
`devinfo`, `keystore`, `frp`, `countrycode`, `secdata`.

## Restoring

From fastboot (bootloader):
```
fastboot flash recovery_a backups/stock/partitions/recovery_a.img
```
From a root shell (if Android boots):
```
adb push backups/stock/partitions/recovery_a.img /data/local/tmp/
adb shell su -c 'dd if=/data/local/tmp/recovery_a.img of=/dev/block/by-name/recovery_a bs=4M && sync'
```
Always verify with `sha256sum` against `backups/stock/SHA256SUMS` before flashing.

## Known issue: USB link instability (2026-09-24)

During the initial dump the adb connection dropped twice (during `modem_b` and
`opcust`). Host kernel log: `usb 2-4: device not accepting address, error -71`
(EPROTO), i.e. a physical-layer problem (cable/port/hub), not the phone.
No bad data was kept: partial `.part` files are discarded and every stored
image passed sha256 verification. The script now retries automatically.

**Fix the USB link before any `fastboot flash`**: a drop mid-flash can leave
a partition half-written.

**Resolved:** after swapping the USB cable the remaining 38 partitions dumped with no
retries. Final state: 137/137 partitions (all by-name except `super`/`userdata`),
7.5 GB, every image re-verified with `sha256sum -c SHA256SUMS`.
