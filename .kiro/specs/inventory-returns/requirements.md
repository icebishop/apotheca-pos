# Requirements Document

## Introduction

The Inventory Returns/Losses feature adds a new management frame to the Apotheca POS system for recording inventory movements that are not regular purchases or sales. This covers three scenarios: customer devolutions (product returns back into inventory), inventory losses (product written off), and returns to provider (product sent back to a supplier). Each scenario creates an operation record with the appropriate operation type and adjusts product balances accordingly.

## Glossary

- **Returns_Frame**: The new TFrame-based UI panel accessible from the sidebar, responsible for displaying and managing return/loss operations.
- **Return_Operation**: A transaction record in the operation table representing a customer devolution, inventory loss, or provider return.
- **Return_Service**: The service-layer component responsible for validating and persisting Return_Operations.
- **Operation_Type**: A record in the operationtype table that classifies an operation (e.g., "Customer Devolution" with type "in", "Inventory Loss" with type "out", "Return to Provider" with type "out").
- **Balance**: The current inventory valuation record for a product, tracking units, cost, and price.
- **Person**: A customer or supplier associated with an operation.

## Requirements

### Requirement 1: Navigate to Returns Frame

**User Story:** As a user, I want a sidebar button to navigate to the Returns/Losses section, so that I can access return and loss management without leaving the main application flow.

#### Acceptance Criteria

1. THE Returns_Frame SHALL be accessible via a dedicated sidebar button labeled "Returns" with a corresponding icon, positioned in the sidebar panel alongside the existing navigation buttons.
2. WHEN the user clicks the Returns sidebar button, THE Application SHALL display the Returns_Frame in the content panel and hide any previously active frame.
3. WHILE the Returns_Frame is the active frame, THE Application SHALL highlight the Returns sidebar button using the active button color and display all other sidebar buttons in the default sidebar color.

### Requirement 2: Select Return Operation Type

**User Story:** As a user, I want to choose the type of return/loss operation before entering details, so that the system applies the correct inventory adjustment direction.

#### Acceptance Criteria

1. THE Returns_Frame SHALL display a selector with three operation type options: "Customer Devolution", "Inventory Loss", and "Return to Provider".
2. WHEN the Returns_Frame is first displayed, THE Returns_Frame SHALL pre-select "Customer Devolution" as the default operation type and configure the operation as type "in".
3. WHEN the user selects "Customer Devolution", THE Returns_Frame SHALL configure the operation as type "in" (inventory increases).
4. WHEN the user selects "Inventory Loss", THE Returns_Frame SHALL configure the operation as type "out" (inventory decreases).
5. WHEN the user selects "Return to Provider", THE Returns_Frame SHALL configure the operation as type "out" (inventory decreases).
6. WHEN the user changes the selected operation type, THE Returns_Frame SHALL clear the currently associated person and reset the person selection field to empty.

### Requirement 3: Associate Person with Operation

**User Story:** As a user, I want to associate a customer or supplier with the return operation, so that records indicate who was involved in the transaction.

#### Acceptance Criteria

1. WHEN the user selects "Customer Devolution", THE Returns_Frame SHALL enable selection of a customer via the existing Find Customer dialog.
2. WHEN the user selects "Return to Provider", THE Returns_Frame SHALL enable selection of a supplier via the existing Find Supplier dialog.
3. WHEN the user selects "Inventory Loss", THE Returns_Frame SHALL disable the person selection field and clear any previously selected person, since no external party is involved.
4. WHEN a person is selected from the Find Customer or Find Supplier dialog, THE Returns_Frame SHALL display the selected person name in a read-only text field.
5. IF the user cancels the Find Customer or Find Supplier dialog without selecting a person, THEN THE Returns_Frame SHALL retain the previously selected person, or remain empty if no person was previously selected.
6. WHEN the user changes the operation type after a person has been selected, THE Returns_Frame SHALL clear the previously selected person from the field.

### Requirement 4: Add Items to Return Operation

**User Story:** As a user, I want to add one or more products with quantities to the return operation, so that the system knows which products and how many units are affected.

#### Acceptance Criteria

1. THE Returns_Frame SHALL display a TStringGrid with columns: Product, Quantity, and Unit Cost.
2. WHEN the user clicks the Add button, THE Returns_Frame SHALL append a new empty row to the items grid with the Quantity column initialized to 1 and the Unit Cost column initialized to 0.00.
3. WHEN the user clicks the product cell in a grid row, THE Returns_Frame SHALL open the Find Product dialog to select a product.
4. WHEN a product is selected, THE Returns_Frame SHALL populate the Product column with the product name and the Unit Cost column with the product current balance cost.
5. THE Returns_Frame SHALL allow the user to edit the Quantity column for each item row, accepting only integer values of 1 or greater.
6. WHEN the user clicks the Delete button with a row selected, THE Returns_Frame SHALL remove that row from the items grid.
7. IF the user clicks the Delete button with no row selected, THEN THE Returns_Frame SHALL take no action.

### Requirement 5: Record Date for Operation

**User Story:** As a user, I want to specify the date of the return/loss operation, so that the record reflects when the event occurred.

#### Acceptance Criteria

1. THE Returns_Frame SHALL display a TDateEdit date picker initialized to the current system date when the frame loads or the form is reset.
2. THE Returns_Frame SHALL allow the user to change the operation date to any past or present date via the date picker.
3. IF the user selects a date later than the current system date, THEN THE Returns_Frame SHALL revert the date picker value to the current system date.
4. WHEN the user changes the date picker value, THE Returns_Frame SHALL update the operation record date to match the selected value.

