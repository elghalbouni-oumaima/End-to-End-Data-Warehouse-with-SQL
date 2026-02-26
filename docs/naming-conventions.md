
# **Naming Conventions**

This document defines the naming standards applied across the Data Warehouse to ensure consistency, readability, and maintainability.

---

# **Table of Contents**

1. [General Principles](#1-general-principles)
2. [Schema Naming Conventions](#2-schema-naming-conventions)
3. [Table Naming Conventions](#3-table-naming-conventions)
4. [Column Naming Conventions](#4-column-naming-conventions)
5. [View Naming Conventions](#5-view-naming-conventions)
6. [Stored Procedure Naming Conventions](#6-stored-procedure-naming-conventions)

---

# **1. General Principles**

* Use **snake_case** (lowercase letters with underscores).
* Use **English** for all database objects.
* Avoid SQL reserved keywords.
* Names must be **clear, descriptive, and business-aligned**.
* No abbreviations unless commonly accepted (e.g., `id`, `qty`).

---

# **2. Schema Naming Conventions**

The warehouse follows a **layered architecture**:

| Schema   | Purpose                               |
| -------- | ------------------------------------- |
| `bronze` | Raw ingested data from source systems |
| `silver` | Cleaned and transformed data          |
| `gold`   | Business-ready analytical tables      |

---

# **3. Table Naming Conventions**

## **Bronze Layer (Raw Data)**

Pattern:

```
<sourcesystem>_<entity>
```

* `<sourcesystem>` → Source identifier (`erp`, `crm`)
* `<entity>` → Original table name from the source

Examples:

* `erp_sales_orders`
* `crm_customers`

🔹 Rule: Bronze tables must preserve original naming to maintain traceability.

---

## **Silver Layer (Cleaned Data)**

Pattern:

```
<sourcesystem>_<entity>
```

* Same naming as Bronze
* Data is cleaned, standardized, and validated

Examples:

* `erp_sales_orders`
* `crm_customers`

🔹 Rule: No business renaming yet — focus on data quality.

---

## **Gold Layer (Business Model – Star Schema)**

Pattern:

```
<category>_<entity>
```

* `<category>`:

  * `dim` → Dimension table
  * `fact` → Fact table
  * `agg` → Aggregated table (optional)

Examples:

* `dim_customers`
* `dim_products`
* `fact_sales`

🔹 Rule: Names must reflect business meaning, not source system structure.

---

# **4. Column Naming Conventions**

## **Primary Keys (Surrogate Keys)**

Pattern:

```
<entity>_key
```

Examples:

* `customer_key`
* `product_key`
* `date_key`

🔹 Used only in dimension tables.

---

## **Foreign Keys**

Pattern:

```
<referenced_entity>_key
```

Example in `fact_sales`:

* `customer_key`
* `product_key`

---

## **Natural Keys**

Pattern:

```
<entity>_id
```

Examples:

* `customer_id`
* `order_id`

🔹 Represents business identifiers from source systems.

---

## **Measures (Fact Table Metrics)**

* Use descriptive names.
* Avoid abbreviations.

Examples:

* `sales_amount`
* `quantity_sold`
* `discount_amount`

---

## **Technical / Metadata Columns**

Pattern:

```
dwh_<description>
```

Examples:

* `dwh_load_date`
* `dwh_source_system`
* `dwh_batch_id`

🔹 Used for auditing and data lineage tracking.

---

# **5. View Naming Conventions**

Pattern:

```
vw_<purpose>
```

Examples:

* `vw_monthly_sales`
* `vw_customer_summary`

---

# **6. Stored Procedure Naming Conventions**

Pattern:

```
sp_<action>_<layer>
```

Examples:

* `sp_load_bronze` → Stored procedure for loading raw data into the Bronze layer.  
* `sp_transform_silver` → Stored procedure for transforming and cleaning data from the Bronze layer into the Silver layer.  
* `sp_build_gold` → Stored procedure for building business-ready tables in the Gold layer.

🔹 Procedures must describe the action clearly.

---