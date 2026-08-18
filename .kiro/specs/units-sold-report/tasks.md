# Implementation Plan: Units Sold Report

## Overview

Implement the Units Sold Report feature for Apotheca POS. This adds a new report method to `TReportEngine` that aggregates sale transactions by product within a date range, a UI form with grid display, and CSV export. The implementation follows the existing layered architecture: model record type → service method → UI form → export, with property-based and example-based tests validating correctness.

## Tasks

- [x] 1. Add TUnitsSoldRow record type and GetUnitsSoldReport method
  - [x] 1.1 Declare TUnitsSoldRow record and GetUnitsSoldReport method signature in ureportengine.pas
    - Add the `TUnitsSoldRow` record type (ProductId, ProductName, UnitsSold, TotalRevenue, TotalCost, Utility) to the type section of `service/ureportengine.pas`
    - Add the `GetUnitsSoldReport(StartDate, EndDate: TDateTime; var GrandTotalUnits: Integer; var GrandTotalRevenue, GrandTotalCost, GrandTotalUtility: Real): TList` function declaration to `TReportEngine`
    - _Requirements: 1.1, 1.5_

  - [x] 1.2 Implement GetUnitsSoldReport method body
    - Initialize empty TList result and zero all grand total out-parameters
    - Return empty list if `FConnection = nil` (requirement 3.2)
    - Return empty list if `StartDate > EndDate` (requirement 2.4)
    - Create TSQLTransaction and TSQLQuery, build aggregation SQL with GROUP BY product, HAVING SUM(stock) > 0, ORDER BY units_sold DESC, product name ASC
    - Convert StartDate/EndDate to Julian Day using existing formula (`Int(Date) + 2415018.5` / `Int(Date) + 2415019.49999`)
    - Iterate result set: allocate `^TUnitsSoldRow` with `New()`, populate fields including `Utility := TotalRevenue - TotalCost` rounded to 2 decimal places
    - Accumulate grand totals during iteration
    - Wrap in try..except, rollback on failure, return empty list with zeroed totals (requirement 3.3)
    - Free Query and Transaction objects
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

  - [ ]* 1.3 Write property test for aggregation correctness (Property 1)
    - **Property 1: Aggregation correctness**
    - **Validates: Requirements 1.2, 1.3, 1.4, 6.5**
    - Create `tests/test_units_sold_aggregation.pas` with `TTestUnitsSoldAggregation` class
    - Generate random sets of items (1..20 products, 1..10 items per product, random quantities 1..100, prices 0.01..999.99, costs 0.01..499.99)
    - Group by product and assert: one row per distinct product, UnitsSold = sum of quantities, TotalRevenue = sum(qty × price) rounded to 2dp, TotalCost = sum(qty × cost) rounded to 2dp
    - 150 iterations

  - [ ]* 1.4 Write property test for utility invariant (Property 2)
    - **Property 2: Utility invariant**
    - **Validates: Requirements 1.5, 6.4**
    - In `tests/test_units_sold_aggregation.pas`, add test method verifying that for any TUnitsSoldRow, Utility = RoundTo(TotalRevenue - TotalCost, -2)
    - Generate random revenue (0.01..99999.99) and cost (0.01..49999.99) values
    - 150 iterations

  - [ ]* 1.5 Write property test for grand totals invariant (Property 3)
    - **Property 3: Grand totals invariant**
    - **Validates: Requirements 1.7, 6.1, 6.2, 6.3, 6.6**
    - In `tests/test_units_sold_aggregation.pas`, add test method that generates a random list of TUnitsSoldRow records (1..25 rows) and verifies grand total sums match individual row sums
    - 150 iterations

  - [ ]* 1.6 Write property test for sort order (Property 4)
    - **Property 4: Sort order**
    - **Validates: Requirements 1.6**
    - In `tests/test_units_sold_aggregation.pas`, add test method that generates random product names and unit counts (including ties), sorts using the report logic, and asserts descending UnitsSold with ascending ProductName tiebreaker
    - 150 iterations

  - [ ]* 1.7 Create test runner for aggregation tests
    - Create `tests/run_units_sold_aggregation_test.lpr` following existing pattern (uses fpcunit, testregistry, consoletestrunner, references test_units_sold_aggregation unit)
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [x] 2. Checkpoint - Verify core engine logic
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Implement date filter tests and report UI form
  - [x] 3.1 Write property test for date filter correctness (Property 5)
    - **Property 5: Date filter correctness**
    - **Validates: Requirements 2.1, 2.2**
    - Create `tests/test_units_sold_date_filter.pas` with `TTestUnitsSoldDateFilter` class
    - Generate random transactions with dates within last year, generate random valid date ranges
    - Apply date filter logic and assert: all returned items have dates within [StartDate 00:00:00, EndDate 23:59:59], no in-range transaction is excluded
    - 150 iterations

  - [ ]* 3.2 Create test runner for date filter tests
    - Create `tests/run_units_sold_date_filter_test.lpr` following existing pattern (uses fpcunit, testregistry, consoletestrunner, references test_units_sold_date_filter unit)
    - _Requirements: 2.1, 2.2_

  - [x] 3.3 Create report UI form with grid display
    - Create a new form unit (e.g., `uframereportunitssold.pas` / `.lfm`) or integrate into the existing reports frame
    - Add TDateEdit controls for StartDate and EndDate
    - Add TStringGrid with 5 columns: Producto, Unidades Vendidas, Ingresos, Costo, Utilidad
    - Add a Generate/Refresh button that calls `TReportEngine.GetUnitsSoldReport` with selected dates
    - Populate grid rows from the returned TList of `^TUnitsSoldRow`, formatting revenue/cost/utility with `Format('%.2f', [Value])`
    - Add grand totals row as last row with "TOTAL" label in column 0
    - Call `DistributeColumns(Grid, [30, 18, 18, 18, 16])` for column widths
    - Handle empty results: show headers + zero totals row only (requirement 4.5)
    - Dispose each `^TUnitsSoldRow` and free the TList after populating grid
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [ ]* 3.4 Write example-based tests for grid and edge cases
    - In `tests/test_units_sold_aggregation.pas` (or a dedicated unit), add example-based tests:
    - Test nil connection returns empty list without exception (Req 3.2)
    - Test StartDate > EndDate returns empty result (Req 1.8, 2.4)
    - Test single-day range (Start = End) includes all transactions on that day (Req 2.3)
    - Test empty date range (no transactions) returns zero totals (Req 3.1)
    - _Requirements: 1.8, 2.3, 2.4, 3.1, 3.2, 3.3_

