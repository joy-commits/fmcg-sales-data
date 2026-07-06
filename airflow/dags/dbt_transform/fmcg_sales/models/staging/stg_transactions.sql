select
    "Transaction Id" as transaction_id,
    "Transaction Date"::date as transaction_date,
    "Product Id" as product_id,
    coalesce("Distributor Id",'UNKNOWN') as distributor_id,
    "Salesperson Id" as salesperson_id,
    "Quantity" as quantity,
    "Unit Price Ngn" as unit_price_ngn,
    coalesce("Discount Pct",0) as discount_pct,
    coalesce("Discount Amount Ngn",0) as discount_amount_ngn,
    coalesce("Revenue Ngn",0) as revenue_ngn,
    coalesce("Cogs Ngn",0) as cogs_ngn,
    coalesce("Gross Profit Ngn",0) as gross_profit_ngn,
    trim("Payment Method") as payment_method,
    trim("Delivery Status") as delivery_status,
    trim("Transaction Status") as transaction_status,
    "Notes" as notes
from {{ source('public','transactions') }}
where "Transaction Id" is not null