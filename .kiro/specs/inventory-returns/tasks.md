# Implementation Plan: Inventory Returns/Losses

## Overview

This plan implements the Inventory Returns/Losses feature following the existing layered architecture (model → repository → service → view). Tasks are ordered to build infrastructure first, then service logic, then the UI frame, and finally navigation integration — ensuring each step builds on the previous one with no orphaned code.

## Tasks

- [x] 1. Add resource strings and Spanish translations
  - [x] 1.1 Add RS_RETURNS_ resource string constants to UResourceString
    - Add all user-visible strings for the Returns frame: title, labels, button captions, grid column headers, validation messages, success/error messages
    - Constants: RS_NAV_RETURNS, RS_RETURNS_TITLE, RS_RETURNS_OP_TYPE, RS_RETURNS_PERSON, RS_RETURNS_DATE, RS_RETURNS_ADD, RS_RETURNS_DELETE, RS_RETURNS_SAVE, RS_RETURNS_REBUILD, RS_RETURNS_GRID_PRODUCT, RS_RETURNS_GRID_QTY, RS_RETURNS_GRID_COST, RS_RETURNS_NO_ITEMS, RS_RETURNS_NO_CUSTOMER, RS_RETURNS_NO_SUPPLIER, RS_RETURNS_INSUFFICIENT_STOCK, RS_RETURNS_SAVE_ERROR, RS_RETURNS_SAVE_SUCCESS, RS_RETURNS_REBUILD_SUCCESS, RS_RETURNS_REBUILD_WARNING
    - _Requirements: 10.1_

  - [x] 1.2 Add Spanish translations to apotheca.es.po
    - Add msgid/msgstr entries for every RS_RETURNS_ constant defined in 1.1
    - Follow existing .po file format with `#: uresourcestring.rs_returns_*` references
    - _Requirements: 10.2_

- [x] 2. Seed new operation types in DataModule
  - [x] 2.1 Add SeedReturnOperationTypes procedure to TDataModule1
    - Add a new private method `SeedReturnOperationTypes` in `udatamodule.pas`
    - Use INSERT OR IGNORE pattern (check by description) to insert: "Customer Devolution" (type "in"), "Inventory Loss" (type "out"), "Return to Provider" (type "out")
    - Call `SeedReturnOperationTypes` from `DataModuleCreate` after existing migrations
    - Wrap in transaction with rollback on failure
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [ ]* 2.2 Write property test for operation type seeding idempotence
    - **Property 6: Operation type seeding is idempotent**
    - Create `tests/test_seed_idempotence.pas` and `tests/run_seed_idempotence_test.lpr`
    - For 100 iterations: invoke seeding procedure multiple times on an in-memory SQLite DB, assert exactly 3 new records exist with correct descriptions and types, no duplicates
    - **Validates: Requirements 7.1, 7.2, 7.3, 7.4**

- [x] 3. Checkpoint - Ensure seeding compiles and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement TReturnService (service layer)
  - [x] 4.1 Create ureturnservice.pas with validation logic
    - Create `service/ureturnservice.pas` with class `TReturnService`
    - Implement `ValidateItems(items: TList): Boolean` — at least one item with non-nil product and qty >= 1
    - Implement `ValidatePerson(opType: TOperationType; person: TPerson): Boolean` — required for Customer Devolution and Return to Provider
    - Implement `ValidateStock(items: TList): Boolean` — aggregate quantities by product, compare against balance stock, collect all failures
    - Implement `AggregateQuantitiesByProduct(items: TList): TList` — helper that sums quantities per distinct product
    - Implement `SaveReturn(opType: TOperationType; person: TPerson; date: TDateTime; items: TList): Boolean`
    - SaveReturn flow: validate → construct TIn or TOut based on opType.getTyp() → calculateNewBalance → persist via TDataTransaction.new() in a DB transaction
    - Store validation error in FLastError, expose via GetLastError
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 8.1, 8.2, 8.3_

  - [ ]* 4.2 Write property test for item list validation
    - **Property 5: Item list validation accepts iff at least one complete row exists**
    - Create `tests/test_return_item_validation.pas` and `tests/run_return_item_validation_test.lpr`
    - For 100 iterations: generate random item lists (empty, nil products, zero qty, mixed), assert validation passes iff at least one item has non-nil product and qty >= 1
    - **Validates: Requirements 6.1**

  - [ ]* 4.3 Write property test for stock aggregation and rejection
    - **Property 3: Stock validation correctly aggregates and rejects**
    - Create `tests/test_return_stock_validation.pas` and `tests/run_return_stock_validation_test.lpr`
    - For 100 iterations: generate items referencing same product multiple times with random quantities, set product balance stock, assert validation rejects iff aggregated sum exceeds stock
    - **Validates: Requirements 8.1, 8.2**

  - [ ]* 4.4 Write property test for IN balance calculation
    - **Property 1: IN balance calculation preserves weighted average cost**
    - Create `tests/test_return_balance_in.pas` and `tests/run_return_balance_in_test.lpr`
    - For 100 iterations: create product with random positive balance, create TIn with random item, call calculateNewBalance, assert new_stock = prev_stock + qty, new_balance = prev_balance + (cost × qty), new_cost = new_balance / new_stock
    - **Validates: Requirements 6.6**

  - [ ]* 4.5 Write property test for OUT balance calculation
    - **Property 2: OUT balance calculation uses current average cost**
    - Create `tests/test_return_balance_out.pas` and `tests/run_return_balance_out_test.lpr`
    - For 100 iterations: create product with random positive stock/balance, create TOut with item qty <= stock, call calculateNewBalance, assert new_stock = prev_stock - qty, new_balance = prev_balance - (prev_avg_cost × qty)
    - **Validates: Requirements 6.7**

