# Requirements Document

## Introduction

The JSON Export feature extends the Apotheca POS system with three capabilities: (1) extending the Product model to include an image reference (stored in a separate dedicated images table as PNG binary data), an original price, and a service flag to distinguish products from services; (2) adding a sidebar utility with an Export Frame that allows the user to export products and services as a structured JSON file; and (3) converting product images from PNG to WebP format during export for web-optimized output. The exported JSON format follows the schema already established in the existing products.json and services.json reference files, enabling integration with external web catalogs or e-commerce platforms.

## Glossary

- **Product_Model**: The TProduct class in the model layer representing a product or service record with its attributes (name, min stock, max stock, balance, image reference, original price, service flag).
- **Image_Database**: A separate "images" table in the main database dedicated to storing product image binary data (PNG blobs), independent from the product table.
- **Image_Record**: A record in the images table containing a unique integer ID, the associated product ID, and the PNG binary blob data.
- **Image_Ref**: An integer attribute on the Product_Model that references an Image_Record ID in the images table. A value of 0 indicates no image is associated.
- **PNG_Validator**: The component responsible for verifying that input image data conforms to PNG format by checking the 8-byte PNG file signature before accepting the image for storage.
- **WebP_Converter**: The component responsible for converting PNG image binary data to WebP format during the export process.
- **Export_Frame**: The new TFrame-based UI panel accessible from the sidebar, responsible for configuring and triggering JSON exports.
- **Image_Output_Directory**: The user-configured file system directory path where exported WebP image files are written, specified separately from the JSON output path.
- **Export_Service**: The service-layer component responsible for querying product data, resolving image references, converting images to WebP, serializing records to JSON, and writing the output file.
- **JSON_Serializer**: The component within Export_Service that converts Product_Model records into JSON text following the established schema.
- **Service_Flag**: A boolean attribute on the Product_Model indicating whether the record represents a service (True) or a physical product (False).
- **Original_Price**: A real-valued attribute on the Product_Model representing the original retail price before any discount or promotional pricing.
- **Normalized_Product_Name**: The product name converted to lowercase with spaces and special characters (anything not a letter or digit) replaced by underscores, used as the WebP image filename during export.
- **Balance**: The current inventory valuation record for a product, tracking units, cost, and price (current selling price).

## Requirements

### Requirement 1: Extend Product Model with Image Reference Attribute

**User Story:** As a store owner, I want to associate an image with each product via a reference to a separate images table, so that exported catalogs can display product images while keeping image binary data independent from the product table.

#### Acceptance Criteria

1. THE Product_Model SHALL include an Image_Ref attribute of type Integer, initialized to 0 upon object creation, representing a foreign key reference to an Image_Record ID in the images table.
2. THE Product_Model SHALL provide a setter method (setImageRef) that accepts an Integer value greater than or equal to 0, and a getter method (getImageRef) that returns the current Image_Ref value.
3. WHEN a new product record is inserted via the repository layer, THE repository SHALL persist the Image_Ref value in the "image_ref" column of the product table in the main database.
4. WHEN an existing product record is updated via the repository layer, THE repository SHALL persist the current Image_Ref value in the "image_ref" column of the product table in the main database.
5. WHEN a product record is loaded via the repository layer, THE repository SHALL read the "image_ref" column value and populate the Product_Model Image_Ref attribute, treating NULL values as 0.
6. IF the "image_ref" column does not exist in the product table, THEN THE DataModule SHALL add the "image_ref" column of type INTEGER with a default value of 0 during database initialization.

### Requirement 2: Separate Images Table

**User Story:** As a developer, I want product images stored in a dedicated table separate from the product table, so that large binary image data does not bloat the product table and can be managed independently.

#### Acceptance Criteria

