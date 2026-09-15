# Apothêca — Retail / POS Compliance Notes

This document records a compliance assessment of the Apothêca POS + inventory
system and what has been addressed. It is an internal engineering reference, not
a legal certification.

**System profile:** single-workstation FreePascal/Lazarus desktop application,
SQLite backend, used to sell billiard supplies. No network/API surface, no card
processing.

---

## Assessment summary

| Domain | Status | Notes |
| --- | --- | --- |
| Payment card security (PCI-DSS) | ✅ Out of scope | No card data, PAN/CVV, or gateway. Tenders are cash-implied sale vs credit (fiado). The `pay` table records debt installments, not card data. |
| Fiscal / tax invoicing | ❌ Not implemented | No IVA/VAT, no invoice/factura, no tax IDs (NIT), no DIAN electronic invoicing. A sale is an inventory movement, not a fiscal document. |
| Customer data / PII | ⚠️ Basic | `person` stores name/phone/address in plaintext. No consent/retention/deletion-audit tooling; PII is not encrypted. |
| Access control | ❌ None | No authentication, users, roles, or permissions. Single-workstation, fully open to anyone at the machine. |
| Audit trail | ⚠️ Partial → improved | Structured logging via `ULogger`. Destructive actions are now audited (see Tier 1). No user identity yet (no auth). |
| Data integrity | ⚠️ Mixed → improved | Transactional writes. FK enforcement now ON (Tier 1). Balances are a derived running total, repairable via the balance builder. Backups are manual/unencrypted. |
| Licensing | ℹ️ GPL v2-or-later | Distribution requires providing source and preserving notices. |

---

## Tier 1 — implemented

### 1. Foreign-key enforcement
SQLite disables foreign keys per-connection by default, so the FK clauses in the
schema were declared but never enforced (orphan rows were possible). Enforcement
is now enabled at connect time.

- `infrastructure/udatamodule.pas` — `OpenDatabase` sets
  `SQLite3Connection1.Params.Add('foreign_keys=ON')` **before** `Connected := True`.
  (A runtime `PRAGMA foreign_keys=ON` does not work through FPC's sqldb because
  it runs inside a transaction and SQLite ignores it there.)
- `EnableForeignKeys` verifies and logs the effective state (`FK_ENFORCEMENT`).
- Test: `tests/test_db.pas` → `TestForeignKeyEnforcementRejectsOrphan` asserts an
  orphan `item` insert is rejected.

### 2. Audit logging of destructive & sensitive actions
Deletions and settings changes now write `SECURITY`-level audit entries via
`ULogger` (`logs/apotheca.log`).

- Product deletion — `view/uframeproducts.pas`: `PRODUCT_DELETED` /
  `PRODUCT_DELETE_FAILED` (id + name).
- Customer/supplier deletion — `view/uframepeople.pas`: `CUSTOMER_DELETED` /
  `SUPPLIER_DELETED` (+ failed variants).
- Settings changes — `view/uframesettings.pas`: `DB_FILE_CHANGED` and
  `PARAMETER_CHANGED`. **Credential values are never logged** (recorded as
  `value=(hidden)`); plain parameter values are recorded.

### 3. Startup data-integrity check
On database open, any product lacking a `balance` row is logged so the issue is
actionable (a product with no balance cannot accumulate stock from purchases —
the "Portatiza O'min" class of bug).

- `infrastructure/udatamodule.pas` — `CheckProductsWithoutBalance`, called at the
  end of `OpenDatabase`. Emits `PRODUCT_WITHOUT_BALANCE` per product and a
  `BALANCE_INTEGRITY` summary. Repair with **Devoluciones → Reconstruir Saldos**
  (the balance builder now inserts missing balance rows).

---

## Known gaps (not yet addressed)

These are documented so they are not forgotten; each is a separate, scoped effort.

- **Access control (Tier 2):** add a `users` table (salted+hashed passwords —
  not the Blowfish/ECB used for the Instagram token), a login screen, and
  cashier/admin roles. This also gives the audit trail a real "who".
- **Backups (Tier 3):** automated, verified, optionally encrypted DB backups
  (currently manual `db/invcar.bak.*`).
- **Secret-at-rest (Tier 3):** `service/ucrypto.pas` uses a hard-coded key +
  Blowfish-ECB (author-labeled obfuscation-grade). Acceptable while it only
  protects the Instagram token; move the key out of source before storing
  anything more sensitive.
- **Fiscal invoicing (Tier 4):** IVA per product, invoice numbering, receipts,
  and — if legally required in Colombia — DIAN electronic invoicing via a
  certified provider. Only needed if the store issues legal invoices.

---

## Audit event reference (current)

| Event | Source | When |
| --- | --- | --- |
| `FK_ENFORCEMENT` | DataModule | On DB open (foreign_keys state) |
| `BALANCE_INTEGRITY` / `PRODUCT_WITHOUT_BALANCE` | DataModule | On DB open |
| `PRODUCT_DELETED` / `PRODUCT_DELETE_FAILED` | FrameProducts | Product deletion |
| `CUSTOMER_DELETED` / `SUPPLIER_DELETED` (+`_FAILED`) | FramePeople | Person deletion |
| `DB_FILE_CHANGED` | FrameSettings | db.file switched |
| `PARAMETER_CHANGED` | FrameSettings | Setting saved (credential value hidden) |
| `SALE_CREATED` / `CREDIT_SALE_CREATED` | SaleService | Sale committed |

Logs: `logs/apotheca.log` (5 MB rotation, 5 files kept).
