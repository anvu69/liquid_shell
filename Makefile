# liquid_shell: one entry point per check. CI, the pre-commit hook and
# contributors all call these targets, so "green" has exactly one definition.
#
# The SDK comes from fvm when it is installed (.fvmrc pins the floor, 3.44.6),
# otherwise from the flutter on PATH (CI). Override with FLUTTER=... DART=...

FVM := $(shell command -v fvm 2>/dev/null)
FLUTTER ?= $(if $(FVM),fvm flutter,flutter)
DART ?= $(if $(FVM),fvm dart,dart)

PACKAGES := liquid_shell liquid_shell_platform_interface liquid_shell_ios liquid_shell_android
EXAMPLE := liquid_shell/example
EXAMPLE_GO_ROUTER := liquid_shell/example_go_router
# Packages whose lib/ must keep >= COVERAGE_MIN % line coverage (spec Q14).
# A barrel-only package instruments 0 lines and stays out; every package whose
# lib/ has more than directives must be listed, or tool/check_covered.dart
# fails `make coverage`.
COVERED := liquid_shell liquid_shell_platform_interface liquid_shell_ios liquid_shell_android
COVERAGE_MIN := 90

.PHONY: help get format format-check analyze test coverage goldens \
        goldens-update provenance public-docs snippets verify pana publish-check \
        android-unit ios-unit ios-ui ios-minimize integration-ios integration-ios-native integration-android pigeon pigeon-check \
        test-impeller compare-images tab-traces tab-frames segment-traces \
        segment-frames

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

get: ## Resolve the whole pub workspace
	$(FLUTTER) pub get

format: ## Rewrite formatting in place (a fixer, not a gate)
	$(DART) format .

format-check: ## Formatting gate: check only, never rewrite
	$(DART) format --output=none --set-exit-if-changed .

analyze: ## Static analysis of every package, the example and tool/; infos and warnings are fatal
	$(DART) analyze --fatal-infos --fatal-warnings $(PACKAGES) $(EXAMPLE) $(EXAMPLE_GO_ROUTER) tool

test: ## Unit and widget tests in every package and the example (no goldens)
	@set -e; for p in $(PACKAGES) $(EXAMPLE) $(EXAMPLE_GO_ROUTER); do \
	  if [ -d $$p/test ]; then \
	    echo "▸ test $$p"; \
	    (cd $$p && $(FLUTTER) test --exclude-tags golden,impeller,liquid_golden); \
	  fi; \
	done
	$(DART) test tool/test

test-impeller: ## Shader tests under Impeller (macOS + Flutter 3.44.x only)
	@if [ "$$(uname)" != Darwin ]; then echo "▸ test-impeller runs on macOS only"; exit 0; fi
	cd liquid_shell && $(FLUTTER) test --enable-impeller --tags impeller

coverage: ## Tests with coverage; fails below COVERAGE_MIN, with no tests, with no lib lines, or when COVERED misses a package with lib code
	@$(DART) run tool/check_covered.dart "$(PACKAGES)" "$(COVERED)"
	@set -e; \
	trap 'for q in $(COVERED); do $(DART) run tool/gen_coverage_helper.dart $$q --remove; done' EXIT; \
	for p in $(COVERED); do \
	  echo "▸ coverage $$p"; \
	  $(DART) run tool/gen_coverage_helper.dart $$p; \
	  (cd $$p && $(FLUTTER) test --exclude-tags golden,impeller,liquid_golden --coverage); \
	  $(DART) run tool/check_coverage.dart $$p/coverage/lcov.info $(COVERAGE_MIN); \
	done

goldens: ## Golden tests (reference toolchain: macOS + Flutter 3.44.x); liquid ones under Impeller
	@if [ -d $(EXAMPLE)/test/goldens ]; then \
	  cd $(EXAMPLE) && $(FLUTTER) test --tags golden && \
	  $(FLUTTER) test --enable-impeller --tags liquid_golden; \
	else echo "▸ no goldens yet"; fi

