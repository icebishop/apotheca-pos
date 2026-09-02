# Apothêca Makefile
# Requires: lazbuild (from Lazarus IDE), fpc

PROJECT = apotheca
LPI = $(PROJECT).lpi
BINARY = $(PROJECT)
TEST_DIR = tests
PACKAGE_NAME = apotheca-dist
VERSION = 2.3.0

# Lazarus build tool
LAZBUILD = lazbuild
FPC = fpc

# Test runners
TEST_RUNNERS = $(wildcard $(TEST_DIR)/run_*.lpr)
TEST_BINARIES = $(TEST_RUNNERS:.lpr=)

# Source unit paths and LCL/LazUtils paths for compiling tests directly with fpc
SRC_UNIT_PATHS = -Fu../model -Fu../service -Fu../repository -Fu../infrastructure
LAZUTILS_PATH = /usr/lib/lazarus/components/lazutils/lib/x86_64-linux
LCL_UNITS_PATH = /usr/lib/lazarus/lcl/units/x86_64-linux

# Instagram Publication test runners (compiled with fpc directly)
IG_TEST_RUNNERS = run_caption_publish_test run_detector_publish_test \
                  run_publish_image_url_test run_publish_tracking_test

.PHONY: all build test test-instagram run clean package release help

# Release settings
TAG = v$(VERSION)
ARCHIVE = dist/$(PACKAGE_NAME)-$(VERSION)-linux-x86_64.tar.gz

## Default target
all: build

## Build the application
build:
	@echo "Building $(PROJECT)..."
	$(LAZBUILD) $(LPI)
	@echo "Build complete: ./$(BINARY)"

## Run all property-based tests
test: build-tests
	@echo "Running tests..."
	@PASS=0; FAIL=0; \
	for t in $(TEST_DIR)/run_*; do \
		if [ -x "$$t" ] && [ ! "$$t" = "*.lpr" ]; then \
			echo "  Running $$t..."; \
			if $$t 2>&1 | tail -5; then \
				PASS=$$((PASS + 1)); \
			else \
				FAIL=$$((FAIL + 1)); \
			fi; \
			echo ""; \
		fi; \
	done; \
	echo "Results: $$PASS passed, $$FAIL failed"; \
	[ $$FAIL -eq 0 ]

## Build test binaries
build-tests:
	@echo "Building tests..."
	@for lpr in $(TEST_RUNNERS); do \
		echo "  Compiling $$lpr..."; \
		$(LAZBUILD) $$lpr 2>&1 | tail -1; \
	done
	@echo "Test build complete"

## Build and run the Instagram Publication property tests (compiled directly with fpc)
test-instagram:
	@echo "Building and running Instagram Publication tests..."
	@cd $(TEST_DIR); PASS=0; FAIL=0; \
	for t in $(IG_TEST_RUNNERS); do \
		echo "  Compiling $$t..."; \
		if $(FPC) -MObjFPC $(SRC_UNIT_PATHS) -Fu$(LAZUTILS_PATH) -Fu$(LCL_UNITS_PATH) $$t.lpr > /tmp/$$t.build 2>&1; then \
			echo "  Running $$t..."; \
			if ./$$t --all --format=plainnotiming 2>&1 | tail -4; then \
				PASS=$$((PASS + 1)); \
			else \
				FAIL=$$((FAIL + 1)); \
			fi; \
		else \
			echo "  BUILD FAILED for $$t (see /tmp/$$t.build)"; \
			FAIL=$$((FAIL + 1)); \
		fi; \
		echo ""; \
	done; \
	echo "Instagram test suites: $$PASS built+run, $$FAIL failed"; \
	[ $$FAIL -eq 0 ]

## Build and run the application
run: build
	@echo "Starting $(PROJECT)..."
	./$(BINARY)

## Remove all build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f *.o *.ppu *.rsj *.compiled *.or *.res
	rm -f $(BINARY)
	rm -f link*.res ppas.sh
	rm -f $(TEST_DIR)/*.o $(TEST_DIR)/*.ppu
	rm -f $(TEST_DIR)/run_balance_invariant_test
	rm -f $(TEST_DIR)/run_csv_export_test
	rm -f $(TEST_DIR)/run_product_search_test
	rm -f $(TEST_DIR)/run_purchase_balance_test
	rm -f $(TEST_DIR)/run_report_date_filter_test
	rm -f $(TEST_DIR)/run_sale_balance_test
	rm -f $(TEST_DIR)/run_tests
	rm -f $(TEST_DIR)/run_caption_publish_test
	rm -f $(TEST_DIR)/run_detector_publish_test
	rm -f $(TEST_DIR)/run_publish_image_url_test
	rm -f $(TEST_DIR)/run_publish_tracking_test
	rm -f $(TEST_DIR)/test_cart_arithmetic
	rm -f $(TEST_DIR)/test_cart_quantity
	@echo "Clean complete"

## Create distributable package
package: build
	@echo "Packaging $(PACKAGE_NAME)-$(VERSION)..."
	@mkdir -p dist/$(PACKAGE_NAME)
	@cp $(BINARY) dist/$(PACKAGE_NAME)/
	@cp $(PROJECT).ico dist/$(PACKAGE_NAME)/
	@cp -r icons dist/$(PACKAGE_NAME)/
	@cp -r res dist/$(PACKAGE_NAME)/
	@cp -r languages dist/$(PACKAGE_NAME)/
	@mkdir -p dist/$(PACKAGE_NAME)/db
	@mkdir -p dist/$(PACKAGE_NAME)/logs
	@echo "Creating archive..."
	@cd dist && tar -czf $(PACKAGE_NAME)-$(VERSION)-linux-x86_64.tar.gz $(PACKAGE_NAME)
	@echo "Package created: dist/$(PACKAGE_NAME)-$(VERSION)-linux-x86_64.tar.gz"

## Create a GitHub release and upload the packaged archive (requires: gh CLI, authenticated)
release: package
	@command -v gh >/dev/null 2>&1 || { echo "ERROR: GitHub CLI 'gh' is not installed."; exit 1; }
	@echo "Publishing release $(TAG)..."
	@if gh release view $(TAG) >/dev/null 2>&1; then \
		echo "Release $(TAG) exists; uploading asset (overwriting if present)..."; \
		gh release upload $(TAG) $(ARCHIVE) --clobber; \
	else \
		echo "Creating release $(TAG)..."; \
		gh release create $(TAG) $(ARCHIVE) \
			--title "Apothêca $(VERSION)" \
			--notes "Apothêca $(VERSION) - Linux x86_64 build."; \
	fi
	@echo "Release $(TAG) published with asset: $(ARCHIVE)"

## Show help
help:
	@echo "Apothêca Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make build        - Compile the application"
	@echo "  make test         - Run all property-based tests"
	@echo "  make build-tests  - Compile test binaries only"
	@echo "  make run          - Build and run the application"
	@echo "  make clean        - Remove all build artifacts"
	@echo "  make package      - Create distributable archive"
	@echo "  make release      - Package + upload archive to a GitHub release (tag v$(VERSION))"
	@echo "  make help         - Show this help"
	@echo ""
	@echo "Requirements: lazbuild (Lazarus IDE), fpc 3.2.2+; 'gh' CLI for 'make release'"
