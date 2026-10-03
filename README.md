# Sales ETL & Data Warehouse — GitHub README

*T-SQL • Snowflake Schema • Dimension–Fact Architecture • Full Load ETL*

## Overview

This project implements a Sales Data Warehouse using SQL Server, T-SQL, and a Snowflake Schema architecture.

The ETL pipeline extracts data from the Northwind source system, transforms and cleans the data, loads normalized dimensions, and finally populates the central sales fact table.

The main goal is to provide a structured analytical model that supports reporting, business intelligence, and sales analysis.

---

## Data Warehouse Architecture

The Data Warehouse follows a Snowflake Schema where selected dimensions are normalized into related sub-dimensions.

The central fact table is:

* `sale.fact_order`

The main dimensions are:

* `sale.dim_customer`
* `sale.dim_employee`
* `sale.dim_product`
* `sale.dim_shipper`
* `sale.dim_supplier`
* `sale.dim_geography`
* `sale.dim_date`

### Snowflake Schema

```text
                         Dim Supplier
                              |
                              v
                         Dim Product
                              |
                              v
Dim Date ----------------> Fact Order <---------------- Dim Customer
                              ^
                              |
                        Dim Employee
                              ^
                              |
                         Dim Shipper


                 Dim Geography
                  /     |      \
                 v      v       v
            Customer Employee Supplier
```

### Dimension Relationships

The Snowflake Schema uses the following relationships:

```text
Fact Order
   |
   +-- Customer ----------------> Geography
   |
   +-- Employee ----------------> Geography
   |
   +-- Product -----------------> Supplier ----------------> Geography
   |
   +-- Shipper
   |
   +-- Date
```

This means that `Geography` and `Supplier` are not directly stored in the fact table.

Supplier information is reached through:

```text
Fact Order → Product → Supplier
```

Geography information can be reached through:

```text
Fact Order → Customer → Geography
Fact Order → Employee → Geography
Fact Order → Product → Supplier → Geography
```

---

## Key Design Decisions

### Snowflake Schema

The warehouse uses a Snowflake Schema instead of a fully denormalized Star Schema.

Selected dimensions are normalized to reduce duplication and maintain clearer relationships between related entities.

### Product → Supplier

Supplier information is separated from the Product dimension.

```text
Fact Order
    |
 Product
    |
 Supplier
```

The fact table therefore stores `product_key` rather than a direct `supplier_key`.

### Customer / Employee / Supplier → Geography

Geography is implemented as a separate dimension.

```text
Customer  ----\
Employee  ----- > Geography
Supplier  ----/
```

The fact table does not store `geography_key` directly.

---

## Schema Layers

The database is organized into the following layers:

```text
stage
  ↓
sale.dim_geography
  ↓
sale.dim_customer
sale.dim_employee
sale.dim_supplier
  ↓
sale.dim_product
sale.dim_shipper
  ↓
sale.fact_order
```

---

## Core Tables

### Dimensions

* `sale.dim_geography`
* `sale.dim_customer`
* `sale.dim_employee`
* `sale.dim_supplier`
* `sale.dim_product`
* `sale.dim_shipper`
* `sale.dim_date`

### Fact

* `sale.fact_order`

---

## Fact Table Grain

The fact table is maintained at the following grain:

> One row per Order ID + Product ID.

This grain is preserved during the ETL process by aggregating duplicate order-line records before inserting into the fact table.

The fact table directly references:

* Customer
* Employee
* Product
* Shipper
* Date

Supplier and Geography are resolved through the normalized dimension relationships.

---

## ETL Process

The ETL process follows this sequence:

1. Load Geography
2. Load Customer
3. Load Employee
4. Load Supplier
5. Load Product
6. Load Shipper
7. Load Fact Order

The dimension loads use Type 1 SCD behavior.

---

## Snowflake Dimension Resolution

### Product → Supplier

```text
Fact Order
    |
    v
Dim Product
    |
    v
Dim Supplier
```

### Customer → Geography

```text
Fact Order
    |
    v
Dim Customer
    |
    v
Dim Geography
```

### Employee → Geography

```text
Fact Order
    |
    v
Dim Employee
    |
    v
Dim Geography
```

### Supplier → Geography

```text
Fact Order
    |
    v
Dim Product
    |
    v
Dim Supplier
    |
    v
Dim Geography
```

---

## Fact Calculations

The ETL calculates:

* Gross Amount
* Discount Amount
* Net Amount
* Freight Amount

Freight is allocated proportionally across order lines based on quantity.

---

## Data Quality Checks

The ETL process includes checks for:

* Duplicate orders
* Duplicate order lines
* Invalid quantities
* Invalid prices
* Null dimension keys
* Standardized discount values
* Missing dimension lookups

Unknown dimension members are resolved using the default key where applicable.

---

## Example KPIs

The warehouse can support common sales KPIs such as:

* Total Sales
* Net Sales
* Total Quantity
* Average Order Value
* Discount Amount
* Freight Cost
* Sales by Customer
* Sales by Employee
* Sales by Product
* Sales by Supplier
* Sales by Geography
* Sales by Date

---

## Final Data Warehouse Model

```text
                         Dim Supplier
                              |
                              v
                         Dim Product
                              |
                              v
Dim Date ----------------> Fact Order <---------------- Dim Customer
                              ^
                              |
                        Dim Employee
                              ^
                              |
                         Dim Shipper


                 Dim Geography
                  /     |      \
                 v      v       v
            Customer Employee Supplier
```

The final model follows a Snowflake Schema by normalizing Supplier and Geography relationships while keeping the Fact Order table focused on measurable sales transactions.

---

## Maintainer

**Ghazal Salehi**
