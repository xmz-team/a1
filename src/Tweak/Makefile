FINALPACKAGE = 1
TARGET := iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
ARCHS := arm64 arm64e

INSTALL_TARGET_PROCESSES = Preferences

include /var/theos/makefiles/common.mk

TWEAK_NAME = a1settings

a1settings_FILES = Tweak.x
a1settings_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
a1settings_FRAMEWORKS = UIKit Preferences
a1settings_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/tweak.mk
