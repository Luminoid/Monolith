.PHONY: help lint lint-fix format check build test setup-hooks
.DEFAULT_GOAL := help

help:
	@echo "Monolith development targets:"
	@echo "  make build        Compile the package"
	@echo "  make test         Run swift test"
	@echo "  make lint         Run SwiftLint"
	@echo "  make lint-fix     Run SwiftLint --fix (autofix what it can)"
	@echo "  make format       Run SwiftFormat (modifies files)"
	@echo "  make check        Run SwiftLint --strict + SwiftFormat --lint (CI check)"
	@echo "  make setup-hooks  Point git to Scripts/git-hooks for pre-commit"
	@echo "  make help         Show this message"

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

setup-hooks:
	git config core.hooksPath Scripts/git-hooks
	@echo "Git hooks configured to Scripts/git-hooks/"
