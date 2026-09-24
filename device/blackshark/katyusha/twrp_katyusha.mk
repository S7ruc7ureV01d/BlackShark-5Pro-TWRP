#
# TWRP product for Black Shark 5 Pro (katyusha)
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# TWRP common config
$(call inherit-product, vendor/twrp/config/common.mk)

# Device
$(call inherit-product, device/blackshark/katyusha/device.mk)

PRODUCT_DEVICE := katyusha
PRODUCT_NAME := twrp_katyusha
PRODUCT_BRAND := blackshark
PRODUCT_MODEL := SHARK KTUS-A0
PRODUCT_MANUFACTURER := blackshark

PRODUCT_GMS_CLIENTID_BASE := android-blackshark