goldens-update: ## Regenerate every golden and doc image, then recompress them losslessly
	FLUTTER="$(FLUTTER)" DART="$(DART)" tool/update_goldens.sh

compare-images: ## Native vs Flutter liquid side by side (iOS sims you create, emulator in ANDROID_SERIAL); README subset to doc/images
	FLUTTER="$(FLUTTER)" DART="$(DART)" tool/compare_ios.sh
	FLUTTER="$(FLUTTER)" DART="$(DART)" tool/compare_android.sh
	cp $(EXAMPLE)/build/compare/ios_iphone_basic.png liquid_shell/doc/images/compare_iphone_basic.png
	cp $(EXAMPLE)/build/compare/ios_ipad_sidebar_slots_sidebar.png liquid_shell/doc/images/compare_ipad_sidebar_slots.png
	cp $(EXAMPLE)/build/compare/android_basic.png liquid_shell/doc/images/compare_android_basic.png
	$(DART) run tool/compress_pngs.dart liquid_shell/doc/images

tab-traces: ## Flutter tab traces on an iOS 26.5 iPhone 17 Pro simulator vs the native reference (spec VK-503 §17.4)
	FLUTTER="$(FLUTTER)" DART="$(DART)" TRACES_ONLY=1 tool/tab_frames.sh
	$(DART) run tool/tab_trace_compare.dart $(EXAMPLE)/build/integration_response_data.json docs/qa/vk503/native_reference.json

tab-frames: ## Native vs Flutter liquid tab bar strips at 60 fps on an iOS 26.5 simulator (needs ffmpeg)
	FLUTTER="$(FLUTTER)" DART="$(DART)" tool/tab_frames.sh

segment-traces: ## Flutter segmented control traces on an iOS 26.5 iPhone 17 Pro simulator vs the native reference (spec VK-550 §14.5)
	FLUTTER="$(FLUTTER)" DART="$(DART)" TRACES_ONLY=1 tool/segment_frames.sh
	$(DART) run tool/segment_trace_compare.dart $(EXAMPLE)/build/integration_response_data.json docs/qa/vk550/native_reference.json

segment-frames: ## Native vs Flutter liquid segmented control strips at 60 fps on an iOS 26.5 simulator (needs ffmpeg)
	FLUTTER="$(FLUTTER)" DART="$(DART)" tool/segment_frames.sh

provenance: ## Fail on app names or banned dependencies outside docs/, or glass outside LiquidGlass
	tool/check_provenance.sh
	tool/check_glass_seam.sh

public-docs: ## Fail on internal references (§, VK-, phase codes) in dartdoc, READMEs and doc/
	tool/check_public_docs.sh

snippets: ## README snippets must equal their #docregion in example/lib/cases
	@if [ -f tool/check_readme_snippets.dart ]; then \
	  $(DART) run tool/check_readme_snippets.dart; \
	else echo "▸ no snippet check yet"; fi

# Generated by `make pigeon` from liquid_shell_ios/pigeons/native_shell.dart.
PIGEON_OUT := liquid_shell_ios/lib/src/native_shell_api.g.dart \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellApi.g.swift

pigeon: ## Regenerate both ends of the native shell channel
	cd liquid_shell_ios && $(DART) run pigeon --input pigeons/native_shell.dart
	$(DART) format liquid_shell_ios/lib/src/native_shell_api.g.dart

# `git status --porcelain`, not `git diff`: an untracked (never committed) or
# staged-but-uncommitted output must fail too.
pigeon-check: pigeon ## Fail when the committed channel code drifts from its Pigeon source
	@drift="$$(git status --porcelain -- $(PIGEON_OUT))"; [ -z "$$drift" ] || { \
	  echo "$$drift" >&2; \
	  echo "✗ generated channel code drifted from pigeons/native_shell.dart; review git status and commit it" >&2; \
	  exit 1; }
	@echo "✓ pigeon output matches its source"