1. THE main database SHALL contain a table named "images" with columns: "id" (INTEGER PRIMARY KEY AUTOINCREMENT), "product_id" (INTEGER NOT NULL referencing the product ID in the product table), and "data" (BLOB NOT NULL storing the PNG binary content).
2. WHEN the application initializes, THE DataModule SHALL ensure the "images" table exists in the main database, creating it if necessary.
3. WHEN a product image is stored, THE images table SHALL receive a new Image_Record with the product_id and the validated PNG binary data, and return the generated ID.
4. WHEN a product image is updated for an existing Image_Record, THE images table SHALL replace the existing PNG binary data in the "data" column for the specified Image_Record ID.
5. WHEN a product is deleted, THE images table SHALL delete the associated Image_Record where product_id matches the deleted product ID.
6. WHEN an image is retrieved by Image_Record ID, THE repository SHALL return the PNG binary data from the "data" column of the images table, or return an empty result if the ID does not exist.

### Requirement 3: PNG Format Validation on Image Input

**User Story:** As a store owner, I want the system to only accept PNG format images, so that I have consistent image data and the export conversion to WebP works reliably.

#### Acceptance Criteria

1. WHEN a user provides an image file for a product, THE PNG_Validator SHALL verify the first 8 bytes of the file match the PNG file signature (hexadecimal: 89 50 4E 47 0D 0A 1A 0A) before accepting the image for storage.
2. IF the image file does not match the PNG file signature, THEN THE PNG_Validator SHALL reject the image and return a validation error message indicating only PNG format images are accepted.
3. IF the image file is empty (zero bytes), THEN THE PNG_Validator SHALL reject the image and return a validation error message indicating the file is empty.
4. WHEN the PNG_Validator accepts an image, THE system SHALL store the validated PNG binary data in the images table and update the Product_Model Image_Ref attribute with the generated Image_Record ID.
5. THE Export_Frame SHALL display a "Select Image" button for associating a PNG image with the currently selected product.
6. WHEN the user clicks the Select Image button, THE Export_Frame SHALL open a file dialog filtered to PNG files (*.png) allowing the user to choose an image file.

### Requirement 4: Extend Product Model with Original Price Attribute

**User Story:** As a store owner, I want to record the original price of each product, so that exported catalogs can show both the current and original price for discount comparison.

#### Acceptance Criteria

1. THE Product_Model SHALL include an Original_Price attribute of type Real with a valid range of 0.00 to 999999999.99, initialized to 0.0 upon object creation.
2. THE Product_Model SHALL provide a setter method (setOriginalPrice) that accepts a Real value within the range 0.00 to 999999999.99, and a getter method (getOriginalPrice) that returns the current Original_Price value.
3. IF the setOriginalPrice method receives a value less than 0.00, THEN THE Product_Model SHALL retain the previous Original_Price value unchanged.
4. WHEN a product record is saved via the repository layer, THE repository SHALL persist the Original_Price value in the "originalprice" column of the product table.
5. WHEN a product record is loaded via the repository layer, THE repository SHALL read the "originalprice" column value and populate the Product_Model Original_Price attribute, treating NULL values as 0.0.
6. IF the "originalprice" column does not exist in the product table, THEN THE DataModule SHALL add the "originalprice" column of type REAL with a default value of 0.0 during database initialization.

### Requirement 5: Extend Product Model with Service Flag Attribute

**User Story:** As a store owner, I want to mark certain records as services rather than physical products, so that the export separates products from services in the output.

#### Acceptance Criteria

1. THE Product_Model SHALL include a Service_Flag attribute of type Boolean, initialized to False upon object creation.
2. THE Product_Model SHALL provide a setter method (setIsService) and a getter method (getIsService) for the Service_Flag attribute.
3. WHEN a product record is inserted via the repository layer, THE repository SHALL persist the Service_Flag value in the "isservice" column of the product table as an integer (1 for True, 0 for False).
4. WHEN a product record is updated via the repository layer, THE repository SHALL persist the current Service_Flag value in the "isservice" column of the product table as an integer (1 for True, 0 for False).
5. WHEN a product record is loaded via the repository layer, THE repository SHALL read the "isservice" column integer value and populate the Product_Model Service_Flag attribute (1 maps to True, any other value including 0 and NULL maps to False).
6. IF the "isservice" column does not exist in the product table, THEN THE DataModule SHALL add the "isservice" column of type INTEGER with a default value of 0 using a non-destructive ALTER TABLE migration during database initialization, preserving all existing product data.

