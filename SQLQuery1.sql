-- Inspecting Data
SELECT * FROM [dbo].[sales_data_sample]

-- Checking Unique Values
SELECT DISTINCT status FROM [dbo].[sales_data_sample] -- Nice one to plot
SELECT DISTINCT year_id FROM [dbo].[sales_data_sample]
SELECT DISTINCT PRODUCTLINE FROM [dbo].[sales_data_sample] -- Nice one to plot
SELECT DISTINCT COUNTRY FROM [dbo].[sales_data_sample]	-- Nice one to plot
SELECT DISTINCT DEALSIZE FROM [dbo].[sales_data_sample] -- Nice one to plot
SELECT DISTINCT TERRITORY FROM [dbo].[sales_data_sample] -- Nice one to plot

-- ANALYSIS 
-- Grouping sales by productline

SELECT PRODUCTLINE, SUM(sales) as Revenue
FROM [dbo].[sales_data_sample]
GROUP BY PRODUCTLINE
ORDER BY 2 DESC

SELECT YEAR_ID, SUM(sales) as Revenue
FROM [dbo].[sales_data_sample]
GROUP BY YEAR_ID
ORDER BY 2 DESC

SELECT DISTINCT MONTH_ID FROM [dbo].[sales_data_sample]
WHERE YEAR_ID = 2005

SELECT DEALSIZE, SUM(sales) as Revenue
FROM [dbo].[sales_data_sample]
GROUP BY DEALSIZE
ORDER BY 2 DESC

-- What was the best month for sales in a specific year? How much we earned that year?
SELECT MONTH_ID, SUM(sales) Revenue, COUNT(ORDERNUMBER) Frequency
FROM [dbo].[sales_data_sample]
WHERE YEAR_ID = 2004 -- Change year to see the rest
GROUP BY MONTH_ID
ORDER BY 2 DESC

-- November is the best month evidently, what product do they sell in November? (Classic)
SELECT MONTH_ID, PRODUCTLINE, SUM(sales) Revenue, COUNT(ORDERNUMBER) Frequency
FROM [dbo].[sales_data_sample]
WHERE YEAR_ID = 2004 and MONTH_ID = 11-- Change year to see the rest
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY 3 DESC

-- Who is our best customer (Performing RFM Analysis)
DROP TABLE IF EXISTS #rfm
;with rfm as
(
	SELECT
		CUSTOMERNAME,
		SUM(sales) MonetaryValue,
		AVG(sales) AvgMonetaryValue,
		COUNT(ORDERNUMBER) Frequency,
		MAX(ORDERDATE) last_order_date,
		(SELECT MAX(ORDERDATE) FROM [dbo].[sales_data_sample]) max_order_date,
		DATEDIFF(DD, max(ORDERDATE), (SELECT MAX(ORDERDATE) FROM [dbo].[sales_data_sample])) Recency 
	FROM [dbo].[sales_data_sample]
	GROUP BY CUSTOMERNAME
), rfm_calc AS
(
	SELECT r.*,
		NTILE(4) OVER (ORDER BY Recency DESC) rfm_recency,
		NTILE(4) OVER (ORDER BY Frequency) rfm_frequency,
		NTILE(4) OVER (ORDER BY AvgMonetaryValue) rfm_monetary
	FROM rfm r
)
SELECT 
	c.*, rfm_recency+rfm_frequency+rfm_monetary AS rfm_cell,
	cast(rfm_recency AS varchar) + cast(rfm_frequency AS varchar) + cast(rfm_monetary AS varchar) AS rfm_cell_string
INTO #rfm
FROM rfm_calc c

SELECT CUSTOMERNAME, rfm_recency, rfm_frequency, rfm_monetary,
	CASE
			WHEN rfm_cell_string in (111, 112, 121, 122, 123, 132, 211, 212, 114, 141) THEN 'lost_customers' -- lost customers
			WHEN rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) THEN 'slipping away, cannot lose' -- Big spenders who're slipping away
			WHEN rfm_cell_string in (311, 411, 331) THEN 'new customers'
			WHEN rfm_cell_string in (222, 223, 233, 322) THEN 'potential churners'
			WHEN rfm_cell_string in (323, 333, 321, 422, 332, 432) THEN 'active' -- Customers who buy often, but at lower price points
			WHEN rfm_cell_string in (433, 434, 443, 444) THEN 'loyal'
	END rfm_segment
FROM #rfm

-- What products are often sold together?
-- SELECT * FROM [dbo].[sales_data_sample] WHERE ORDERNUMBER = 10411

SELECT DISTINCT ORDERNUMBER, STUFF(

	(SELECT ',' + PRODUCTCODE
	FROM [dbo].[sales_data_sample] p
	WHERE ORDERNUMBER in
		(	
			SELECT ORDERNUMBER
			FROM (
				SELECT ORDERNUMBER, COUNT(*) rn
				FROM [dbo].[sales_data_sample]
				WHERE STATUS = 'Shipped'
				GROUP BY ORDERNUMBER
			)m
			WHERE rn = 3
		)
		AND p.ORDERNUMBER = s.ORDERNUMBER
		FOR xml path (''))
		
		, 1, 1, '') ProductCodes

FROM [dbo].[sales_data_sample] s
ORDER BY 2 DESC