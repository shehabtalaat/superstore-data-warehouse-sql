# superstore-data-warehouse-sql
Enterprise Medallion Data Warehouse (Staging ➔ Bronze ➔ Silver ➔ Gold) &amp; Dimensional Star Schema in SQL Server for Retail Performance, Margin Leakage, and Customer Economics.
# 🏛️ Enterprise Retail Data Warehouse & Dimensional Analytics (T-SQL)

An end-to-end Enterprise Data Warehouse implementation for the **Central Superstore** dataset built in **Microsoft SQL Server (T-SQL)**. The project follows the **Medallion Architecture (Staging ➔ Bronze ➔ Silver ➔ Gold)** and implements a **Kimball Star Schema** to evaluate commercial yield, margin erosion, and customer lifetime value.

---

## 🏗️ Architectural Framework: The Medallion Paradigm

The warehouse moves data systematically across four governed layers:

1. **Staging Layer (`staging.Central_Superstore`):**
   - High-throughput raw landing zone via `BULK INSERT` with UTF-8 (`CODEPAGE = '65001'`).
   - All columns ingested as unconstrained strings (`NVARCHAR(255)`) to eliminate ingestion failures.
2. **Bronze Layer (`bronze.Central_Superstore`):**
   - Immutable historical record retaining source fidelity.
   - Enriched with audit columns (`bronze_id` identity and `ingested_at` timestamp).
   - Deduplicated using set-based `EXCEPT` operations against staging.
3. **Silver Layer (`silver.Central_Superstore`):**
   - Quality-governed layer applying a **"Flag-not-Drop"** framework (`has_missing_value`, `has_invalid_value`, `has_outlier_value`).
   - Deduplication via `ROW_NUMBER()` window functions over `[Row ID]`.
   - String sanitization (stripping `CHAR(13)` and `CHAR(10)` line breaks), type casting with `TRY_CAST`, and outlier bounds calculated via IQR percentiles (`PERCENTILE_CONT`).
4. **Gold Layer (`gold.*`):**
   - Analytics-ready, high-performance dimensional dimensional layer implementing the **Kimball Star Schema**.

---

## 🌟 Dimensional Modeling (Kimball Star Schema)

```text
       [dim_customer]       [dim_product]       [dim_geography]       [dim_date]
              \                   |                    |                  /
               \                  |                    |                 /
                ----------------> [fact_sales] <------------------------
Fact Table: gold.fact_sales (Grain: One row per order line item).Dimension Tables:gold.dim_customer: Customer natural keys, demographics, and segments.gold.dim_product: Granular SKU hierarchies (category, sub_category, product_name).gold.dim_geography: Geographic delivery footprint (country, state, city, postal_code, region).gold.dim_date: Role-playing calendar dimension (2010–2030) joined on order_date_key and ship_date_key for lead-time analytics.Unknown Member Pattern: Every dimension includes an artificial member (key = -1, 'Unknown') to prevent transaction drop during inner joins on orphaned natural keys.📊 Executive & Strategic FindingsMetric / DimensionInsight / Data PointBusiness ActionStore Executive KPIs$501,239.88 Total Revenue | $39,706.45 Net Profit | 7.92% Net Margin | 1,175 OrdersBaseline performance monitoring via gold.vw_store_executive_kpis.Discounting ImpactNo Discount: +33.58% Margin | Deep Discount (>20%): -7.98% Net Loss (-$22.8k)Enforce hard discount caps at 20% to immediately halt structural losses.Bleeding Sub-CategoriesTables (-$3,607 loss, -9.2% margin) and Bookcases (-$1,997 loss, -8.3% margin)Immediate repricing, supplier renegotiation, or catalog decommissioning.Customer SegmentsHome Office (14.1% margin) & Corporate (11.5% margin) outperform Consumer (3.4% margin)Shift sales incentives toward higher-margin B2B customer tiers.VIP ConcentrationTop 10 VIP accounts generate 14.8% of total store revenueAllocate dedicated account management to prevent enterprise churn.Geographic ExtremesMichigan: +$24,463 profit (32% margin) | Texas: -$25,729 loss (high volume, deeply unprofitable)Parameterized auditing via gold.usp_get_state_performance.🛠️️ Advanced T-SQL Capabilities ImplementedStored Procedures: gold.usp_get_state_performance (parameterized state SLA fulfillment & profit reporting).Views: gold.vw_store_executive_kpis (macro executive health dashboard).Analytical Window Functions: DENSE_RANK(), ROW_NUMBER(), LAG(), and PERCENTILE_CONT().ETL / Merge Operations: Declarative MERGE statements with WHEN MATCHED and WHEN NOT MATCHED logic.Common Table Expressions (CTEs): Multi-layered CTE pipelines for modular data transformations and MoM growth trajectories.👤 AuthorShehab Talaat IsmailRole: Data Analyst
