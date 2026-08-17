# Apothêca

Inventory and point-of-sale management application for billiard supplies. Built with Free Pascal and Lazarus LCL.

## Features

- Point of Sale (POS) with product search, cart, and customer selection
- Purchase management with supplier tracking
- Credit sales and debt payment management
- Product inventory with balance tracking
- Customer and supplier management
- Reports (income, inventory valuation, purchases)
- Multi-language support (English default, Spanish via OS detection)
- OWASP-compliant structured logging

## Architecture

### Project Structure

```
invcar/
├── apotheca.lpr            # Main program entry point
├── apotheca.lpi            # Lazarus project file
├── db/                     # Database
│   ├── invcar              # SQLite database file
│   └── schema.sql          # DDL script
├── icons/                  # UI icons (SVG sources + PNG exports)
├── infrastructure/         # Cross-cutting concerns
│   ├── udatamodule.pas     # Database connection and migrations
│   ├── ugridutils.pas      # TStringGrid helpers
│   ├── ulanguage.pas       # i18n / OS language detection
│   ├── ulogger.pas         # OWASP-compliant structured logger
│   └── uresourcestring.pas # All UI strings (English default)
├── languages/              # Translation files
│   └── es/apotheca.es.po   # Spanish translations
├── model/                  # Domain models
│   ├── utransaction.pas    # Base transaction (purchase/sale)
│   ├── upurchase.pas       # Purchase (extends TIn)
│   ├── usale.pas           # Sale (extends TOut)
│   ├── uitem.pas           # Line item within a transaction
│   ├── uproduct.pas        # Product catalog entry
│   ├── ubalance.pas        # Product stock/valuation
│   ├── uperson.pas         # Person (name, phone, address)
│   ├── ucustomer.pas       # Customer (extends Person)
│   ├── usupplier.pas       # Supplier (extends Person)
│   ├── upay.pas            # Payment record
│   ├── udebtorinfo.pas     # Debtor summary (credit view)
│   └── ucreditsaleinfo.pas # Credit sale detail
├── repository/             # Data access layer
│   ├── udata.pas           # Base repository class
│   ├── udatatransaction.pas# Transaction persistence
│   ├── udatain.pas         # Purchase persistence
│   ├── udataout.pas        # Sale persistence
│   ├── udataitem.pas       # Item persistence
│   ├── udataproduct.pas    # Product queries
│   ├── udatabalance.pas    # Balance read/write
│   ├── udatacustomer.pas   # Customer queries
│   ├── udatasupplier.pas   # Supplier queries
│   ├── udataperson.pas     # Person persistence
│   └── udatapay.pas        # Payment persistence
├── service/                # Business logic layer
│   ├── usaleservice.pas    # Sale workflow (POS → persist)
│   ├── ucartservice.pas    # Shopping cart management
│   ├── ucreditservice.pas  # Credit/debt calculations
│   ├── upurchaseservice.pas# Purchase workflow
│   ├── ureportengine.pas   # Report generation
│   ├── ubalancebuilder.pas # Balance recalculation
│   └── u*validator.pas     # Input validation
├── view/                   # UI layer (LCL Frames and Forms)
│   ├── apothecamain.pas    # Main form + sidebar navigation
│   ├── uframepos.pas       # POS frame
│   ├── uframecredits.pas   # Credit management frame
│   ├── uframepurchase.pas  # Purchase entry frame
│   ├── uframeproducts.pas  # Product catalog frame
│   ├── uframepeople.pas    # Customer/supplier frame
│   ├── uframereports.pas   # Reports frame
│   ├── uformsplash.pas     # Startup splash screen
│   └── uf*.pas             # Dialog forms (find, edit)
├── tests/                  # Property-based tests (FPCUnit)
│   ├── test_balance_invariant.pas
│   ├── test_cart_arithmetic.pas
│   ├── test_product_search.pas
│   └── ...
└── res/                    # Runtime resources
    └── Splash.jpg          # Splash screen image
```

### Layer Diagram

