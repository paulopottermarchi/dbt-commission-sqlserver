-- CPF/CNPJ via cadeia case → debtor → Persons
select
    c.case_id,
    c.case_statute_id,
    p.persons_born_number,
    case
        when len(replace(replace(replace(replace(p.persons_born_number, '.', ''), '-', ''), '/', ''), ' ', '')) > 11
            then 'CNPJ'
        else 'CPF'
    end as documento_tipo
from {{ ref('stg_casos_516') }} c
inner join {{ source('dtdi', 'debtor') }} d
    on d.debtor_id = c.debtor_id
inner join {{ source('dtdi', 'Persons') }} p
    on p.persons_id = d.Persons_id
