TARGET := iphone:clang:16.5:16.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DualWieldPad

DualWieldPad_FILES = Tweak.x DWGeometry.c
DualWieldPad_CFLAGS = -fobjc-arc
DualWieldPad_FRAMEWORKS = UIKit QuartzCore CoreMotion GameController

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += dualwieldpadprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

# The geometry, on the Mac: make test
test:
	@mkdir -p $(THEOS_OBJ_DIR)
	@cc -Wall -Wextra -O2 -I. tests/geometry_test.c DWGeometry.c -lm -o $(THEOS_OBJ_DIR)/geometry_test && $(THEOS_OBJ_DIR)/geometry_test
