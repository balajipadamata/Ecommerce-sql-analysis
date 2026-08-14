create database ecommerce_project;
use ecommerce_project;
create table raw_salea(
InvoiceNo     VARCHAR(20),
    StockCode     VARCHAR(20),
    Description   VARCHAR(255),
    Quantity      INT,
    InvoiceDate   VARCHAR(30),
    UnitPrice     DECIMAL(10,2),
    CustomerID    INT null,
    Country       VARCHAR(50)
);
Alter table raw_salea 
modify CustomerID varchar(50);
describe raw_salea;
SHOW CREATE TABLE raw_salea;

INSERT INTO raw_salea
(InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country)
VALUES
('C536391', '85123A', 'WHITE HANGING HEART T-LIGHT HOLDER', 6,
 '12/1/2010 8:26', 2.55, '17850', 'United Kingdom');
 
 LOAD DATA LOCAL INFILE 'C:/Users/DELL/Downloads/data.csv'
INTO TABLE raw_sales
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(InvoiceNo, StockCode, Description, Quantity, InvoiceDate, @UnitPrice, @CustomerID, Country)
SET 
    UnitPrice = NULLIF(@UnitPrice, ''),
    CustomerID = NULLIF(@CustomerID, '');
    
    SET GLOBAL local_infile = 1;
    show tables
    
    LOAD DATA LOCAL INFILE 'C:/Users/DELL/Downloads/data.csv'
INTO TABLE raw_sales
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(InvoiceNo, StockCode, Description, Quantity, InvoiceDate, @UnitPrice, @CustomerID, Country)
SET 
    UnitPrice = NULLIF(@UnitPrice, ''),
    CustomerID = NULLIF(@CustomerID, '');
    RENAME TABLE raw_salea TO raw_sales;
    SHOW VARIABLES LIKE 'secure_file_priv';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/data.csv'
INTO TABLE raw_sales
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(InvoiceNo, StockCode, Description, Quantity, InvoiceDate, @UnitPrice, @CustomerID, Country)
SET
    UnitPrice = NULLIF(@UnitPrice, ''),
    CustomerID = NULLIF(@CustomerID, '');
    
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
    
    SELECT COUNT(*) FROM raw_sales;
    
    CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,
    Country VARCHAR(50)
);

INSERT INTO Customers (CustomerID, Country)
SELECT DISTINCT CustomerID, Country
FROM raw_sales
WHERE CustomerID IS NOT NULL;

INSERT INTO Customers (CustomerID, Country)
SELECT CustomerID, MAX(Country)
FROM raw_sales
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID;

SELECT COUNT(*) FROM Customers;
SELECT * FROM Customers LIMIT 10;

CREATE TABLE Products (
    StockCode VARCHAR(20) PRIMARY KEY,
    Description VARCHAR(255)
);

INSERT INTO Products (StockCode, Description)
SELECT StockCode, MAX(Description)
FROM raw_sales
WHERE StockCode IS NOT NULL
GROUP BY StockCode;

SELECT COUNT(*) FROM Products;
SELECT * FROM Products LIMIT 10;
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
select count(*) from orders

CREATE TABLE OrderDetails (
    OrderDetailID INT AUTO_INCREMENT PRIMARY KEY,
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Quantity INT,
    UnitPrice DECIMAL(10,2),
    FOREIGN KEY (InvoiceNo) REFERENCES Orders(InvoiceNo),
    FOREIGN KEY (StockCode) REFERENCES Products(StockCode)
);


TRUNCATE TABLE OrderDetails;
INSERT INTO OrderDetails (InvoiceNo, StockCode, Quantity, UnitPrice)
SELECT InvoiceNo, StockCode, Quantity, UnitPrice
FROM raw_sales;

SELECT COUNT(*) FROM OrderDetails;

SELECT 
    DATE_FORMAT(o.InvoiceDate, '%Y-%m') AS Month,
    ROUND(SUM(od.Quantity * od.UnitPrice), 2) AS Revenue
FROM Orders o
JOIN OrderDetails od ON o.InvoiceNo = od.InvoiceNo
GROUP BY Month
ORDER BY Month;

SELECT 
    p.Description,
    SUM(od.Quantity * od.UnitPrice) AS Revenue
FROM OrderDetails od
JOIN Products p ON od.StockCode = p.StockCode
GROUP BY p.Description
ORDER BY Revenue DESC
LIMIT 10;

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
SET FOREIGN_KEY_CHECKS = 0;

SET FOREIGN_KEY_CHECKS = 0;

SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE Products;

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

SET FOREIGN_KEY_CHECKS = 1;

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
