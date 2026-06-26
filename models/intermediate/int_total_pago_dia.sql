-- Total pago por case_id + update_date
-- Usado para calcular payed_capital proporcional entre invoices do mesmo dia
select
    case_id,
    update_date             as update_dia,
    sum(valor_pago_invoice) as valor_pago_total_dia
from {{ ref('int_invoice_agregada') }}
where valor_pago_invoice > 0
group by case_id, update_date
