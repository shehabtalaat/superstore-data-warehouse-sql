-- CREAT DATABASE --

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'Central_Superstore')
BEGIN
    CREATE DATABASE Central_Superstore;
END
GO

USE Central_Superstore;
GO

-- CREAT SCHEMAS --

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC('CREATE SCHEMA bronze');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC('CREATE SCHEMA silver');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');
GO

-- ==============================================================================
--  Staging Table Creation --
-- ==============================================================================

IF NOT EXISTS (
    SELECT 1 
    FROM sys.tables t 
    JOIN sys.schemas s ON t.schema_id = s.schema_id 
    WHERE s.name = 'staging' AND t.name = 'Central_Superstore'
)
BEGIN
    CREATE TABLE staging.Central_Superstore (
        [Row ID]        NVARCHAR(255),
        [Order ID]      NVARCHAR(255),
        [Order Date]    NVARCHAR(255),
        [Ship Date]     NVARCHAR(255),
        [Ship Mode]     NVARCHAR(255),
        [Customer ID]   NVARCHAR(255),
        [Customer Name] NVARCHAR(255),
        [Segment]       NVARCHAR(255),
        [Country]       NVARCHAR(255),
        [City]          NVARCHAR(255),
        [State]         NVARCHAR(255),
        [Postal Code]   NVARCHAR(255),
        [Region]        NVARCHAR(255),
        [Product ID]    NVARCHAR(255),
        [Category]      NVARCHAR(255),
        [Sub-Category]  NVARCHAR(255),
        [Product Name]  NVARCHAR(255),
        [Sales]         NVARCHAR(255),
        [Quantity]      NVARCHAR(255),
        [Discount]      NVARCHAR(255),
        [Profit]        NVARCHAR(255)
    );
END
GO
SELECT * FROM staging.Central_Superstore;

-- Load Data 

TRUNCATE TABLE staging.Central_Superstore;

BULK INSERT staging.Central_Superstore
FROM 'C:\Users\Mega\SQL\Miniproject\Central_Superstore.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    MAXERRORS = 0,
    ERRORFILE = 'C:\Users\Mega\SQL\Miniproject\superstore_err.log',
    TABLOCK
);
GO

SELECT COUNT(*) AS Loaded_Rows FROM staging.Central_Superstore;
GO


-- ============================================================
-- BRONZE LAYER
-- ============================================================

IF NOT EXISTS (
    SELECT 1 
    FROM sys.tables t 
    JOIN sys.schemas s ON t.schema_id = s.schema_id 
    WHERE s.name = 'bronze' AND t.name = 'Central_Superstore'
)
BEGIN
    CREATE TABLE bronze.Central_Superstore (
        bronze_id       INT IDENTITY(1,1) PRIMARY KEY,
        [Row ID]        NVARCHAR(255),
        [Order ID]      NVARCHAR(255),
        [Order Date]    NVARCHAR(255),
        [Ship Date]     NVARCHAR(255),
        [Ship Mode]     NVARCHAR(255),
        [Customer ID]   NVARCHAR(255),
        [Customer Name] NVARCHAR(255),
        [Segment]       NVARCHAR(255),
        [Country]       NVARCHAR(255),
        [City]          NVARCHAR(255),
        [State]         NVARCHAR(255),
        [Postal Code]   NVARCHAR(255),
        [Region]        NVARCHAR(255),
        [Product ID]    NVARCHAR(255),
        [Category]      NVARCHAR(255),
        [Sub-Category]  NVARCHAR(255),
        [Product Name]  NVARCHAR(255),
        [Sales]         NVARCHAR(255),
        [Quantity]      NVARCHAR(255),
        [Discount]      NVARCHAR(255),
        [Profit]        NVARCHAR(255),
        ingested_at     DATETIME DEFAULT GETDATE()
    );
END
GO


INSERT INTO bronze.Central_Superstore (
    [Row ID], [Order ID], [Order Date], [Ship Date], [Ship Mode],
    [Customer ID], [Customer Name], [Segment], [Country], [City],
    [State], [Postal Code], [Region], [Product ID], [Category],
    [Sub-Category], [Product Name], [Sales], [Quantity], [Discount], [Profit]
)
SELECT 
    [Row ID], [Order ID], [Order Date], [Ship Date], [Ship Mode],
    [Customer ID], [Customer Name], [Segment], [Country], [City],
    [State], [Postal Code], [Region], [Product ID], [Category],
    [Sub-Category], [Product Name], [Sales], [Quantity], [Discount], [Profit]
FROM staging.Central_Superstore

EXCEPT

SELECT 
    [Row ID], [Order ID], [Order Date], [Ship Date], [Ship Mode],
    [Customer ID], [Customer Name], [Segment], [Country], [City],
    [State], [Postal Code], [Region], [Product ID], [Category],
    [Sub-Category], [Product Name], [Sales], [Quantity], [Discount], [Profit]
FROM bronze.Central_Superstore;
GO

---==============================================
SELECT * FROM bronze.Central_Superstore;

-- ============================================================
-- SILVER LAYER
-- ============================================================

IF NOT EXISTS (
    SELECT 1 FROM sys.tables t 
    JOIN sys.schemas s ON t.schema_id = s.schema_id 
    WHERE s.name = 'silver' AND t.name = 'Central_Superstore'
)
BEGIN
    CREATE TABLE silver.Central_Superstore (
        [Row ID]             INT NOT NULL,
        [Order ID]           NVARCHAR(50),
        [Order Date]         DATE,
        [Ship Date]          DATE,
        [Ship Mode]          NVARCHAR(50),
        [Customer ID]        NVARCHAR(50),
        [Customer Name]      NVARCHAR(150),
        [Segment]            NVARCHAR(50),
        [Country]            NVARCHAR(50),
        [City]               NVARCHAR(100),
        [State]              NVARCHAR(100),
        [Postal Code]        NVARCHAR(20),
        [Region]             NVARCHAR(50),
        [Product ID]         NVARCHAR(50),
        [Category]           NVARCHAR(50),
        [Sub-Category]       NVARCHAR(50),
        [Product Name]       NVARCHAR(255),
        [Sales]              DECIMAL(10, 2),
        [Quantity]           INT,
        [Discount]           DECIMAL(5, 2),
        [Profit]             DECIMAL(10, 4),
        has_missing_value    BIT NOT NULL DEFAULT 0,
        has_invalid_value    BIT NOT NULL DEFAULT 0,
        has_outlier_value    BIT NOT NULL DEFAULT 0,
        silver_updated_at    DATETIME DEFAULT GETDATE(),
        CONSTRAINT PK_silver_Central_Superstore PRIMARY KEY ([Row ID])
    );
END;
GO


