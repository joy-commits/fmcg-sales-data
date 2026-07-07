--Top 5 products by total revenue in 2025
SELECT
    product_name,
    SUM(revenue_ngn) AS total_revenue
FROM public_marts.mart_sales_performance
WHERE year = 2025
GROUP BY product_name
ORDER BY total_revenue DESC
LIMIT 5;

--Region with the highest month-over-month revenue growth in Q3 2025
WITH monthly_revenue AS (
    SELECT
        region,
        month,
        SUM(revenue_ngn) AS monthly_revenue
    FROM public_marts.mart_sales_performance
    WHERE year = 2025
      AND quarter = 3
    GROUP BY region, month
),

growth AS (
    SELECT
        region,
        month,
        monthly_revenue,
        LAG(monthly_revenue) OVER (
            PARTITION BY region
            ORDER BY month
        ) AS previous_month_revenue
    FROM monthly_revenue
)

SELECT
    region,
    month,
    monthly_revenue,
    previous_month_revenue,
    ROUND(
        (((monthly_revenue - previous_month_revenue)
        / previous_month_revenue) * 100)::numeric,
        2
    ) AS revenue_growth_percent
FROM growth
WHERE previous_month_revenue IS NOT NULL
ORDER BY revenue_growth_percent DESC
LIMIT 1;


--Average target achievement percentage per salesperson
SELECT
    s.salesperson_name,
    ROUND(
        AVG(t.achievement_pct),
        2
    ) AS average_target_achievement_percent
FROM public_staging.stg_targets t
JOIN public_staging.stg_salespersons s
    ON t.salesperson_id = s.salesperson_id
GROUP BY s.salesperson_name
ORDER BY average_target_achievement_percent DESC;

--Distributor with the highest return rate
SELECT
    distributor_name,
    COUNT(*) AS total_transactions,
    SUM(
        CASE
            WHEN transaction_status = 'Returned' THEN 1
            ELSE 0
        END
    ) AS returned_transactions,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN transaction_status = 'Returned' THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS return_rate_percent
FROM public_marts.mart_sales_performance
GROUP BY distributor_name
ORDER BY return_rate_percent DESC
LIMIT 1;

--Rolling three-month revenue trend by product category
WITH monthly_revenue AS (
    SELECT
        year,
        month,
        category,
        SUM(revenue_ngn) AS monthly_revenue
    FROM public_marts.mart_sales_performance
    GROUP BY year, month, category
)

SELECT
    year,
    month,
    category,
    monthly_revenue,
    ROUND(
        AVG(monthly_revenue) OVER (
            PARTITION BY category
            ORDER BY year, month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        )::numeric,
        2
    ) AS rolling_3_month_revenue
FROM monthly_revenue
ORDER BY category, year, month;