verify: format-check analyze provenance public-docs pigeon-check test test-impeller coverage goldens snippets ## Everything CI's blocking jobs run
	@echo "✓ verify passed"

pana: ## pana for each package (see docs/plans: pre-publish limits)
	@set -e; for p in $(PACKAGES); do \
	  echo "▸ pana $$p"; \
	  $(DART) pub global run pana --no-warning $$p; \
	done

publish-check: ## pub publish --dry-run for each package
	@set -e; for p in $(PACKAGES); do \
	  echo "▸ publish --dry-run $$p"; \
	  (cd $$p && $(FLUTTER) pub publish --dry-run); \
	done

android-unit: ## JVM unit tests of the Android plugin (SignalReaderTest)
	cd $(EXAMPLE) && $(FLUTTER) build apk --debug --config-only
	cd $(EXAMPLE)/android && ./gradlew :liquid_shell_android:testDebugUnitTest

# The XCTest targets run tool/ios_xctest.sh (spec VK-625 §6): build-for-
# testing (each build step capped at IOS_BUILD_TIMEOUT), one warm-up launch
# of the built app on the booted simulator (tool/ios_sim.sh warmup: outside
# every cap, never failing), then test-without-building under the suite's
# own cap, IOS_UNIT_TIMEOUT / IOS_UI_TIMEOUT / IOS_MINIMIZE_TIMEOUT (exit 124
# after a diagnostics dump). A red run prints the result bundle's summary.
#
# IOS_BUILD_TIMEOUT: CI's first app launch came 93-458 s after `xcodebuild
# test` started, build and implicit boot included, and flutter's first drive
# build took up to 109 s (VK-625 evidence); 900 s is about twice the worst.
IOS_BUILD_TIMEOUT ?= 900
IOS_UNIT_TIMEOUT ?= 900
IOS_UNIT_RESULT := $(CURDIR)/$(EXAMPLE)/build/ios-unit.xcresult

ios-unit: ## XCTest of liquid_shell_ios (example RunnerTests) on an iPad or iPhone simulator; IOS_UNIT_DEVICE=<udid>
	FLUTTER="$(FLUTTER)" IOS_BUILD_TIMEOUT=$(IOS_BUILD_TIMEOUT) tool/ios_xctest.sh \
	  "$${IOS_UNIT_DEVICE:?set IOS_UNIT_DEVICE to a simulator UDID}" \
	  $(IOS_UNIT_RESULT) $(IOS_UNIT_TIMEOUT) 60 120 \
	  -only-testing:RunnerTests -skip-testing:RunnerUITests

