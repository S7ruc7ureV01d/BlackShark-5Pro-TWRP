#
# Black Shark 5 Pro (katyusha)
#

LOCAL_PATH := device/blackshark/katyusha

# Virtual A/B
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)

PRODUCT_SHIPPING_API_LEVEL := 31
PRODUCT_TARGET_VNDK_VERSION := 31
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Boot control (QTI implementation is prebuilt in recovery/root/vendor/lib64)
PRODUCT_PACKAGES += \
    android.hardware.boot@1.0 \
    android.hardware.boot@1.1 \
    android.hardware.boot@1.2 \
    bootctl \
    libutilscallstack \
    libion

# Needed by the QTI boot control HAL at runtime in recovery
TARGET_RECOVERY_DEVICE_MODULES += \
    android.hardware.boot@1.0 \
    android.hardware.boot@1.1 \
    android.hardware.boot@1.2 \
    libion \
    libutilscallstack

RECOVERY_LIBRARY_SOURCE_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/libutilscallstack.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.boot@1.0.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.boot@1.1.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.boot@1.2.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libion.so

# A/B OTA / fastbootd
PRODUCT_PACKAGES += \
    otapreopt_script \
    update_engine \
    update_engine_sideload \
    update_verifier \
    checkpoint_gc \
    fastbootd

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=ext4 \
    POSTINSTALL_OPTIONAL_system=true

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += $(LOCAL_PATH)

# Stock props the vendor HALs expect in recovery
PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.device=katyusha \
    ro.build.product=katyusha

# FBE decryption (experimental, off by default): build with KATYUSHA_DECRYPT=true
ifeq ($(KATYUSHA_DECRYPT),true)
PRODUCT_PACKAGES += \
    qcom_decrypt \
    qcom_decrypt_fbe

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/decrypt/init.recovery.katyusha_decrypt.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.katyusha_decrypt.rc
endif
