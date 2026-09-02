# Requirements Document

## Introduction

The Instagram Auto-Publish feature migrates the Python automation pipeline from the `don-pilido-app/scripts` project into the Apotheca POS application, re-implemented in Free Pascal to match the existing tech stack. The feature detects newly-added products and services from external JSON catalog files, generates formatted Instagram captions (with pricing, discounts, and hashtags), resolves and validates their images against Instagram's aspect-ratio constraints, and publishes single-image or carousel posts through the Instagram Graph API. Each publication is recorded in the application's SQLite database, together with its publish date, so every item is posted exactly once and the catalog's publication state stays current.

This feature is one of two clearly separated pipelines, each with its own name:

- **Update Web Catalog** — the existing JSON Export capability (`TExportService`), which writes `products.json` and `services.json` for the web store. It is unchanged by this spec and is referenced only to define the boundary.
- **Instagram Publication** — the pipeline defined by this spec, which consumes the catalog JSON and publishes to Instagram.

The two pipelines share no runtime state other than the JSON files: *Update Web Catalog* produces them, *Instagram Publication* consumes them, and each can be run independently. In this migration the canonical source files are the Don Pulido web catalog files located at `don-pilido-app/src/res/products.json` and `don-pilido-app/src/res/services.json`.

## Glossary

- **Publisher**: The overall Instagram Auto-Publish feature that orchestrates detection, caption generation, image resolution, and publishing.
- **Product_Registry**: The source of truth for catalog items, backed by two JSON files: a products file (`products.json`) and a services file (`services.json`), following the schema produced by the JSON Export feature.
- **Registry_Item**: A single parsed product or service loaded from the Product_Registry, carrying id, name, category, price, original price, description, image list, visibility, and brand.
- **Tracking_Store**: The `instagram_publication` table in the application's SQLite database recording which Registry_Items have already been published, keyed by catalog item id, with the published media id, publish date/time, and item name.
- **Update_Web_Catalog**: The existing JSON Export pipeline (`TExportService`) that generates `products.json` and `services.json` for the web store; the upstream producer of the files this feature consumes.
- **Instagram_Publication**: The pipeline defined by this spec that reads the catalog JSON, detects unpublished items, and publishes them to Instagram.
- **New_Item**: A Registry_Item that is marked visible and whose id is absent from the Tracking_Store.
- **Publish_Config**: The runtime configuration (Instagram access token, business account id, public image base URL) loaded from environment variables and/or a `.env` file.
- **Caption**: The Instagram post text generated for a Registry_Item, containing the name, optional brand line, description, formatted price, optional discount line, store link, and a hashtag set, constrained to Instagram's maximum length.
- **Resolved_Image**: An image belonging to a Registry_Item that has been located on disk, validated (and if necessary converted/cropped) to satisfy Instagram's supported aspect-ratio range, paired with the public URL under which it will be served.
- **Image_Base_URL**: The public base URL prefix used to construct the publicly reachable URL for each Resolved_Image.
- **Public_Folder**: The local directory containing the image files referenced by Registry_Items.
- **Graph_API_Client**: The component that communicates with the Instagram Graph API to create media containers and publish them.
- **Media_Container**: A staged post created via the Graph API that must reach a ready state before it can be published.
- **Aspect_Ratio_Range**: Instagram's supported image aspect-ratio interval, from 4:5 (0.8, portrait) to 1.91:1 (1.91, landscape) inclusive.

## Requirements

### Requirement 1: Load and Validate Publish Configuration

**User Story:** As a store operator, I want the publisher to load Instagram credentials from environment configuration, so that secrets are not hard-coded and the run fails fast when configuration is incomplete.

#### Acceptance Criteria

1. WHEN the Publisher starts, THE Publish_Config SHALL read the values `INSTAGRAM_ACCESS_TOKEN`, `INSTAGRAM_BUSINESS_ACCOUNT_ID`, and `PUBLIC_IMAGE_BASE_URL` from environment variables.
2. IF a `.env` file is present at the configured path, THEN THE Publish_Config SHALL load values from it, and existing system environment variables SHALL take precedence over `.env` values.
3. IF any of the three required values is missing or empty after loading, THEN THE Publish_Config SHALL report a configuration error naming every missing variable and THE Publisher SHALL stop the run with an error status without contacting the Graph API.
4. IF `PUBLIC_IMAGE_BASE_URL` does not begin with `http://` or `https://`, THEN THE Publish_Config SHALL report a configuration error and THE Publisher SHALL stop the run with an error status.

### Requirement 2: Load Products and Services Registry

