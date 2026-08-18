# Implementation Plan: JSON Export

## Overview

This plan implements the JSON Export feature for Apotheca POS in Free Pascal/Lazarus. The implementation proceeds bottom-up: database schema migration first, then model extensions, repository layer, service-layer components (validator, converter, serializer, orchestrator), and finally the Export Frame UI. Property-based tests are interspersed with their corresponding implementation tasks to catch errors early.

## Tasks

- [x] 1. Database schema migration and images table
  - [x] 1.1 Add export column migrations to TDataModule1
    - Add `MigrateProductExportColumns` private method to `infrastructure/udatamodule.pas`
    - Use `PRAGMA table_info(product)` to check for `image_ref`, `originalprice`, and `isservice` columns
    - Add each missing column individually via ALTER TABLE with defaults (INTEGER 0, REAL 0.0, INTEGER 0)
    - Log errors with `LogError` if ALTER TABLE fails for a column; skip and continue
    - Call after existing migrations in `DataModuleCreate`, before any product data access
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

  - [x] 1.2 Create images table in TDataModule1
    - Add `CreateImagesTable` private method to `infrastructure/udatamodule.pas`
    - Execute `CREATE TABLE IF NOT EXISTS images (id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL, data BLOB NOT NULL)`
    - Create index: `CREATE INDEX IF NOT EXISTS idx_images_product ON images(product_id)`
    - Add public field `ImagesTableReady: Boolean` set to True on success, False on failure
    - Log error with `LogError` if creation fails; continue startup with images disabled
    - Call from `DataModuleCreate` after `MigrateProductExportColumns`
    - _Requirements: 2.1, 2.2, 13.6, 13.7_

- [x] 2. Extend TProduct model
  - [x] 2.1 Add Image_Ref, Original_Price, and Service_Flag to TProduct
    - Add private fields to `model/uproduct.pas`: `imageRef: Integer`, `originalPrice: Real`, `isService: Boolean`
    - Add getter/setter methods: `setImageRef`/`getImageRef`, `setOriginalPrice`/`getOriginalPrice`, `setIsService`/`getIsService`
    - Initialize in constructor: `imageRef := 0`, `originalPrice := 0.0`, `isService := False`
    - In `setOriginalPrice`: reject negative values (retain previous value if V < 0.0)
    - _Requirements: 1.1, 1.2, 4.1, 4.2, 4.3, 5.1, 5.2_

  - [x]* 2.2 Write property test for Original Price range validation (Property 2)
    - Create `tests/test_original_price.pas`
    - **Property 2: Original Price Range Validation and Round-Trip**
    - Generate random Real values in [0.00, 999999999.99]; verify set/get round-trip
    - Generate random negative values; verify previous value is retained
    - Minimum 150 iterations
    - **Validates: Requirements 4.2, 4.3**

- [x] 3. Update TDataProducto repository for new columns
  - [x] 3.1 Extend TDataProducto CRUD for new product attributes
    - Update `repository/udataproduct.pas` `new` method: include `image_ref`, `originalprice`, `isservice` in INSERT
    - Update `edit` method: include new columns in UPDATE SET clause
    - Update `get` method: read new columns from query result, populate model (NULL → defaults)
    - _Requirements: 1.3, 1.4, 1.5, 4.4, 4.5, 5.3, 5.4, 5.5_

- [x] 4. Implement TDataImage repository
  - [x] 4.1 Create TDataImage unit
    - Create `repository/udataimage.pas` with class `TDataImage` extending `TData`
    - Implement `Store(productId: Integer; const PngData: TBytes): Integer` — INSERT and return generated ID
    - Implement `Update(imageId: Integer; const PngData: TBytes): Boolean` — UPDATE data column
    - Implement `Get(imageId: Integer): TBytes` — SELECT data by id
    - Implement `GetByProduct(productId: Integer): TBytes` — SELECT data by product_id
    - Implement `Delete(productId: Integer): Boolean` — DELETE by product_id
    - Use parameterized queries with BLOB binding for PngData
    - _Requirements: 2.3, 2.4, 2.5, 2.6_

