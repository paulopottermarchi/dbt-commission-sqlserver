-- Fact table: comissionamento Dentalpar (cliente 516)
-- Filtra invoices com pagamento no mês atual
-- Calcula payed_capital proporcional e valor_comissao por faixa de DPD

select
    b.case_id,
    b.ref_number,
    b.client_ref_number,
    b.invoice_id,
    b.invoice_number,
    b.original_capital_total,
    b.actual_capital_total,
    b.valor_pago,
    b.status_pagamento,
    b.competencia,
    b.vencimento_original,
    b.data_vencimento,
    b.codigo_titulo,
    b.dpd_invoice,
    b.live_dpd,
    b.dpd_final,
    b.fase,
    b.update_date,

    p.promise_date,
    p.promise_capital,
    p.contact_date,

    d.case_statute_id,
    d.persons_born_number,
    d.documento_tipo,

    pg.payment_id,
    pg.payment_date,

    pg.payed_capital                                                              as payed_capital_original,

    round(
        pg.payed_capital * (b.valor_pago_invoice / tpd.valor_pago_total_dia)
    , 2)                                                                          as payed_capital_proporcional,

    cm.commission_rate,

    round(
        round(pg.payed_capital * (b.valor_pago_invoice / tpd.valor_pago_total_dia), 2)
        * cm.commission_rate
    , 2)                                                                          as valor_comissao,

    pg.payment_insert_date,
    pg.payment_insert_time,
    pg.pay_insert_filename,
    pg.payment_insert_user,

    -- metadados de controle
    cast(getdate() as date)                                                       as data_carga

from {{ ref('int_invoice_agregada') }} b
left join {{ ref('int_ptp') }} p
    on p.case_id = b.case_id
left join {{ ref('int_devedores') }} d
    on d.case_id = b.case_id
left join {{ ref('int_invoice_payment') }} pg
    on pg.invoice_id = b.invoice_id
left join {{ ref('int_total_pago_dia') }} tpd
    on tpd.case_id    = b.case_id
   and tpd.update_dia = b.update_date
left join {{ ref('int_comissao') }} cm
    on b.dpd_final between cm.dpd_on_payment_day_from and cm.dpd_on_payment_day_to

where
    b.valor_pago > 0
    and (
        (month(b.update_date) = month(getdate()) and year(b.update_date) = year(getdate()))
        or pg.payment_id is not null
    )