```mermaid
graph TD
    subgraph VIEW["VIEW (LCL Frames & Forms)"]
        FM[TFormPrincipal]
        FP[TFramePOS]
        FC[TFrameCredits]
        FPU[TFramePurchase]
        FPR[TFrameProducts]
        FPE[TFramePeople]
        FR[TFrameReports]
        FS[TFormSplash]
    end

    subgraph SERVICE["SERVICE (Business Logic)"]
        SS[TSaleService]
        CS[TCartService]
        CRS[TCreditService]
        PS[TPurchaseService]
        RE[TReportEngine]
        BB[TBalanceBuilder]
    end

    subgraph REPOSITORY["REPOSITORY (Data Access)"]
        DT[TDataTransaction]
        DI[TDataIn]
        DO[TDataOut]
        DIt[TDataItem]
        DP[TDataProduct]
        DB[TDataBalance]
        DC[TDataCustomer]
        DSu[TDataSupplier]
        DPe[TDataPerson]
        DPa[TDataPay]
    end

    subgraph INFRASTRUCTURE["INFRASTRUCTURE"]
        DM[TDataModule1 - SQLite]
        LG[ULogger]
        LN[ULanguage]
        RS[UResourceString]
    end

    subgraph DATABASE["SQLite DB"]
        TBL[person, customer, supplier, product, balance, operationtype, operation, item, pay]
    end

    FM --> FP & FC & FPU & FPR & FPE & FR
    FP --> SS & CS
    FC --> CRS
    FPU --> PS
    FR --> RE
    SS --> DO
    CRS --> DPa
    PS --> DI
    RE --> DM
    DO --> DT & DIt & DB
    DI --> DT & DIt & DB
    DT --> DM
    DIt --> DM
    DB --> DM
    DC --> DM
    DPa --> DM
    DM --> TBL
```

### Components

| Component | Responsibility |
|-----------|---------------|
| `TFormPrincipal` | Main window, sidebar navigation, frame switching |
| `TFramePOS` | Product search, cart grid, credit checkbox, sale completion |
| `TFrameCredits` | Debtor list, credit sale detail, payment registration |
| `TFramePurchase` | Supplier selection, item grid, purchase save |
| `TFrameProducts` | Product CRUD with search |
| `TFramePeople` | Customer/supplier management (tabbed) |
| `TFrameReports` | Date-filtered reports with CSV export |
| `TSaleService` | Validates cart, sets credit flag, persists sale via TDataOut |
| `TCreditService` | Debt balance calculation, payment registration |
| `TCartService` | In-memory cart operations (add, remove, quantities) |
| `TDataModule1` | DB connection, schema creation, migrations |
| `ULogger` | OWASP-compliant file logging with rotation |
| `ULanguage` | OS language detection, .po file loading |

### Data Model

```mermaid
erDiagram
    person {
        INTEGER id PK
        TEXT name
        TEXT telephone
        TEXT address
    }
    customer {
        INTEGER id PK
        INTEGER person FK
    }
    supplier {
        INTEGER id PK
        INTEGER person FK
    }
    product {
        INTEGER id PK
        TEXT name
        INTEGER minstock
        INTEGER maxstock
    }
    balance {
        INTEGER id PK
        INTEGER product FK
        INTEGER units
        REAL balance
        REAL cost
        REAL price
    }
    operationtype {
        INTEGER id PK
        TEXT description
        TEXT type
    }
    operation {
        INTEGER id PK
        INTEGER type FK
        REAL date
        INTEGER person FK
        INTEGER credit
    }
    item {
        INTEGER id PK
        INTEGER product FK
        INTEGER operation FK
        REAL cost
        INTEGER stock
        REAL price
    }
    pay {
        INTEGER id PK
        INTEGER person FK
        REAL val
        REAL date
        INTEGER operation FK
    }

    person ||--o{ customer : "is a"
    person ||--o{ supplier : "is a"
    product ||--|| balance : "has"
    operationtype ||--o{ operation : "categorizes"
    person ||--o{ operation : "performs"
    operation ||--o{ item : "contains"
    product ||--o{ item : "referenced in"
    person ||--o{ pay : "makes"
    operation ||--o{ pay : "paid against"
```

## Sequence Diagrams

### Credit Sale (POS)

```mermaid
sequenceDiagram
    participant U as User
    participant FP as FramePOS
    participant CS as CartService
    participant SS as SaleService
    participant DO as DataOut
    participant DB as SQLite

    U->>FP: Check "Crédito" checkbox
    U->>FP: Select customer
    U->>FP: Add products
    U->>FP: Click "Complete Sale"
    FP->>FP: Validate (customer required)
    FP->>SS: SaveSale(cart, credit=True)
    SS->>SS: sale.setCredit(1)
    SS->>DO: new(sale)
    DO->>DB: INSERT operation (credit=1)
    DO->>DB: INSERT items
    DO->>DB: UPDATE balance
    DB-->>SS: Success
    SS-->>FP: True
    FP->>CS: ClearCart
    FP-->>U: Show confirmation
```

