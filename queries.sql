-- queries.sql: Duka Smart Electronics, retail_analytics (PostgreSQL)
-- Rules used throughout:
--   revenue = quantity * unit_price * (1 - discount / 100)   cost = quantity * cost_price
--   money questions use order_status = 'Completed' only; order counts use every order.
--   "today" = MAX(order_date) from orders.

-- ============================================================
-- SECTION A: SQL fundamentals (Q1-Q10)
-- ============================================================

-- Q1: Retrieve all customer records
SELECT * FROM customers;

-- Q2: Display customer names, cities, and segments
SELECT customer_name, city, customer_segment FROM customers;

-- Q3: Find customers living in Nairobi
SELECT * FROM customers WHERE city = 'Nairobi';

-- Q4: Find customers registered after January 1, 2025
SELECT * FROM customers WHERE registration_date > '2025-01-01' ORDER BY registration_date;

-- Q5: Display all unique customer cities
SELECT DISTINCT city FROM customers ORDER BY city;

-- Q6: Retrieve the 10 most recent orders
SELECT * FROM orders ORDER BY order_date DESC, order_id DESC LIMIT 10;

-- Q7: Find orders with unit prices above KSh 10,000
SELECT * FROM orders WHERE unit_price > 10000 ORDER BY unit_price DESC;

-- Q8: Find customers whose names start with A
SELECT * FROM customers WHERE customer_name LIKE 'A%' ORDER BY customer_name;

-- Q9: Retrieve orders with quantities between 2 and 5
SELECT * FROM orders WHERE quantity BETWEEN 2 AND 5;

-- Q10: Find orders paid through M-Pesa
SELECT * FROM orders WHERE payment_method = 'M-Pesa';

-- ============================================================
-- SECTION B: Aggregation and grouping (Q11-Q20)
-- ============================================================

-- Q11: Count all customers
SELECT COUNT(*) AS total_customers FROM customers;

-- Q12: Count all orders (every status)
SELECT COUNT(*) AS total_orders FROM orders;

-- Q13: Calculate completed-order revenue
SELECT ROUND(SUM(quantity * unit_price * (1 - discount / 100)), 2) AS completed_revenue
FROM orders
WHERE order_status = 'Completed';

-- Q14: Calculate the average completed-order value
SELECT ROUND(AVG(quantity * unit_price * (1 - discount / 100)), 2) AS avg_completed_order_value
FROM orders
WHERE order_status = 'Completed';

-- Q15: Find the highest and lowest product prices (unit_price, all orders)
SELECT MAX(unit_price) AS highest_price, MIN(unit_price) AS lowest_price FROM orders;

-- Q16: Calculate revenue by product category (completed orders)
SELECT product_category,
       ROUND(SUM(quantity * unit_price * (1 - discount / 100)), 2) AS revenue
FROM orders
WHERE order_status = 'Completed'
GROUP BY product_category
ORDER BY revenue DESC;

-- Q17: Count customers by city
SELECT city, COUNT(*) AS customers
FROM customers
GROUP BY city
ORDER BY customers DESC, city;

-- Q18: Calculate quantity sold by product (completed orders = units actually sold)
SELECT product_name, SUM(quantity) AS units_sold
FROM orders
WHERE order_status = 'Completed'
GROUP BY product_name
ORDER BY units_sold DESC;

-- Q19: Categories generating more than KSh 100,000 in revenue
SELECT product_category,
       ROUND(SUM(quantity * unit_price * (1 - discount / 100)), 2) AS revenue
FROM orders
WHERE order_status = 'Completed'
GROUP BY product_category
HAVING SUM(quantity * unit_price * (1 - discount / 100)) > 100000
ORDER BY revenue DESC;

-- Q20: Percentage of cancelled orders (out of all orders)
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE order_status = 'Cancelled') / COUNT(*), 2) AS cancelled_pct
FROM orders;

-- ============================================================
-- SECTION C: Joins and customer analytics (Q21-Q28)
-- ============================================================

-- Q21: Orders with customer names and cities
SELECT o.order_id, o.order_date, c.customer_name, c.city,
       o.product_name, o.quantity, o.order_status
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
ORDER BY o.order_id;