### Requirement 6: Save Return Operation

**User Story:** As a user, I want to save the return/loss operation, so that inventory balances are updated and a permanent record is created.

#### Acceptance Criteria

1. WHEN the user clicks the Save button, THE Return_Service SHALL validate that at least one item row has a selected product and a quantity of 1 or more, ignoring any rows that have no product selected.
2. IF the operation type is "Customer Devolution" and no customer is selected, THEN THE Return_Service SHALL reject the save with a validation error indicating a customer is required.
3. IF the operation type is "Return to Provider" and no supplier is selected, THEN THE Return_Service SHALL reject the save with a validation error indicating a supplier is required.
4. IF validation fails, THEN THE Returns_Frame SHALL display the validation error in the status bar without persisting any data.
5. WHEN validation passes, THE Return_Service SHALL persist the operation record, item records, and update product balances within a single database transaction.
6. WHEN the operation type is "in" (Customer Devolution), THE Return_Service SHALL increase the product balance stock by the returned quantity, add (item unit cost multiplied by item quantity) to the current balance value, and set the new average cost to the resulting balance value divided by the resulting stock.
7. WHEN the operation type is "out" (Inventory Loss or Return to Provider), THE Return_Service SHALL decrease the product balance stock by the specified quantity and reduce the balance value by (current average cost multiplied by the specified quantity).
8. IF the database transaction fails, THEN THE Return_Service SHALL rollback all changes and THE Returns_Frame SHALL display an error message indicating the operation was not saved.
9. WHEN the save operation succeeds, THE Returns_Frame SHALL display a success message in the status bar and reset the form by clearing all item rows, clearing the selected person, setting the operation type selector to its first option, and setting the date picker to the current date.

### Requirement 7: Seed New Operation Types

**User Story:** As a developer, I want the system to automatically create the new operation types in the database on startup, so that return operations can reference valid operation type records.

#### Acceptance Criteria

1. WHEN the application initializes and no record with description "Customer Devolution" exists in the operationtype table, THE DataModule SHALL insert a record with description "Customer Devolution" and type "in" using the next available auto-increment id.
2. WHEN the application initializes and no record with description "Inventory Loss" exists in the operationtype table, THE DataModule SHALL insert a record with description "Inventory Loss" and type "out" using the next available auto-increment id.
3. WHEN the application initializes and no record with description "Return to Provider" exists in the operationtype table, THE DataModule SHALL insert a record with description "Return to Provider" and type "out" using the next available auto-increment id.
4. IF the operationtype table already contains a record matching the description of a seed entry, THEN THE DataModule SHALL skip insertion for that entry and leave the existing record unchanged.
5. IF the seeding operation fails due to a database error, THEN THE DataModule SHALL roll back any partially inserted seed records from this batch, preserving the prior state of the operationtype table.

### Requirement 8: Validate Stock Availability for Outgoing Operations

**User Story:** As a user, I want the system to prevent removing more units than are available in stock, so that inventory balances remain non-negative.

#### Acceptance Criteria

1. IF the operation type is "out" and the total specified quantity for a product across all item rows exceeds that product's current balance stock, THEN THE Return_Service SHALL reject the operation and display in the status bar an error message indicating which product has insufficient stock and the available quantity.
2. THE Return_Service SHALL check stock availability for each distinct product, summing quantities across all item rows referencing the same product, before persisting any changes.
3. IF multiple products have insufficient stock, THEN THE Return_Service SHALL report all insufficient products in a single validation error rather than stopping at the first failure.

### Requirement 9: Rebuild Balance Inventory

**User Story:** As a store owner, I want a button to rebuild all product balance records from transaction history, so that I can correct any balance inconsistencies caused by data corruption or manual database edits.

#### Acceptance Criteria

1. THE Returns_Frame SHALL display a "Rebuild Balances" button in the toolbar area.
2. WHEN the user clicks the "Rebuild Balances" button, THE Returns_Frame SHALL invoke the existing `TBalanceBuilder.build()` method which recalculates all product balances from the operation and item tables.
3. WHEN the rebuild operation returns true (success), THE Returns_Frame SHALL display a success message in the status bar indicating that balances were rebuilt.
4. WHEN the rebuild operation returns false (one or more products have negative stock), THE Returns_Frame SHALL display the warning message from `TBalanceBuilder.getBalanceMessage()` in a message dialog, listing which products have negative computed stock.
5. THE "Rebuild Balances" button SHALL be available regardless of the currently selected operation type or form state.

### Requirement 10: Internationalization Support

**User Story:** As a user, I want the Returns/Losses frame to support English and Spanish languages, so that the interface matches the application language setting.

#### Acceptance Criteria

1. THE Returns_Frame SHALL define all user-visible strings as resourcestring constants with the prefix "RS_RETURNS_" in UResourceString, covering: frame title, field labels, button captions, grid column headers, search hints, validation messages, and success/error messages.
2. THE Application SHALL provide a non-empty Spanish msgstr entry in the apotheca.es.po translation file for every Returns_Frame resource string constant defined in UResourceString.
3. WHEN the operating system language is Spanish, THE Application SHALL display all Returns_Frame text using the Spanish translations from the .po file instead of the English default values.
