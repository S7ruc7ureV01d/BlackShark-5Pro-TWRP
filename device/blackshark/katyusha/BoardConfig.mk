#
# TWRP device tree for Black Shark 5 Pro (katyusha), SM8450 / taro
#

DEVICE_PATH := device/blackshark/katyusha

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a-dotprod
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a76

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a76

TARGET_SUPPORTS_64_BIT_APPS := true

# Platform
TARGET_BOARD_PLATFORM := taro
TARGET_BOOTLOADER_BOARD_NAME := taro
TARGET_NO_BOOTLOADER := true
TARGET_USES_UEFI := true
QCOM_BOARD_PLATFORMS += taro

# Kernel
# The recovery partition on this device holds a ramdisk only (stock recovery has
# kernel_size = 0); the bootloader combines it with the GKI kernel from boot and the
# vendor_boot ramdisk. The prebuilt kernel below only satisfies the build system and
# is NOT packed into recovery.img. Extract it with tools/extract_prebuilt_kernel.sh.
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_IMAGE_NAME := Image
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_RAMDISK_USE_LZ4 := true

# Partitions (sizes from the device GPT, see device-info/gpt-layout.txt)
BOARD_FLASH_BLOCK_SIZE := 262144
BOARD_BOOTIMAGE_PARTITION_SIZE := 201326592
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_DTBOIMG_PARTITION_SIZE := 67108864
BOARD_USES_RECOVERY_AS_BOOT := false
TARGET_NO_RECOVERY := false
BOARD_USES_METADATA_PARTITION := true
BOARD_USES_VENDOR_DLKMIMAGE := true

# Dynamic partitions (super = 12 GiB on sda31)
BOARD_SUPER_PARTITION_SIZE := 12884901888
BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 12880707584
BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext product vendor vendor_dlkm odm

TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_ODM := odm
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm

BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# A/B (Virtual A/B)
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    odm \
    product \
    recovery \
    system \
    system_ext \
    vbmeta \
    vbmeta_system \
    vendor \
    vendor_boot \
    vendor_dlkm

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_QCOM_RTC_FIX := true
TARGET_USES_MKE2FS := true
RECOVERY_SDCARD_ON_DATA := true
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_HAS_NO_SELECT_BUTTON := true
BOARD_SUPPRESS_SECURE_ERASE := true

# AVB
# vbmeta_a has verification disabled (flags=3), so the signature is not enforced on
# slot A. We still sign with the AOSP test key so the image has a valid AVB footer.
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

# Security patch / version (high values avoid keymaster rollback refusal)
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := 2022-06-01
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# Encryption: deferred to phase 2 (see docs/DECISIONS.md)
# TW_INCLUDE_CRYPTO := true
# TW_INCLUDE_CRYPTO_FBE := true
# TW_INCLUDE_FBE_METADATA_DECRYPT := true
# BOARD_USES_QCOM_FBE_DECRYPTION := true
TW_USE_FSCRYPT_POLICY := 2

# TWRP
TW_THEME := portrait_hdpi
TARGET_SCREEN_DENSITY := 440
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_MAX_BRIGHTNESS := 4095
TW_DEFAULT_BRIGHTNESS := 1200
TW_FRAMERATE := 60
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone49/temp"
TW_BATTERY_SYSFS_WAIT_SECONDS := 6
TW_EXTRA_LANGUAGES := true
TW_DEFAULT_LANGUAGE := en
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_FUSE_EXFAT := true
TW_INCLUDE_FUSE_NTFS := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_USE_TOOLBOX := true
TW_HAS_EDL_MODE := true
TW_EXCLUDE_APEX := true
TW_NO_SCREEN_BLANK := true
TARGET_USE_CUSTOM_LUN_FILE_PATH := /config/usb_gadget/g1/functions/mass_storage.0/lun.%d/file
TW_INPUT_BLACKLIST := "hbtp_vm\x0auinput-fpc"
TW_DEVICE_VERSION := katyusha-1

# Debug
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
