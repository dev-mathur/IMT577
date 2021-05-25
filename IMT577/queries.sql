-- ====================================
-- Create DimDate table
-- ====================================

IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'DimDate')
BEGIN
	DROP TABLE dbo.DimDate;
END
GO

CREATE TABLE dbo.DimDate
(
DimDateID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY,
FullDate [date] NOT NULL,
DayNumberOfWeek [tinyint] NOT NULL,
DayNameOfWeek [varchar] (9) NOT NULL,
DayNumberOfMonth [tinyint] NOT NULL,
DayNumberOfYear [int] NOT NULL,
WeekdayFlag [int] NOT NULL,
WeekNumberOfYear [tinyint] NOT NULL,
[MonthName] [varchar](9) NOT NULL,
MonthNumberOfYear [tinyint] NOT NULL,
CalendarQuarter [tinyint] NOT NULL,
CalendarYear [int] NOT NULL,
CalendarSemester [tinyint] NOT NULL,
CreatedDate DATETIME NOT NULL
,CreatedBy NVARCHAR(255) NOT NULL
,ModifiedDate DATETIME NULL
,ModifiedBy NVARCHAR(255) NULL
);
GO

-- =========================================================================
-- Create Stored Proceudre InsDimDateyearly to load one year of data
-- =========================================================================

IF EXISTS (SELECT name FROM sys.procedures WHERE name = 'InsDimDateYearly')
BEGIN
	DROP PROCEDURE dbo.InsDimDateYearly;
END
GO

CREATE PROC [dbo].[InsDimDateYearly]
( 
	@Year INT=NULL
)
AS
SET NOCOUNT ON;

DECLARE @Date DATE, @FirstDate Date, @LastDate Date;

SELECT @Year=COALESCE(@Year,YEAR(DATEADD(d,1,MAX(DimDateID)))) FROM dbo.DimDate;

SET @FirstDate=DATEFROMPARTS(COALESCE(@Year,YEAR(GETDATE())-1), 01, 01); -- First Day of the Year
SET @LastDate=DATEFROMPARTS(COALESCE(@Year,YEAR(GETDATE())-1), 12, 31); -- Last Day of the Year

SET @Date=@FirstDate;
-- create CTE with all dates needed for load
;WITH DateCTE AS
(
SELECT @FirstDate AS StartDate -- earliest date to load in table
UNION ALL
SELECT DATEADD(day, 1, StartDate)
FROM DateCTE -- recursively select the date + 1 over and over
WHERE DATEADD(day, 1, StartDate) <= @LastDate -- last date to load in table
)

-- load date dimension table with all dates
INSERT INTO dbo.DimDate 
	(
	FullDate 
	,DayNumberOfWeek 
	,DayNameOfWeek 
	,DayNumberOfMonth 
	,DayNumberOfYear 
	,WeekdayFlag
	,WeekNumberOfYear 
	,[MonthName] 
	,MonthNumberOfYear 
	,CalendarQuarter 
	,CalendarYear 
	,CalendarSemester
	,CreatedDate
	,CreatedBy
	,ModifiedDate
	,ModifiedBy 
	)
SELECT 
	 CAST(StartDate AS DATE) AS FullDate
	,DATEPART(dw, StartDate) AS DayNumberOfWeek
	,DATENAME(dw, StartDate) AS DayNameOfWeek
	,DAY(StartDate) AS DayNumberOfMonth
	,DATEPART(dy, StartDate) AS DayNumberOfYear
	,CASE DATENAME(dw, StartDate) WHEN 'Saturday' THEN 0 WHEN 'Sunday' THEN 0 ELSE 1 END AS WeekdayFlag
	,DATEPART(wk, StartDate) AS WeekNumberOfYear
	,DATENAME(mm, StartDate) AS [MonthName]
	,MONTH(StartDate) AS MonthNumberOfYear
	,DATEPART(qq, StartDate) AS CalendarQuarter
	,YEAR(StartDate) AS CalendarYear
	,(CASE WHEN MONTH(StartDate)>=1 AND MONTH(StartDate) <=6 THEN 1 ELSE 2 END) AS CalendarSemester
	,DATEADD(dd,DATEDIFF(dd,GETDATE(), '2013-01-01'),GETDATE()) AS CreatedDate
	,'company\SQLServerServiceAccount' AS CreatedBy
	,NULL AS ModifiedDate
	,NULL AS ModifiedBy