;WITH superstore_latest AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY [Row ID] ORDER BY bronze_id DESC) AS rn
    FROM bronze.Central_Superstore
    WHERE NULLIF(LTRIM(RTRIM([Row ID])), '') IS NOT NULL
),
superstore_cleaned AS (
    SELECT 
        TRY_CAST(LTRIM(RTRIM([Row ID])) AS INT) AS [Row ID],
        NULLIF(LTRIM(RTRIM([Order ID])), '') AS [Order ID],
        
        TRY_CAST(NULLIF(LTRIM(RTRIM([Order Date])), '') AS DATE) AS [Order Date],
        NULLIF(LTRIM(RTRIM([Order Date])), '') AS raw_order_date,
        
        TRY_CAST(NULLIF(LTRIM(RTRIM([Ship Date])), '') AS DATE) AS [Ship Date],
        NULLIF(LTRIM(RTRIM([Ship Date])), '') AS raw_ship_date,
        
        NULLIF(LTRIM(RTRIM([Ship Mode])), '') AS [Ship Mode],
        NULLIF(LTRIM(RTRIM([Customer ID])), '') AS [Customer ID],
        NULLIF(LTRIM(RTRIM([Customer Name])), '') AS [Customer Name],
        NULLIF(LTRIM(RTRIM([Segment])), '') AS [Segment],
        NULLIF(LTRIM(RTRIM([Country])), '') AS [Country],
        NULLIF(LTRIM(RTRIM([City])), '') AS [City],
        NULLIF(LTRIM(RTRIM([State])), '') AS [State],
        NULLIF(LTRIM(RTRIM([Postal Code])), '') AS [Postal Code],
        NULLIF(LTRIM(RTRIM([Region])), '') AS [Region],
        NULLIF(LTRIM(RTRIM([Product ID])), '') AS [Product ID],
        NULLIF(LTRIM(RTRIM([Category])), '') AS [Category],
        NULLIF(LTRIM(RTRIM([Sub-Category])), '') AS [Sub-Category],
        NULLIF(LTRIM(RTRIM([Product Name])), '') AS [Product Name],
        
        TRY_CAST(NULLIF(LTRIM(RTRIM([Sales])), '') AS DECIMAL(10, 2)) AS [Sales],
        NULLIF(LTRIM(RTRIM([Sales])), '') AS raw_sales,
        
        TRY_CAST(NULLIF(LTRIM(RTRIM([Quantity])), '') AS INT) AS [Quantity],
        NULLIF(LTRIM(RTRIM([Quantity])), '') AS raw_quantity,
        
        TRY_CAST(NULLIF(LTRIM(RTRIM([Discount])), '') AS DECIMAL(5, 2)) AS [Discount],
        NULLIF(LTRIM(RTRIM([Discount])), '') AS raw_discount,
        
        TRY_CAST(
            NULLIF(
                REPLACE(REPLACE(LTRIM(RTRIM([Profit])), CHAR(13), ''), CHAR(10), ''), 
            '') 
        AS DECIMAL(10, 4)) AS [Profit],
        NULLIF(REPLACE(REPLACE(LTRIM(RTRIM([Profit])), CHAR(13), ''), CHAR(10), ''), '') AS raw_profit
    FROM superstore_latest
    WHERE rn = 1
),
superstore_flagged AS (
    SELECT 
        [Row ID], [Order ID], [Order Date], [Ship Date], [Ship Mode],
        [Customer ID], [Customer Name], [Segment], [Country], [City],
        [State], [Postal Code], [Region], [Product ID], [Category],
        [Sub-Category], [Product Name], [Sales], [Quantity], [Discount], [Profit],
        
        CASE 
            WHEN [Row ID] IS NULL
              OR [Order ID] IS NULL
              OR [Order Date] IS NULL
              OR [Customer ID] IS NULL
              OR [Product ID] IS NULL
              OR [Sales] IS NULL
              OR [Quantity] IS NULL
              OR [Profit] IS NULL
            THEN 1 ELSE 0 
        END AS has_missing_value,
        
        CASE 
            WHEN (raw_order_date IS NOT NULL AND [Order Date] IS NULL)
              OR (raw_ship_date IS NOT NULL AND [Ship Date] IS NULL)
              OR (raw_sales IS NOT NULL AND [Sales] IS NULL)
              OR (raw_quantity IS NOT NULL AND [Quantity] IS NULL)
              OR (raw_discount IS NOT NULL AND [Discount] IS NULL)
              OR (raw_profit IS NOT NULL AND [Profit] IS NULL)
              OR ([Ship Date] < [Order Date])
              OR ([Discount] < 0 OR [Discount] > 1)
            THEN 1 ELSE 0 
        END AS has_invalid_value,
        
        CASE 
            WHEN [Sales] > 500
              OR [Quantity] > 10
              OR [Profit] > 70
              OR [Profit] < -40
            THEN 1 ELSE 0 
        END AS has_outlier_value
    FROM superstore_cleaned
    WHERE [Row ID] IS NOT NULL
)
MERGE silver.Central_Superstore AS tgt
USING superstore_flagged AS src
ON tgt.[Row ID] = src.[Row ID]

WHEN MATCHED THEN
    UPDATE SET
        tgt.[Order ID]          = src.[Order ID],
        tgt.[Order Date]        = src.[Order Date],
        tgt.[Ship Date]         = src.[Ship Date],
        tgt.[Ship Mode]         = src.[Ship Mode],
        tgt.[Customer ID]       = src.[Customer ID],
        tgt.[Customer Name]     = src.[Customer Name],
        tgt.[Segment]           = src.[Segment],
        tgt.[Country]           = src.[Country],
        tgt.[City]              = src.[City],
        tgt.[State]             = src.[State],
        tgt.[Postal Code]       = src.[Postal Code],
        tgt.[Region]            = src.[Region],
        tgt.[Product ID]        = src.[Product ID],
        tgt.[Category]          = src.[Category],
        tgt.[Sub-Category]      = src.[Sub-Category],
        tgt.[Product Name]      = src.[Product Name],
        tgt.[Sales]             = src.[Sales],
        tgt.[Quantity]          = src.[Quantity],
        tgt.[Discount]          = src.[Discount],
        tgt.[Profit]            = src.[Profit],
        tgt.has_missing_value   = src.has_missing_value,
        tgt.has_invalid_value   = src.has_invalid_value,
        tgt.has_outlier_value   = src.has_outlier_value,
        tgt.silver_updated_at   = GETDATE()

WHEN NOT MATCHED THEN
    INSERT (
        [Row ID], [Order ID], [Order Date], [Ship Date], [Ship Mode],
        [Customer ID], [Customer Name], [Segment], [Country], [City],
        [State], [Postal Code], [Region], [Product ID], [Category],
        [Sub-Category], [Product Name], [Sales], [Quantity], [Discount], [Profit],
        has_missing_value, has_invalid_value, has_outlier_value, silver_updated_at
    )
    VALUES (
        src.[Row ID], src.[Order ID], src.[Order Date], src.[Ship Date], src.[Ship Mode],
        src.[Customer ID], src.[Customer Name], src.[Segment], src.[Country], src.[City],
        src.[State], src.[Postal Code], src.[Region], src.[Product ID], src.[Category],
        src.[Sub-Category], src.[Product Name], src.[Sales], src.[Quantity], src.[Discount], src.[Profit],
        src.has_missing_value, src.has_invalid_value, src.has_outlier_value, GETDATE()
    );
GO


