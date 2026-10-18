# Backpressure for humans and agents: `make check` must pass before every push.
#
#   make bootstrap       install tools and enable git hooks
#   make fix             auto-format
#   make check           lint + build (warnings are errors) + tests + coverage gate
#   make test-linux      run the tests in a Linux container (needs Docker)
#   make demos           re-record the README GIF/MP4/PNG demos (needs vhs)

SOURCES := Sources Tests Examples Package.swift
MIN_COVERAGE ?= 90
SWIFT_IMAGE ?= swift:6.2-noble

.PHONY: bootstrap fix format lint wiki-lint build test coverage check test-linux demos clean

bootstrap:
	@command -v swiftlint >/dev/null || { \
		if command -v brew >/dev/null; then brew install swiftlint; \
		else echo "Install SwiftLint: https://github.com/realm/SwiftLint#installation (Linux: release binary or 'swift run swiftlint')"; exit 1; fi; }
	@swift format --version >/dev/null || { echo "swift-format ships with Swift 6 toolchains; install Swift 6.2+"; exit 1; }
	git config core.hooksPath .githooks

fix format:
	swift format format --in-place --recursive --parallel $(SOURCES)
	swiftlint lint --fix --quiet

lint: wiki-lint
	swift format lint --strict --recursive --parallel $(SOURCES)
	swiftlint lint --strict --quiet

wiki-lint:
	python3 -I Scripts/wiki-lint.py

build:
	swift build

test:
	swift test --parallel --enable-code-coverage

coverage: test
	python3 -I Scripts/check-coverage.py "$$(swift test --show-codecov-path)" $(MIN_COVERAGE) Sources/Stipple

check: lint build coverage

# Build artefacts live in a named volume, so only the first run is slow.
test-linux:
	docker run --rm -v "$(CURDIR)":/src -v stipple-linux-build:/build -w /src $(SWIFT_IMAGE) \
		swift test --parallel --scratch-path /build

# Re-record the README demos (needs `brew install vhs`; macOS, because the chat
# demo pastes from the clipboard). Outputs land in .github/assets/demos/.
demos:
	swift build -c release --product counter --product tasks --product chat
	printf 'Pasted via bracketed paste.' | pbcopy
	@for tape in Scripts/demos/*.tape; do \
		echo "recording $$tape"; \
		STIPPLE_BIN="$(CURDIR)/.build/release" vhs "$$tape" >/dev/null || exit 1; \
	done

clean:
	swift package clean