FROM DateCTE
OPTION (MAXRECURSION 0);
GO

-- ========================================================================
-- Execute the procedure for 2013 and 2014 (those are the years you need)
-- ========================================================================
EXEC InsDimDateYearly 2013

EXEC InsDimDateYearly 2014

-- ====================================
-- Begin load of unknown member for DimDate
-- ====================================
SET IDENTITY_INSERT dbo.DimDate ON;

INSERT INTO dbo.DimDate
(
DimDateID
, FullDate
, DayNumberOfWeek
, DayNameOfWeek
, DayNumberOfMonth
, DayNumberOfYear
, WeekdayFlag
, WeekNumberOfYear
, [MonthName]
, MonthNumberOfYear
, CalendarQuarter
, CalendarYear
, CalendarSemester
, CreatedDate
, CreatedBy
, ModifiedDate
, ModifiedBy
)
VALUES
(
-1
, '1999-01-01'
, 99
, 'Unknown'
, 99
, -1
, -1
, 99
, 'Unknown'
, 99
, 99
, -1
, 99
, '1999-01-01'
, 'Unknown'
, '1999-01-01'
, 'Unknown'
);
-- Turn the identity insert to OFF so new rows auto assign identities
SET IDENTITY_INSERT dbo.DimDate OFF;
GO

-- ====================================
-- Delete dimChannel table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimChannel')
BEGIN
	DROP TABLE dbo.dimChannel;
END
GO

-- ====================================
-- Create dimChannel table
-- ====================================
IF NOT EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimChannel')
BEGIN
	CREATE TABLE dbo.dimChannel
	(
	dimChannelKey INT IDENTITY(1,1) CONSTRAINT PK_dimChannel PRIMARY KEY CLUSTERED NOT NULL, -- SurrogateKey
	ChannelID INT NOT NUll, --Natural Key
	ChannelCategoryID INT NOT NUll, --Natural Key
	ChannelName VARCHAR(50) NOT NULL,
	ChannelCategory VARCHAR(50) NOT NULL
	);
END
GO

-- ====================================
-- Load dimChannel table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimChannel')
BEGIN
	DBCC CHECKIDENT (dimChannel, RESEED, 1)
	INSERT INTO dbo.dimChannel
	(
	ChannelID
	, ChannelCategoryID
	, ChannelName
	, ChannelCategory
	)
	SELECT
	dbo.StageChannel.ChannelID AS ChannelID
	,dbo.StageChannel.ChannelCategoryID AS ChannelCategoryID
	,dbo.StageChannel.Channel AS ChannelName
	,dbo.StageChannelCategory.ChannelCategory AS ChannelCategory

	FROM StageChannel
	INNER JOIN StageChannelCategory
	ON StageChannel.ChannelCategoryID = StageChannelCategory.ChannelCategoryID;
END
GO
UPDATE dimChannel
SET ChannelName = 'Online'
WHERE ChannelName = 'On-line'
GO

-- ====================================
-- Begin load of unknown member for dimChannel
-- ====================================
SET IDENTITY_INSERT dbo.dimChannel ON;

INSERT INTO dbo.dimChannel
(
dimChannelKey
, ChannelID
, ChannelCategoryID
, ChannelName
, ChannelCategory
)
VALUES
(
-1
,-1
,-1
,'Unknown'
,'Unknown'
);

-- ====================================
-- Delete dimLocation table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimLocation')
BEGIN
	DROP TABLE dbo.dimLocation;
END
GO

-- ====================================
-- Create dimLocation table
-- ====================================
IF NOT EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimLocation')
BEGIN
	CREATE TABLE dbo.dimLocation
	(
	dimLocationKey INT IDENTITY(1,1) CONSTRAINT PK_dimLocation PRIMARY KEY CLUSTERED NOT NULL, -- SurrogateKey
	[Address] NVARCHAR(255) NOT NULL,
	City NVARCHAR(255) NOT NULL,
	PostalCode NVARCHAR(255) NOT NULL,
	State_Province NVARCHAR(255) NOT NULL,
	Country NVARCHAR(255) NOT NULL
	);
END
GO