- [x] 5. Checkpoint - Ensure data layer compiles
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement TPngValidator
  - [x] 6.1 Create TPngValidator unit
    - Create `service/upngvalidator.pas` with class `TPngValidator`
    - Implement `class function IsValidPng(const Data: TBytes): Boolean` — check length >= 8 and first 8 bytes = [$89, $50, $4E, $47, $0D, $0A, $1A, $0A]
    - Implement `class function IsValidPngFile(const FilePath: String): Boolean` — read first 8 bytes from file, delegate to IsValidPng
    - Implement `class function GetValidationError(const Data: TBytes): String` — return descriptive error (empty file, invalid signature)
    - _Requirements: 3.1, 3.2, 3.3_

  - [x]* 6.2 Write property test for PNG signature validation (Property 1)
    - Create `tests/test_png_validator.pas`
    - **Property 1: PNG Signature Validation**
    - Generate random byte arrays of various lengths (0..1024); verify IsValidPng returns True iff first 8 bytes match PNG signature
    - Generate valid 8-byte prefix + random trailing bytes; verify returns True
    - Minimum 150 iterations
    - **Validates: Requirements 3.1, 3.2, 3.3**

- [x] 7. Implement TWebPConverter
  - [x] 7.1 Create TWebPConverter unit with name normalization
    - Create `service/uwebpconverter.pas` with class `TWebPConverter`
    - Implement `class function NormalizeProductName(const Name: String): String` — lowercase, replace non-alphanumeric with underscore
    - Implement constructor `Create` — locate cwebp executable via PATH search using `FindDefaultExecutablePath`
    - Implement `function Convert(const PngData: TBytes; const OutputDir: String; const NormalizedName: String; Quality: Integer = 80): Boolean`
      - Write PngData to temp file in OutputDir
      - Invoke `cwebp -q {Quality} {tempfile} -o {OutputDir}/{NormalizedName}.webp` via `TProcess`
      - Delete temp file
      - Return True on success (exit code 0), False on failure
    - Implement `function GetLastError(): String` — stores last error message
    - _Requirements: 8.1, 8.2, 8.3_

  - [x]* 7.2 Write property test for name normalization (Property 3)
    - Create `tests/test_name_normalization.pas`
    - **Property 3: Name Normalization Output Invariant**
    - Generate random non-empty strings with Unicode and special characters
    - Verify output contains only [a-z0-9_] characters
    - Verify output equals lowercase of input with non-alphanumeric replaced by underscore
    - Minimum 150 iterations
    - **Validates: Requirements 8.3, 8.4**