**User Story:** As a store operator, I want the publisher to read products and services from the catalog JSON files, so that the same data used by the web catalog drives Instagram publishing.

#### Acceptance Criteria

1. WHEN the Publisher runs, THE Product_Registry SHALL load product records from the products file, defaulting to `don-pilido-app/src/res/products.json`, and service records from the services file, defaulting to `don-pilido-app/src/res/services.json`.
2. THE Product_Registry SHALL parse each product entry into a Registry_Item using the fields `id`, `name`, `category`, `price`, `originalPrice` (optional), `description`, `images` (optional array, defaulting to empty), `isVisible` (optional, defaulting to false), and `brand` (optional, defaulting to empty).
3. THE Product_Registry SHALL parse each service entry into a Registry_Item using the fields `id`, `name`, `price`, `originalPrice` (optional), `description`, and `image` (optional single string), mapping a present non-empty `image` to a one-element image list and an absent or empty `image` to an empty image list, and defaulting `category` and `brand` to empty and `isVisible` to true.
4. IF a registry file does not exist, contains malformed JSON, or is not a JSON array, THEN THE Product_Registry SHALL report an error identifying the file and THE Publisher SHALL stop the run with an error status.
5. IF a registry entry is missing a required field (`id`, `name`, `price`, or `description`), THEN THE Product_Registry SHALL report an error identifying the offending entry and THE Publisher SHALL stop the run with an error status.
6. WHERE only one registry file is required for a given run, THE Product_Registry SHALL still succeed if the other file is absent, treating its item list as empty.

### Requirement 3: Track Published Items in the Database

**User Story:** As a store operator, I want the publisher to record what it already posted in the application database along with the publish date, so that products and services are never published twice and the catalog's publication state stays up to date.

#### Acceptance Criteria

1. WHEN the application database is initialized, THE Tracking_Store SHALL ensure a database table named `instagram_publication` exists with columns for a surrogate key, a `product_id` (unique integer foreign key referencing `product.id`), `item_name`, `media_id`, and `published_at` (ISO 8601 UTC text), creating it via a non-destructive migration if absent.
2. THE Tracking_Store SHALL map a catalog id to a `product_id` by stripping a single leading `p` or `s` prefix and parsing the remainder as an integer; IF a catalog id has no such prefix or a non-integer remainder, THEN the item SHALL be treated as unmappable.
3. WHEN the Publisher starts, THE Tracking_Store SHALL load the set of already-published `product_id` values from the `instagram_publication` table, returning an empty set when the table has no rows.
4. IF reading the `instagram_publication` table fails, THEN THE Tracking_Store SHALL report an error and THE Publisher SHALL stop the run with an error status.
5. WHEN an item is published successfully, THE Tracking_Store SHALL insert or update (upsert on `product_id`) a row recording the `product_id`, `item_name`, `media_id`, and the publish date/time in `published_at`, committing before the next item is processed.
6. IF writing the publication row fails after a successful publish, THEN THE Publisher SHALL log the error, count the item as published, and stop the run with an error status to prevent untracked publications.
7. THE Tracking_Store SHALL keep at most one row per `product_id`, so re-publishing an existing item updates its `media_id` and `published_at` rather than creating a duplicate row.
8. IF an item's catalog id is unmappable to a `product_id`, THEN THE Publisher SHALL log a warning, skip the item, and count it as skipped, rather than publishing an untrackable item.

### Requirement 4: Detect New Items

**User Story:** As a store operator, I want only new, visible items to be published, so that hidden or already-posted items are skipped.

#### Acceptance Criteria

1. THE Publisher SHALL treat a Registry_Item as a New_Item if and only if its `isVisible` value is true, its catalog id maps to a `product_id` (Requirement 3.2), and that `product_id` is absent from the Tracking_Store.
2. THE Publisher SHALL evaluate products and services for new items, preserving each source file's order.
3. WHEN no New_Items are found, THE Publisher SHALL log that there is nothing to publish and finish with a completed (success) status.
4. WHEN New_Items are found, THE Publisher SHALL log the total count of items, the count of visible items, and the count of new items to publish.

### Requirement 5: Generate Instagram Captions

**User Story:** As a store operator, I want each post to have a well-formatted caption, so that followers see the product name, price, discount, and relevant hashtags.

#### Acceptance Criteria

