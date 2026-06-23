-- Extração de campos do campo description da invoice (texto livre)
select
    c.case_id,
    c.ref_number,
    c.client_ref_number,

    try_cast(ca.case_attribute_value as int)    as live_dpd,

    i.invoice_id,
    i.invoice_number,
    cast(i.update_date as date)                 as update_date,
    i.original_capital                          as invoice_original_capital,
    i.actual_capital                            as invoice_actual_capital,

    -- codigo_titulo: prefixo NN: ou Titulo:
    ltrim(rtrim(
        case
            when i.description like '%NN:%' then
                substring(i.description, charindex('NN:', i.description) + 3,
                    charindex(char(10), i.description + char(10), charindex('NN:', i.description))
                    - (charindex('NN:', i.description) + 3))
            when i.description like '%Titulo:%' then
                substring(i.description, charindex('Titulo:', i.description) + 7,
                    charindex(char(10), i.description + char(10), charindex('Titulo:', i.description))
                    - (charindex('Titulo:', i.description) + 7))
        end
    )) as codigo_titulo,

    -- competencia raw (dd.mm.yyyy)
    ltrim(rtrim(
        substring(i.description,
            charindex('Competencia:', i.description) + len('Competencia:'),
            patindex('%[' + char(13) + char(10) + ']%',
                substring(i.description,
                    charindex('Competencia:', i.description) + len('Competencia:'), 50)
                + char(13)) - 1)
    )) as competencia_raw,

    -- vencimento raw (dd.mm.yyyy)
    ltrim(rtrim(
        substring(i.description,
            charindex('Vencimento:', i.description) + len('Vencimento:'),
            patindex('%[' + char(13) + char(10) + ']%',
                substring(i.description,
                    charindex('Vencimento:', i.description) + len('Vencimento:'), 50)
                + char(13)) - 1)
    )) as vencimento_raw,

    -- dpd: aceita negativos (titulos a vencer)
    try_cast(
        left(
            ltrim(substring(i.description, charindex('DPD:', i.description) + 4, 20)),
            patindex('%[^0-9\-]%',
                ltrim(substring(i.description, charindex('DPD:', i.description) + 4, 20)) + 'X'
            ) - 1
        )
    as int) as dpd_invoice

from {{ ref('stg_casos_516') }} c
inner join {{ source('dtdi', 'invoice') }} i
    on i.case_id = c.case_id
left join {{ source('dtdi', 'case_attribute') }} ca
    on ca.case_id = c.case_id
   and ca.case_attribute_type_id = 560