- [x] 8. Implement TJsonSerializer
  - [x] 8.1 Create TJsonSerializer unit
    - Create `service/ujsonserializer.pas` with class `TJsonSerializer`
    - Implement `function EscapeJsonString(const S: String): String` — escape `"`, `\`, control chars U+0000..U+001F as `\uXXXX`
    - Implement `function RoundHalfUp(Value: Real): Integer` — return `Floor(Value + 0.5)`
    - Implement `function FormatJsonObject(const Pairs: array of String): String` — format key-value pairs with 2-space indent and fixed ordering
    - Implement `function SerializeProduct(Product: TProduct; const ImagePath: String): String`
      - Keys in order: "id", "name", "price", "originalPrice", "description", "images", "isVisible"
      - "id" = "p" + IntToStr(id); "price" = RoundHalfUp(balance.price); "images" = array with path or empty
      - "isVisible" = balance.units > 0
    - Implement `function SerializeService(Product: TProduct; const ImagePath: String): String`
      - Keys in order: "id", "name", "price", "originalPrice", "description", "image"
      - "id" = "s" + IntToStr(id); "image" = path string or empty string
    - Implement `function SerializeProducts(Products: TList; const ImageDir: String): String` — JSON array of product objects
    - Implement `function SerializeServices(Services: TList; const ImageDir: String): String` — JSON array of service objects
    - Use 2-space indentation, UTF-8 encoding, RFC 8259 compliance
    - _Requirements: 9.2, 9.3, 10.2, 10.3, 11.1, 11.2, 11.3, 11.4, 11.5, 11.6_

  - [x]* 8.2 Write property test for JSON string escaping (Property 7)
    - Add test to `tests/test_json_serializer.pas`
    - **Property 7: JSON String Escaping**
    - Generate random strings with embedded quotes, backslashes, and control characters
    - Verify all `"` escaped as `\"`, all `\` escaped as `\\`, all U+0000..U+001F escaped as `\uXXXX`
    - Verify result placed between quotes forms valid JSON string
    - Minimum 150 iterations
    - **Validates: Requirements 11.3**

  - [x]* 8.3 Write property test for round-half-up pricing (Property 8)
    - Add test to `tests/test_json_serializer.pas`
    - **Property 8: Round-Half-Up Pricing**
    - Generate random Real values in [0.0, 999999999.99]
    - Verify `RoundHalfUp(V) = Floor(V + 0.5)`
    - Test boundary cases: 0.5→1, 1.4→1, 1.5→2, 0.0→0
    - Minimum 150 iterations
    - **Validates: Requirements 11.4**

  - [x]* 8.4 Write property test for product JSON structure (Property 4)
    - Add test to `tests/test_json_serializer.pas`
    - **Property 4: Product JSON Serialization Structure**
    - Generate random TProduct instances with Service_Flag=False, random names, prices, stocks, image paths
    - Verify serialized JSON has exactly 7 keys in fixed order
    - Verify "id" = "p" + id, "price" = RoundHalfUp(balance.price), "isVisible" = stock > 0
    - Minimum 150 iterations
    - **Validates: Requirements 9.2, 9.3, 11.6**

  - [x]* 8.5 Write property test for service JSON structure (Property 5)
    - Add test to `tests/test_json_serializer.pas`
    - **Property 5: Service JSON Serialization Structure**
    - Generate random TProduct instances with Service_Flag=True, random names, prices, image paths
    - Verify serialized JSON has exactly 6 keys in fixed order
    - Verify "id" = "s" + id, "price" = RoundHalfUp(balance.price), "image" = path or ""
    - Minimum 150 iterations
    - **Validates: Requirements 10.2, 10.3, 11.6**

  - [x]* 8.6 Write property test for JSON idempotence (Property 9)
    - Add test to `tests/test_json_serializer.pas`
    - **Property 9: JSON Serialization Idempotence**
    - Generate random product/service lists, serialize, parse key-value structure, re-serialize
    - Verify byte-for-byte identical output
    - Minimum 150 iterations
    - **Validates: Requirements 11.7**

- [x] 9. Implement TExportService
  - [x] 9.1 Create TExportService unit with file path derivation and orchestration
    - Create `service/uexportservice.pas` with records `TExportResult` and `TExportOptions`, and class `TExportService`
    - Implement `function DeriveFilePaths(const BasePath: String; Both: Boolean): TStringArray`
      - If BasePath contains ".json": insert "_products"/"_services" before ".json"
      - Otherwise: append "_products.json"/"_services.json"
    - Implement `function QueryProducts(IsService: Boolean): TList` — query TDataProducto filtering by isservice column
    - Implement `function ProcessImage(Product: TProduct; const ImageDir: String): String`
      - If ImageRef > 0: retrieve PNG from TDataImage, validate, convert via TWebPConverter
      - Return relative WebP path or empty string on failure
    - Implement `function Execute(const Options: TExportOptions): TExportResult`
      - Validate paths (directory exists, writable)
      - Query products/services based on Options
      - Process images for each record
      - Serialize via TJsonSerializer
      - Write files; handle partial failure for dual export
      - Delete partial file on write error
    - _Requirements: 8.1, 8.5, 8.6, 9.1, 9.4, 9.5, 10.1, 10.4, 10.5, 10.6, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7_

  - [x]* 9.2 Write property test for file path derivation (Property 6)
    - Add test to `tests/test_json_serializer.pas`
    - **Property 6: File Path Derivation**
    - Generate random path strings with and without ".json" extension
    - Verify "_products" inserted before ".json" or appended as "_products.json"
    - Verify "_services" inserted before ".json" or appended as "_services.json"
    - Minimum 150 iterations
    - **Validates: Requirements 9.5, 10.4**

