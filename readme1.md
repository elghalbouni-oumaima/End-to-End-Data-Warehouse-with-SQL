# 🚀 End-to-End Data Warehouse & Customer Analytics Platform

An end-to-end data engineering and analytics project that transforms raw sales and customer data into a structured **Data Warehouse**, an analytical **Gold Layer**, interactive **Power BI dashboards**, and a **Machine Learning churn prediction pipeline**.

The project demonstrates the complete journey from raw data ingestion and transformation to business intelligence and predictive analytics.

---

## 📌 Table of Contents

- [Project Overview](#-project-overview)
- [Business Objectives](#-business-objectives)
- [Architecture](#-architecture)
- [Technology Stack](#-technology-stack)
- [Data Warehouse](#-data-warehouse)
- [Gold Layer](#-gold-layer)
- [Star Schema](#-star-schema)
- [Machine Learning - Customer Churn Prediction](#-machine-learning---customer-churn-prediction)
- [Power BI Analytics](#-power-bi-analytics)
- [Project Structure](#-project-structure)
- [Data Flow](#-data-flow)
- [Key Metrics](#-key-metrics)
- [Machine Learning Results](#-machine-learning-results)
- [Setup and Installation](#-setup-and-installation)
- [Running the Project](#-running-the-project)
- [Power BI Connection](#-power-bi-connection)
- [Screenshots](#-screenshots)
- [Future Improvements](#-future-improvements)
- [Key Learnings](#-key-learnings)
- [Author](#-author)

---

# 📊 Project Overview

This project implements an end-to-end data platform designed to support both **descriptive analytics** and **predictive analytics**.

The project starts with raw business data and progressively transforms it into structured analytical datasets.

The final platform provides:

- A structured SQL Data Warehouse
- Bronze, Silver, and Gold data layers
- A dimensional Star Schema
- Customer, product, sales, and date dimensions
- Business intelligence dashboards using Power BI
- Customer segmentation and sales analytics
- Customer churn prediction using Machine Learning
- Customer risk scoring
- Feature importance analysis
- A "Customers at Risk" analytical dashboard

The overall workflow is:

```text
                    ┌─────────────────────┐
                    │     Raw Sources     │
                    │ Customer / Product  │
                    │ Sales Data           │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Bronze Layer      │
                    │ Raw / Initial Data  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Silver Layer      │
                    │ Cleaning &          │
                    │ Transformation      │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │    Gold Layer       │
                    │ Dimensional Model  │
                    └──────────┬──────────┘
                               │
                 ┌─────────────┴─────────────┐
                 ▼                           ▼
        ┌─────────────────┐        ┌────────────────────┐
        │    Power BI     │        │ Machine Learning   │
        │    Analytics    │        │ Churn Prediction   │
        └────────┬────────┘        └─────────┬──────────┘
                 │                           │
                 ▼                           ▼
        ┌─────────────────┐        ┌────────────────────┐
        │ Business        │        │ Customer Risk      │
        │ Dashboards      │        │ Predictions        │
        └─────────────────┘        └────────────────────┘
````

---

# 🎯 Business Objectives

The main objective is to transform transactional data into useful business insights and predictive intelligence.

The project answers questions such as:

### Customer Analytics

* How many customers do we have?
* What is the average customer age?
* Which countries generate the most customers?
* What percentage of customers are male/female?
* How many new customers joined during a given period?
* How many customers make repeat purchases?
* How many orders does each customer make on average?

### Sales Analytics

* What is the total sales amount?
* Which products generate the most revenue?
* Which product lines perform best?
* How does sales performance evolve over time?
* Which countries generate the highest sales?

### Product Analytics

* Which products generate the highest revenue?
* Which product lines perform best?
* How are products distributed across categories?
* Which products have the highest sales volume?

### Customer Churn

* Which customers are likely to churn?
* What percentage of customers are at risk?
* Which customers have the highest churn probability?
* What behavioral characteristics are associated with churn?
* Which countries have the highest concentration of at-risk customers?

---

# 🏗️ Architecture

The project follows a layered Data Warehouse architecture.

```text
                    DATA SOURCES
                         │
                         ▼
                ┌─────────────────┐
                │  Bronze Layer   │
                │ Raw Data        │
                └────────┬────────┘
                         │
                         ▼
                ┌─────────────────┐
                │  Silver Layer   │
                │ Cleaned Data    │
                │ Standardization │
                └────────┬────────┘
                         │
                         ▼
                ┌─────────────────┐
                │   Gold Layer    │
                │ Star Schema     │
                └────────┬────────┘
                         │
             ┌───────────┴───────────┐
             │                       │
             ▼                       ▼
      ┌─────────────┐        ┌─────────────────┐
      │   Power BI  │        │ Machine Learning│
      │ Dashboards  │        │ Churn Prediction│
      └─────────────┘        └────────┬────────┘
                                      │
                                      ▼
                           ┌─────────────────────┐
                           │ Customer Risk Data  │
                           └─────────────────────┘
```

---

# 🛠️ Technology Stack

## Data Engineering

* SQL Server
* T-SQL
* Data Warehouse
* Dimensional Modeling
* Star Schema
* ETL / ELT concepts

## Data Analysis

* Python
* Pandas
* NumPy
* Matplotlib
* Scikit-learn

## Machine Learning

* Logistic Regression
* Random Forest
* Gradient Boosting
* XGBoost
* Cross-validation
* Hyperparameter tuning
* Feature importance
* Churn probability prediction

## Business Intelligence

* Microsoft Power BI
* DAX
* Interactive dashboards
* Data modeling
* Time-series analysis
* Conditional formatting
* Geographic analysis

## Development Tools

* Git
* GitHub
* VS Code
* Jupyter Notebook

---

# 🏢 Data Warehouse

The Data Warehouse is organized into multiple layers to separate raw data from analytical data.

## Bronze Layer

The Bronze layer contains the initial/raw representation of the source data.

The main objective is to preserve the source information before applying extensive transformations.

---

## Silver Layer

The Silver layer is responsible for cleaning and standardizing the data.

Typical transformations include:

* Data type corrections
* Cleaning missing values
* Standardizing categorical values
* Removing inconsistencies
* Data validation
* Preparing data for analytical modeling

---

# 🥇 Gold Layer

The Gold layer contains business-ready analytical tables.

It follows a **dimensional modeling approach** using a Star Schema.

The main tables are:

```text
gold.dim_customers
gold.dim_products
gold.dim_dates
gold.fact_sales
```

Additional tables support the Machine Learning workflow:

```text
gold.customer_churn_training
gold.customer_churn_scoring
gold.customer_churn_predictions
gold.churn_feature_importance
```

---

# ⭐ Star Schema

The main analytical model follows a Star Schema.

```text
                         ┌─────────────────────┐
                         │   dim_customers     │
                         │─────────────────────│
                         │ customer_key        │
                         │ customer_id         │
                         │ first_name          │
                         │ last_name           │
                         │ gender              │
                         │ birth_date          │
                         │ country             │
                         │ created_date        │
                         └──────────┬──────────┘
                                    │
                                    │ 1 : *
                                    ▼
                         ┌─────────────────────┐
                         │     fact_sales      │
                         │─────────────────────│
                         │ sales_key           │
                         │ order_number        │
                         │ customer_key        │
                         │ product_key         │
                         │ order_date_key      │
                         │ shipping_date_key   │
                         │ due_date_key        │
                         │ quantity            │
                         │ price               │
                         │ sales_amount        │
                         └───────┬───────┬─────┘
                                 │       │
                       * : 1     │       │     * : 1
                                 │       │
                                 ▼       ▼
                    ┌────────────────┐ ┌────────────────┐
                    │  dim_products  │ │    dim_dates   │
                    │────────────────│ │────────────────│
                    │ product_key    │ │ date_key       │
                    │ product_id     │ │ full_date      │
                    │ product_name   │ │ day_name       │
                    │ category       │ │ month_number   │
                    │ subcategory    │ │ month_name     │
                    │ product_cost   │ │ quarter_number │
                    │ product_line   │ │ year_number    │
                    └────────────────┘ └────────────────┘
```

---

# 👥 Customer Dimension

### `gold.dim_customers`

This table contains descriptive information about customers.

Important columns include:

| Column            | Description                  |
| ----------------- | ---------------------------- |
| `customer_key`    | Surrogate key                |
| `customer_id`     | Business/customer identifier |
| `customer_number` | Customer number              |
| `first_name`      | Customer first name          |
| `last_name`       | Customer last name           |
| `gender`          | Customer gender              |
| `birth_date`      | Customer birth date          |
| `marital_status`  | Marital status               |
| `country`         | Customer country             |
| `created_date`    | Customer creation date       |

The `customer_key` is used to connect customers to the sales fact table.

---

# 📦 Product Dimension

### `gold.dim_products`

Contains product-related descriptive information.

Important attributes include:

| Column               | Description                 |
| -------------------- | --------------------------- |
| `product_key`        | Surrogate key               |
| `product_id`         | Business/product identifier |
| `product_number`     | Product number              |
| `product_name`       | Product name                |
| `category`           | Product category            |
| `subcategory`        | Product subcategory         |
| `maintenance`        | Maintenance information     |
| `product_cost`       | Product cost                |
| `product_line`       | Product line                |
| `product_start_date` | Product start date          |

---

# 📅 Date Dimension

### `gold.dim_dates`

The date dimension supports time-based analytics.

It contains:

* Day
* Week
* Month
* Quarter
* Year
* Weekend/business-day flags
* Month sorting
* Quarter boundaries
* Year boundaries

Examples:

```text
date_key
full_date
day_name
day_of_week
day_of_year
week_of_year
month_number
month_name
quarter_number
year_number
year_month
month_year
month_year_sort
is_weekend
is_business_day
is_month_start
is_month_end
is_quarter_start
is_quarter_end
is_year_start
is_year_end
```

The `date_key` follows the format:

```text
YYYYMMDD
```

For example:

```text
20260815
```

This allows date keys to preserve chronological ordering.

---

# 💰 Sales Fact

### `gold.fact_sales`

The fact table stores transactional sales data.

Important columns include:

| Column              | Description               |
| ------------------- | ------------------------- |
| `sales_key`         | Surrogate fact key        |
| `order_number`      | Order identifier          |
| `customer_key`      | Customer foreign key      |
| `product_key`       | Product foreign key       |
| `order_date_key`    | Order date foreign key    |
| `shipping_date_key` | Shipping date foreign key |
| `due_date_key`      | Due date foreign key      |
| `quantity`          | Quantity sold             |
| `price`             | Unit price                |
| `sales_amount`      | Total sales amount        |

The model uses `dim_dates` rather than storing the complete date values directly in the fact table.

---

# 🤖 Machine Learning - Customer Churn Prediction

A Machine Learning pipeline was developed to identify customers who are at risk of churn.

The objective is to predict whether a customer is likely to stop purchasing based on historical behavior and customer characteristics.

---

## Churn Features

The training dataset contains behavioral and demographic features.

### Behavioral Features

```text
recency_days
frequency
monetary
avg_order_value
tenure_days
```

### Demographic Features

```text
age
gender
marital_status
country
```

### Target

```text
churned
```

Where:

```text
0 → Retained
1 → Churned
```

---

# 🧠 RFM-Based Customer Features

The churn model uses several behavioral features related to customer purchasing behavior.

### Recency

Number of days since the customer's last purchase.

```text
recency_days
```

A higher recency generally means the customer has been inactive for longer.

### Frequency

Number of distinct orders placed by the customer.

```text
frequency
```

### Monetary

Total amount spent by the customer.

```text
monetary
```

### Average Order Value

Average value of the customer's orders.

```text
avg_order_value
```

### Tenure

Number of days the customer has been registered.

```text
tenure_days
```

---

# 🏋️ Churn Training Dataset

### `gold.customer_churn_training`

This table is used to train the Machine Learning model.

It contains:

```text
customer_id
recency_days
frequency
monetary
avg_order_value
tenure_days
age
gender
marital_status
country
churned
```

The `churned` column is the target variable.

---

# 🎯 Churn Scoring Dataset

### `gold.customer_churn_scoring`

This table contains the latest customer features used for prediction.

Unlike the training dataset, it does not contain the `churned` target.

The model uses this table to calculate the current churn probability for each customer.

---

# 🔮 Churn Predictions

### `gold.customer_churn_predictions`

The prediction table stores the output of the Machine Learning model.

Main columns:

```text
customer_id
churn_probability
risk_tier
scored_at
```

Example:

| Customer | Churn Probability | Risk Tier |
| -------- | ----------------: | --------- |
| 1023     |              0.92 | High      |
| 5098     |              0.91 | High      |
| 2045     |              0.65 | Medium    |
| 3099     |              0.21 | Low       |

---

# 🚦 Risk Classification

Customers are divided into three risk tiers according to their predicted churn probability.

```text
                 Churn Probability

0.00 ──────────────── 0.70 ──────────────── 0.90 ─────────── 1.00
          LOW                  MEDIUM                HIGH
          🟢                     🟠                    🔴
```

The risk classification allows the business to prioritize customers who require attention.

---

# 🕐 `scored_at`

The `scored_at` column records when the Machine Learning model generated the prediction.

Example:

```text
2026-08-15 19:48:32
```

This allows the dashboard to display when the current predictions were generated.

---

# 📊 Power BI Analytics

Power BI is connected to the Gold layer and Machine Learning prediction tables.

The report contains several analytical pages.

---

## 1. 👥 Customer Overview

The Customer page provides an overview of the customer base.

![alt text](../End-to-End-Data-Warehouse-with-SQL/docs/powerbi_pages/customers.png)

Main KPIs include:

* Total Customers
* Average Customer Age
* Most Common Customer Country
* Male Customer Percentage
* Female Customer Percentage
* New Customers
* Repeat Purchase Rate
* Orders per Customer

Visualizations include:

* Customers Over Time
* Customers by Country
* Customer Demographics
* Customer Insights
* Customer Purchase Behavior

---

## 2. 📦 Product Analytics

The Product page focuses on product performance.
![alt text](../End-to-End-Data-Warehouse-with-SQL/docs/powerbi_pages/products.png)

Key visualizations include:

* Sales by Product
* Sales by Product Line
* Sales by Category
* Top Products
* Product Performance
* Product Distribution

A Treemap is used to visualize sales contribution by product line.

---

## 3. 💰 Sales Analytics

The Sales page provides an overview of sales performance.
![alt text](../End-to-End-Data-Warehouse-with-SQL/docs/powerbi_pages/sales.png)

Key metrics include:

* Total Sales
* Total Orders
* Average Order Value
* Total Quantity
* Sales by Gender
* Sales by Product Line
* Sales Trends



---

## 5. 📈 Trends & Insights

The Trends page focuses on changes over time.
![alt text](../End-to-End-Data-Warehouse-with-SQL/docs/powerbi_pages/trends.png)


Examples include:

* Sales over time
* Customer growth
* New customers over time
* Orders over time
* Monthly trends
* Yearly comparisons

The `dim_dates` table is used to support time-based filtering and analysis.

---

# 🚨 Customers at Risk

The Customers at Risk page combines Machine Learning predictions with Power BI analytics.

The page is designed to help identify customers who may require proactive retention actions.

![alt text](../End-to-End-Data-Warehouse-with-SQL/docs/powerbi_pages/customersat_risk.png)

Main KPIs:

```text
Total Customers
At Risk Customers
High Risk Customers
Average Churn Probability
Customers to Recover
```

Main visualizations:

### Customers by Risk Tier

Shows the distribution of:

```text
Low Risk
Medium Risk
High Risk
```
### At Risk Customers by Country

Shows geographic distribution of customers with elevated churn risk.

### Churn Probability Distribution

Shows how predicted churn probabilities are distributed across customers.

### Top Risk Factors

Shows the most important features influencing the churn model.

### Top High-Risk Customers

A table showing customers with the highest churn probabilities.

Example:

| Customer ID | Country | Churn Probability | Risk |
| ----------- | ------- | ----------------: | ---- |
| CUST_1023   | Morocco |              0.92 | High |
| CUST_5098   | Morocco |              0.91 | High |
| CUST_2045   | France  |              0.89 | High |

---

# 🔄 End-to-End Data Flow

The complete workflow is:

```text
1. Raw Data
      │
      ▼
2. Bronze Layer
      │
      ▼
3. Silver Layer
      │
      ▼
4. Gold Dimensional Model
      │
      ├───────────────┐
      │               │
      ▼               ▼
5. Power BI       5. Churn Feature
   Analytics          Engineering
                          │
                          ▼
                    6. Training Dataset
                          │
                          ▼
                    7. ML Model Training
                          │
                          ▼
                    8. Customer Scoring
                          │
                          ▼
                    9. Churn Predictions
                          │
                          ▼
                    10. Power BI
                        Customers at Risk
```

---

# 📁 Project Structure

The repository is organized as follows:

```text
End-to-End-Data-Warehouse-with-SQL/
│
├── README.md
│
├── data/
│   └── ...
│
├── docs/
│   └── images/
│       ├── architecture.png
│       ├── gold-layer-model.png
│       ├── customer-dashboard.png
│       ├── product-dashboard.png
│       ├── sales-dashboard.png
│       ├── geography-dashboard.png
│       ├── trends-dashboard.png
│       └── customers-at-risk.png
│
├── scripts/
│   │
│   ├── bronze/
│   │   └── ...
│   │
│   ├── silver/
│   │   └── ...
│   │
│   └── gold/
│       └── ...
│
├── ml/
│   │
│   ├── notebooks/
│   │   ├── ...
│   │
│   ├── model/
│   │   └── churn_model.joblib
│   │
│   └── src/
│       └── ...
│
├── report/powerbi/
│   ├── Customer_Analytics.pbix
│   └── screenshots/
│
└── requirements.txt
```

---

# 📌 Key Metrics

Some of the main business metrics implemented in Power BI include:

### Total Customers

```DAX
Total Customers =
DISTINCTCOUNT(dim_customers[customer_key])
```

### Total Sales

```DAX
Total Sales =
SUM(fact_sales[sales_amount])
```

### Total Orders

```DAX
Total Orders =
DISTINCTCOUNT(fact_sales[order_number])
```

### Average Order Value

```DAX
Average Order Value =
DIVIDE(
    [Total Sales],
    [Total Orders]
)
```

### Orders per Customer

```DAX
Orders per Customer =
DIVIDE(
    [Total Orders],
    [Total Customers]
)
```

Other DAX measures are used for:

* New Customers
* Repeat Customers
* Repeat Purchase Rate
* Customer growth
* Average customer age
* Gender distribution
* Geographic analysis
* Churn risk analysis

---

# Machine Learning — Customer Churn Prediction

The Gold layer also supports a customer churn prediction pipeline.

A Random Forest classifier was selected as the final model after comparing several classification algorithms, providing a good balance between predictive performance and execution efficiency.

### Final Model Performance

| Metric | Score |
|---|---:|
| Accuracy | 95% |
| ROC-AUC | 0.985 |
| Churn Precision | 84% |
| Churn Recall | 84% |
| Churn F1-score | 84% |

The model is used to:

- Predict the probability of customer churn.
- Classify customers into **Low**, **Medium**, and **High** risk tiers.
- Identify the main features associated with churn.
- Store predictions back in the Gold layer.

The final model scored **18,482 customers**, producing:

| Risk Tier | Customers |
|---|---:|
| Low | 13,130 |
| Medium | 3,877 |
| High | 1,475 |

The predictions are stored in:

```text
gold.customer_churn_predictions
---

# ⚙️ Setup and Installation

## 1. Clone the repository

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
cd End-to-End-Data-Warehouse-with-SQL
```

---

## 2. Create a Python virtual environment

```bash
python -m venv .venv
```

Activate it on Windows:

```bash
.venv\Scripts\activate
```

---

## 3. Install dependencies

```bash
pip install -r requirements.txt
```

Or:

```bash
pip install pandas numpy scikit-learn sqlalchemy pyodbc joblib xgboost matplotlib seaborn jupyter
```

---

# 🗄️ SQL Server Setup

The project uses SQL Server as the Data Warehouse.

Before running the scripts:

1. Install SQL Server.
2. Create the required database.
3. Create the Bronze, Silver, and Gold schemas.
4. Execute the SQL scripts in the correct order.

Recommended execution order:

```text
1. Database initialization
        ↓
2. Bronze tables
        ↓
3. Silver tables
        ↓
4. Gold dimensions
        ↓
5. Gold fact tables
        ↓
6. Date dimension
        ↓
7. Churn training/scoring tables
        ↓
8. Churn prediction tables
```

---

# 🤖 Running the Churn Pipeline

The churn workflow consists of three main stages.

### Step 1 — Build training data

The SQL procedure:

```sql
EXEC gold.build_churn_training_data;
```

creates the training dataset.

---

### Step 2 — Train the Machine Learning model

Run the Jupyter notebook:

```text
ml/notebooks/churn_model_training.ipynb
```

The notebook:

1. Loads the training data from SQL Server.
2. Preprocesses numerical and categorical features.
3. Splits the data.
4. Trains the classification model.
5. Evaluates the model.
6. Calculates feature importance.
7. Saves the trained model.

---

### Step 3 — Build scoring data

Run:

```sql
EXEC gold.build_churn_scoring_data;
```

This generates the current customer features used for prediction.

---

### Step 4 — Generate predictions

The Python pipeline:

```text
Load scoring data
       ↓
Apply preprocessing
       ↓
Load trained model
       ↓
Predict churn probability
       ↓
Assign risk tier
       ↓
Write predictions to SQL Server
```

The results are stored in:

```text
gold.customer_churn_predictions
```

---

# 🔌 Power BI Connection

Power BI connects directly to the SQL Server Gold layer.

The main analytical tables are:

```text
gold.dim_customers
gold.dim_products
gold.dim_dates
gold.fact_sales
```

The churn dashboard additionally uses:

```text
gold.customer_churn_predictions
gold.churn_feature_importance
```

This allows Power BI to display the latest Machine Learning predictions alongside business data.

---

# 🖼️ Screenshots

## Gold Layer Data Model

![Gold Layer Model](docs/images/gold-layer-model.png)

The Gold layer follows a dimensional model where:

* Customers describe customers
* Products describe products
* Dates describe time
* Sales contain transactional measures

---

## Customer Analytics

![Customer Dashboard](docs/images/customer-dashboard.png)

The Customer Analytics page provides insights into:

* Customer growth
* Customer demographics
* Customers by country
* Repeat purchases
* Customer behavior

---

## Product Analytics

![Product Dashboard](docs/images/product-dashboard.png)

The Product page analyzes:

* Sales by product
* Sales by product line
* Product categories
* Top-performing products

---

## Sales Analytics

![Sales Dashboard](docs/images/sales-dashboard.png)

The Sales page focuses on:

* Total sales
* Sales trends
* Sales by gender
* Sales by product line
* Order performance

---

## Geography

![Geography Dashboard](docs/images/geography-dashboard.png)

The Geography page provides a geographic view of customers and sales.

---

## Trends & Insights

![Trends Dashboard](docs/images/trends-dashboard.png)

The Trends page provides time-based analysis of customer and sales behavior.

---

## Customers at Risk

![Customers at Risk](docs/images/customers-at-risk.png)

The Customers at Risk dashboard combines Machine Learning predictions with business intelligence.

It helps identify:

* High-risk customers
* Medium-risk customers
* Low-risk customers
* Churn probability
* Geographic risk
* Risk factors
* Customers requiring retention actions

---

# 🔐 Data and Security

The repository should not contain:

* Database passwords
* Personal credentials
* Connection strings containing sensitive information
* API keys
* Private customer information

Database connection settings should be configured locally.

For example:

```python
SERVER = "YOUR_SERVER"
DATABASE = "YOUR_DATABASE"
```

Sensitive configuration files should be added to `.gitignore`.

---

# 🚀 Future Improvements

Potential improvements include:

### Data Engineering

* Automate ETL pipelines
* Add incremental loading to all Gold tables
* Add data quality checks
* Add orchestration with Apache Airflow
* Implement pipeline monitoring
* Add automated testing

### Machine Learning

* Hyperparameter tuning using GridSearchCV
* RandomizedSearchCV for larger parameter spaces
* Feature engineering
* Model explainability using SHAP
* Model versioning
* Automated model retraining
* Threshold optimization based on business costs

### Churn Analytics

* Historical prediction tracking
* Churn probability trends per customer
* Customer retention recommendations
* Automated alerts for high-risk customers
* Customer lifetime value prediction

### Power BI

* Automated dashboard refresh
* More advanced drill-through pages
* Customer-level drill-through
* Churn prediction monitoring
* Retention campaign tracking

---

# 💡 Key Learnings

This project provided practical experience with:

### Data Engineering

* Data Warehouse architecture
* ETL/ELT pipelines
* Layered data architecture
* Dimensional modeling
* Star Schema
* Surrogate keys
* Fact and dimension tables
* Date dimensions
* SQL Server

### Data Analytics

* SQL analytical queries
* DAX
* KPI design
* Time-series analysis
* Customer segmentation
* Geographic analysis

### Machine Learning

* Feature engineering
* Data preprocessing
* Classification
* Cross-validation
* Model evaluation
* Hyperparameter tuning
* Churn prediction
* Feature importance

### Business Intelligence

* Power BI data modeling
* Interactive dashboards
* Conditional formatting
* KPI cards
* Funnel analysis
* Geographic visualization
* Risk dashboards

---

# 🏁 Conclusion

This project demonstrates an end-to-end approach to building a modern analytical data platform.

The workflow combines:

```text
Data Engineering
       +
Data Warehousing
       +
Business Intelligence
       +
Machine Learning
       =
End-to-End Analytics Platform
```

The final solution transforms raw transactional data into actionable business insights and predictive customer intelligence.

The Machine Learning component extends traditional BI by allowing the business to identify customers who are potentially at risk of churn and prioritize them for proactive retention actions.

---

# 👩‍💻 Author

**Oumaima El Ghalbouni**

Data Engineering Student

Interested in:

* Data Engineering
* Data Science
* Machine Learning
* Big Data
* Business Intelligence

---

## ⭐ If you found this project interesting

Feel free to explore the repository and the different components of the data platform.

````
