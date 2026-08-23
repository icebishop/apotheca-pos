# Apothêca Makefile
# Requires: lazbuild (from Lazarus IDE), fpc

PROJECT = apotheca
LPI = $(PROJECT).lpi
BINARY = $(PROJECT)
TEST_DIR = tests
PACKAGE_NAME = apotheca-dist
VERSION = 2.0.0

# Lazarus build tool
LAZBUILD = lazbuild
FPC = fpc

# Test runners
TEST_RUNNERS = $(wildcard $(TEST_DIR)/run_*.lpr)
TEST_BINARIES = $(TEST_RUNNERS:.lpr=)

.PHONY: all build test run clean package help

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
	@echo "  make help         - Show this help"
	@echo ""
	@echo "Requirements: lazbuild (Lazarus IDE), fpc 3.2.2+"
