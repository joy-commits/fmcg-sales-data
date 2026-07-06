select
    "Distributor Id" as distributor_id,
    trim("Distributor Name") as distributor_name,
    trim("Region") as region,
    trim("City") as city,
    trim("Outlet Type") as outlet_type,
    "Onboarding Date"::date as onboarding_date,
    "Is Active" as is_active
from {{ source('public','distributors') }}
union all
select
    'UNKNOWN' as distributor_id,
    'Unknown Distributor' as distributor_name,
    'Unknown' as region,
    null::text as city,
    null::text as outlet_type,
    null::date as onboarding_date,
    false as is_active
-- Added an 'UNKNOWN' distributor to preserve transactions with missing distributor IDs