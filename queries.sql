-- ============================================================
-- E-Commerce Sales Analysis
-- Dataset: UK Online Retail Dataset (Kaggle) - 541,909 transactions
-- Author: Balaji
-- ============================================================


-- ============================================================
-- SECTION 1: DATABASE & STAGING TABLE SETUP
-- ============================================================

CREATE DATABASE IF NOT EXISTS ecommerce_project;
USE ecommerce_project;

-- Staging table matching the raw CSV structure
CREATE TABLE raw_sales (
    InvoiceNo     VARCHAR(20),
    StockCode     VARCHAR(20),
    Description   VARCHAR(255),
    Quantity      INT,
    InvoiceDate   VARCHAR(30),
    UnitPrice     DECIMAL(10,2),
    CustomerID    INT,
    Country       VARCHAR(50)
);

-- Bulk load the CSV (encoding set to latin1 to handle special characters)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/data.csv'
INTO TABLE raw_sales
CHARACTER SET latin1
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(InvoiceNo, StockCode, Description, Quantity, InvoiceDate, @UnitPrice, @CustomerID, Country)
SET
    UnitPrice = NULLIF(@UnitPrice, ''),
    CustomerID = NULLIF(@CustomerID, '');

SELECT COUNT(*) AS total_rows_loaded FROM raw_sales;  -- Expect 541,909


-- ============================================================
-- SECTION 2: NORMALIZED SCHEMA (Customers, Products, Orders, OrderDetails)
-- ============================================================

-- --- Customers ---
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,
    Country VARCHAR(50)
);

-- Some customers have inconsistent Country values across rows; MAX() picks one consistently
INSERT INTO Customers (CustomerID, Country)
SELECT CustomerID, MAX(Country)
FROM raw_sales
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID;

-- --- Products ---
CREATE TABLE Products (
    StockCode VARCHAR(20) PRIMARY KEY,
    Description VARCHAR(255)
);

-- Picks the MOST FREQUENTLY used description per StockCode, filtering out
-- rare junk entries (e.g. "damaged", "mailout") that appear as stray Description values
INSERT INTO Products (StockCode, Description)
SELECT StockCode, Description
FROM (
    SELECT
        StockCode,
        Description,
        ROW_NUMBER() OVER (PARTITION BY StockCode ORDER BY COUNT(*) DESC) AS rn
    FROM raw_sales
    WHERE StockCode IS NOT NULL AND Description IS NOT NULL
    GROUP BY StockCode, Description
) ranked
WHERE rn = 1;

-- --- Orders ---
CREATE TABLE Orders (
    InvoiceNo VARCHAR(20) PRIMARY KEY,
    CustomerID INT,
    InvoiceDate DATETIME,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

INSERT INTO Orders (InvoiceNo, CustomerID, InvoiceDate)
SELECT InvoiceNo, MAX(CustomerID), STR_TO_DATE(MAX(InvoiceDate), '%m/%d/%Y %H:%i')
FROM raw_sales
GROUP BY InvoiceNo;

-- --- OrderDetails ---
CREATE TABLE OrderDetails (
    OrderDetailID INT AUTO_INCREMENT PRIMARY KEY,
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Quantity INT,
    UnitPrice DECIMAL(10,2),
    FOREIGN KEY (InvoiceNo) REFERENCES Orders(InvoiceNo),
    FOREIGN KEY (StockCode) REFERENCES Products(StockCode)
);

INSERT INTO OrderDetails (InvoiceNo, StockCode, Quantity, UnitPrice)
SELECT InvoiceNo, StockCode, Quantity, UnitPrice
FROM raw_sales;

-- Sanity checks
SELECT COUNT(*) AS customers_count FROM Customers;      -- ~4,372
SELECT COUNT(*) AS products_count  FROM Products;        -- ~3,958
SELECT COUNT(*) AS orders_count    FROM Orders;           -- ~25,900
SELECT COUNT(*) AS orderdetails_count FROM OrderDetails;  -- ~541,909


-- ============================================================
-- SECTION 3: BUSINESS ANALYSIS QUERIES
-- ============================================================

-- Q1: Monthly Revenue Trend
SELECT
    DATE_FORMAT(o.InvoiceDate, '%Y-%m') AS Month,
    ROUND(SUM(od.Quantity * od.UnitPrice), 2) AS Revenue
FROM Orders o
JOIN OrderDetails od ON o.InvoiceNo = od.InvoiceNo
GROUP BY Month
ORDER BY Month;


-- Q2: Top 10 Products by Revenue
-- (Excludes non-product admin codes like postage/bank charges/manual adjustments)
SELECT
    p.StockCode,
    p.Description,
    SUM(od.Quantity * od.UnitPrice) AS Revenue
FROM OrderDetails od
JOIN Products p ON od.StockCode = p.StockCode
WHERE p.StockCode NOT IN ('POST', 'D', 'M', 'BANK CHARGES', 'DOT', 'CRUK', 'AMAZONFEE', 'S', 'C2')
  AND od.Quantity > 0
GROUP BY p.StockCode, p.Description
ORDER BY Revenue DESC
LIMIT 10;


-- Q3: Top 10 Customers by Total Spend
SELECT
    c.CustomerID,
    c.Country,
    ROUND(SUM(od.Quantity * od.UnitPrice), 2) AS TotalSpend
FROM Customers c
JOIN Orders o ON c.CustomerID = o.CustomerID
JOIN OrderDetails od ON o.InvoiceNo = od.InvoiceNo
GROUP BY c.CustomerID, c.Country
ORDER BY TotalSpend DESC
LIMIT 10;


-- Q4: Month-over-Month Revenue Growth % (CTE + LAG window function)
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(o.InvoiceDate, '%Y-%m') AS Month,
        SUM(od.Quantity * od.UnitPrice) AS Revenue
    FROM Orders o
    JOIN OrderDetails od ON o.InvoiceNo = od.InvoiceNo
    GROUP BY Month
)
SELECT
    Month,
    Revenue,
    ROUND(
        (Revenue - LAG(Revenue) OVER (ORDER BY Month))
        / LAG(Revenue) OVER (ORDER BY Month) * 100, 2
    ) AS GrowthPercent