-- Q22: Total spending by customer (completed orders; customers with at least one completed order)
SELECT c.customer_id, c.customer_name,
       ROUND(SUM(o.quantity * o.unit_price * (1 - o.discount / 100)), 2) AS total_spending
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.customer_id, c.customer_name
ORDER BY total_spending DESC;

-- Q23: Customers who have never ordered (any status)
SELECT c.customer_id, c.customer_name, c.city, c.customer_segment
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL
ORDER BY c.customer_id;

-- Q24: The 10 highest-spending customers
SELECT c.customer_id, c.customer_name,
       ROUND(SUM(o.quantity * o.unit_price * (1 - o.discount / 100)), 2) AS total_spending
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.customer_id, c.customer_name
ORDER BY total_spending DESC
LIMIT 10;

-- Q25: Revenue by customer city
SELECT c.city,
       ROUND(SUM(o.quantity * o.unit_price * (1 - o.discount / 100)), 2) AS revenue
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.city
ORDER BY revenue DESC;

-- Q26: Customers with more than five orders (any status)
SELECT c.customer_id, c.customer_name, COUNT(*) AS orders
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(*) > 5
ORDER BY orders DESC, c.customer_id;

-- Q27: Average customer spending by segment
-- Definition: first total each purchasing customer's completed spending, then average those totals per segment.
WITH customer_totals AS (
    SELECT c.customer_id, c.customer_segment,
           SUM(o.quantity * o.unit_price * (1 - o.discount / 100)) AS total_spending
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    WHERE o.order_status = 'Completed'
    GROUP BY c.customer_id, c.customer_segment
)
SELECT customer_segment,
       COUNT(*) AS purchasing_customers,
       ROUND(AVG(total_spending), 2) AS avg_spending_per_customer
FROM customer_totals
GROUP BY customer_segment
ORDER BY avg_spending_per_customer DESC;

-- Q28: Most popular category among VIP customers
-- "Popular" = number of orders (all statuses); units are shown as a tie-breaker.
SELECT o.product_category, COUNT(*) AS orders, SUM(o.quantity) AS units
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE c.customer_segment = 'VIP'
GROUP BY o.product_category
ORDER BY orders DESC, units DESC
LIMIT 1;

-- ============================================================
-- SECTION D: Subqueries and CTEs (Q29-Q34)
-- ============================================================

-- Q29: Customers spending above the average total spending per purchasing customer
WITH customer_totals AS (
    SELECT customer_id,
           SUM(quantity * unit_price * (1 - discount / 100)) AS total_spending
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id
)
SELECT ct.customer_id, c.customer_name, ROUND(ct.total_spending, 2) AS total_spending
FROM customer_totals ct
JOIN customers c ON c.customer_id = ct.customer_id
WHERE ct.total_spending > (SELECT AVG(total_spending) FROM customer_totals)
ORDER BY ct.total_spending DESC;

-- Q30: Products priced above the overall average unit price (average across all orders)
SELECT product_name, ROUND(AVG(unit_price), 2) AS avg_unit_price
FROM orders
GROUP BY product_name
HAVING AVG(unit_price) > (SELECT AVG(unit_price) FROM orders)
ORDER BY avg_unit_price DESC;

