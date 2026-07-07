{{ config(
    materialized='table'
) }}

select
    t.transaction_id,
    t.transaction_date,
    d.year,
    d.quarter,
    d.month,
    d.month_name,
    p.product_name,
    p.category,
    dist.distributor_name,
    dist.region,
    s.salesperson_name,
    s.salesperson_id,
    s.team,
    t.quantity,
    t.unit_price_ngn,
    t.discount_amount_ngn,
    t.revenue_ngn,
    t.cogs_ngn,
    t.gross_profit_ngn,
    t.payment_method,
    t.delivery_status,
    t.transaction_status
from {{ ref('stg_transactions') }} t
left join {{ ref('stg_products') }} p
on t.product_id = p.product_id
left join {{ ref('stg_distributors') }} dist
on t.distributor_id = dist.distributor_id
left join {{ ref('stg_salespersons') }} s
on t.salesperson_id = s.salesperson_id
left join {{ ref('stg_date') }} d
on cast(t.transaction_date as date) = cast(d.date as date)