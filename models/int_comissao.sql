-- Faixas de comissão vigentes para o cliente 516
select
    dpd_on_payment_day_from,
    dpd_on_payment_day_to,
    commission_rate
from {{ source('dtdi', 'client_settings_commission_by_dpd') }}
where client_id = 516
  and cast(getdate() as date) between date_from and date_to
