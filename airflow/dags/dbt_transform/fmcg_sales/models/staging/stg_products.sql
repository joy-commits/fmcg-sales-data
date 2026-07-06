select
    "Product Id" as product_id,
    trim("Product Name") as product_name,
    trim("Category") as category,
    "Unit Price Ngn" as unit_price_ngn,
    "Unit Cost Ngn" as unit_cost_ngn,
    "Pack Size" as pack_size,
    "Is Active" as is_active
from {{ source('public','products') }}