SELECT 
    COUNT(*) AS total_rows,
    SUM(CAST(has_missing_value AS INT)) AS missing_count,
    SUM(CAST(has_invalid_value AS INT)) AS invalid_count,
    SUM(CAST(has_outlier_value AS INT)) AS outlier_count,
    ROUND(100.0 * SUM(CASE WHEN has_missing_value = 0 AND has_invalid_value = 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS clean_data_percentage
FROM silver.Central_Superstore;

SELECT 
    [Row ID], [Customer Name], [Product Name], [Sales], [Quantity], [Profit]
FROM silver.Central_Superstore
WHERE has_outlier_value = 1;

---=============================================

SELECT * FROM Silver.Central_Superstore;

--==== IQR ====--
WITH Percentiles AS (
    SELECT DISTINCT
        -- Sales
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Sales) OVER () AS sales_q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Sales) OVER () AS sales_q3,
        
        -- Quantity
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Quantity) OVER () AS qty_q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Quantity) OVER () AS qty_q3,
        
        -- Profit
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Profit) OVER () AS profit_q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Profit) OVER () AS profit_q3
    FROM silver.Central_Superstore
)
SELECT 
    'Sales' AS metric,
    sales_q1 AS Q1,
    sales_q3 AS Q3,
    (sales_q3 - sales_q1) AS IQR,
    (sales_q1 - 1.5 * (sales_q3 - sales_q1)) AS Lower_Bound,
    (sales_q3 + 1.5 * (sales_q3 - sales_q1)) AS Upper_Bound
FROM Percentiles

UNION ALL

SELECT 
    'Quantity',
    qty_q1, qty_q3,
    (qty_q3 - qty_q1),
    (qty_q1 - 1.5 * (qty_q3 - qty_q1)),
    (qty_q3 + 1.5 * (qty_q3 - qty_q1))
FROM Percentiles

UNION ALL

SELECT 
    'Profit',
    profit_q1, profit_q3,
    (profit_q3 - profit_q1),
    (profit_q1 - 1.5 * (profit_q3 - profit_q1)),
    (profit_q3 + 1.5 * (profit_q3 - profit_q1))
FROM Percentiles;


-- Compare num with outlire & without outlire

SELECT 
    COUNT(*) AS total_transactions,
    SUM(Sales) AS total_sales,
    AVG(Sales) AS avg_order_value,
    SUM(Profit) AS total_profit,
    
    SUM(CASE WHEN has_outlier_value = 0 THEN Sales ELSE 0 END) AS adjusted_sales,
    AVG(CASE WHEN has_outlier_value = 0 THEN Sales ELSE NULL END) AS adjusted_avg_order_value,
    SUM(CASE WHEN has_outlier_value = 0 THEN Profit ELSE 0 END) AS adjusted_profit
FROM silver.Central_Superstore;


-- ============================================================
--  Gold Layer
-- ============================================================
--- Star Schema Design:
/*


   dim_customer          dim_product          dim_geography          dim_date
             \                    |                     |                   /
              \                   |                     |                  /
               -----------------> fact_sales <---------------------------

- Architecture: Kimball Star Schema Design
- Fact Table:   gold.fact_sales (Grain = One row per order line item)
- Dimensions:   gold.dim_customer, gold.dim_product, gold.dim_geography, gold.dim_date
================================================================================
*/

---- Creat Tables to Star Schema ----

-- 1 ===== gold.dim_customer

IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'gold' AND t.name = 'dim_customer')
BEGIN
    CREATE TABLE gold.dim_customer (
        customer_key    INT IDENTITY(1,1) NOT NULL,
        customer_id     NVARCHAR(50)      NOT NULL,
        customer_name   NVARCHAR(150),
        segment         NVARCHAR(50),
        CONSTRAINT PK_gold_dim_customer PRIMARY KEY (customer_key),
        CONSTRAINT UQ_gold_dim_customer_id UNIQUE (customer_id)
    );
END;
GO

-- Unknown (-1)
SET IDENTITY_INSERT gold.dim_customer ON;
IF NOT EXISTS (SELECT 1 FROM gold.dim_customer WHERE customer_key = -1)
BEGIN
    INSERT INTO gold.dim_customer (customer_key, customer_id, customer_name, segment)
    VALUES (-1, 'UNKNOWN', 'Unknown Customer', 'Unknown');
END;
SET IDENTITY_INSERT gold.dim_customer OFF;
GO

;WITH ranked_customers AS (
    SELECT 
        [Customer ID]   AS customer_id,
        [Customer Name] AS customer_name,
        [Segment]       AS segment,
        ROW_NUMBER() OVER (
            PARTITION BY [Customer ID] 
            ORDER BY [Order Date] DESC, [Row ID] DESC
        ) AS rn
    FROM silver.Central_Superstore
    WHERE [Customer ID] IS NOT NULL
)
MERGE gold.dim_customer AS tgt
USING (SELECT customer_id, customer_name, segment FROM ranked_customers WHERE rn = 1) AS src
ON tgt.customer_id = src.customer_id
WHEN MATCHED THEN
    UPDATE SET 
        tgt.customer_name = src.customer_name,
        tgt.segment       = src.segment
WHEN NOT MATCHED THEN
    INSERT (customer_id, customer_name, segment)
    VALUES (src.customer_id, src.customer_name, src.segment);
GO


-- 2 ===== gold.dim_product

IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'gold' AND t.name = 'dim_product')
BEGIN
    CREATE TABLE gold.dim_product (
        product_key     INT IDENTITY(1,1) NOT NULL,
        product_id      NVARCHAR(50)      NOT NULL,
        product_name    NVARCHAR(255),
        category        NVARCHAR(50),
        sub_category    NVARCHAR(50),
        CONSTRAINT PK_gold_dim_product PRIMARY KEY (product_key),
        CONSTRAINT UQ_gold_dim_product_id UNIQUE (product_id)
    );
END;
GO

-- Unknown (-1) 
SET IDENTITY_INSERT gold.dim_product ON;
IF NOT EXISTS (SELECT 1 FROM gold.dim_product WHERE product_key = -1)
BEGIN
    INSERT INTO gold.dim_product (product_key, product_id, product_name, category, sub_category)
    VALUES (-1, 'UNKNOWN', 'Unknown Product', 'Unknown', 'Unknown');
END;
SET IDENTITY_INSERT gold.dim_product OFF;
GO

;WITH ranked_products AS (
    SELECT 
        [Product ID]   AS product_id,
        [Product Name] AS product_name,
        [Category]     AS category,
        [Sub-Category] AS sub_category,
        ROW_NUMBER() OVER (
            PARTITION BY [Product ID] 
            ORDER BY [Order Date] DESC, [Row ID] DESC
        ) AS rn
    FROM silver.Central_Superstore
    WHERE [Product ID] IS NOT NULL
)
MERGE gold.dim_product AS tgt
USING (SELECT product_id, product_name, category, sub_category FROM ranked_products WHERE rn = 1) AS src
ON tgt.product_id = src.product_id
WHEN MATCHED THEN
    UPDATE SET 
        tgt.product_name = src.product_name,
        tgt.category     = src.category,
        tgt.sub_category = src.sub_category
WHEN NOT MATCHED THEN
    INSERT (product_id, product_name, category, sub_category)
    VALUES (src.product_id, src.product_name, src.category, src.sub_category);
GO


-- 3  ===== gold.dim_geography

IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'gold' AND t.name = 'dim_geography')
BEGIN
    CREATE TABLE gold.dim_geography (
        geography_key   INT IDENTITY(1,1) NOT NULL,
        country         NVARCHAR(50),
        city            NVARCHAR(100),
        state           NVARCHAR(100),
        postal_code     NVARCHAR(20),
        region          NVARCHAR(50),
        CONSTRAINT PK_gold_dim_geography PRIMARY KEY (geography_key)
    );