FROM monthly_revenue
ORDER BY Month;


-- Q5: Repeat vs One-Time Customers
SELECT
    CASE
        WHEN OrderCount = 1 THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END AS CustomerType,
    COUNT(*) AS NumberOfCustomers,
    ROUND(AVG(TotalSpend), 2) AS AvgSpendPerCustomer
FROM (
    SELECT
        c.CustomerID,
        COUNT(DISTINCT o.InvoiceNo) AS OrderCount,
        SUM(od.Quantity * od.UnitPrice) AS TotalSpend
    FROM Customers c
    JOIN Orders o ON c.CustomerID = o.CustomerID
    JOIN OrderDetails od ON o.InvoiceNo = od.InvoiceNo
    GROUP BY c.CustomerID
) customer_summary
GROUP BY CustomerType;


-- Q6: RFM Segmentation (Recency, Frequency, Monetary)
-- Segments customers into Champions / Loyal / At Risk / Lost using NTILE() quartiles
WITH rfm_base AS (
    SELECT
        c.CustomerID,
        DATEDIFF((SELECT MAX(InvoiceDate) FROM Orders), MAX(o.InvoiceDate)) AS Recency,
        COUNT(DISTINCT o.InvoiceNo) AS Frequency,
        SUM(od.Quantity * od.UnitPrice) AS Monetary
    FROM Customers c
    JOIN Orders o ON c.CustomerID = o.CustomerID
    JOIN OrderDetails od ON o.InvoiceNo = od.InvoiceNo
    GROUP BY c.CustomerID
),
rfm_scores AS (
    SELECT
        CustomerID,
        Recency,
        Frequency,
        Monetary,
        NTILE(4) OVER (ORDER BY Recency DESC) AS R_Score,
        NTILE(4) OVER (ORDER BY Frequency ASC) AS F_Score,
        NTILE(4) OVER (ORDER BY Monetary ASC) AS M_Score
    FROM rfm_base
)
SELECT
    CASE
        WHEN R_Score >= 3 AND F_Score >= 3 AND M_Score >= 3 THEN 'Champions'
        WHEN R_Score >= 3 AND F_Score >= 2 THEN 'Loyal Customers'
        WHEN R_Score <= 2 AND F_Score >= 3 THEN 'At Risk'
        WHEN R_Score <= 2 AND F_Score <= 2 THEN 'Lost/Churned'
        ELSE 'Others'
    END AS Segment,
    COUNT(*) AS NumberOfCustomers,
    ROUND(AVG(Monetary), 2) AS AvgSpend
FROM rfm_scores
GROUP BY Segment
ORDER BY AvgSpend DESC;
