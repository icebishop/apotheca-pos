# Requirements Document

## Introduction

The Units Sold Report provides Apotheca POS users with a detailed view of product quantities sold within a specified date range. The report aggregates sale transactions (outbound operations) to show how many units of each product were sold, along with revenue and cost totals per product. This allows business owners to identify top-selling products, track sales volume trends, and make informed inventory decisions.

## Glossary

- **Report_Engine**: The service component (TReportEngine) responsible for querying the database, aggregating transaction data, and returning structured report results.
- **Units_Sold_Report**: A report that lists products sold within a date range, showing total quantity sold, revenue, and cost per product.
- **Sale_Transaction**: An outbound operation (operationtype.type = 'out') representing a sale to a customer.
- **Item**: A line item within a sale transaction, containing product reference, quantity (stock field), unit price, and unit cost.
- **Date_Range_Filter**: A filter defined by a start date and an end date that restricts report results to transactions occurring within that inclusive period.
- **Product**: A merchandise entry tracked in inventory with a name, ID, and balance information.
- **CSV_Exporter**: The component responsible for exporting report data to CSV file format.
- **Report_Grid**: The UI grid component that displays report results in tabular form.

## Requirements

### Requirement 1: Generate Units Sold Report Data

**User Story:** As a store owner, I want to see how many units of each product were sold in a date range, so that I can identify my best-selling products and plan inventory accordingly.

#### Acceptance Criteria

1. WHEN a start date and end date are provided, THE Report_Engine SHALL query all Sale_Transactions within the inclusive date range and return a list of aggregated rows grouped by product, including only products that have at least one Item sold in the date range.
2. THE Report_Engine SHALL calculate the total units sold for each product by summing the quantity (stock field) of all Items belonging to Sale_Transactions in the date range.
3. THE Report_Engine SHALL calculate the total revenue per product by summing (quantity × unit price) for all matching Items, rounded to two decimal places.
4. THE Report_Engine SHALL calculate the total cost per product by summing (quantity × unit cost) for all matching Items, rounded to two decimal places.
5. THE Report_Engine SHALL return each row containing: product ID, product name, total units sold, total revenue, total cost, and total utility (revenue minus cost).
6. THE Report_Engine SHALL order the results by total units sold in descending order, using product name in ascending alphabetical order as a tiebreaker when two or more products have equal units sold.
7. THE Report_Engine SHALL compute grand totals for units sold, revenue, cost, and utility across all product rows.
8. IF a start date or end date is not provided, THEN THE Report_Engine SHALL return an empty result list with all grand totals set to zero.

### Requirement 2: Date Range Filtering

**User Story:** As a store owner, I want to filter the units sold report by date range, so that I can analyze sales for specific periods.

#### Acceptance Criteria

1. WHEN a start date is provided, THE Date_Range_Filter SHALL include only Sale_Transactions with a transaction date on or after the start date at 00:00:00.
2. WHEN an end date is provided, THE Date_Range_Filter SHALL include only Sale_Transactions with a transaction date on or before the end date at 23:59:59.
3. WHEN both start date and end date are equal, THE Date_Range_Filter SHALL include all Sale_Transactions occurring from 00:00:00 to 23:59:59 of that single calendar day.
4. IF the start date is after the end date, THEN THE Report_Engine SHALL return an empty result list with all totals set to zero.
5. IF neither a start date nor an end date is provided, THEN THE Date_Range_Filter SHALL include all Sale_Transactions with no date restriction.
6. WHEN only a start date is provided and no end date, THE Date_Range_Filter SHALL include all Sale_Transactions with a transaction date on or after the start date at 00:00:00 with no upper bound.
7. WHEN only an end date is provided and no start date, THE Date_Range_Filter SHALL include all Sale_Transactions with a transaction date on or before the end date at 23:59:59 with no lower bound.

### Requirement 3: Handle Empty Results

**User Story:** As a store owner, I want clear feedback when no sales exist for the selected period, so that I understand the report has no data rather than being broken.

#### Acceptance Criteria

1. WHEN no Sale_Transactions exist within the specified date range, THE Report_Engine SHALL return an empty list with zero rows and set grand totals for units sold, revenue, cost, and utility each to zero.
2. IF the database connection is nil, THEN THE Report_Engine SHALL return an empty list with zero rows and set grand totals for units sold, revenue, cost, and utility each to zero without raising an exception.
3. IF a database query error occurs during report generation, THEN THE Report_Engine SHALL return an empty list with zero rows and set all grand totals to zero without raising an unhandled exception.

### Requirement 4: Display Report in Grid

**User Story:** As a store owner, I want to see the units sold report in a readable table, so that I can quickly review product sales performance.

#### Acceptance Criteria

1. THE Report_Grid SHALL display columns in the following left-to-right order: product name, units sold, total revenue, total cost, and utility.
2. THE Report_Grid SHALL display numeric values for revenue, cost, and utility formatted to exactly 2 decimal places.
3. THE Report_Grid SHALL display a grand totals row as the last row, showing the sum of units sold, total revenue, total cost, and utility across all product rows, with the product name column displaying a label indicating it is a totals row.
4. WHEN the user changes the date range, THE Report_Grid SHALL clear existing rows and display the updated results sorted by units sold in descending order.
5. IF the Report_Engine returns an empty result list, THEN THE Report_Grid SHALL display only the column headers and the grand totals row with all numeric values set to zero.

### Requirement 5: Export Report to CSV

**User Story:** As a store owner, I want to export the units sold report to a CSV file, so that I can share it or analyze it in a spreadsheet application.

#### Acceptance Criteria

1. WHEN the user requests a CSV export, THE CSV_Exporter SHALL write a header row containing the column names: Product, Units Sold, Revenue, Cost, Utility.
2. WHEN the user requests a CSV export, THE CSV_Exporter SHALL write one data row per product with values matching the Report_Grid display, using comma as the field delimiter and enclosing each field value in double quotes.
3. WHEN the user requests a CSV export, THE CSV_Exporter SHALL write the grand totals as the last row of the CSV file, with the Product column containing the label "Total" and the remaining columns containing the corresponding grand total values.
4. WHEN the user requests a CSV export and the report contains no product rows, THE CSV_Exporter SHALL write only the header row followed by the grand totals row with all numeric values set to zero.
5. IF the CSV file cannot be written to the specified path, THEN THE CSV_Exporter SHALL display an error message indicating the file could not be saved and SHALL preserve the report data in the Report_Grid without modification.
6. FOR ALL valid Units_Sold_Report data, exporting to CSV then parsing the CSV SHALL produce values equivalent to the original report data, where equivalence means each parsed field string is identical to the corresponding Report_Grid cell value (round-trip property).

### Requirement 6: Aggregation Correctness

**User Story:** As a store owner, I want the report totals to be mathematically correct, so that I can trust the data for business decisions.

#### Acceptance Criteria

1. THE Report_Engine SHALL ensure that the grand total of units sold equals the sum of units sold across all product rows.
2. THE Report_Engine SHALL ensure that the grand total revenue equals the sum of revenue across all product rows, with values rounded to 2 decimal places.
3. THE Report_Engine SHALL ensure that the grand total cost equals the sum of cost across all product rows, with values rounded to 2 decimal places.
4. THE Report_Engine SHALL ensure that utility for each row equals that row's revenue minus that row's cost, with the result rounded to 2 decimal places.
5. WHEN multiple Sale_Transactions contain Items for the same product, THE Report_Engine SHALL aggregate all quantities, revenue, and cost into a single product row.
6. THE Report_Engine SHALL ensure that the grand total utility equals the sum of utility across all product rows.