-- ====================================
-- Load dimLocation table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimLocation')
BEGIN
	DBCC CHECKIDENT (dimLocation, RESEED, 1)
	-- Load customer addresses
	INSERT INTO dbo.dimLocation
	(
	[Address]
	, City
	, PostalCode
	, State_Province
	, Country
	)
	SELECT
	dbo.StageCustomer.[Address]
	, dbo.StageCustomer.City
	, dbo.StageCustomer.PostalCode
	, dbo.StageCustomer.StateProvince
	, dbo.StageCustomer.Country
	FROM
	dbo.StageCustomer;
	-- Load store addresses
	INSERT INTO dbo.dimLocation
	(
	[Address]
	, City
	, PostalCode
	, State_Province
	, Country
	)
	SELECT
	dbo.StageStore.[Address]
	, dbo.StageStore.City
	, dbo.StageStore.PostalCode
	, dbo.StageStore.StateProvince
	, dbo.StageStore.Country
	FROM
	dbo.StageStore;
	-- Load reseller addresses
	INSERT INTO dbo.dimLocation
	(
	[Address]
	, City
	, PostalCode
	, State_Province
	, Country
	)
	SELECT
	dbo.StageReseller.[Address]
	, dbo.StageReseller.City
	, dbo.StageReseller.PostalCode
	, dbo.StageReseller.StateProvince
	, dbo.StageReseller.Country
	FROM
	dbo.StageReseller;
END
GO

-- ====================================
-- Begin load of unknown member for dimLocation
-- ====================================
SET IDENTITY_INSERT dbo.dimLocation ON;

INSERT INTO dbo.dimLocation
(
dimLocationKey
, [Address]
, City
, PostalCode
, State_Province
, Country
)
VALUES
(
-1
, 'Unknown'
, 'Unknown'
, 'Unknown'
, 'Unknown'
, 'Unknown'
);
-- Turn the identity insert to OFF so new rows auto assign identities
SET IDENTITY_INSERT dbo.dimLocation OFF;
GO

-- ====================================
-- Delete dimProduct table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimProduct')
BEGIN
	DROP TABLE dbo.dimProduct;
END
GO

-- ====================================
-- Create dimProduct table
-- ====================================
IF NOT EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimProduct')
BEGIN
	CREATE TABLE dbo.dimProduct
	(
	dimProductKey INT IDENTITY(1,1) CONSTRAINT PK_dimProduct PRIMARY KEY CLUSTERED NOT NULL, -- SurrogateKey
	ProductID INT NOT NULL, -- Natural Key
	ProductTypeID INT NOT NULL, -- Natural Key
	ProductCategoryID INT NOT NULL, -- Natural Key
	ProductName NVARCHAR(50) NOT NULL,
	ProductType NVARCHAR(50) NOT NULL,
	ProductCategory NVARCHAR(50) NOT NULL,
	ProductRetailPrice NUMERIC(18,2) NOT NULL,
	ProductWholesalePrice NUMERIC(18,2) NOT NULL,
	ProductCost NUMERIC(18,2) NOT NULL,
	ProductRetailProfit NUMERIC(18,2) NOT NULL,
	ProductWholesaleUnitProfit NUMERIC(18,2) NOT NULL,
	ProductProfitMarginUnitPercent NUMERIC(18,2) NOT NULL
	);
END
GO

-- ====================================
-- Load dimProduct table
-- ====================================
-- ====================================
-- Load dimProduct table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimProduct')
BEGIN
	DBCC CHECKIDENT (dimProduct, RESEED, 1)
	INSERT INTO dbo.dimProduct
	(
	ProductID
	, ProductTypeID
	, ProductCategoryID
	, ProductName
	, ProductType
	, ProductCategory
	, ProductRetailPrice
	, ProductWholesalePrice
	, ProductCost
	, ProductRetailProfit
	, ProductWholesaleUnitProfit
	, ProductProfitMarginUnitPercent
	)
	SELECT
	dbo.StageProduct.ProductID AS ProductID
	, dbo.StageProductType.ProductTypeID AS ProductTypeID
	, PC.ProductCategoryID AS ProductCategoryID
	, dbo.StageProduct.Product AS ProductName
	, dbo.StageProductType.ProductType AS ProductTypeName
	, dbo.StageProductCategory.ProductCategory AS ProductCategoryName
	, dbo.StageProduct.Price AS RetailPrice
	, dbo.StageProduct.WholesalePrice AS WholesalePrice
	, dbo.StageProduct.Cost AS Cost
	, dbo.StageProduct.Price-dbo.StageProduct.Cost AS RetailProfit
	, dbo.StageProduct.WholesalePrice-dbo.StageProduct.Cost AS WholesaleProfit
	, ((dbo.StageProduct.Price-dbo.StageProduct.Cost)/dbo.StageProduct.Price)*100 AS ProfitMargin
	FROM dbo.StageProduct
	INNER JOIN dbo.StageProductType ON dbo.StageProduct.ProductTypeID = dbo.StageProductType.ProductTypeID
	INNER JOIN dbo.StageProductCategory ON dbo.StageProductType.ProductCategoryID = dbo.StageProductCategory.ProductCategoryID