### Requirement 6: Navigate to Export Frame

**User Story:** As a user, I want a sidebar button to access the JSON Export utility, so that I can export product and service data without leaving the main application.

#### Acceptance Criteria

1. THE Export_Frame SHALL be accessible via a dedicated sidebar button labeled "Export" using the existing export icon (icons/export_16.png), positioned as the last button in the sidebar panel below the existing navigation buttons, matching the existing button dimensions (180 pixels wide, 48 pixels tall) with top-alignment, white font, and the default sidebar background color.
2. WHEN the user clicks the Export sidebar button, THE Application SHALL set the Export_Frame visible and aligned to fill the content panel, and hide any previously active frame.
3. WHILE the Export_Frame is the active frame, THE Application SHALL display the Export sidebar button in the active button color used by the existing sidebar highlighting mechanism, and display all other sidebar buttons in the default sidebar color.
4. IF the Export sidebar button is clicked while the Export_Frame is already the active frame, THEN THE Application SHALL remain on the Export_Frame without reloading or changing visible state.

### Requirement 7: Export Frame Layout and Controls

**User Story:** As a user, I want a clear interface for configuring the JSON export, so that I can choose what to export and where to save it.

#### Acceptance Criteria

1. THE Export_Frame SHALL display a checkbox group with two options: "Export Products" and "Export Services", both checked by default.
2. THE Export_Frame SHALL display a read-only file path field showing the target export file path, initialized to the application directory with a default filename of "export.json", with a maximum displayed path length of 260 characters.
3. THE Export_Frame SHALL display a "Browse" button adjacent to the file path field.
4. WHEN the user clicks the Browse button adjacent to the file path field, THE Export_Frame SHALL open a Save File dialog filtered to JSON files (*.json) allowing the user to choose the destination path and filename.
5. WHEN the user selects a file path in the Save File dialog, THE Export_Frame SHALL update the file path field with the selected path.
6. IF the user cancels the Save File dialog without selecting a file, THEN THE Export_Frame SHALL retain the current value in the file path field without modification.
7. THE Export_Frame SHALL display a read-only directory path field labeled "Image Output Directory" showing the target directory for exported WebP image files, initialized to the application directory, with a maximum displayed path length of 260 characters.
8. THE Export_Frame SHALL display a "Browse" button adjacent to the image output directory field.
9. WHEN the user clicks the Browse button adjacent to the image output directory field, THE Export_Frame SHALL open a Select Directory dialog allowing the user to choose the destination directory for exported WebP images.
10. WHEN the user selects a directory in the Select Directory dialog, THE Export_Frame SHALL update the image output directory field with the selected path.
11. IF the user cancels the Select Directory dialog without selecting a directory, THEN THE Export_Frame SHALL retain the current value in the image output directory field without modification.
12. THE Export_Frame SHALL display an "Export" button that initiates the export process.
13. THE Export_Frame SHALL display a status label below the controls, initialized to an empty string, for showing success or error messages resulting from export operations.

### Requirement 8: PNG-to-WebP Image Conversion During Export

**User Story:** As a store owner, I want product images automatically converted from PNG to WebP format during export, so that the exported catalog uses web-optimized images with smaller file sizes.

#### Acceptance Criteria

