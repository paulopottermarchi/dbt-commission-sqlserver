-- Remove duplicatas de invoices com mesmo codigo_titulo no mesmo caso
-- Mantém a invoice com DPD não negativo (título mais recente/correto)
-- Invoices sem codigo_titulo passam sem deduplicação

select * from (
    select
        b.*,
        row_number() over (
            partition by b.case_id, b.codigo_titulo
            order by
                case when b.dpd_invoice >= 0 then 0 else 1 end,
                b.dpd_invoice desc
        ) as rn_titulo
    from {{ ref('int_invoice_base') }} b
    where b.codigo_titulo is not null
      and b.codigo_titulo <> ''
) x
where rn_titulo = 1

union all

select b.*, 1 as rn_titulo
from {{ ref('int_invoice_base') }} b
where b.codigo_titulo is null
   or b.codigo_titulo = ''