END;
GO

-- Unknown (-1)
SET IDENTITY_INSERT gold.dim_geography ON;
IF NOT EXISTS (SELECT 1 FROM gold.dim_geography WHERE geography_key = -1)
BEGIN
    INSERT INTO gold.dim_geography (geography_key, country, city, state, postal_code, region)
    VALUES (-1, 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown');
END;
SET IDENTITY_INSERT gold.dim_geography OFF;
GO

;WITH unique_geo AS (
    SELECT DISTINCT
        ISNULL(Country, 'Unknown')     AS country,
        ISNULL(City, 'Unknown')        AS city,
        ISNULL(State, 'Unknown')       AS state,
        ISNULL([Postal Code], 'Unknown') AS postal_code,
        ISNULL(Region, 'Unknown')      AS region
    FROM silver.Central_Superstore
)
INSERT INTO gold.dim_geography (country, city, state, postal_code, region)
SELECT u.country, u.city, u.state, u.postal_code, u.region
FROM unique_geo u
WHERE NOT EXISTS (
    SELECT 1 FROM gold.dim_geography g
    WHERE g.country     = u.country
      AND g.city        = u.city
      AND g.state       = u.state
      AND g.postal_code = u.postal_code
      AND g.region      = u.region
);
GO


-- 4 ===== gold.dim_date

IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'gold' AND t.name = 'dim_date')
BEGIN
    CREATE TABLE gold.dim_date (
        date_key     INT NOT NULL,
        full_date    DATE NOT NULL,
        [year]       INT NOT NULL,
        [quarter]    TINYINT NOT NULL,
        [month]      TINYINT NOT NULL,
        month_name   NVARCHAR(20) NOT NULL,
        [day]        TINYINT NOT NULL,
        day_of_week  NVARCHAR(20) NOT NULL,
        is_weekend   BIT NOT NULL,
        CONSTRAINT PK_gold_dim_date PRIMARY KEY (date_key)
    );
END;
GO

-- Unknown (-1) 
IF NOT EXISTS (SELECT 1 FROM gold.dim_date WHERE date_key = -1)
BEGIN
    INSERT INTO gold.dim_date (date_key, full_date, [year], [quarter], [month], month_name, [day], day_of_week, is_weekend)
    VALUES (-1, '1900-01-01', 1900, 0, 0, 'Unknown', 0, 'Unknown', 0);
END;
GO

--(2010 - 2030)
DECLARE @StartDate DATE = '2010-01-01';
DECLARE @EndDate   DATE = '2030-12-31';

;WITH DateGenerator AS (
    SELECT @StartDate AS CurrentDate
    UNION ALL
    SELECT DATEADD(DAY, 1, CurrentDate)
    FROM DateGenerator
    WHERE CurrentDate < @EndDate
)
INSERT INTO gold.dim_date (
    date_key, full_date, [year], [quarter], [month], month_name, [day], day_of_week, is_weekend
)
SELECT 
    CAST(CONVERT(VARCHAR(8), CurrentDate, 112) AS INT),
    CurrentDate,
    YEAR(CurrentDate),
    DATEPART(QUARTER, CurrentDate),
    MONTH(CurrentDate),
    DATENAME(MONTH, CurrentDate),
    DAY(CurrentDate),
    DATENAME(WEEKDAY, CurrentDate),
    CASE WHEN DATEPART(WEEKDAY, CurrentDate) IN (1, 7) THEN 1 ELSE 0 END
FROM DateGenerator
WHERE NOT EXISTS (
    SELECT 1 FROM gold.dim_date WHERE date_key = CAST(CONVERT(VARCHAR(8), CurrentDate, 112) AS INT)
)
OPTION (MAXRECURSION 0);
GO


-- 5 ===== gold.fact_sales

IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'gold' AND t.name = 'fact_sales')
BEGIN
    CREATE TABLE gold.fact_sales (
        sales_key           INT IDENTITY(1,1) NOT NULL,
        row_id              INT NOT NULL,              
        order_id            NVARCHAR(50) NOT NULL,
        order_date_key      INT NOT NULL,
        ship_date_key       INT NOT NULL,
        customer_key        INT NOT NULL,
        product_key         INT NOT NULL,
        geography_key       INT NOT NULL,
        ship_mode           NVARCHAR(50),
        sales               DECIMAL(10, 2),
        quantity            INT,
        discount            DECIMAL(5, 2),
        profit              DECIMAL(10, 4),
        has_outlier_value   BIT NOT NULL DEFAULT 0,
        gold_created_at     DATETIME DEFAULT GETDATE(),

        CONSTRAINT PK_gold_fact_sales PRIMARY KEY (sales_key),
        CONSTRAINT FK_fact_order_date FOREIGN KEY (order_date_key) REFERENCES gold.dim_date(date_key),
        CONSTRAINT FK_fact_ship_date  FOREIGN KEY (ship_date_key)  REFERENCES gold.dim_date(date_key),
        CONSTRAINT FK_fact_customer   FOREIGN KEY (customer_key)   REFERENCES gold.dim_customer(customer_key),
        CONSTRAINT FK_fact_product    FOREIGN KEY (product_key)    REFERENCES gold.dim_product(product_key),
        CONSTRAINT FK_fact_geography  FOREIGN KEY (geography_key)  REFERENCES gold.dim_geography(geography_key)
    );
END;
GO

INSERT INTO gold.fact_sales (
    row_id,
    order_id,
    order_date_key,
    ship_date_key,
    customer_key,
    product_key,
    geography_key,
    ship_mode,
    sales,
    quantity,
    discount,
    profit,
    has_outlier_value
)
SELECT 
    s.[Row ID] AS row_id,
    ISNULL(s.[Order ID], 'UNKNOWN') AS order_id,
    
    --- define order_date_key and ship_date_key, using -1 for unknown dates
    ISNULL(CAST(CONVERT(VARCHAR(8), s.[Order Date], 112) AS INT), -1) AS order_date_key, 
    ISNULL(CAST(CONVERT(VARCHAR(8), s.[Ship Date], 112) AS INT), -1) AS ship_date_key,
    
    -- Unknown (-1)

    ISNULL(c.customer_key, -1) AS customer_key,
   
    ISNULL(p.product_key, -1) AS product_key,
 
    ISNULL(g.geography_key, -1) AS geography_key,
    
    s.[Ship Mode] AS ship_mode,
    s.[Sales] AS sales,
    s.[Quantity] AS quantity,
    s.[Discount] AS discount,
    s.[Profit] AS profit,
    s.has_outlier_value
FROM silver.Central_Superstore s
LEFT JOIN gold.dim_customer c 
    ON s.[Customer ID] = c.customer_id
LEFT JOIN gold.dim_product p 
    ON s.[Product ID] = p.product_id
LEFT JOIN gold.dim_geography g 
    ON ISNULL(s.Country, 'Unknown')     = g.country
   AND ISNULL(s.City, 'Unknown')        = g.city
   AND ISNULL(s.State, 'Unknown')       = g.state
   AND ISNULL(s.[Postal Code], 'Unknown') = g.postal_code
   AND ISNULL(s.Region, 'Unknown')      = g.region
