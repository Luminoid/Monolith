SWIFTLINT := /opt/homebrew/bin/swiftlint
SWIFTFORMAT := /opt/homebrew/bin/swiftformat

.PHONY: lint lint-fix format check build test

lint:
	$(SWIFTLINT)

lint-fix:
	$(SWIFTLINT) --fix

format:
	$(SWIFTFORMAT) .

check:
	$(SWIFTLINT) --strict
	$(SWIFTFORMAT) --lint .

build:
	swift build

test:
	swift test
