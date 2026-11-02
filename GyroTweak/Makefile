# Theos Makefile для сборки dylib твика

ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GyroTweak
GyroTweak_FILES = GyroTweak.xm
GyroTweak_FRAMEWORKS = Foundation CoreMotion UIKit
GyroTweak_CFLAGS = -fobjc-arc -Wall -Wextra -fvisibility=hidden

# Выходной файл: GyroTweak.dylib
include $(THEOS_MAKE_PATH)/tweak.mk