WHERE NOT EXISTS (
    SELECT 1 FROM gold.fact_sales f WHERE f.row_id = s.[Row ID]
);
GO

--- =====================================================

-- Rows of Tables in Gold Layer

SELECT 'dim_customer'  AS table_name, COUNT(*) AS total_rows FROM gold.dim_customer
UNION ALL
SELECT 'dim_product',   COUNT(*) FROM gold.dim_product
UNION ALL
SELECT 'dim_geography', COUNT(*) FROM gold.dim_geography
UNION ALL
SELECT 'dim_date',      COUNT(*) FROM gold.dim_date
UNION ALL
SELECT 'fact_sales',    COUNT(*) FROM gold.fact_sales;

-- Compare Silver & Gold Layer

SELECT 
    'Silver' AS layer,
    ROUND(SUM(Sales), 2)  AS total_sales,
    SUM(Quantity)         AS total_quantity,
    ROUND(SUM(Profit), 2) AS total_profit
FROM silver.Central_Superstore

UNION ALL

SELECT 
    'Gold',
    ROUND(SUM(sales), 2),
    SUM(quantity),
    ROUND(SUM(profit), 2)
FROM gold.fact_sales;

/*
================================================================================
                    STRATEGIC BUSINESS ANALYTICS FRAMEWORK
================================================================================

-- TEN Quations to Analysis

1. PROFITABILITY & PRICING ANALYSIS:
   -----------------------------------------------------------------------------
   - Q1 (Executive KPIs):
     What are the store's high-level financial KPIs (Total Revenue, Total Net 
     Profit, Overall Profit Margin %, and Unique Order Count)?
     --> Target Implementation: SQL View [gold.vw_store_executive_kpis]

   - Q2 (Sub-Category Bleeders):
     Which product sub-categories are operating at a net negative profit, 
     and what is their negative profit margin relative to their revenue?

   - Q3 (Discount Threshold Impact):
     How do aggressive discount brackets (No Discount, Moderate <= 20%, Deep > 20%) 
     erode gross profit margin percentages using conditional logic?

   - Q4 (Bottom 5 Value Destroyers):
     What are the top 5 worst-performing individual products by total financial 
     loss that require immediate repricing or decommissioning?


2. CUSTOMER BEHAVIOR & SEGMENTATION:
   -----------------------------------------------------------------------------
   - Q5 (Top VIP Contributors):
     Who are the top 10 customers by total spending, what is their individual 
     share of total profit, and what is their ranking using analytical window functions?

   - Q6 (Segment Economics):
     What is the Average Order Value (AOV), total order frequency, and average 
     item volume across customer segments (Consumer, Corporate, Home Office)?

   - Q7 (Unprofitable Customer Footprint):
     Which customers have generated transactions that yield net negative profit 
     across their order history (implemented via correlated subqueries)?

   - Q8 (Value Tiering):
     How can our customer base be categorized into spending tiers (Tier A: High Value, 
     Tier B: Mid Value, Tier C: Low Value) using CTEs and conditional logic?


3. SALES TRENDS & GEOGRAPHIC DYNAMICS:
   -----------------------------------------------------------------------------
   - Q9 (MoM Growth & Seasonality):
     What is the Month-over-Month (MoM) revenue growth trajectory across calendar 
     years using temporal dimension joins and offset window functions?

   - Q10 (State Performance & Fulfillment SLA):
     What are the total revenue, net profitability, and average shipping 
     duration (lead time in days) by state/region?
     --> Target Implementation: Parameterized Stored Procedure [gold.usp_get_state_performance]

================================================================================
*/


-- =============================================================================
-- Special Item 1: Executive KPIs View
-- Answers Question 1: Executive KPIs (Total Revenue, Total Net Profit, Overall Profit Margin %, Unique Order Count)
-- Business Value & Insight: Provides executive leadership with a high-level macroeconomic dashboard to evaluate overall financial health, top-line scale, and consolidated profitability margins without transactional noise.
-- =============================================================================
CREATE OR ALTER VIEW gold.vw_store_executive_kpis AS
SELECT 
    ROUND(SUM(sales), 2)  AS total_revenue,
    ROUND(SUM(profit), 2) AS total_net_profit,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(sales), 0), 2) AS overall_profit_margin_pct,
    COUNT(DISTINCT order_id) AS total_orders
FROM gold.fact_sales
WHERE customer_key <> -1;
GO

SELECT * FROM gold.vw_store_executive_kpis;


-- =============================================================================
-- Special Item 2: State Performance & Fulfillment SLA (Stored Procedure)
-- Answers Question 10: State Performance & Fulfillment SLA (Total revenue, net profitability, average shipping duration by state/region)
-- Business Value & Insight: Serves as a parameterized operational reporting tool to benchmark state-level commercial yield against supply chain lead times, exposing fulfillment bottlenecks across specific territories.
-- =============================================================================
CREATE OR ALTER PROCEDURE gold.usp_get_state_performance
    @StateName NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        g.state,
        COUNT(DISTINCT f.order_id) AS total_orders,
        ROUND(SUM(f.sales), 2)     AS total_sales,
        ROUND(SUM(f.profit), 2)    AS total_profit,
        ROUND(100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0), 2) AS profit_margin_pct,
        AVG(DATEDIFF(DAY, od.full_date, sd.full_date)) AS avg_shipping_days
    FROM gold.fact_sales f
    JOIN gold.dim_geography g ON f.geography_key = g.geography_key
    JOIN gold.dim_date od    ON f.order_date_key = od.date_key
    JOIN gold.dim_date sd    ON f.ship_date_key  = sd.date_key
    WHERE f.geography_key <> -1
      AND (@StateName IS NULL OR g.state = @StateName)
    GROUP BY g.state
    ORDER BY total_sales DESC;
END;
GO

EXEC gold.usp_get_state_performance;
EXEC gold.usp_get_state_performance @StateName = 'Texas';

-- Quaries for Business Analytics Framework --
-- 1: PROFITABILITY & PRICING ANALYSIS:
-- =============================================================================
-- Query 1
-- Answers Question 2: Sub-Category Bleeders (Sub-categories operating at net negative profit and their negative profit margin)
-- Business Value & Insight: Isolates structurally unprofitable product lines (such as Tables or Bookcases) to halt capital erosion, review vendor cost models, and adjust baseline catalog pricing.
-- =============================================================================
SELECT 
    p.category,
    p.sub_category,
    COUNT(DISTINCT f.order_id)                             AS total_orders,
    ROUND(SUM(f.sales), 2)                                 AS total_revenue,
    ROUND(SUM(f.profit), 2)                                AS total_profit,
    ROUND(100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0), 2)  AS profit_margin_pct
FROM gold.fact_sales f
JOIN gold.dim_product p ON f.product_key = p.product_key
WHERE f.product_key <> -1
GROUP BY p.category, p.sub_category
ORDER BY total_profit ASC;


