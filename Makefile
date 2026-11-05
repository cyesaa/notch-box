# Command Line Tools ship the Swift Testing macro plugin outside the default search path.
DEV_DIR := $(shell xcode-select -p)
ifeq ($(DEV_DIR),/Library/Developer/CommandLineTools)
TEST_FLAGS := -Xswiftc -plugin-path -Xswiftc $(DEV_DIR)/usr/lib/swift/host/plugins/testing
endif

.PHONY: build test adapter clean

build:
	swift build

test:
	swift test $(TEST_FLAGS) $(if $(FILTER),--filter $(FILTER),)

adapter:
	scripts/build-adapter.sh

clean:
	rm -rf .build build dist
