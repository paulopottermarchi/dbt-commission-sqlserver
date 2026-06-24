-- Agrega por case_id + invoice_id: capitais, status, dpd_final, fase
select
    b.case_id,
    b.ref_number,
    b.client_ref_number,
    b.invoice_id,
    b.invoice_number,

    sum(b.invoice_actual_capital)                              as actual_capital_total,
    sum(b.invoice_original_capital)                            as original_capital_total,
    sum(b.invoice_original_capital - b.invoice_actual_capital) as valor_pago,
    sum(b.invoice_original_capital - b.invoice_actual_capital) as valor_pago_invoice,

    case
        when sum(b.invoice_actual_capital) = 0
            then 'PAGO TOTAL'
        when sum(b.invoice_actual_capital) < sum(b.invoice_original_capital)
            then 'PAGO PARCIAL'
        else 'EM ABERTO'
    end as status_pagamento,

    max(b.live_dpd)                as live_dpd,
    max(b.dpd_invoice)             as dpd_invoice,
    max(b.competencia_description) as competencia,
    max(b.vencimento_original)     as vencimento_original,
    max(b.vencimento_description)  as data_vencimento,
    max(b.update_date)             as update_date,

    case
        when max(b.vencimento_description) is not null
            then datediff(day, max(b.vencimento_description), cast(getdate() as date))
        when max(b.dpd_invoice) is null
            then max(b.live_dpd)
        else max(b.dpd_invoice)
    end as dpd_final,

    string_agg(b.codigo_titulo, ',') as codigo_titulo,

    case
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 1    and 30    then 'A - 1 A 30 | 6%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 31   and 60    then 'B - 31 A 60 | 11%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 61   and 90    then 'C - 61 A 90 | 13%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 91   and 120   then 'D - 91 A 120 | 15%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 121  and 180   then 'E - 121 A 180 | 18%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 181  and 240   then 'F - 181 A 240 | 20%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 241  and 270   then 'G - 241 A 270 | 21%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 271  and 300   then 'H - 271 A 300 | 22%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 301  and 330   then 'I - 301 A 330 | 24%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 331  and 360   then 'J - 331 A 360 | 28%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 361  and 540   then 'K - 361 A 540 | 30%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 541  and 720   then 'L - 541 A 720 | 35%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 721  and 1440  then 'M - 721 A 1440 | 40%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 1441 and 1800  then 'N - 1441 A 1800 | 40%'
        when datediff(day, max(b.vencimento_description), cast(getdate() as date)) between 1801 and 99999 then 'O - 1801 A 99999 | 40%'
        else ''
    end as fase

from {{ ref('int_invoice_dedup') }} b
group by
    b.case_id,
    b.ref_number,
    b.client_ref_number,
    b.invoice_id,
    b.invoice_number