-- Q31: Three highest-revenue months (CTE)
WITH monthly AS (
    SELECT DATE_TRUNC('month', order_date)::date AS month,
           SUM(quantity * unit_price * (1 - discount / 100)) AS revenue
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT month, ROUND(revenue, 2) AS revenue
FROM monthly
ORDER BY revenue DESC
LIMIT 3;

-- Q32: Customers purchasing from at least three categories (completed orders)
SELECT c.customer_id, c.customer_name, COUNT(DISTINCT o.product_category) AS categories
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(DISTINCT o.product_category) >= 3
ORDER BY categories DESC, c.customer_id;

-- Q33: Category revenue, cost, profit and profit margin (CTE)
WITH category_totals AS (
    SELECT product_category,
           SUM(quantity * unit_price * (1 - discount / 100)) AS revenue,
           SUM(quantity * cost_price) AS cost
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY product_category
)
SELECT product_category,
       ROUND(revenue, 2) AS revenue,
       ROUND(cost, 2) AS cost,
       ROUND(revenue - cost, 2) AS profit,
       ROUND((revenue - cost) / NULLIF(revenue, 0) * 100, 2) AS profit_margin_pct
FROM category_totals
ORDER BY profit DESC;

-- Q34: Customers whose latest completed order is more than 90 days before the latest order date in the data
WITH last_completed AS (
    SELECT customer_id, MAX(order_date) AS last_order_date
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id
)
SELECT c.customer_id, c.customer_name, lc.last_order_date,
       (SELECT MAX(order_date) FROM orders) - lc.last_order_date AS days_since_last_order
FROM last_completed lc
JOIN customers c ON c.customer_id = lc.customer_id
WHERE (SELECT MAX(order_date) FROM orders) - lc.last_order_date > 90
ORDER BY days_since_last_order DESC;

-- ============================================================
-- SECTION E: Window functions (Q35-Q42)
-- ============================================================

-- Q35: Rank customers by spending using RANK()
SELECT c.customer_id, c.customer_name,
       ROUND(SUM(o.quantity * o.unit_price * (1 - o.discount / 100)), 2) AS total_spending,
       RANK() OVER (ORDER BY SUM(o.quantity * o.unit_price * (1 - o.discount / 100)) DESC) AS spending_rank
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.customer_id, c.customer_name
ORDER BY spending_rank, c.customer_id;

-- Q36: Number each customer's orders by recency (1 = most recent), all statuses
SELECT customer_id, order_id, order_date, order_status,
       ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC, order_id DESC) AS recency_no
FROM orders
ORDER BY customer_id, recency_no;

-- Q37: Rank products within categories by revenue using DENSE_RANK()
WITH product_revenue AS (
    SELECT product_category, product_name,
           SUM(quantity * unit_price * (1 - discount / 100)) AS revenue
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY product_category, product_name
)
SELECT product_category, product_name, ROUND(revenue, 2) AS revenue,
       DENSE_RANK() OVER (PARTITION BY product_category ORDER BY revenue DESC) AS rank_in_category
FROM product_revenue
ORDER BY product_category, rank_in_category;

-- Q38: Cumulative monthly revenue
WITH monthly AS (
    SELECT DATE_TRUNC('month', order_date)::date AS month,
           SUM(quantity * unit_price * (1 - discount / 100)) AS revenue
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT month, ROUND(revenue, 2) AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY month), 2) AS cumulative_revenue
FROM monthly
ORDER BY month;

-- Q39: Compare monthly revenue with the previous month using LAG()
WITH monthly AS (
    SELECT DATE_TRUNC('month', order_date)::date AS month,
           SUM(quantity * unit_price * (1 - discount / 100)) AS revenue
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT month, ROUND(revenue, 2) AS revenue,
       ROUND(LAG(revenue) OVER (ORDER BY month), 2) AS previous_month_revenue,
       ROUND(revenue - LAG(revenue) OVER (ORDER BY month), 2) AS change
FROM monthly
ORDER BY month;

-- Q40: Month-over-month revenue growth (%)
WITH monthly AS (
    SELECT DATE_TRUNC('month', order_date)::date AS month,
           SUM(quantity * unit_price * (1 - discount / 100)) AS revenue
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT month, ROUND(revenue, 2) AS revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY month))
             / NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100, 2) AS growth_pct
FROM monthly
ORDER BY month;

-- Q41: Divide purchasing customers into four spending groups using NTILE(4)
-- Group 1 = highest spenders, group 4 = lowest.
WITH customer_totals AS (
    SELECT customer_id,
           SUM(quantity * unit_price * (1 - discount / 100)) AS total_spending
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id
)
SELECT customer_id, ROUND(total_spending, 2) AS total_spending,
       NTILE(4) OVER (ORDER BY total_spending DESC) AS spending_group
FROM customer_totals
ORDER BY total_spending DESC;

-- Q42: Each category's share of total revenue using window functions
SELECT product_category,
       ROUND(SUM(quantity * unit_price * (1 - discount / 100)), 2) AS revenue,
       ROUND(100.0 * SUM(quantity * unit_price * (1 - discount / 100))
             / SUM(SUM(quantity * unit_price * (1 - discount / 100))) OVER (), 2) AS revenue_share_pct