- [x] 4. Implement CSV export
  - [x] 4.1 Implement CSV export procedure for Units Sold Report
    - Add `ExportUnitsSoldToCSV(Grid: TStringGrid; const FileName: String)` procedure (or integrate into the report form's export button handler)
    - Write header row: `"Product","Units Sold","Revenue","Cost","Utility"`
    - Write data rows: iterate grid rows 1..RowCount-1, each field quoted and comma-separated
    - Last row contains grand totals with "Total" label
    - On write failure: show error message, preserve grid data unchanged (requirement 5.5)
    - Handle empty report: write only header + zero totals row (requirement 5.4)
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [ ]* 4.2 Write property test for CSV round-trip (Property 6)
    - **Property 6: CSV export round-trip**
    - **Validates: Requirements 5.2, 5.6**
    - Create `tests/test_units_sold_csv.pas` with `TTestUnitsSoldCSV` class
    - Generate random report grids (0..25 product rows + header + totals row, 5 columns), export to CSV string, parse back, assert field values match original grid cells, correct line count (N+2), correct field count per line (5)
    - 150 iterations

  - [ ]* 4.3 Create test runner for CSV tests
    - Create `tests/run_units_sold_csv_test.lpr` following existing pattern (uses fpcunit, testregistry, consoletestrunner, references test_units_sold_csv unit)
    - _Requirements: 5.2, 5.6_

  - [ ]* 4.4 Write example-based tests for CSV export
    - Test CSV header row contains expected column names (Req 5.1)
    - Test last CSV row has "Total" label with correct grand total values (Req 5.3)
    - Test empty report exports header + zero totals row only (Req 5.4)
    - Test write to invalid path shows error and grid is unchanged (Req 5.5)
    - _Requirements: 5.1, 5.3, 5.4, 5.5_

- [x] 5. Wire UI and add translations
  - [x] 5.1 Wire report form into the application navigation
    - Register the new report form/frame in the main application so it is accessible from the reports menu/section
    - Ensure the report is reachable from the existing reports navigation panel
    - _Requirements: 4.1, 4.4_

  - [x] 5.2 Add Spanish translations to language file
    - Add translation entries to `languages/es/apotheca.es.po` for all user-facing strings: column headers (Producto, Unidades Vendidas, Ingresos, Costo, Utilidad), TOTAL label, date picker labels, export button text, error messages
    - _Requirements: 4.1, 5.5_

- [x] 6. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document (Properties 1–6)
- Unit/example tests validate specific scenarios and edge cases
- The implementation uses Free Pascal with FPCUnit for testing (150 iterations per property test)
- Test runners follow the existing `.lpr` pattern with consoletestrunner

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["1.3", "1.4", "1.5", "1.6", "3.1"] },
    { "id": 3, "tasks": ["1.7", "3.2", "3.3"] },
    { "id": 4, "tasks": ["3.4", "4.1"] },
    { "id": 5, "tasks": ["4.2", "4.3", "4.4", "5.1", "5.2"] }
  ]
}
```
