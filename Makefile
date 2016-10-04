iOS_MIN_VERSION =  9.0
ARCH_FLAGS      =  -arch arm64
TARGET          =  -target arm64-apple-ios9
PLATFORM        =  iphoneos

SDK_PATH        = $(shell xcrun --show-sdk-path -sdk $(PLATFORM))
TOOLCHAIN        = Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/$(PLATFORM)
TOOLCHAIN_PATH  = $(shell xcode-select --print-path)/$(TOOLCHAIN)

## SWIFT COMPILER SETUP ##
SWIFT        =  $(shell xcrun -f swift) -frontend -c -color-diagnostics
SWIFT_FLAGS  = -g -Onone $(TARGET) \
               -import-objc-header src/bridgingheader.h \
              -sdk $(SDK_PATH)

## CLANG COMPILER SETUP FOR C ##
CLANG        =  $(shell xcrun -f clang) -c
CLANG_FLAGS  =  $(ARCH_FLAGS) \
              -isysroot  $(SDK_PATH) \
              -mios-version-min=$(iOS_MIN_VERSION)

## LINKER SETTINGS ##
LD        = $(shell xcrun -f ld)
LD_FLAGS  =  -syslibroot $(SDK_PATH) \
            -lSystem $(ARCH_FLAGS)  \
            -ios_version_min $(iOS_MIN_VERSION) \
            -no_objc_category_merging  \
            -L $(TOOLCHAIN_PATH)

SOURCE = $(notdir $(wildcard src/*.swift))

keychaineditor: compile link sign package removegarbage

compile: decodeSecAccessControl.c $(SOURCE) main.swift

decodeSecAccessControl.c:
	$(CLANG) $(CLANG_FLAGS) src/$@

%.swift:
	$(SWIFT) $(SWIFT_FLAGS) -primary-file src/$@ \
	$(addprefix src/,$(filter-out $@,$(SOURCE))) \
	-module-name keychaineditor -o $*.o -emit-module \
	-emit-module-path $*~partial.swiftmodule

main.swift:
	$(SWIFT) $(SWIFT_FLAGS) -primary-file src/$@ \
	$(addprefix src/,$(filter-out $@,$(SOURCE))) \
	-module-name keychaineditor -o main.o -emit-module \
	-emit-module-path main~partial.swiftmodule

link:
	$(LD) $(LD_FLAGS) *.o -o keychaineditor/usr/local/bin/keychaineditor

sign:
	ldid -Ssrc/entitlements.xml keychaineditor/usr/local/bin/keychaineditor

package:
	dpkg-deb -Zgzip -b keychaineditor

removegarbage:
	rm *.o *.swiftmodule

clean:
	rm -f keychaineditor/usr/local/bin/keychaineditor
	rm -f keychaineditor.deb
