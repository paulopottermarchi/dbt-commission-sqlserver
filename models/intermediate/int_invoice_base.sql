-- Converte raws em DATE aplicando correção de inversão dd/mm
-- quando mês do vencimento != mês da competência
select
    r.case_id,
    r.ref_number,
    r.client_ref_number,
    r.live_dpd,
    r.invoice_id,
    r.invoice_number,
    r.update_date,
    r.invoice_original_capital,
    r.invoice_actual_capital,
    r.codigo_titulo,
    r.dpd_invoice,

    try_convert(date, r.competencia_raw, 104)  as competencia_description,
    try_convert(date, r.vencimento_raw,  104)  as vencimento_original,

    -- vencimento corrigido:
    -- 1) se mes vencimento != mes competencia → inverte dd/mm do vencimento
    -- 2) se vencimento NULL → inverte dd/mm da competencia como fallback
    coalesce(
        try_convert(date,
            case
                when substring(r.vencimento_raw, 4, 2) <> substring(r.competencia_raw, 4, 2)
                then
                    substring(r.vencimento_raw, 4, 2) + '.' +
                    substring(r.vencimento_raw, 1, 2) + '.' +
                    substring(r.vencimento_raw, 7, 4)
                else r.vencimento_raw
            end
        , 104),
        try_convert(date,
            substring(r.competencia_raw, 4, 2) + '.' +
            substring(r.competencia_raw, 1, 2) + '.' +
            substring(r.competencia_raw, 7, 4)
        , 104)
    ) as vencimento_description

from {{ ref('stg_invoice_raw') }} r