-- =============================================================================
-- Query 2
-- Answers Question 3: Discount Threshold Impact (How aggressive discount brackets erode gross profit margin percentages)
-- Business Value & Insight: Empirically establishes commercial discount guardrails by proving that promotions exceeding 20% severely cannibalize margins and drive net losses regardless of transaction volume.
-- =============================================================================
SELECT 
    CASE 
        WHEN f.discount = 0.00 THEN 'No Discount (0%)'
        WHEN f.discount <= 0.20 THEN 'Low-Moderate Discount (1% - 20%)'
        ELSE 'Deep Discount (> 20%)'
    END AS discount_tier,
    COUNT(*)                                                   AS transaction_count,
    ROUND(SUM(f.sales), 2)                                     AS total_revenue,
    ROUND(SUM(f.profit), 2)                                    AS total_profit,
    ROUND(100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0), 2)  AS profit_margin_pct
FROM gold.fact_sales f
WHERE f.customer_key <> -1
GROUP BY 
    CASE 
        WHEN f.discount = 0.00 THEN 'No Discount (0%)'
        WHEN f.discount <= 0.20 THEN 'Low-Moderate Discount (1% - 20%)'
        ELSE 'Deep Discount (> 20%)'
    END
ORDER BY profit_margin_pct DESC;


-- =============================================================================
-- Query 3
-- Answers Question 4: Bottom 5 Value Destroyers (Top 5 worst-performing individual products by total financial loss)
-- Business Value & Insight: Flags the top 5 worst individual capital-destroying SKUs to execute immediate commercial interventions, including discount termination, supplier renegotiation, or catalog decommissioning.
-- =============================================================================
WITH product_financials AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category,
        p.sub_category,
        ROUND(SUM(f.sales), 2)  AS total_sales,
        ROUND(SUM(f.profit), 2) AS total_loss,
        DENSE_RANK() OVER (ORDER BY SUM(f.profit) ASC) AS loss_rank
    FROM gold.fact_sales f
    JOIN gold.dim_product p ON f.product_key = p.product_key
    WHERE f.product_key <> -1
    GROUP BY p.product_id, p.product_name, p.category, p.sub_category
)
SELECT 
    loss_rank,
    product_id,
    product_name,
    category,
    sub_category,
    total_sales,
    total_loss
FROM product_financials
WHERE loss_rank <= 5
ORDER BY loss_rank ASC;


-- =============================================================================
-- Query 4
-- Business Value & Insight: Audits severe negative outlier transactions exceeding the historical loss benchmark to uncover predatory order discounting and address localized pricing compliance failures.
-- =============================================================================
SELECT 
    f.order_id,
    p.product_name,
    c.customer_name,
    f.sales,
    f.discount,
    f.profit
FROM gold.fact_sales f
JOIN gold.dim_product p  ON f.product_key = p.product_key
JOIN gold.dim_customer c ON f.customer_key = c.customer_key
WHERE f.profit < (
    SELECT AVG(profit)
    FROM gold.fact_sales
    WHERE profit < 0
)
ORDER BY f.profit ASC;


-- =============================================================================
-- Query 5
-- Business Value & Insight: Evaluates macro category dynamics using automated rule-based diagnostics to differentiate primary cash cows from margin-diluting categories, guiding capital and marketing reallocation.
-- =============================================================================
SELECT 
    p.category,
    ROUND(SUM(f.sales), 2)                                     AS total_sales,
    ROUND(SUM(f.profit), 2)                                    AS net_profit,
    ROUND(100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0), 2)  AS profit_margin_pct,
    ROUND(AVG(f.discount) * 100, 1)                            AS avg_discount_pct,
    CASE 
        WHEN SUM(f.profit) < 0 
            THEN 'Severe Margin Bleed (Net Loss Overall)'
        WHEN ROUND(100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0), 2) < 5.0 
            THEN 'Heavy Discount Erosion (Low Margin < 5%)'
        ELSE 'Healthy Baseline Margins'
    END AS primary_cause_of_weakness,
    CASE 
        WHEN ROUND(100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0), 2) < 5.0 
            THEN 'Cap Max Discounts to 10% & Re-index Pricing'
        ELSE 'Core Cash Cow: Scale Sales Volume Aggressively'
    END AS strategic_profit_lever
FROM gold.fact_sales f
JOIN gold.dim_product p ON f.product_key = p.product_key
WHERE f.product_key <> -1
GROUP BY p.category
ORDER BY net_profit DESC;

-- 2: CUSTOMER BEHAVIOR & SEGMENTATION:
-- =============================================================================
-- Query 6
-- Answers Question 6: Segment Economics (Average Order Value, total order frequency, and average item volume across customer segments)
-- Business Value & Insight: Benchmarks unit economics (AOV, transaction velocity, margin retention) across market sectors to identify segments over-reliant on promotional subsidies.
-- =============================================================================

SELECT 
    c.segment,
    COUNT(DISTINCT c.customer_key) AS total_customers,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.quantity) AS total_units_sold,
    ROUND(SUM(f.sales), 2) AS total_revenue,
    ROUND(SUM(f.profit), 2) AS total_profit,
    ROUND(100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0), 2) AS profit_margin_pct,
    -- Average Order Value (AOV)
    ROUND(SUM(f.sales) / NULLIF(COUNT(DISTINCT f.order_id), 0), 2) AS avg_order_value,
    -- Average Item Volume (AIV) - متوسط عدد القطع لكل أوردر
    ROUND(CAST(SUM(f.quantity) AS FLOAT) / NULLIF(COUNT(DISTINCT f.order_id), 0), 2) AS avg_item_volume_per_order
FROM gold.fact_sales f
JOIN gold.dim_customer c ON f.customer_key = c.customer_key
WHERE f.customer_key <> -1
GROUP BY c.segment
ORDER BY total_revenue DESC;



-- =============================================================================
-- Query 7.0
-- Answers Question 5: Top VIP Contributors (Top 10 customers by total spending, share of total profit, and ranking using window functions)
-- Business Value & Insight: Ranks the top revenue-contributing accounts per segment via analytical window functions to safeguard essential high-yield client relationships and prevent enterprise churn.
-- =============================================================================
WITH customer_segment_metrics AS (
    SELECT 
        c.segment,
        c.customer_id,
        c.customer_name,
        COUNT(DISTINCT f.order_id)                             AS orders_count,
        ROUND(SUM(f.sales), 2)                                 AS total_spend,
        ROUND(SUM(f.profit), 2)                                AS total_profit,
        ROUND(100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0), 2) AS profit_margin_pct,
        ROUND(AVG(f.discount) * 100, 2)                        AS avg_discount_received,
        DENSE_RANK() OVER (
            PARTITION BY c.segment 
            ORDER BY SUM(f.sales) DESC
        ) AS rank_in_segment
    FROM gold.fact_sales f
    JOIN gold.dim_customer c ON f.customer_key = c.customer_key
    WHERE f.customer_key <> -1
    GROUP BY c.segment, c.customer_id, c.customer_name
)
SELECT 
    segment,
    rank_in_segment,
    customer_id,
    customer_name,
    orders_count,
    total_spend,
    total_profit,
    profit_margin_pct,
    avg_discount_received
FROM customer_segment_metrics
WHERE rank_in_segment <= 10
ORDER BY total_spend DESC;

-- Query 7.1
-- Top 10 Customers by Total Spend Across All Segments