### Payment Registration

```mermaid
sequenceDiagram
    participant U as User
    participant FC as FrameCredits
    participant CS as CreditService
    participant DB as SQLite

    U->>FC: Select debtor in grid
    FC->>CS: GetCreditSales(personId)
    CS->>DB: SELECT credit sales
    DB-->>CS: Sale rows
    CS-->>FC: TCreditSaleInfo list
    FC-->>U: Show credit sales

    U->>FC: Select a credit sale
    FC->>CS: GetPayments(operationId)
    CS->>DB: SELECT payments for operation
    DB-->>CS: Payment rows
    CS-->>FC: TPay list
    FC-->>U: Show payments

    U->>FC: Enter amount + click "Register"
    FC->>FC: Validate amount > 0
    FC->>CS: RegisterPayment(personId, operationId, amount, date)
    CS->>DB: BEGIN TRANSACTION
    CS->>DB: INSERT INTO pay
    CS->>DB: COMMIT
    DB-->>CS: Success
    CS-->>FC: True
    FC->>FC: RefreshAll
    FC-->>U: Show success
```

### Application Startup

```mermaid
sequenceDiagram
    participant M as Main
    participant L as ULanguage
    participant S as Splash
    participant DM as DataModule
    participant F as MainForm

    M->>L: InitializeLanguage
    L->>L: DetectOSLanguage
    L->>L: Load .po file (if not English)
    L-->>M: Ready

    M->>S: Create + ShowModal
    S->>S: Load Splash.jpg
    S->>S: 5s timer
    S-->>M: Closed

    M->>DM: CreateForm
    DM->>DM: Connect SQLite
    DM->>DM: InitDefaultDatabaseSchema
    DM->>DM: MigrateCreditColumn
    DM->>DM: MigratePayOperationColumn
    DM-->>M: Ready

    M->>F: CreateForm
    F->>F: CreateFrames
    F->>F: LoadIcons
    F->>F: NavigateTo(POS)
    M->>F: Application.Run
```

### Navigation Flow

```mermaid
stateDiagram-v2
    [*] --> POS : App starts
    POS --> Credits : Click "Créditos"
    POS --> Purchases : Click "Compras"
    POS --> Products : Click "Productos"
    POS --> People : Click "Personas"
    POS --> Reports : Click "Reportes"
    Credits --> POS : Click "Ventas"
    Purchases --> POS : Click "Ventas"
    Products --> POS : Click "Ventas"
    People --> POS : Click "Ventas"
    Reports --> POS : Click "Ventas"
```

## Prerequisites

- **Free Pascal Compiler** (FPC) 3.2.2+
- **Lazarus IDE** 2.2+ (provides `lazbuild` CLI)
- **SQLite3** runtime library

### Linux (Debian/Ubuntu)

```bash
sudo apt install fpc lazarus libsqlite3-0
```

### Linux (Arch)

```bash
sudo pacman -S fpc lazarus sqlite
```

## Building

### Using Makefile

```bash
make build     # Compile the application
make test      # Run all property-based tests
make run       # Build and run
make clean     # Remove build artifacts
make package   # Create distributable archive
```

### Using lazbuild directly

```bash
lazbuild apotheca.lpi
```

## Running

```bash
./apotheca
```

The application will:
1. Show a splash screen for 5 seconds
2. Create/connect to `db/invcar` SQLite database
3. Run schema migrations automatically
4. Detect OS language and load translations
5. Display the main window with sidebar navigation

## Testing

Tests use FPCUnit with property-based testing (100+ random iterations per property):

```bash
make test
```

Individual test suites:

```bash
cd tests
./run_balance_invariant_test
./run_sale_balance_test
./run_product_search_test
```

## Logging

Logs are written to `logs/apotheca.log` with automatic rotation (5 MB max, 5 files kept).

Format: `TIMESTAMP | LEVEL | SOURCE | EVENT | DETAILS`

Levels: DEBUG, INFO, WARN, ERROR, SECURITY

## License

GNU General Public License v2.0 or later. See source file headers.