END
GO

-- ====================================
-- Begin load of unknown member for dimProduct
-- ====================================
SET IDENTITY_INSERT dbo.dimProduct ON;

INSERT INTO dbo.dimProduct
(
dimProductKey
, ProductID
, ProductTypeID
, ProductCategoryID
, ProductName
, ProductType
, ProductCategory
, ProductRetailPrice
, ProductWholesalePrice
, ProductCost
, ProductRetailProfit
, ProductWholesaleUnitProfit
, ProductProfitMarginUnitPercent
)
VALUES
(
-1
, -1
, -1
, -1
, 'Unknown'
, 'Unknown'
, 'Unknown'
, -1.00
, -1.00
, -1.00
, -1.00
, -1.00
, -1.00
);
-- Turn the identity insert to OFF so new rows auto assign identities
SET IDENTITY_INSERT dbo.dimProduct OFF;
GO

-- ====================================
-- Delete dimReseller table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimReseller')
BEGIN
	DROP TABLE dbo.dimReseller;
END
GO

-- ====================================
-- Create dimReseller table
-- ====================================
IF NOT EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimReseller')
BEGIN
	CREATE TABLE dbo.dimReseller
	(
	dimResellerKey INT IDENTITY(1,1) CONSTRAINT PK_dimReseller PRIMARY KEY CLUSTERED NOT NULL, -- SurrogateKey
	dimLocationKey INT CONSTRAINT FK_ResellerLocation FOREIGN KEY REFERENCES dbo.dimLocation(dimLocationKey) NOT NUll,
	ResellerID NVARCHAR(50) NOT NUll, --Natural Key
	ResellerName NVARCHAR(255) NOT NULL,
	ContactName NVARCHAR(255) NOT NULL,
	PhoneNumber NVARCHAR(255) NOT NULL,
	Email NVARCHAR(255) NOT NULL
	);
END
GO

-- ====================================
-- Load dimReseller table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimReseller')
BEGIN
	DBCC CHECKIDENT (dimReseller, RESEED, 1)
	INSERT INTO dbo.dimReseller
	(
	dimLocationKey
	, ResellerID
	, ResellerName
	, ContactName
	, PhoneNumber
	, Email
	)
	SELECT
	dbo.dimLocation.dimLocationKey AS LocationKey
	, CAST(dbo.StageReseller.ResellerID AS NVARCHAR(50)) AS CustomerID
	, dbo.StageReseller.ResellerName AS [Name]
	, dbo.StageReseller.Contact AS Contact
	, dbo.StageReseller.PhoneNumber AS Phone
	, dbo.StageReseller.EmailAddress AS Email
	FROM dbo.StageReseller
	INNER JOIN dbo.dimLocation ON dbo.StageReseller.[Address] = dbo.dimLocation.[Address]
	AND dbo.StageReseller.PostalCode = dbo.dimLocation.PostalCode;
END
GO

UPDATE dimReseller
SET ResellerName = 'Mississippi Distributors'
WHERE ResellerName = 'Mississipi Distributors'
GO
-- ====================================
-- Begin load of unknown member for dimReseller
-- ====================================
SET IDENTITY_INSERT dbo.dimReseller ON;

INSERT INTO dbo.dimReseller
(
dimResellerKey
, dimLocationKey
, ResellerID
, ResellerName
, ContactName
, PhoneNumber
, Email
)
VALUES
(
-1
, -1
, 'Unknown'
, 'Unknown'
, 'Unknown'
, 'Unknown'
, 'Unknown'
);

SET IDENTITY_INSERT dbo.dimReseller OFF;
GO


