select
    "Date"::date as date,
    "Year" as year,
    "Quarter" as quarter,
    "Month" as month,
    trim("Month Name") as month_name,
    "Week" as week,
    trim("Day Of Week") as day_of_week,
    "Is Weekend" as is_weekend,
    "Is Month End" as is_month_end
from {{ source('public','date_table') }}