# The UI suite's own cap. Until VK-625 it included the build; the numbers
# below do, so they overstate the suite alone. Measured on CI's iPhone 17
# (iOS 26.5): 12 tests took 436-840 s by runner (PR #9); with VK-551's
# three edge-swipe tests (15) a slow runner hit 900 s with four still to
# run, about 1100 s in all; locally 477 s. VK-571 adds two full-launch
# search tests (17): locally 383 s on an iPhone 16 Plus and 336 s on an
# iPad Pro 11 (14 run, 3 iPhone-only skipped), both iOS 26.5; scaled to
# the slow runner, about 1250 s, too close to the old 1500 s. 1800 s keeps
# ~550 s in hand, inside the job's 40 minutes; a stalled test still stops
# at its 300 s. VK-550 adds the native scope bar test (18): locally 410 s
# on an iPhone 17 Pro and 343 s on an iPad Air 11 (M4) (15 run), iOS
# 26.5, the new test 26-37 s of it; scaled the same way, about 1350 s, so
# 1800 s still keeps ~450 s in hand. Its reset-scope test (19): 446 s on
# the iPhone and 397 s on the iPad (16 run), the new test 21-22 s; about
# 1400 s scaled. VK-567 adds one iPhone-only full-launch test: 29 s
# locally, its whole run 445 s on an iPhone 17 (iOS 26.5) under heavy
# load; about 1330 s on the slow runner. Merged, with VK-550's
# SegmentFidelityUITests (iPhone only), 21 tests: 443 s on an iPhone 17
# Pro (21 run) and 318 s on an iPad Air 11 (M4) (16 run, 5 iPhone-only
# skipped), iOS 26.5, load 4-7; scaled the same way, about 1400 s. CI ran
# PR #13's 18 in about 850 s per device (the whole XCUITest step), so
# 1800 s keeps ~400 s in hand even on the slow-runner scale. On a shared
# host at load ~850 one run stalled past 1800 s; IOS_UI_TIMEOUT=3600 gets
# such a host through. VK-600 adds MinimizeUITests (7: five iPhone-only,
# two iPad-only; 28 in the suite): locally 534 s on an iPhone 17 Pro (26 run,
# the five 81 s of it) and 357 s on an iPad Air 11 (M4) (18 run), iOS 26.5,
# load 6-11. Scaled as above (443 s, about 1400 s), about 1700 s, which
# 1800 s would keep only ~100 s ahead of; VK-571 raised the cap at 250 s.
# 2100 s keeps ~400 s in hand, as before; CI's job allows 45 minutes.
# CI ran those 26 iPhone tests in 1092-1156 s and the iPad's 18 in 847-849 s
# (PR #15). The final review's lock test (one more iPhone launch, 35 s
# locally) makes 27 of 29: well inside the cap.
IOS_UI_TIMEOUT ?= 2100
IOS_UI_RESULT := $(CURDIR)/$(EXAMPLE)/build/ios-ui.xcresult

ios-ui: ## XCUITest: real taps on native dialogs and the search tab (example RunnerUITests) on a simulator; IOS_UNIT_DEVICE=<udid>
	FLUTTER="$(FLUTTER)" IOS_BUILD_TIMEOUT=$(IOS_BUILD_TIMEOUT) tool/ios_xctest.sh \
	  "$${IOS_UNIT_DEVICE:?set IOS_UNIT_DEVICE to a simulator UDID}" \
	  $(IOS_UI_RESULT) $(IOS_UI_TIMEOUT) 180 300 \
	  -only-testing:RunnerUITests

# M7 of VK-600's review, blocking on CI since VK-625: MinimizeUITests alone
# (6 iPhone tests, 2 iPad-only skips). 165 s on an iPhone 17 (iOS 26.5) here,
# at host load ~200; VK-600 measured five of them at 81 s at load 6-11. On
# the slow-runner scale above (x3.2) six take about 310 s; one test stopped
# at its 300 s allowance makes about 610 s. 900 s keeps ~290 s in hand.
IOS_MINIMIZE_TIMEOUT ?= 900
IOS_MINIMIZE_RESULT := $(CURDIR)/$(EXAMPLE)/build/ios-minimize.xcresult

ios-minimize: ## XCUITest: MinimizeUITests only (native tab bar minimize) on a simulator; IOS_UNIT_DEVICE=<udid>
	FLUTTER="$(FLUTTER)" IOS_BUILD_TIMEOUT=$(IOS_BUILD_TIMEOUT) tool/ios_xctest.sh \
	  "$${IOS_UNIT_DEVICE:?set IOS_UNIT_DEVICE to a simulator UDID}" \
	  $(IOS_MINIMIZE_RESULT) $(IOS_MINIMIZE_TIMEOUT) 180 300 \
	  -only-testing:RunnerUITests/MinimizeUITests

integration-ios: ## Signal channel round-trip on an iOS simulator
	FLUTTER="$(FLUTTER)" tool/integration_ios.sh

integration-ios-native: ## Native iOS 26 shell, dialogs and search tab on iPad and iPhone simulators
	FLUTTER="$(FLUTTER)" tool/integration_ios_native.sh

integration-android: ## Signal channel + every Android signal on an emulator
	FLUTTER="$(FLUTTER)" tool/integration_android.sh
