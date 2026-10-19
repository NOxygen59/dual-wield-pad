TARGET := iphone:clang:16.5:16.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = DualWieldPadPrefs

DualWieldPadPrefs_FILES = DWPRootListController.m
DualWieldPadPrefs_FRAMEWORKS = UIKit
DualWieldPadPrefs_PRIVATE_FRAMEWORKS = Preferences
DualWieldPadPrefs_INSTALL_PATH = /Library/PreferenceBundles
DualWieldPadPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
