# E-Commerce Sales Analysis (SQL Project)

## Overview
This project analyzes ~542,000 real transaction records from a UK-based online retailer using MySQL. Raw transactional data was cleaned, normalized into a relational schema, and analyzed using SQL to answer key business questions around revenue trends, customer behavior, and product performance.

**Dataset source:** [UK Online Retail Dataset (Kaggle)](https://www.kaggle.com/datasets/carrie1/ecommerce-data) — real transactions from Dec 2010 to Dec 2011.

## Tools Used
- MySQL 8.0 / MySQL Workbench
- SQL: Joins, CTEs, Window Functions (`LAG`, `NTILE`), Aggregations, Data Cleaning

## Database Design
The raw flat CSV (single table) was normalized into 4 relational tables to reflect proper database design:

| Table | Description |
|---|---|
| `Customers` | Unique customers with CustomerID (PK) and Country |
| `Products` | Unique products with StockCode (PK) and Description |
| `Orders` | One row per invoice, linked to a customer via CustomerID (FK) |
| `OrderDetails` | Line items per order — Quantity, UnitPrice, linked to Orders and Products via FKs |

**Data cleaning highlights:**
- Handled inconsistent `Country` values per customer by selecting the most representative value
- Removed non-product entries (e.g. "damaged", "mailout", adjustment notes) that were mixed into product descriptions in the raw data
- Converted text-based dates to proper `DATETIME` using `STR_TO_DATE()`
- Handled NULL `CustomerID` values (guest checkouts) without breaking foreign key constraints

## Business Questions Answered

1. **What is the monthly revenue trend?**
   Revenue peaked in November 2011 (₤1.46M), consistent with pre-holiday season buying.

2. **What are the top 10 products by revenue?**
   Identified best-selling products after filtering out non-product administrative entries.

3. **Who are the top customers by total spend?**
   Top customer contributed ₤279K — nearly double the next highest, suggesting a wholesale/business account.

4. **What is the month-over-month revenue growth rate?**
   Used a CTE + `LAG()` window function to calculate % growth, showing strong acceleration (+49%) heading into September–November.

5. **How do repeat customers compare to one-time customers?**
   Repeat customers (70% of the base) spend ~8x more on average (₤2,571 vs ₤330) than one-time buyers — a strong case for retention-focused strategy.

6. **How can customers be segmented using RFM analysis?**
   Segmented customers into Champions, Loyal Customers, At Risk, and Lost/Churned using `NTILE()` window functions across Recency, Frequency, and Monetary dimensions — 1,349 "Champion" customers were identified as the highest-value segment.

## Key Insights
- Revenue is highly seasonal, with a strong Q4 (Sep–Nov) peak
- A small number of high-spend customers contribute disproportionately to revenue
- Repeat customers are significantly more valuable than one-time buyers, reinforcing the importance of retention
- RFM segmentation surfaces actionable customer groups (e.g. "At Risk" customers worth a win-back campaign)

## Files
- `raw_sales` — staging table with imported raw CSV data
- SQL scripts for schema creation, data cleaning/normalization, and all business queries above

---
*Project by Balaji — built as part of Data Analyst portfolio development.*
