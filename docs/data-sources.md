
# **Data Sources**

## 1. Overview

The Data Warehouse consolidates data from two independent operational systems: an ERP system and a CRM system.
Both systems provide structured data in CSV format and serve different business purposes.

The objective is to integrate these heterogeneous sources into a unified analytical model that supports reporting and decision-making.

---

## 2. Source Systems Description

### 2.1 ERP System (Enterprise Resource Planning)

The ERP system manages internal business operations and transactional processes.

#### Data Characteristics

* High-volume transactional data
* Structured tabular format
* Business-critical financial and operational metrics

#### Typical Entities

* Sales orders
* Products
* Order details
* Quantities
* Prices
* Revenue

#### Role in the Data Warehouse

The ERP system primarily feeds:

* Fact tables (e.g., `fact_sales`)
* Product-related dimensions (if applicable)

It provides measurable business metrics used for performance analysis.

---

### 2.2 CRM System (Customer Relationship Management)

The CRM system manages customer information and relationship data.

#### Data Characteristics

* Customer master data
* Descriptive attributes
* Lower volume compared to transactional ERP data

#### Typical Entities

* Customers
* Contact details
* Geographic information
* Customer segmentation

#### Role in the Data Warehouse

The CRM system primarily feeds:

* Customer dimension tables (e.g., `dim_customers`)

It enables customer-level analysis and segmentation.

---

## 3. Data Format

* Format: CSV (Comma-Separated Values)
* Encoding: UTF-8
* Structure: Structured flat files
* Update Scope: Latest dataset only (no historization required)

---

## 4. Data Integration Strategy

The integration process follows a layered architecture:

1. Bronze Layer
   Raw ingestion of ERP and CRM data without structural modification.

2. Silver Layer
   Data cleansing, standardization, and validation.

3. Gold Layer
   Business-oriented modeling using a Star Schema (fact and dimension tables).

---

## 5. Source-to-Warehouse Mapping (Conceptual)

| Source System | Warehouse Layer | Target Table Type |
| ------------- | --------------- | ----------------- |
| ERP           | Gold            | Fact Tables       |
| CRM           | Gold            | Dimension Tables  |

---

## 6. Design Considerations

* Maintain traceability between source systems and warehouse tables.
* Preserve natural keys from source systems.
* Introduce surrogate keys in dimension tables.
* Ensure consistent data types and standardized formats.

---
