-- PTP mais recente por caso (MAX de promise_date, promise_capital, contact_date)
select
    case_id,
    max(promise_date)    as promise_date,
    max(promise_capital) as promise_capital,
    max(contact_date)    as contact_date
from {{ source('reports', 'vw_ptp_ptpr_overview') }}
where client_id = 516
group by case_id