WITH total_store_metrics AS (
    SELECT SUM(sales) AS store_total_sales, SUM(profit) AS store_total_profit
    FROM gold.fact_sales
    WHERE customer_key <> -1
),
customer_aggregates AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        c.segment,
        COUNT(DISTINCT f.order_id) AS total_orders,
        SUM(f.quantity) AS total_units,
        ROUND(SUM(f.sales), 2) AS total_spend,
        ROUND(SUM(f.profit), 2) AS total_profit,
        ROUND(100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0), 2) AS profit_margin_pct,
        DENSE_RANK() OVER (ORDER BY SUM(f.sales) DESC) AS store_spend_rank
    FROM gold.fact_sales f
    JOIN gold.dim_customer c ON f.customer_key = c.customer_key
    WHERE f.customer_key <> -1
    GROUP BY c.customer_id, c.customer_name, c.segment
)
SELECT 
    ca.store_spend_rank,
    ca.customer_id,
    ca.customer_name,
    ca.segment,
    ca.total_orders,
    ca.total_units,
    ca.total_spend,
    ca.total_profit,
    ca.profit_margin_pct,
    ROUND(100.0 * ca.total_spend / ts.store_total_sales, 2) AS store_sales_share_pct
FROM customer_aggregates ca
CROSS JOIN total_store_metrics ts
WHERE ca.store_spend_rank <= 10
ORDER BY ca.store_spend_rank ASC;

-- =============================================================================
-- Query 8
-- Answers Question 7: Unprofitable Customer Footprint (Customers generating net negative profit across order history)
-- Business Value & Insight: Detects structurally toxic accounts running cumulative net negative lifetime profits, enabling the business to revoke promotional discounts and protect gross margins.
-- =============================================================================
SELECT 
    c.customer_id,
    c.customer_name,
    c.segment,
    COUNT(DISTINCT f.order_id)                                 AS orders_placed,
    ROUND(SUM(f.sales), 2)                                     AS total_spent,
    ROUND(SUM(f.profit), 2)                                    AS total_net_loss,
    ROUND(AVG(f.discount) * 100, 2)                            AS avg_discount_received
FROM gold.fact_sales f
JOIN gold.dim_customer c ON f.customer_key = c.customer_key
WHERE f.customer_key <> -1
GROUP BY c.customer_id, c.customer_name, c.segment
HAVING SUM(f.profit) < 0
ORDER BY total_net_loss ASC;


-- =============================================================================
-- Query 9
-- Answers Question 8: Value Tiering (Categorizing customer base into spending tiers Tier A, Tier B, Tier C using CTEs and conditional logic)
-- Business Value & Insight: Segments the customer portfolio into monetary value tiers to quantify revenue concentration, optimize retention resources, and align acquisition CAC with customer value.
-- =============================================================================
WITH customer_spending AS (
    SELECT 
        c.customer_key,
        c.customer_name,
        ROUND(SUM(f.sales), 2)  AS total_spend,
        ROUND(SUM(f.profit), 2) AS total_profit
    FROM gold.fact_sales f
    JOIN gold.dim_customer c ON f.customer_key = c.customer_key
    WHERE f.customer_key <> -1
    GROUP BY c.customer_key, c.customer_name
),
tiered_customers AS (
    SELECT 
        customer_key,
        customer_name,
        total_spend,
        total_profit,
        CASE 
            WHEN total_spend >= 3000 THEN 'Tier A: High-Value (>= $3k)'
            WHEN total_spend >= 1000 THEN 'Tier B: Mid-Value ($1k - $3k)'
            ELSE 'Tier C: Low-Value (< $1k)'
        END AS customer_tier
    FROM customer_spending
)
SELECT 
    customer_tier,
    COUNT(*)                                                   AS customer_count,
    ROUND(SUM(total_spend), 2)                                 AS tier_total_revenue,
    ROUND(SUM(total_profit), 2)                                AS tier_total_profit,
    ROUND(100.0 * SUM(total_profit) / NULLIF(SUM(total_spend), 0), 2) AS tier_margin_pct
FROM tiered_customers
GROUP BY customer_tier
ORDER BY tier_total_revenue DESC;


-- =============================================================================
-- Query 10
-- Business Value & Insight: Assesses purchase velocity and buyer retention while isolating extreme bulk purchase behavior (10+ orders) to evaluate sustainable lifetime loyalty versus single-order churn.
-- =============================================================================
WITH customer_order_summary AS (
    SELECT 
        c.customer_key,
        COUNT(DISTINCT f.order_id) AS orders_count,
        SUM(f.sales)               AS total_sales,
        SUM(f.profit)              AS total_profit
    FROM gold.fact_sales f
    JOIN gold.dim_customer c ON f.customer_key = c.customer_key
    WHERE f.customer_key <> -1
    GROUP BY c.customer_key
)
SELECT 
    CASE 
        WHEN orders_count = 1 THEN '1. One-Time Buyer (1 Order)'
        WHEN orders_count BETWEEN 2 AND 4 THEN '2. Repeat Buyer (2-4 Orders)'
        WHEN orders_count BETWEEN 5 AND 9 THEN '3. Frequent Buyer (5-9 Orders)'
        ELSE '4. Frequency Outlier / Extreme Bulk (10+ Orders)'
    END AS customer_loyalty_segment,
    COUNT(*)                                                   AS total_customers,
    ROUND(SUM(total_sales), 2)                                 AS segment_total_sales,
    ROUND(SUM(total_profit), 2)                                AS segment_total_profit,
    ROUND(100.0 * SUM(total_profit) / NULLIF(SUM(total_sales), 0), 2) AS segment_margin_pct
FROM customer_order_summary
GROUP BY 
    CASE 
        WHEN orders_count = 1 THEN '1. One-Time Buyer (1 Order)'
        WHEN orders_count BETWEEN 2 AND 4 THEN '2. Repeat Buyer (2-4 Orders)'
        WHEN orders_count BETWEEN 5 AND 9 THEN '3. Frequent Buyer (5-9 Orders)'
        ELSE '4. Frequency Outlier / Extreme Bulk (10+ Orders)'
    END
ORDER BY segment_total_sales DESC;

-- 3: SALES TRENDS & GEOGRAPHIC DYNAMICS:
-- =============================================================================
-- Query 11
-- Business Value & Insight: Pinpoints the top 10 net profit-generating items alongside physical unit movement to ensure inventory continuity for primary margin contributors.
-- =============================================================================
WITH product_profit_ranking AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category,
        p.sub_category,
        COUNT(DISTINCT f.order_id)                             AS total_orders,
        SUM(f.quantity)                                        AS total_units_sold,
        ROUND(SUM(f.sales), 2)                                 AS total_revenue,
        ROUND(SUM(f.profit), 2)                                AS total_profit,
        ROUND(100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0), 2) AS profit_margin_pct,
        ROUND(AVG(f.discount) * 100, 2)                        AS avg_discount_pct,
        DENSE_RANK() OVER (ORDER BY SUM(f.profit) DESC)        AS profit_rank
    FROM gold.fact_sales f
    JOIN gold.dim_product p ON f.product_key = p.product_key
    WHERE f.product_key <> -1
    GROUP BY p.product_id, p.product_name, p.category, p.sub_category
)
SELECT 
    profit_rank,
    product_name,
    category,
    sub_category,
    total_orders,
    total_units_sold,
    total_revenue,
    total_profit,
    profit_margin_pct,
    avg_discount_pct