FROM orders
WHERE order_status = 'Completed'
GROUP BY product_category
ORDER BY revenue DESC;

-- ============================================================
-- SECTION F: Advanced business intelligence (Q43-Q46)
-- ============================================================

-- Q43: monthly_sales_summary view (month, orders, revenue, cost, profit)
-- "orders" counts every order in the month (all statuses); revenue, cost and profit use completed orders only.
CREATE OR REPLACE VIEW monthly_sales_summary AS
SELECT DATE_TRUNC('month', order_date)::date AS month,
       COUNT(*) AS orders,
       ROUND(COALESCE(SUM(quantity * unit_price * (1 - discount / 100))
             FILTER (WHERE order_status = 'Completed'), 0), 2) AS revenue,
       ROUND(COALESCE(SUM(quantity * cost_price)
             FILTER (WHERE order_status = 'Completed'), 0), 2) AS cost,
       ROUND(COALESCE(SUM(quantity * unit_price * (1 - discount / 100) - quantity * cost_price)
             FILTER (WHERE order_status = 'Completed'), 0), 2) AS profit
FROM orders
GROUP BY DATE_TRUNC('month', order_date);

SELECT * FROM monthly_sales_summary ORDER BY month;

-- Q44: Function returning completed-order revenue for a customer ID (0 if none)
CREATE OR REPLACE FUNCTION customer_completed_revenue(p_customer_id INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql AS $$
DECLARE
    v_revenue NUMERIC;
BEGIN
    SELECT COALESCE(ROUND(SUM(quantity * unit_price * (1 - discount / 100)), 2), 0)
    INTO v_revenue
    FROM orders
    WHERE customer_id = p_customer_id
      AND order_status = 'Completed';
    RETURN v_revenue;
END;
$$;

SELECT customer_completed_revenue(33)    AS existing_customer;   -- customer 33 is the top spender
SELECT customer_completed_revenue(99999) AS nonexistent_customer; -- returns 0, not NULL

-- Q45: Segment customers into High / Medium / Low Value
-- Thresholds (on completed-order spending, purchasing customers only):
--   High Value   : KSh 300,000 or more   (about the top 21% of buyers, roughly the 80th percentile cut)
--   Medium Value : KSh 100,000 to 299,999 (the middle group, around the median-to-80th-percentile band)
--   Low Value    : under KSh 100,000      (the long tail; the median buyer spends about KSh 90,000)
-- Why: I looked at the spread first. Spending is very skewed (median about 90K, but the top fifth spend 300K+),
-- so round KSh figures near the 80th percentile and the 50th-60th percentile give three groups that are easy
-- to explain and big enough to act on. Customers with no completed orders are not in this list.
WITH customer_totals AS (
    SELECT customer_id,
           SUM(quantity * unit_price * (1 - discount / 100)) AS total_spending
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id
),
segmented AS (
    SELECT customer_id, total_spending,
           CASE WHEN total_spending >= 300000 THEN 'High Value'
                WHEN total_spending >= 100000 THEN 'Medium Value'
                ELSE 'Low Value' END AS value_segment
    FROM customer_totals
)
SELECT value_segment,
       COUNT(*) AS customers,
       ROUND(SUM(total_spending), 2) AS revenue,
       ROUND(100.0 * SUM(total_spending) / SUM(SUM(total_spending)) OVER (), 1) AS revenue_share_pct
FROM segmented
GROUP BY value_segment
ORDER BY revenue DESC;

-- The same segmentation customer by customer
WITH customer_totals AS (
    SELECT customer_id,
           SUM(quantity * unit_price * (1 - discount / 100)) AS total_spending
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id
)
SELECT ct.customer_id, c.customer_name, ROUND(ct.total_spending, 2) AS total_spending,
       CASE WHEN ct.total_spending >= 300000 THEN 'High Value'
            WHEN ct.total_spending >= 100000 THEN 'Medium Value'
            ELSE 'Low Value' END AS value_segment
FROM customer_totals ct
JOIN customers c ON c.customer_id = ct.customer_id
ORDER BY ct.total_spending DESC;

-- Q46: Management report
-- Q46a: Top five customers (completed revenue)
SELECT c.customer_id, c.customer_name, c.city,
       ROUND(SUM(o.quantity * o.unit_price * (1 - o.discount / 100)), 2) AS revenue
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.customer_id, c.customer_name, c.city
ORDER BY revenue DESC
LIMIT 5;

-- Q46b: Top five products (completed revenue)
SELECT product_name, product_category,
       SUM(quantity) AS units_sold,
       ROUND(SUM(quantity * unit_price * (1 - discount / 100)), 2) AS revenue
FROM orders
WHERE order_status = 'Completed'
GROUP BY product_name, product_category
ORDER BY revenue DESC
LIMIT 5;

-- Q46c: Most profitable category (by profit in KSh)
SELECT product_category,
       ROUND(SUM(quantity * unit_price * (1 - discount / 100)) - SUM(quantity * cost_price), 2) AS profit
FROM orders
WHERE order_status = 'Completed'
GROUP BY product_category
ORDER BY profit DESC
LIMIT 1;

-- Q46d: Lowest-revenue month
SELECT DATE_TRUNC('month', order_date)::date AS month,
       ROUND(SUM(quantity * unit_price * (1 - discount / 100)), 2) AS revenue
FROM orders
WHERE order_status = 'Completed'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY revenue ASC
LIMIT 1;

-- ============================================================
-- STRETCH: Monthly cohort retention
-- ============================================================
-- Cohort = month of a customer's first completed order. A customer is "retained" in month N
-- if they placed a completed order N months after their cohort month (N = 1, 2, 3 ...).
WITH customer_months AS (
    SELECT DISTINCT customer_id, DATE_TRUNC('month', order_date)::date AS order_month
    FROM orders
    WHERE order_status = 'Completed'
),
cohorts AS (
    SELECT customer_id, MIN(order_month) AS cohort_month
    FROM customer_months
    GROUP BY customer_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM cohorts
    GROUP BY cohort_month
),
activity AS (
    SELECT c.cohort_month,
           (EXTRACT(YEAR FROM cm.order_month) - EXTRACT(YEAR FROM c.cohort_month)) * 12
         + (EXTRACT(MONTH FROM cm.order_month) - EXTRACT(MONTH FROM c.cohort_month)) AS months_since,
           COUNT(DISTINCT cm.customer_id) AS active_customers
    FROM cohorts c
    JOIN customer_months cm ON cm.customer_id = c.customer_id
    GROUP BY c.cohort_month, months_since
)
SELECT s.cohort_month, s.cohort_size, a.months_since, a.active_customers,
       ROUND(100.0 * a.active_customers / s.cohort_size, 1) AS retention_pct
FROM cohort_sizes s
JOIN activity a ON a.cohort_month = s.cohort_month
WHERE a.months_since >= 1
ORDER BY s.cohort_month, a.months_since;

-- Simpler view: of each cohort, how many ordered again in ANY later month?
-- (The September 2026 cohort shows 0% only because there is no later month in the data yet.)
WITH customer_months AS (
    SELECT DISTINCT customer_id, DATE_TRUNC('month', order_date)::date AS order_month
    FROM orders
    WHERE order_status = 'Completed'
),
cohorts AS (
    SELECT customer_id, MIN(order_month) AS cohort_month
    FROM customer_months
    GROUP BY customer_id
)
SELECT c.cohort_month,
       COUNT(*) AS cohort_size,
       COUNT(*) FILTER (WHERE EXISTS (
           SELECT 1 FROM customer_months cm
           WHERE cm.customer_id = c.customer_id AND cm.order_month > c.cohort_month)) AS ordered_again,
       ROUND(100.0 * COUNT(*) FILTER (WHERE EXISTS (
           SELECT 1 FROM customer_months cm
           WHERE cm.customer_id = c.customer_id AND cm.order_month > c.cohort_month)) / COUNT(*), 1) AS ordered_again_pct
FROM cohorts c
GROUP BY c.cohort_month
ORDER BY c.cohort_month;
