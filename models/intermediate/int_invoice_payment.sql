-- Match sequencial: 1º pagamento → 1ª invoice com desconto, 2º → 2ª, etc.
-- Garante que cada payment_id vai para exatamente uma invoice
-- e nenhuma invoice sem desconto recebe pagamento

with pg_ranked as (
    select
        case_id,
        payment_id,
        payment_date,
        payed_capital,
        payment_insert_date,
        payment_insert_time,
        pay_insert_filename,
        payment_insert_user,
        row_number() over (
            partition by case_id
            order by payment_date asc, payment_id asc
        ) as rn_pg
    from {{ ref('int_pagamentos') }}
),

inv_ranked as (
    select
        invoice_id,
        case_id,
        invoice_number,
        update_date,
        row_number() over (
            partition by case_id
            order by invoice_number asc
        ) as rn_inv
    from {{ ref('int_invoice_agregada') }}
    where valor_pago_invoice > 0
)

select
    inv.invoice_id,
    inv.case_id,
    pg.payment_id,
    pg.payment_date,
    pg.payed_capital,
    pg.payment_insert_date,
    pg.payment_insert_time,
    pg.pay_insert_filename,
    pg.payment_insert_user
from pg_ranked pg
inner join inv_ranked inv
    on inv.case_id = pg.case_id
   and inv.rn_inv  = pg.rn_pg