1. WHEN the Export_Service processes a product or service with a valid Image_Ref (greater than 0), THE Export_Service SHALL retrieve the PNG binary data from the images table using the Image_Ref value.
2. WHEN PNG binary data is retrieved for export, THE WebP_Converter SHALL convert the PNG binary data to WebP format using lossy compression with a quality setting of 80.
3. THE WebP_Converter SHALL write the converted WebP file to the Image_Output_Directory specified in the Export_Frame, using a filename derived from the product name converted to lowercase with spaces and special characters replaced by underscores, followed by the ".webp" extension (e.g., product name "Acetaminophen 500mg" becomes "acetaminophen_500mg.webp").
4. THE JSON_Serializer SHALL reference the exported WebP image in the JSON output using the relative path "/{normalized_product_name}.webp" (e.g., "/acetaminophen_500mg.webp") based on the Image_Output_Directory.
5. IF the Image_Ref is 0 or the referenced Image_Record does not exist in the images table, THEN THE Export_Service SHALL treat the product as having no image (empty images array for products, empty string for services).
6. IF the WebP_Converter fails to convert a PNG image, THEN THE Export_Service SHALL log the error including the product ID, treat that product as having no image in the JSON output, and continue processing remaining products without interruption.

### Requirement 9: Export Products to JSON

**User Story:** As a store owner, I want to export all products as a JSON file, so that I can use the data in external systems such as web catalogs.

#### Acceptance Criteria

1. WHEN the user clicks the Export button and "Export Products" is checked, THE Export_Service SHALL query all Product_Model records where Service_Flag is False and return them ordered by product ID ascending.
2. THE JSON_Serializer SHALL serialize each product record as a JSON object with fields: "id" (string, the product integer ID converted to its decimal string representation prefixed with "p", e.g. product ID 42 becomes "p42"), "name" (string), "price" (integer, from balance current price rounded to the nearest whole number using round-half-up), "originalPrice" (integer, from Original_Price attribute rounded to the nearest whole number using round-half-up), "description" (empty string), "images" (array containing the WebP image relative path "/{normalized_product_name}.webp" as a single string element if the product has a valid image written to the Image_Output_Directory after conversion, otherwise an empty array), and "isVisible" (boolean, True if balance stock is greater than 0, False otherwise).
3. THE JSON_Serializer SHALL output the collection of product JSON objects as a JSON array.
4. THE Export_Service SHALL write the serialized JSON text to the file path specified in the Export_Frame file path field, overwriting the file if it already exists.
5. IF the "Export Services" checkbox is also checked, THEN THE Export_Service SHALL write products and services as separate files following the file-naming convention specified in Requirement 10 Criterion 4.

### Requirement 10: Export Services to JSON

**User Story:** As a store owner, I want to export all services as a JSON file, so that I can use the data for my service catalog.

#### Acceptance Criteria

