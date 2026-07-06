select
    "Record Id" as record_id,
    "Salesperson Id" as salesperson_id,
    "Year" as year,
    "Month" as month,
    trim("Region") as region,
    "Target Revenue Ngn" as target_revenue_ngn,
    "Actual Revenue Ngn" as actual_revenue_ngn,
    case
        when "Target Revenue Ngn" = 0 then 0
        else round(
            (("Actual Revenue Ngn" / "Target Revenue Ngn") * 100)::numeric,
            2
        )
    end as achievement_pct
from {{ source('public','monthly_targets') }}