- [x] 10. Checkpoint - Ensure service layer compiles and property tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Implement TFrameExport UI
  - [x] 11.1 Create TFrameExport frame unit
    - Create `view/uframeexport.pas` and `view/uframeexport.lfm`
    - Add TFrame with components:
      - `chkProducts: TCheckBox` ("Export Products", checked by default)
      - `chkServices: TCheckBox` ("Export Services", checked by default)
      - `edtFilePath: TEdit` (read-only, initialized to app directory + "export.json")
      - `btnBrowseFile: TBitBtn` (opens TSaveDialog filtered to *.json)
      - `edtImageDir: TEdit` (read-only, initialized to app directory)
      - `btnBrowseDir: TBitBtn` (opens TSelectDirectoryDialog)
      - `btnExport: TBitBtn` (triggers export)
      - `btnSelectImage: TBitBtn` ("Select Image" for associating PNG with product)
      - `lblStatus: TLabel` (empty, shows result/error messages)
    - Implement Browse button handlers: update paths on selection, retain on cancel
    - Implement Export button handler:
      - Validate at least one checkbox checked (show error in lblStatus if not)
      - Build TExportOptions from UI state
      - Call TExportService.Execute
      - Display result in lblStatus (success count or error message)
    - Implement Select Image button handler:
      - Open file dialog filtered to *.png
      - Validate via TPngValidator
      - Store in images table via TDataImage
      - Update product ImageRef via TDataProducto
    - _Requirements: 3.4, 3.5, 3.6, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 7.10, 7.11, 7.12, 7.13, 12.1, 12.5_

  - [x] 11.2 Wire Export sidebar button in main form
    - Add Export button to sidebar panel in the main form (apothecamain or equivalent)
    - Use `icons/export_16.png` icon, label "Export", 180×48 pixels, top-aligned, white font
    - Position as last button below existing sidebar navigation buttons
    - On click: show TFrameExport, hide other frames, highlight Export button
    - If already active: no-op (don't reload frame)
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 12. Integration tests
  - [x]* 12.1 Write integration tests for images table CRUD and full export pipeline
    - Create `tests/test_json_export_integration.pas`
    - Test images table: Store, Get, GetByProduct, Update, Delete with real SQLite DB
    - Test product persistence round-trip with new attributes (image_ref, originalprice, isservice)
    - Test full export pipeline: create products/services, assign images, run export, verify JSON files content
    - Test migration idempotency: run migration twice without errors
    - Test WebP conversion: valid PNG produces .webp file (skip if cwebp not available)
    - _Requirements: 2.3, 2.4, 2.5, 2.6, 1.3, 1.4, 1.5, 9.1, 9.4, 10.1_

- [x] 13. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The project uses FPCUnit with a random-generator harness (150 iterations per property), following the existing pattern in `tests/test_csv_export.pas`
- WebP conversion integration tests should gracefully skip if `cwebp` is not installed on the test machine

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "3.1"] },
    { "id": 3, "tasks": ["4.1"] },
    { "id": 4, "tasks": ["6.1", "7.1", "8.1"] },
    { "id": 5, "tasks": ["6.2", "7.2", "8.2", "8.3"] },
    { "id": 6, "tasks": ["8.4", "8.5", "8.6", "9.1"] },
    { "id": 7, "tasks": ["9.2"] },
    { "id": 8, "tasks": ["11.1", "11.2"] },
    { "id": 9, "tasks": ["12.1"] }
  ]
}
```