1. THE Caption SHALL begin with the item name preceded by a billiard emoji, followed by a brand line only WHERE the brand is non-empty and not equal to `Don Pulido`, followed by the description, a price line, an optional discount line, and a store-link line.
2. THE Caption SHALL format prices as Colombian pesos with period-separated thousands and a trailing ` COP` suffix (for example, `25000` renders as `$25.000 COP`).
3. WHERE the original price is present and greater than the current price, THE Caption SHALL include a discount line showing the struck-through original price and the rounded savings percentage computed as `round((original - current) / original * 100)`.
4. THE Caption SHALL append a hashtag set consisting of `#DonPulido`, up to five category-specific hashtags for the item's category, and general billiard hashtags, capped at sixteen hashtags total.
5. IF the assembled caption exceeds 2200 characters, THEN THE Caption SHALL first remove hashtags from the end until it fits, and only if it still exceeds the limit with a single hashtag remaining SHALL it truncate the description with an ellipsis so the final caption is at most 2200 characters.

### Requirement 6: Resolve and Validate Images

**User Story:** As a store operator, I want product images resolved to public URLs and adjusted to Instagram's requirements, so that posts are accepted by the Graph API.

#### Acceptance Criteria

1. WHEN an item has no images, THE Publisher SHALL skip that item, log that it was skipped for lack of valid images, and count it as skipped.
2. THE Publisher SHALL construct each Resolved_Image public URL by joining the Image_Base_URL (with any trailing slash removed) and the image filename.
3. WHEN a referenced image file exists in the Public_Folder AND its aspect ratio lies within the Aspect_Ratio_Range, THE Publisher SHALL use the original file's public URL directly.
4. WHEN a referenced image file exists but its aspect ratio lies outside the Aspect_Ratio_Range, THE Publisher SHALL produce a JPEG copy cropped to the nearest bound of the Aspect_Ratio_Range and reference the JPEG's public URL.
5. WHEN only a WebP variant of a referenced image exists, THE Publisher SHALL convert it to a JPEG (cropping to the Aspect_Ratio_Range if necessary) and reference the JPEG's public URL.
6. IF neither the referenced file nor a WebP variant is found for an image, THEN THE Publisher SHALL log a warning identifying the item and skip that image.
7. THE Publisher SHALL cap the number of Resolved_Images per item at ten to respect Instagram's carousel limit.

### Requirement 7: Publish via Instagram Graph API

**User Story:** As a store operator, I want the publisher to post to Instagram through the Graph API, so that new items appear on the store's feed automatically.

#### Acceptance Criteria

1. WHEN an item resolves to exactly one image, THE Graph_API_Client SHALL create a single-image Media_Container with the image URL and caption, then publish it.
2. WHEN an item resolves to more than one image, THE Graph_API_Client SHALL create a child Media_Container per image, create a carousel Media_Container referencing the children with the caption, then publish it.
3. BEFORE publishing any Media_Container, THE Graph_API_Client SHALL poll the container status until it reports a finished/published state, and SHALL fail the item if the container reports an error, expires, or does not become ready within the maximum wait time.
4. IF the Graph API responds with an authentication error (HTTP 401 or error code 190), THEN THE Graph_API_Client SHALL raise an authentication failure, and THE Publisher SHALL log a partial summary and stop the run with an error status.
5. IF the Graph API responds with a rate-limit error (HTTP 429 or error code 4), THEN THE Graph_API_Client SHALL retry with backoff up to a fixed maximum number of attempts before reporting a publish failure.
6. IF publishing a single item fails with a non-authentication error, THEN THE Publisher SHALL log the failure, count the item as failed, and continue processing the remaining items.
7. WHEN publishing succeeds, THE Graph_API_Client SHALL return the resulting media id and a UTC timestamp in `YYYY-MM-DDTHH:MM:SSZ` format.

### Requirement 8: Orchestrate the Run and Report Results

**User Story:** As a store operator, I want to trigger the whole pipeline from the existing Export screen and see what happened, so that I can publish and monitor without leaving the application.

#### Acceptance Criteria

1. THE Publisher SHALL be invoked from the existing Export frame (`TFrameExport`) via an "Instagram Publication" action alongside the existing "Update Web Catalog" (export) action, and SHALL NOT introduce a separate application or standalone program.
2. THE Publisher SHALL execute the pipeline in order: load config, load registry, load tracking, detect new items, then for each new item resolve images, generate caption, publish, and update tracking.
3. WHEN the run completes, THE Publisher SHALL report a summary of the number of items published, skipped, and failed to the Export frame status label and log the same summary.
4. THE Publisher SHALL indicate a completed status when the run finishes without a critical error (including the no-new-items case), and a stopped/error status when a critical error (configuration failure, registry load failure, tracking load/persist failure, or authentication failure) occurs.
5. THE Publisher SHALL emit structured log lines through the application logger for informational, warning, and error events so runs are auditable.