-- ====================================
-- Delete dimStore table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimStore')
BEGIN
	DROP TABLE dbo.dimStore;
END
GO

-- ====================================
-- Create dimStore table
-- ====================================
IF NOT EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimStore')
BEGIN
	CREATE TABLE dbo.dimStore
	(
	dimStoreKey INT IDENTITY(1,1) CONSTRAINT PK_dimStore PRIMARY KEY CLUSTERED NOT NULL, -- SurrogateKey
	dimLocationKey INT CONSTRAINT FK_StoreLocation FOREIGN KEY REFERENCES dbo.dimLocation(dimLocationKey) NOT NULL,
	StoreID INT NOT NULL, --Natural Key
	StoreName NVARCHAR(255) NOT NULL,
	StoreNumber INT NOT NULL,
	StoreManager NVARCHAR(255) NOT NULL
	);
END
GO

-- ====================================
-- Load dimStore table
-- ====================================
-- Load dimStore table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimStore')
BEGIN
	DBCC CHECKIDENT (dimStore, RESEED, 1)
	INSERT INTO dbo.dimStore
	(
	dimLocationKey
	, StoreID
	, StoreName
	, StoreNumber
	, StoreManager
	)
	SELECT
	dbo.dimLocation.dimLocationKey AS LocationKey
	, dbo.StageStore.StoreID AS StoreID
	, 'Store Number ' + CAST(dbo.StageStore.StoreNumber AS nvarchar(10)) AS [Name]
	, dbo.StageStore.StoreNumber AS Number
	, dbo.StageStore.StoreManager AS Manager
	FROM dbo.StageStore
	INNER JOIN dbo.dimLocation ON dbo.StageStore.[Address] = dbo.dimLocation.[Address]
	AND dbo.StageStore.PostalCode = dbo.dimLocation.PostalCode;
END
GO

-- ====================================
-- Begin load of unknown member for dimStore
-- ====================================
SET IDENTITY_INSERT dbo.dimStore ON;

INSERT INTO dbo.dimStore
(
dimStoreKey
, dimLocationKey
, StoreID
, StoreName
, StoreNumber
, StoreManager
)
VALUES
(
-1
, -1
, -1
, 'Unknown'
, -1
, 'Unknown'
);

SET IDENTITY_INSERT dbo.dimStore OFF;
GO

-- ====================================
-- Delete dimCustomer table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimCustomer')
BEGIN
	DROP TABLE dbo.dimCustomer;
END
GO

-- ====================================
-- Create dimCustomer table
-- ====================================
IF NOT EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimCustomer')
BEGIN
	CREATE TABLE dbo.dimCustomer
	(
	dimCustomerKey INT IDENTITY(1,1) CONSTRAINT PK_dimCustomer PRIMARY KEY CLUSTERED NOT NULL, -- SurrogateKey
	dimLocationKey INT CONSTRAINT FK_CustomerLocation FOREIGN KEY REFERENCES dbo.dimLocation(dimLocationKey) NOT NUll,
	CustomerID NVARCHAR(50) NOT NUll, --Natural Key
	CustomerFullName NVARCHAR(255) NOT NULL,
	CustomerFirstName NVARCHAR(255) NOT NULL,
	CustomerLastName NVARCHAR(255) NOT NULL,
	CustomerGender NVARCHAR(1) NOT NULL
	);
END
GO

-- ====================================
-- Load dimCustomer table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dimCustomer')
BEGIN
	DBCC CHECKIDENT (dimCustomer, RESEED, 1)
	INSERT INTO dbo.dimCustomer
	(
	dimLocationKey
	, CustomerID
	, CustomerFullName
	, CustomerFirstName
	, CustomerLastName
	, CustomerGender
	)
	SELECT
	dbo.dimLocation.dimLocationKey AS LocationKey
	, CAST(dbo.StageCustomer.CustomerID AS NVARCHAR(50)) AS CustomerID
	, dbo.StageCustomer.FirstName + ' ' + dbo.StageCustomer.LastName AS FullName
	, dbo.StageCustomer.FirstName AS [First]
	, dbo.StageCustomer.LastName AS [Last]
	, dbo.StageCustomer.Gender AS Gender
	FROM dbo.StageCustomer
	INNER JOIN dbo.dimLocation ON dbo.StageCustomer.[Address] = dbo.dimLocation.[Address]
	AND dbo.StageCustomer.PostalCode = dbo.dimLocation.PostalCode;
