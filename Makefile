ARCH_FLAGS=-arch arm64 -arch armv7 -marm -march=armv7-a

keychaineditor: main.m
	clang \
		-Os -Wall -bind_at_load -fobjc-arc \
		$(ARCH_FLAGS) \
		-mios-version-min=8.0 \
		-isysroot `xcrun --sdk iphoneos9.2 --show-sdk-path` \
		-framework Foundation -framework Security \
		-o keychaineditor main.m
	ldid -Sentitlements.xml keychaineditor

clean:
	rm -f keychaineditor
