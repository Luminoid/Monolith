.PHONY: lint lint-fix format check build test

lint:
	swiftlint

lint-fix:
	swiftlint --fix

format:
	swiftformat .

check:
	swiftlint --strict
	swiftformat --lint .

build:
	swift build

test:
	swift test