END
GO

-- ====================================
-- Begin load of unknown member for dimCustomer
-- ====================================
SET IDENTITY_INSERT dbo.dimCustomer ON;

INSERT INTO dbo.dimCustomer
(
dimCustomerKey
, dimLocationKey
, CustomerID
, CustomerFullName
, CustomerFirstName
, CustomerLastName
, CustomerGender
)
VALUES
(
-1
, -1
, 'Unknown'
, 'Unknown'
, 'Unknown'
, 'Unknown'
, '-'
);
SET IDENTITY_INSERT dbo.dimCustomer OFF;
GO

-- ====================================
-- Delete factSalesActual table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'factSalesActual')
BEGIN
	DROP TABLE dbo.factSalesActual;
END
GO

-- ====================================
-- Create factSalesActual table
-- ====================================
IF NOT EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'factSalesActual')
BEGIN
	CREATE TABLE dbo.factSalesActual
	(
	factSalesActualKey INT IDENTITY(1,1) CONSTRAINT PK_factSalesActual PRIMARY KEY CLUSTERED NOT NULL, -- SurrogateKey
	dimProductKey INT CONSTRAINT FK_SalesActualProduct FOREIGN KEY REFERENCES dbo.dimProduct(dimProductKey) NOT NULL,
	dimStoreKey INT CONSTRAINT FK_SalesActualStore FOREIGN KEY REFERENCES dbo.dimStore(dimStoreKey) NUll,
	dimResellerKey INT CONSTRAINT FK_SalesActualReseller FOREIGN KEY REFERENCES dbo.dimReseller(dimResellerKey) NULL,
	dimCustomerKey INT CONSTRAINT FK_SalesActualCustomer FOREIGN KEY REFERENCES dbo.dimCustomer(dimCustomerKey) NULL,
	dimChannelKey INT CONSTRAINT FK_SalesActualChannel FOREIGN KEY REFERENCES dbo.dimChannel(dimChannelKey) NOT NULL,
	dimSaleDateKey INT CONSTRAINT FK_SalesActualDate FOREIGN KEY REFERENCES dbo.DimDate(dimDateKey) NOT NULL,
	dimLocationKey INT CONSTRAINT FK_SalesActualLocation FOREIGN KEY REFERENCES dbo.dimLocation(dimLocationKey) NOT NULL,
	SalesHeaderID INT NOT NULL, -- Natural Key
	SalesDetailID INT NOT NULL, -- Natural Key
	SaleAmount NUMERIC(18,2) NOT NULL,
	SaleQuantity INT NOT NULL,
	SaleUnitPrice NUMERIC(18,2) NOT NULL,
	SaleExtendedCost NUMERIC(18,2) NOT NULL,
	SaleTotalProfit NUMERIC(18,2) NOT NULL
	);
END
GO