1. WHEN the user clicks the Export button and "Export Services" is checked, THE Export_Service SHALL query all Product_Model records where Service_Flag is True.
2. THE JSON_Serializer SHALL serialize each service record as a JSON object with fields: "id" (string, the character "s" followed by the product record's integer ID converted to a string, e.g. "s12"), "name" (string), "price" (integer, the balance current price rounded to the nearest whole number using half-up rounding), "originalPrice" (integer, the Original_Price attribute rounded to the nearest whole number using half-up rounding), "description" (empty string), and "image" (string, the WebP image relative path "/{normalized_product_name}.webp" referencing the file written to the Image_Output_Directory if the service has a valid image after conversion, or empty string if no image).
3. THE JSON_Serializer SHALL output the collection of service JSON objects as a JSON array.
4. WHEN both "Export Products" and "Export Services" checkboxes are checked, THE Export_Service SHALL derive the output file paths from the file path field value: if the path contains a ".json" extension, insert "_products" or "_services" immediately before the ".json" extension; if the path does not contain a ".json" extension, append "_products.json" or "_services.json" to the end of the path.
5. WHEN only one checkbox is checked, THE Export_Service SHALL write a single file using the exact path specified in the file path field.
6. WHEN the export completes and services are exported, THE Export_Service SHALL preserve the order of service records as returned by the database query without additional sorting.

### Requirement 11: JSON Serialization Format

**User Story:** As a developer, I want the JSON serializer to produce well-formatted output, so that the exported files are human-readable and compatible with external systems.

#### Acceptance Criteria

1. THE JSON_Serializer SHALL produce valid JSON output conforming to RFC 8259.
2. THE JSON_Serializer SHALL format the output with indentation of 2 spaces per nesting level for readability.
3. THE JSON_Serializer SHALL encode string values using UTF-8 encoding and escape special characters according to JSON specification (control characters U+0000 through U+001F, quotation mark, and reverse solidus).
4. THE JSON_Serializer SHALL represent price and originalPrice values as integers by rounding the source Real value to the nearest whole number (0.5 rounds up) and outputting the result without a decimal point or fractional digits.
5. THE JSON_Serializer SHALL represent boolean values as JSON true or false literals.
6. THE JSON_Serializer SHALL output JSON object keys in the fixed order defined by the field lists in Requirements 9 and 10 (products: "id", "name", "price", "originalPrice", "description", "images", "isVisible"; services: "id", "name", "price", "originalPrice", "description", "image").
7. WHEN a valid JSON output produced by the JSON_Serializer is parsed by a conforming JSON parser and re-serialized using the same JSON_Serializer settings, THE JSON_Serializer SHALL produce byte-for-byte identical output to the original serialization.

### Requirement 12: Export Error Handling

**User Story:** As a user, I want clear feedback when the export fails, so that I can understand and resolve the issue.

#### Acceptance Criteria

1. IF neither "Export Products" nor "Export Services" is checked when the user clicks Export, THEN THE Export_Frame SHALL display a validation message in the status label indicating at least one export option must be selected, and SHALL NOT initiate any file I/O operations.
2. IF the file path field is empty or the specified file path directory does not exist, THEN THE Export_Service SHALL report an error and THE Export_Frame SHALL display a message in the status label indicating the target directory is invalid.
3. IF the Image_Output_Directory field is empty, or the specified directory does not exist, or the directory is not writable, THEN THE Export_Service SHALL report an error and THE Export_Frame SHALL display a message in the status label indicating the image output directory is invalid or not writable, and SHALL NOT initiate any export operations.
4. IF the file cannot be written due to a permission error or disk space issue, THEN THE Export_Service SHALL report the error, THE Export_Frame SHALL display a message in the status label indicating the file could not be saved, and THE Export_Service SHALL delete any partially written output file for the failed operation.
5. WHEN the export completes successfully, THE Export_Frame SHALL display a success message in the status label indicating the number of records exported and the file path.
6. IF no records are found matching the selected export criteria, THEN THE Export_Service SHALL write an empty JSON array to the output file and THE Export_Frame SHALL display a message in the status label indicating zero records were exported.
7. IF both "Export Products" and "Export Services" are checked and one file is written successfully but the other fails, THEN THE Export_Service SHALL retain the successfully written file, report the error for the failed file, and THE Export_Frame SHALL display a message in the status label indicating which file failed and which succeeded.

### Requirement 13: Database Schema Migration for New Attributes

**User Story:** As a developer, I want the database schema to be automatically updated when the application starts, so that existing installations gain the new columns and the images table without manual intervention.

#### Acceptance Criteria

1. WHEN the application initializes, THE DataModule SHALL check for the existence of the "image_ref", "originalprice", and "isservice" columns in the product table using PRAGMA table_info.
2. IF any of the three columns do not exist, THEN THE DataModule SHALL execute ALTER TABLE statements to add each missing column individually with its respective type and default value: "image_ref" as INTEGER defaulting to 0, "originalprice" as REAL defaulting to 0.0, and "isservice" as INTEGER defaulting to 0.
3. IF the ALTER TABLE operation fails for a given column, THEN THE DataModule SHALL log the error including the column name using LogError, skip that column, and continue attempting to add any remaining missing columns without interrupting application startup.
4. THE DataModule SHALL execute column existence checks and migrations after the base schema initialization and before any product data is loaded or displayed.
5. WHEN the application starts and the columns already exist in the product table, THE DataModule SHALL skip the ALTER TABLE statements and proceed without error.
6. WHEN the application initializes, THE DataModule SHALL create the "images" table in the main database if it does not exist, using the schema defined in Requirement 2.
7. IF the images table cannot be created, THEN THE DataModule SHALL log the error using LogError and continue application startup with image functionality disabled (Image_Ref values treated as 0 for all products).