- [x] 5. Checkpoint - Ensure TReturnService compiles and property tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement TFrameReturns (view layer)
  - [x] 6.1 Create uframereturns.pas and uframereturns.lfm
    - Create `view/uframereturns.pas` with `TFrameReturns = class(TFrame)`
    - Design the .lfm with: ComboOpType (TComboBox), BtnSelectPerson (TBitBtn), EditPerson (TEdit, read-only), DateEdit (TDateEdit), GridItems (TStringGrid with columns Product/Qty/Unit Cost), BtnAddItem (TBitBtn), BtnDeleteItem (TBitBtn), BtnSave (TBitBtn), BtnRebuild (TBitBtn), BtnSelectProduct (TButton hidden, inline in grid), StatusBarReturns (TStatusBar)
    - Internal state: FReturnService, FOperationType, FPerson, FItems (TList of TItem), FOperationDirection (String)
    - Follow TFramePurchase structure as reference
    - _Requirements: 1.1, 2.1, 3.4, 4.1, 5.1, 9.1_

  - [x] 6.2 Implement operation type selection and person association logic
    - Populate ComboOpType with 3 items from resourcestrings on Create
    - `ComboOpType.OnChange`: update FOperationDirection ('in'/'out'), clear FPerson, clear EditPerson, enable/disable BtnSelectPerson based on type
    - Default to "Customer Devolution" (index 0, direction 'in')
    - `BtnSelectPerson.OnClick`: open TFormFindCustomer for devolution, TFormFindSupplier for provider return, disabled for loss
    - Display selected person name in EditPerson; retain previous if dialog cancelled
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [x] 6.3 Implement item grid management (add, delete, product selection)
    - `BtnAddItem.OnClick`: append new TItem with qty=1, cost=0.00, reload grid
    - `BtnDeleteItem.OnClick`: remove selected row if one is selected, otherwise no-op
    - `BtnSelectProduct.OnClick` (inline grid button): open TFormFindProduct, set product name and balance cost in row
    - `GridItems.OnEditingDone`: parse Quantity column (integer >= 1)
    - Grid column layout: Product (50%), Quantity (25%), Unit Cost (25%) using DistributeColumns
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

  - [x] 6.4 Implement date picker with future-date prevention
    - Initialize DateEdit to Now on frame create and form reset
    - `DateEdit.OnChange`: if selected date > Today, revert to Today
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [x] 6.5 Implement Save button handler
    - `BtnSave.OnClick`: collect operation type (query from DB by description via TDataOperationType), person, date, items list
    - Call `FReturnService.SaveReturn(opType, person, date, items)`
    - On success: show success message dialog, call ClearForm (reset items, person, combo to index 0, date to today)
    - On failure: display FReturnService.GetLastError in StatusBarReturns
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.8, 6.9_

  - [x] 6.6 Implement Rebuild Balances button handler
    - `BtnRebuild.OnClick`: create TBalanceBuilder, call build()
    - If returns true: display RS_RETURNS_REBUILD_SUCCESS in StatusBarReturns
    - If returns false: show MessageBox with TBalanceBuilder.getBalanceMessage()
    - Button always enabled regardless of form state
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 7. Integrate Returns frame into main navigation
  - [x] 7.1 Add stReturns to TSectionType and wire up navigation
    - Add `stReturns` to `TSectionType` enum in `apothecamain.pas`
    - Add `BtnReturns: TBitBtn` to sidebar panel (positioned after BtnReports or before, per design)
    - Add `FFrameReturns: TFrameReturns` private field
    - Create FFrameReturns in `CreateFrames`, set Parent/Align/Visible as other frames
    - Add `BtnReturnsClick` handler calling `NavigateTo(stReturns)`
    - Update `NavigateTo` case statement with stReturns entry
    - Update `HighlightActiveButton` to reset BtnReturns color
    - Set `BtnReturns.Caption := RS_NAV_RETURNS`
    - Load button icons for Returns frame (BtnAddItem, BtnDeleteItem, BtnSave, BtnRebuild)
    - Add UFrameReturns to uses clause
    - _Requirements: 1.1, 1.2, 1.3_

- [x] 8. Checkpoint - Full compilation and manual smoke test
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. Property test for TBalanceBuilder rebuild behavior
  - [ ]* 9.1 Write property test for rebuild skipping negative-stock products
    - **Property 4: TBalanceBuilder rebuild skips negative-stock products**
    - Create `tests/test_rebuild_negative_skip.pas` and `tests/run_rebuild_negative_skip_test.lpr`
    - For 100 iterations: set up in-memory DB with products and operation history that results in negative stock for some products, call TBalanceBuilder.build(), assert those products' balances are unchanged and their names appear in getBalanceMessage()
    - **Validates: Requirements 9.4**

- [x] 10. Final checkpoint - All tests pass and project compiles cleanly
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- The project uses Free Pascal / Lazarus with fpcunit for testing
- Test pattern: 100 iterations with manual Random()/RandomRange() calls (no external PBT library)
- Each test runner is a separate .lpr file following existing project convention

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "4.1"] },
    { "id": 3, "tasks": ["4.2", "4.3", "4.4", "4.5"] },
    { "id": 4, "tasks": ["6.1"] },
    { "id": 5, "tasks": ["6.2", "6.3", "6.4"] },
    { "id": 6, "tasks": ["6.5", "6.6"] },
    { "id": 7, "tasks": ["7.1"] },
    { "id": 8, "tasks": ["9.1"] }
  ]
}
```