-- ====================================
-- Load factSalesActual table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'factSalesActual')
BEGIN
	DBCC CHECKIDENT (factSalesActual, RESEED, 1)
	INSERT INTO dbo.factSalesActual
	(
	dimProductKey
	, dimStoreKey
	, dimResellerKey
	, dimCustomerKey
	, dimChannelKey
	, dimSaleDateKey
	, dimLocationKey
	, SalesHeaderID
	, SalesDetailID
	, SaleAmount
	, SaleQuantity
	, SaleUnitPrice
	, SaleExtendedCost
	, SaleTotalProfit
	)
	SELECT 
	dbo.dimProduct.dimProductKey AS ProductKey
	, dbo.dimStore.dimStoreKey AS StoreKey
	, dbo.dimReseller.dimResellerKey AS ResellerKey
	, dbo.dimCustomer.dimCustomerKey AS CustomerKey
	, dbo.dimChannel.dimChannelKey AS ChannelKey
	, dbo.DimDate.dimDateKey AS SaleDateKey
	, (SELECT (CASE WHEN (dbo.StageSalesHeader.StoreID IS NOT NULL) THEN dbo.dimStore.dimLocationKey 
					WHEN (dbo.StageSalesHeader.CustomerID IS NOT NULL) THEN dbo.dimCustomer.dimLocationKey
					WHEN (dbo.StageSalesHeader.ResellerID IS NOT NULL) THEN dbo.dimReseller.dimLocationKey
				END)) AS LocKey
	, dbo.StageSalesHeader.SalesHeaderID -- Natural Key
	, dbo.StageSalesDetail.SalesDetailID -- Natural Key
	, dbo.StageSalesDetail.SalesAmount AS TotalPrice
	, dbo.StageSalesDetail.SalesQuantity AS Quantity
	, dbo.StageSalesDetail.SalesAmount/dbo.StageSalesDetail.SalesQuantity AS UnitPrice
	, dbo.dimProduct.ProductCost*dbo.StageSalesDetail.SalesQuantity AS TotalCost
	, dbo.StageSalesDetail.SalesAmount-(dbo.dimProduct.ProductCost*dbo.StageSalesDetail.SalesQuantity) AS TotalProfit
	FROM dbo.StageSalesHeader
	JOIN dbo.StageSalesDetail ON dbo.StageSalesHeader.SalesHeaderID = dbo.StageSalesDetail.SalesHeaderID
	LEFT JOIN dbo.dimProduct ON dbo.StageSalesDetail.ProductID = dbo.dimProduct.ProductID
	LEFT JOIN dbo.dimStore ON dbo.StageSalesHeader.StoreID = dbo.dimStore.StoreID
	LEFT JOIN dbo.dimReseller ON CAST(dbo.StageSalesHeader.ResellerID AS NVARCHAR(50)) = dbo.dimReseller.ResellerID
	LEFT JOIN dbo.dimCustomer ON CAST(dbo.StageSalesHeader.CustomerID AS NVARCHAR(50)) = dbo.dimCustomer.CustomerID
	LEFT JOIN dbo.dimChannel ON dbo.StageSalesHeader.ChannelID = dbo.dimChannel.ChannelID
	LEFT JOIN dbo.DimDate ON dbo.StageSalesHeader.[Date] = dbo.DimDate.FullDate
END
GO

-- ====================================
-- Delete factSalesTarget table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'factSalesTarget')
BEGIN
	DROP TABLE dbo.factSalesTarget;
END
GO

-- ====================================
-- Create factSalesTarget table
-- ====================================
IF NOT EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'factSalesTarget')
BEGIN
	CREATE TABLE dbo.factSalesTarget
	(
	factSalesTarget INT IDENTITY(1,1) CONSTRAINT PK_factSRCSalesTarget PRIMARY KEY CLUSTERED NOT NULL, -- SurrogateKey
	dimStoreKey INT CONSTRAINT FK_SRCSalesTargetStore FOREIGN KEY REFERENCES dbo.dimStore(dimStoreKey) NUll,
	dimResellerKey INT CONSTRAINT FK_SRCSalesTargetReseller FOREIGN KEY REFERENCES dbo.dimReseller(dimResellerKey) NULL,
	dimChannelKey INT CONSTRAINT FK_SRCSalesTargetChannel FOREIGN KEY REFERENCES dbo.dimChannel(dimChannelKey) NOT NULL,
	dimTargetDateKey INT CONSTRAINT FK_SRCSalesTargetDate FOREIGN KEY REFERENCES dbo.DimDate(dimDateKey) NOT NULL,
	SalesTargetAmount NUMERIC(18,2) NULL
	);
END
GO

-- ====================================
-- Load factSalesTarget table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'factSalesTarget')
	DBCC CHECKIDENT (factSalesTarget, RESEED, 1)

IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'factSalesTarget')
BEGIN
	WITH CTE_CRSDates
	(
	TargetName
	, DateKey
	) 
	AS
	(
	SELECT DISTINCT dbo.StageTargetCRS.TargetName
	, dbo.DimDate.DimDateKey
	FROM dbo.StageTargetCRS
	CROSS JOIN dbo.DimDate
	WHERE dbo.DimDate.DimDateKey > 0
	)
	, CTE_CRSTargets --2nd CTE for target names and target keys
	(
	ChannelKey
	, ChannelName
	, StoreKey
	, StoreName
	, ResellerKey
	, ResellerName
	, CustomerName
	)
	AS
	(
	SELECT dbo.dimChannel.dimChannelKey
	, dbo.dimChannel.ChannelName
	, dbo.dimStore.dimStoreKey
	, dbo.dimStore.StoreName
	, dbo.dimReseller.dimResellerKey
	, dbo.dimReseller.ResellerName
	, CASE WHEN dbo.StageTargetCRS.TargetName = 'Customer Sales' THEN 'Customer Sales' END AS CustomerName
	FROM dbo.StageTargetCRS
	LEFT JOIN dbo.dimChannel ON dbo.StageTargetCRS.ChannelName = dbo.dimChannel.ChannelName
	LEFT JOIN dbo.dimStore on dbo.StageTargetCRS.TargetName = dbo.dimStore.StoreName
	LEFT JOIN dbo.dimReseller ON dbo.StageTargetCRS.TargetName = dbo.dimReseller.ResellerName
	WHERE dbo.dimChannel.dimChannelKey > 0
	)
	INSERT INTO dbo.factSalesTarget
	(
	dimStoreKey
	, dimResellerKey
	, dimChannelKey
	, dimTargetDateKey
	, SalesTargetAmount
	)
	SELECT DISTINCT CTE_CRSTargets.StoreKey
	, CTE_CRSTargets.ResellerKey
	, CTE_CRSTargets.ChannelKey
	, CTE_CRSDates.DateKey
	, dbo.StageTargetCRS.TargetSalesAmount/365
	FROM CTE_CRSDates
	LEFT JOIN dbo.DimDate ON CTE_CRSDates.DateKey = dbo.DimDate.DimDateKey
	LEFT JOIN dbo.StageTargetCRS ON CTE_CRSDates.TargetName = dbo.StageTargetCRS.TargetName
		AND dbo.DimDate.CalendarYear = CAST(dbo.StageTargetCRS.[Year] AS INT)                         
	LEFT JOIN CTE_CRSTargets ON CTE_CRSDates.TargetName = CTE_CRSTargets.ResellerName  
		OR CTE_CRSDates.TargetName = CTE_CRSTargets.StoreName                                    
		OR CTE_CRSDates.TargetName = CTE_CRSTargets.CustomerName
END
GO

-- ====================================
-- Delete factProductSalesTarget table
-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'factProductSalesTarget')
BEGIN
	DROP TABLE dbo.factProductSalesTarget;
END
GO

-- ====================================
-- Create factProductSalesTarget table
-- ====================================
IF NOT EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'factProductSalesTarget')
BEGIN
	CREATE TABLE dbo.factProductSalesTarget
	(
	factSalesTargetKey INT IDENTITY(1,1) CONSTRAINT PK_factProductSalesTarget PRIMARY KEY CLUSTERED NOT NULL, -- SurrogateKey
	dimProductKey INT CONSTRAINT FK_ProductSalesTargetProduct FOREIGN KEY REFERENCES dbo.dimProduct(dimProductKey) NOT NULL,
	dimTargetDateKey INT CONSTRAINT FK_ProductSalesTargetDate FOREIGN KEY REFERENCES dbo.DimDate(dimDateKey) NOT NULL,
	ProductTargetSalesQuantity INT NOT NULL
	);
END
GO

-- ====================================
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'factProductSalesTarget')
	DBCC CHECKIDENT (factProductSalesTarget, RESEED, 1)

IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'factProductSalesTarget')
BEGIN
	WITH CTE_ProductDate (ProductID, DateID, ProductName, [Year]) AS 
	(
	SELECT DISTINCT dProd.dimProductKey AS ProductID
	, dDate.DimDateKey AS DateID
	, dProd.ProductName AS ProductName
	, dDate.CalendarYear AS [Year]
	FROM dbo.dimProduct
	CROSS JOIN dbo.DimDate
	WHERE dbo.dimProduct.dimProductKey > 0
	AND dbo.DimDate.DimDateKey > 0
	)
	INSERT INTO dbo.factProductSalesTarget
	(
	dimProductKey
	, dimTargetDateKey
	, ProductTargetSalesQuantity
	)
	SELECT 
	ProductID
	, DateID 
	, CEILING(dbo.StageTargetProduct.SalesQuantityTarget/365)
	FROM CTE_ProductDate AS CTE
	INNER JOIN dbo.StageTargetProduct ON CTE.ProductID = dbo.StageTargetProduct.ProductID
	AND CTE.[Year] = StageTargetProduct.[Year]
	ORDER BY ProductID, ASC, DateID, ASC
END
GO