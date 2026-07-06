{{ config(
    materialized='incremental',
    unique_key='transaction_id'
) }}

select
    distributor_name,
    region,
    count(transaction_id) as total_transactions,
    sum(revenue_ngn) as total_revenue,
    sum(gross_profit_ngn) as total_profit,
    avg(revenue_ngn) as average_revenue
from {{ ref('mart_sales_performance') }}
group by
    distributor_name,
    region