FROM product_profit_ranking
WHERE profit_rank <= 10
ORDER BY profit_rank ASC;


-- =============================================================================
-- Query 12
-- Business Value & Insight: Highlights the top 10 capital destroyer SKUs alongside discount rates to differentiate between structural manufacturing/vendor deficits and self-inflicted promotional price degradation.
-- =============================================================================
WITH loss_products AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category,
        p.sub_category,
        ROUND(SUM(f.sales), 2)                                 AS total_sales,
        ROUND(SUM(f.profit), 2)                                AS total_loss,
        ROUND(AVG(f.discount) * 100, 2)                        AS avg_discount_pct,
        DENSE_RANK() OVER (ORDER BY SUM(f.profit) ASC)         AS loss_rank
    FROM gold.fact_sales f
    JOIN gold.dim_product p ON f.product_key = p.product_key
    WHERE f.product_key <> -1
    GROUP BY p.product_id, p.product_name, p.category, p.sub_category
)
SELECT 
    loss_rank,
    product_name,
    category,
    sub_category,
    total_sales,
    total_loss,
    avg_discount_pct
FROM loss_products
WHERE loss_rank <= 10
ORDER BY loss_rank ASC;


-- =============================================================================
-- Query 13.0
-- Answers Question 9: MoM Growth & Seasonality (Month-over-Month revenue growth trajectory and seasonality rankings)
-- Business Value & Insight: Identifies annual revenue and profit seasonality cycles to support financial forecasting, marketing campaign timing, and operational inventory build-up.
-- =============================================================================
SELECT 
    d.year,
    d.quarter,
    d.month_name,
    d.month,
    ROUND(SUM(f.sales), 2)                                     AS total_sales,
    ROUND(SUM(f.profit), 2)                                    AS total_profit,
    ROUND(100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0), 2)  AS profit_margin_pct,
    DENSE_RANK() OVER (
        PARTITION BY d.year 
        ORDER BY SUM(f.profit) DESC
    ) AS monthly_profit_rank_within_year
FROM gold.fact_sales f
JOIN gold.dim_date d ON f.order_date_key = d.date_key
WHERE f.order_date_key <> -1
GROUP BY d.year, d.quarter, d.month_name, d.month
ORDER BY d.year ASC, total_sales DESC;

-- =============================================================================
-- Query 13.1: Multi-Year Macro Performance & Best Quarter Analysis
-- Answers Question 9: Multi-Year Growth & Seasonality Trajectory
-- Business Value & Insight: Benchmarks four-year macro commercial growth across total revenue, net profitability, order volume, and average order value (AOV), while dynamically identifying the peak revenue-generating quarter for each calendar year.
-- =============================================================================
WITH quarterly_breakdown AS (
    SELECT 
        d.year,
        d.quarter,
        SUM(f.sales) AS quarter_sales,
        DENSE_RANK() OVER (
            PARTITION BY d.year 
            ORDER BY SUM(f.sales) DESC
        ) AS quarter_rank
    FROM gold.fact_sales f
    JOIN gold.dim_date d ON f.order_date_key = d.date_key
    WHERE f.order_date_key <> -1
    GROUP BY d.year, d.quarter
),
best_quarter_per_year AS (
    SELECT 
        year,
        quarter AS best_performing_quarter
    FROM quarterly_breakdown
    WHERE quarter_rank = 1
),
yearly_aggregations AS (
    SELECT 
        d.year,
        COUNT(DISTINCT f.order_id)                             AS total_orders,
        SUM(f.quantity)                                        AS total_units_sold,
        ROUND(SUM(f.sales), 2)                                 AS total_revenue,
        ROUND(SUM(f.profit), 2)                                AS total_profit,
        ROUND(100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0), 2)  AS profit_margin_pct,
        ROUND(SUM(f.sales) / NULLIF(COUNT(DISTINCT f.order_id), 0), 2) AS avg_order_value,
        ROUND(SUM(f.profit) / NULLIF(COUNT(DISTINCT f.order_id), 0), 2) AS avg_profit_per_order
    FROM gold.fact_sales f
    JOIN gold.dim_date d ON f.order_date_key = d.date_key
    WHERE f.order_date_key <> -1
    GROUP BY d.year
)
SELECT 
    y.year,
    y.total_orders,
    y.total_units_sold,
    y.total_revenue,
    y.total_profit,
    y.profit_margin_pct,
    y.avg_order_value,
    y.avg_profit_per_order,
    b.best_performing_quarter
FROM yearly_aggregations y
JOIN best_quarter_per_year b ON y.year = b.year
ORDER BY total_revenue DESC;


-- =============================================================================
-- Query 14
-- Business Value & Insight: Benchmarks shipping mode efficiency against customer SLA fulfillment, confirming whether accelerated delivery options dilute profitability relative to standard fulfillment channels.
-- =============================================================================
SELECT 
    f.ship_mode,
    COUNT(DISTINCT f.order_id)                                 AS total_orders,
    ROUND(SUM(f.sales), 2)                                     AS total_sales,
    ROUND(SUM(f.profit), 2)                                    AS total_profit,
    ROUND(100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0), 2)  AS profit_margin_pct,
    AVG(DATEDIFF(DAY, od.full_date, sd.full_date))             AS avg_shipping_days,
    MAX(DATEDIFF(DAY, od.full_date, sd.full_date))             AS max_shipping_days
FROM gold.fact_sales f
JOIN gold.dim_date od ON f.order_date_key = od.date_key
JOIN gold.dim_date sd ON f.ship_date_key  = sd.date_key
WHERE f.order_date_key <> -1 AND f.ship_date_key <> -1
GROUP BY f.ship_mode
ORDER BY total_orders DESC;


-- =============================================================================
-- Query 15
-- Answers Question 9: MoM Growth Trajectory (Month-over-Month Growth with LAG across Multiple Years)
-- Business Value & Insight: Tracks monthly revenue progression and percentage growth velocity across multiple target years, pinpointing acceleration phases and seasonal slowdowns using offset window functions.
-- =============================================================================
WITH monthly_sales AS (
    SELECT 
        d.year,
        d.month,
        d.month_name,
        ROUND(SUM(f.sales), 2)  AS monthly_sales,
        ROUND(SUM(f.profit), 2) AS monthly_profit
    FROM gold.fact_sales f
    JOIN gold.dim_date d ON f.order_date_key = d.date_key
    WHERE f.order_date_key <> -1
      AND d.year IN (2013) -- one or more of (2013 | 2014 | 2015 | 2016 )
    GROUP BY d.year, d.month, d.month_name
),
mom_calculation AS (
    SELECT 
        year,
        month,
        month_name,
        monthly_sales,
        monthly_profit,
        LAG(monthly_sales, 1) OVER (ORDER BY year ASC, month ASC) AS prev_month_sales
    FROM monthly_sales
)
SELECT 
    year,
    month,
    month_name,
    monthly_sales,
    prev_month_sales,
    ROUND(monthly_sales - prev_month_sales, 2) AS mom_sales_change,
    ROUND(100.0 * (monthly_sales - prev_month_sales) / NULLIF(prev_month_sales, 0), 2) AS mom_growth_pct,
    monthly_profit
FROM mom_calculation
ORDER BY year ASC, month ASC;
