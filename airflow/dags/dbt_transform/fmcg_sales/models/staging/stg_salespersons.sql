select
    "Salesperson Id" as salesperson_id,
    trim("Salesperson Name") as salesperson_name,
    trim("Region") as region,
    trim("Team") as team,
    "Hire Date"::date as hire_date,
    "Monthly Target Ngn" as monthly_target_ngn
from {{ source('public','salespersons') }}