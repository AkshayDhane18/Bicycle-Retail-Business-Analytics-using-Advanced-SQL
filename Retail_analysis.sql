use DataWarehouseAnalytics;

-- 1. Who are our most valueable customers ?

SELECT
	c.customer_key,
	CONCAT(c.first_name,' ', c.last_name) as customer_name,
	SUM(f.sales_amount) as lifetime_value
FROM gold.fact_sales f
JOIN gold.dim_customers c
	ON f.customer_key = c.customer_key
GROUP BY c.customer_key, CONCAT(c.first_name,' ', c.last_name)
ORDER BY lifetime_value DESC;

-- 2. Which products generate the highest revenue in each category?
WITH product_rank AS (
	SELECT 
		p.category,
		p.product_name,
		SUM(f.sales_amount) as revenue,
		RANK() OVER( PARTITION BY p.category ORDER BY SUM(f.sales_amount) DESC) AS rnk
	FROM gold.fact_sales f
	JOIN gold.dim_products p
		ON f.product_key = p.product_key
	GROUP BY p.category, p.product_name
)
SELECT * FROM product_rank
WHERE rnk <=3;


-- 3. Are sales growing Month over Month(MoM) ?
WITH monthly_sales AS (
SELECT 
	YEAR(order_date) as yr,
	MONTH(order_date) as mn,
	SUM(sales_amount) as total_sales
FROM gold.fact_sales 
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
)
SELECT yr, mn, total_sales,
	total_sales - LAG(total_sales) OVER(ORDER BY yr, mn) as mom_growth
FROM monthly_sales

-- 4. Which customers drive the most revenue per country ?
WITH ranked_customers AS (
SELECT 
	c.country,
	c.customer_key,
	CONCAT(c.first_name,' ',c.last_name) as customer_name,
	SUM(f.sales_amount) as total_sales,
	DENSE_RANK() OVER (PARTITION BY c.country ORDER BY SUM(f.sales_amount) DESC) as rnk
FROM gold.fact_sales f
JOIN gold.dim_customers c
	ON f.customer_key = c.customer_key
GROUP BY c.country,
	c.customer_key,
	CONCAT(c.first_name,' ',c.last_name)
)
SELECT *
FROM ranked_customers 
WHERE rnk <= 3 AND country not like 'n/a'
ORDER BY country;

-- 5. Are we dependent on few products for revenue

SELECT 
	p.product_name,
	SUM(f.sales_amount) as product_sales,
	CONCAT(
		CAST(
			SUM(f.sales_amount)*100.0 / SUM(SUM(f.sales_amount)) OVER() 
			AS decimal(10,2))
			,'%') as revenue_percentage
FROM gold.fact_sales f
JOIN gold.dim_products p
	ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY revenue_percentage DESC;


-- 6. Are shipments delivered on time?
SELECT 
	COUNT(*) AS total_orders,
	SUM( CASE WHEN shipping_date > due_date THEN 1 ELSE 0 END) AS late_orders,
	round( 
		SUM( CASE WHEN shipping_date > due_date THEN 1 ELSE 0 END) * 100.0
		/ COUNT(*),2) as percentage
FROM gold.fact_sales;


-- 7. How is cumulative sales progressing?
SELECT 
	order_date,
	SUM(sales_amount) as daily_sales,
	SUM(SUM(sales_amount)) over ( ORDER BY order_date) as cumulative_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY order_date;


-- 8. Which orders are unusually high for customers ?
SELECT *
FROM (
	SELECT *,
		AVG(sales_amount) OVER( PARTITION BY customer_key) as avg_sales
	FROM gold.fact_sales
	) t
WHERE sales_amount > avg_sales
Order by customer_key;


-- 9. Which products are profitable vs loss-making?

SELECT 
	p.category,
	p.product_name,
	SUM(f.sales_amount) as revenue,
	SUM(f.quantity * p.cost) as cost,
	sum(f.sales_amount) - SUM(f.quantity - p.cost)  as profit
FROM gold.fact_sales f
JOIN gold.dim_products p
	ON f.product_key = p.product_key
GROUP BY p.category, p.product_name
ORDER BY profit DESC;

-- 10. How many customers are repeated buyers ?
SELECT 
	customer_key,
	COUNT(DISTINCT order_number) as total_orders,
	CASE
		WHEN COUNT( DISTINCT order_number) = 1 THEN 'One-time'
		ELSE 'Repeat'
	END AS customer_type
FROM gold.fact_sales
GROUP BY customer_key;


-- 11. Are there data quality issues in sales data ?
SELECT * 
FROM gold.fact_sales 
WHERE sales_amount <> quantity * price;


-- 12. How frequently do customers purchase ?

SELECT 
	customer_key,
	COUNT(DISTINCT order_number) as total_orders,
	CASE
		WHEN COUNT( DISTINCT order_number) = 1 THEN 'Low'
		WHEN COUNT( DISTINCT order_number) BETWEEN 2 AND 5 THEN 'Medium'
		ELSE 'High'
	END AS purchase_frequency
FROM gold.fact_sales
GROUP BY customer_key
ORDER BY purchase_frequency Desc;

