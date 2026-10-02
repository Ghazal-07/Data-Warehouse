
# Sales ETL & Data Warehouse — GitHub README

<div align="center">

**A modern SQL Server Data Warehouse project for Sales Analytics**

_T-SQL • Star Schema • Dimension–Fact Architecture • Full Load ETL_

</div>

---

## 📌 Overview

This repository contains the complete source code and documentation for a **Sales Data Warehouse** built on **Microsoft SQL Server**.

The project implements a clean **Staging → Dimension → Fact** architecture with a denormalized star schema, enabling reliable, auditable, and analytics-ready sales reporting for BI tools such as Power BI and Grafana.

---

## 🗂️ Repo Contents

| Path | Description |
|---|---|
| `sql/schema` | Database, schema, and table creation scripts (DDL) |
| `sql/etl` | Stored procedures for ETL loading |
| `sql/quality` | Data quality and validation queries |
| `data-catalog/` | Operational and business metadata documentation |
| `docs/` | Supplemental design and architecture notes |

```
.
├── sql
│   ├── schema/          # DDL for stg, dim, fact, etl layers
│   ├── etl/             # ETL stored procedures (full load)
│   └── quality/         # Data quality & validation queries
├── data-catalog/        # DATA_CATALOG.md
├── docs/                # Architecture & design documentation
└── README.md
```

---

## 🏗️ Architecture

The warehouse follows a classic layered design:

```
Source Systems
      │
      ▼
  [stg] Staging Layer        → Raw ingestion, minimal transformation
      │
      ▼
  [dim] Dimension Layer      → Business entities (Product, Customer, Date)
      │
      ▼
  [fact] Fact Layer          → Measurable transactions (Sales)
      │
      ▼
    BI / Reporting
```

### Key Design Decisions

- **Denormalized Star Schema** — the `Product` dimension includes category attributes directly, reducing required joins.
- **Full Load ETL** — dimensions and facts are rebuilt on each run for a consistent, reproducible state.
- **Surrogate Keys** — every dimension has a dedicated integer key (`ProductKey`, `CustomerKey`, etc.).
- **Unknown Members** — missing lookups map to surrogate key `0` to preserve referential integrity.
- **Atomic Transactions** — all ETL runs under transactional control with error handling.

---

## 🧱 Schema Layers

| Schema | Type | Responsibility |
|---|---|---|
| `stg` | Staging | Stores raw extracted source data |
| `dim` | Dimension | Stores descriptive attributes for analysis |
| `fact` | Fact | Stores measurable business transactions |
| `etl` | Operational | Stores ETL logs and execution metadata |

---

## 📚 Core Tables

### Dimensions

- **`dim.Product`** — product attributes, including denormalized category and brand.
- **`dim.Customer`** — customer attributes and location.
- **`dim.Date`** — reusable calendar dimension.

### Fact

- **`fact.Sales`** — grain is one row per order line, with quantity, price, and amount calculations.

### Staging

- **`stg.SalesOrder`**, `stg.Customer`, `stg.Product` — raw source snapshots.

---

## 🔧 ETL Pipeline

### Load Sequence

1. Load staging tables from source.
2. Clean and validate incoming records.
3. Load dimension tables.
4. Resolve surrogate keys.
5. Load the fact table.
6. Write execution logs.

### Standard Cleansing Pattern

```sql
COALESCE(
    NULLIF(LTRIM(RTRIM(SourceColumn)), N''),
    N'Unknown'
)
```

### Transaction Pattern

```sql
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- ETL operations here

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
```

---

## 📊 KPI Examples

| KPI | Formula |
|---|---|
| **Gross Sales** | `SUM(GrossAmount)` |
| **Net Sales** | `SUM(NetAmount)` |
| **Total Discount** | `SUM(DiscountAmount)` |
| **Total Quantity Sold** | `SUM(Quantity)` |
| **Order Count** | `COUNT(DISTINCT OrderKey)` |

---

## ✅ Data Quality

The pipeline includes validation queries for:

- Duplicate source lines
- Invalid or negative quantities
- Inconsistent financial calculations
- Orphan fact records
- Unknown member mapping rates

---

## 🧰 Prerequisites

- **Microsoft SQL Server** (2019+ recommended)
- SQL Server Management Studio (or equivalent)
- Permission to create databases, schemas, tables, and stored procedures

---

## 🚀 Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/your-org/sales-dwh.git
cd sales-dwh
```

### 2. Create the database and schema

Execute the DDL scripts under `sql/schema` against your target SQL Server instance.

### 3. Deploy the ETL procedures

Execute the stored procedures under `sql/etl`. Each procedure adopts the full load strategy.

### 4. Run the pipeline

```sql
EXEC etl.usp_load_dim_northwind;
EXEC etl.usp_load_fact_order_full;
```

### 5. Validate

Run the validation queries under `sql/quality` to confirm data integrity.

---

## 📖 Documentation

| Document | Purpose |
|---|---|
| `DATA_CATALOG.md` | Complete metadata, definitions, and business rules |

---

## 🛠️ Roadmap

- [ ] Add incremental load support for large-volume tables
- [ ] Introduce Slowly Changing Dimension (SCD) Type 2 for history
- [ ] Add automated monitoring in Grafana / Loki
- [ ] Publish curated reporting views
- [ ] Add CI checks for schema drift

---

## 👤 Maintainers

**Reza Afkhamnia** — Data Warehouse Developer & BI Developer
