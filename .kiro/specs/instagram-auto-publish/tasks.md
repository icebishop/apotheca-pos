# Implementation Plan

- [x] 1. Create the registry item model
  - Implement `model/uregistryitem.pas` with `TRegistryKind = (rkProduct, rkService)` and `TRegistryItem` (id, name, category, price, hasOriginalPrice, originalPrice, description, images: TStringList owned, isVisible, brand, kind) with property accessors and a constructor/destructor that allocates and frees the images list.
  - _Requirements: 2.2, 2.3_

- [x] 2. Implement configuration loading
  - Implement `service/upublishconfig.pas`: `TPublishConfig.Load` reads `INSTAGRAM_ACCESS_TOKEN`, `INSTAGRAM_BUSINESS_ACCOUNT_ID`, `PUBLIC_IMAGE_BASE_URL` from the environment; a `.env` parser fills only unset variables (system env wins); raise `EPublishConfigError` naming all missing vars, and on a base URL not starting with `http://`/`https://`.
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 3. Implement the product/service registry loader
  - Implement `service/uproductregistry.pas` using `fpjson`/`jsonparser` (`GetJSON`): `LoadProducts` and `LoadServices` return an owned `TFPObjectList` of `TRegistryItem`; require a JSON array root; map product and service fields per design; treat missing optional fields with defaults; raise `ERegistryError` on missing file, malformed JSON, non-array root, or missing required fields (id/name/price/description).
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [x] 4. Add the publication tracking table and repository
  - Extend `infrastructure/udatamodule.pas` with `CreatePublicationTable` (CREATE TABLE IF NOT EXISTS `instagram_publication` with `id`, `product_id` INTEGER UNIQUE FK -> product.id, `item_name`, `media_id`, `published_at`, plus `idx_pub_product` index) and call it from `DataModuleCreate` after `CreateImagesTable`, logging failures via `LogError` without aborting startup.
  - Implement `repository/udatapublication.pas` (`TDataPublication` extending `TData`) with `TryParseCatalogId` (strip `p`/`s` prefix -> integer), `IsPublished(ProductId)`, `LoadPublishedIds` (owned `TStringList` of product ids), `Record_` (upsert via `INSERT ... ON CONFLICT(product_id) DO UPDATE`), and `Get`, using parameterized `TSQLQuery` like `udataimage.pas`.
  - Implement `service/upublicationtracker.pas` (`TPublicationTracker`) wrapping `TDataPublication`, exposing `LoadPublishedIds`, `IsPublished(CatalogId)`, and `RecordPublication(CatalogId, ...)` (maps catalog id -> product id), and raising `ETrackingError` on unmappable id or DB failures.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

- [x] 5. Implement the caption builder
  - Implement `service/ucaptionbuilder.pas`: constant category/general hashtag arrays; `FormatPriceCop` (period thousands + ` COP`); `DiscountPercent` (half-up); `Build` composing body + hashtags (`#DonPulido` + up to 5 category + general, cap 16), with UTF-8-safe 2200-char control that drops hashtags first then binary-searches a truncated description.
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 6. Implement the image resolver
  - Implement `service/upublishimageresolver.pas` using `fcl-image`: `CheckAspectRatio` (true iff 0.8..1.91), `ConvertToJpeg` (center-crop to range, JPEG quality 90), `DecodeWebpToPng` (via `TProcess` `dwebp`), and `Resolve` (original when valid, JPEG-crop when invalid, WebP fallback, warn+skip when absent, cap 10, URL = trimmed base + '/' + filename).
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

- [x] 7. Implement the Instagram Graph API client
  - Implement `service/uinstagramapiclient.pas` using `fphttpclient` + `opensslsockets`: `MakeRequest` with token injection, error mapping (EAuthError on 401/190, bounded backoff retry on 429/code 4, EPublishError otherwise); container creation (single, carousel item, carousel), `WaitForContainerReady` (poll `status_code` 5s/60s), `PublishContainer`, `PublishSingleImage`, `PublishCarousel`, returning `TPublishResult` with UTC timestamp.
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_

- [x] 8. Implement the orchestrator
  - Implement `service/upublishorchestrator.pas`: `Create(AConnection)` builds a `TPublicationTracker` from the shared SQLite connection; `Run(TPublishOptions): TPublishSummary` executes config -> registry -> load published ids -> detect -> per-item resolve/caption/publish/record; detection filter (visible AND not published, order preserved); summary counts; exit code 1 on critical errors (including publication-record write failure), per-item EPublishError continues; log via `ULogger`.
  - _Requirements: 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 8.1, 8.2, 8.3, 8.4_

- [x] 9. Wire the pipeline into the existing Export frame
  - Add a `btnPublishInstagram` ("Instagram Publication") button to `view/uframeexport.lfm` next to the existing export button (relabel it "Update Web Catalog").
  - In `view/uframeexport.pas`, add the field, the `btnPublishInstagramClick` handler, and `UPublishOrchestrator` to `uses`. The handler builds `TPublishOptions` (defaults at `don-pilido-app/src/res` and `don-pilido-app/public`, `.env` at `export/.env`, include flags from the existing checkboxes), calls `DataModule1.EnsureTransaction`, runs `TPublishOrchestrator` on `DataModule1.SQLite3Connection1`, and shows the summary in `lblStatus`.
  - Add `export/.env.example`. No new program, project, or Makefile target — the feature ships inside the existing `apotheca` application, which already references the required FPC packages.
  - _Requirements: 8.1, 8.2_

- [x] 10. Add automated tests
  - Added `tests/test_caption_publish.pas` (Properties 2, 3, 4), `tests/test_detector_publish.pas` (Properties 1, 8b), `tests/test_publish_image_url.pas` (Properties 5, 6, 7 — Property 7 end-to-end by generating >10 PNGs and calling `Resolve`), `tests/test_publish_tracking.pas` (Property 8 — against a temp SQLite DB exercising `TDataPublication` insert/upsert/read), each with an FPCUnit runner `tests/run_*_test.lpr`. All 4 suites pass (13 tests, 0 failures). Added a `make test-instagram` target that compiles them directly with `fpc` (the generic `build-tests` uses `lazbuild`, which needs `.lpi` files not present in this environment).
  - _Requirements: 3.2, 3.6, 4.1, 5.2, 5.3, 5.4, 6.2, 6.3, 6.7_

- [x] 11. Compile and verify
  - [x] Build the whole application with `lazbuild apotheca.lpi` (the new units compile transitively via the Export frame) and resolve any package/uses issues. (App builds and links cleanly; `instagram_publication` table confirmed created in `db/invcar`.)
  - [x] Confirm the Export frame exposes both the "Update Web Catalog" and "Instagram Publication" actions.
  - [x] Run the test runners from task 10 via `make test-instagram` — all 4 suites pass (13 tests, 0 failures).
  - _Requirements: 2.1, 2.4, 4.3, 8.2_
