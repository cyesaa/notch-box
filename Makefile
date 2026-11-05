# Command Line Tools ship the Swift Testing macro plugin outside the default search path.
DEV_DIR := $(shell xcode-select -p)
ifeq ($(DEV_DIR),/Library/Developer/CommandLineTools)
TEST_FLAGS := -Xswiftc -plugin-path -Xswiftc $(DEV_DIR)/usr/lib/swift/host/plugins/testing
endif

.PHONY: build test adapter icon app run dist clean

build:
	swift build

test:
	swift test $(TEST_FLAGS) $(if $(FILTER),--filter $(FILTER),)

adapter:
	scripts/build-adapter.sh

# Redraws Resources/AppIcon.icns from scripts/make-icon.swift (the .icns is committed).
icon:
	swift scripts/make-icon.swift

app:
	scripts/bundle.sh

run: app
	-pkill -x NotchBox
	@tries=0; while pgrep -x NotchBox >/dev/null; do \
		tries=$$((tries + 1)); \
		if [ $$tries -ge 50 ]; then echo "error: NotchBox did not quit within 5 s" >&2; exit 1; fi; \
		sleep 0.1; \
	done
	open build/NotchBox.app

dist: app
	scripts/dist.sh

clean:
	rm -rf .build build dist
