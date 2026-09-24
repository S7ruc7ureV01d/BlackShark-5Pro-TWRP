#!/system/bin/sh
# Debug-only: dump boot diagnostics to the "rescue" partition (stock /cache, unused by
# the GSI, backed up in backups/stock/partitions/rescue.img) so they survive a reboot
# when neither touch nor adb works. Remove once touch/USB are fixed.
mkdir -p /dbg
mount -t ext4 -o rw,nosuid,nodev /dev/block/by-name/rescue /dbg || exit 1
D=/dbg/twrp-debug
rm -rf $D; mkdir -p $D
for i in 1 2 3 4 5 6; do
  sleep 20
  O=$D/$i; mkdir -p $O
  dmesg > $O/dmesg.txt 2>&1
  logcat -d -b all > $O/logcat.txt 2>&1
  cp /tmp/recovery.log $O/recovery.log 2>/dev/null
  getprop > $O/getprop.txt 2>&1
  {
    echo "### getenforce"; getenforce
    echo "### lsmod"; lsmod
    echo "### input"; cat /proc/bus/input/devices
    echo "### udc"; ls -l /sys/class/udc; cat /sys/class/udc/*/state
    echo "### gadget"; cat /config/usb_gadget/g1/UDC; ls -lR /config/usb_gadget/g1/configs
    echo "### dwc3 mode"; cat /sys/bus/platform/devices/a600000.ssusb/mode
    echo "### role"; cat /sys/class/usb_role/*/role
    echo "### typec"; ls /sys/class/typec; cat /sys/class/typec/port0/data_role /sys/class/typec/port0/power_role
    echo "### boot_adsp"; cat /sys/kernel/boot_adsp/boot
    echo "### remoteproc"; for r in /sys/class/remoteproc/*; do echo "$r $(cat $r/name) $(cat $r/state)"; done
    echo "### power_supply"; ls /sys/class/power_supply; cat /sys/class/power_supply/battery/capacity
    echo "### firmware"; ls -l /etc/firmware /vendor/firmware /vendor/firmware_mnt 2>&1 | head -40
    echo "### spi / touch"; ls /sys/bus/spi/devices; ls -l /sys/bus/spi/drivers
    echo "### mounts"; cat /proc/mounts
    echo "### ps"; ps -A
    echo "### by-name"; ls /dev/block/by-name | head -5; ls -l /dev/block/bootdevice
  } > $O/state.txt 2>&1
  sync
done
umount /dbg
