-- Pagamentos do mês atual do cliente 516
select
    p.case_id,
    p.payment_id,
    p.payment_date,
    p.payed_capital,
    p.payment_insert_date,
    p.payment_insert_time,
    p.pay_insert_filename,
    p.payment_insert_user
from {{ source('dtdi', 'vw_cases_payment_information') }} p
where exists (
    select 1 from {{ ref('stg_casos_516') }} c where c.case_id = p.case_id
)
and month(p.payment_date) = month(getdate())
and year(p.payment_date)  = year(getdate())
