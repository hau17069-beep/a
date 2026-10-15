TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FoodyJB
FoodyJB_FILES = Tweak.x
FoodyJB_CFLAGS = -fobjc-arc -Wno-everything -Wno-unused-variable -Wno-unused-function
FoodyJB_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk