-- Casos ativos do cliente 516
select
    case_id,
    ref_number,
    client_ref_number,
    case_statute_id,
    debtor_id
from {{ source('dtdi', 'case') }}
where client_id = 516
