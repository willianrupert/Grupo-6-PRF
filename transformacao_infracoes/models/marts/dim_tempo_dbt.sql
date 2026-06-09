{{ config(materialized='table') }}

with base as (
    select distinct 
        data_infracao::date as data_infracao
    from {{ ref('int_multas_preparados') }} 
    where data_infracao is not null
)

select
    row_number() over (order by data_infracao) as id_tempo_sk,
    data_infracao,
    cast(extract(day from data_infracao) as integer) as dia,
    cast(extract(month from data_infracao) as integer) as mes,
    cast(extract(year from data_infracao) as integer) as ano,
    cast(extract(quarter from data_infracao) as integer) as trimestre,
    
    case extract(isodow from data_infracao)
        when 1 then 'Segunda-feira'
        when 2 then 'Terça-feira'
        when 3 then 'Quarta-feira'
        when 4 then 'Quinta-feira'
        when 5 then 'Sexta-feira'
        when 6 then 'Sábado'
        when 7 then 'Domingo'
    end as dia_semana,

    case 
        -- Feriados Fixos Brasileiros
        when extract(month from data_infracao) = 1 and extract(day from data_infracao) = 1 then true
        when extract(month from data_infracao) = 4 and extract(day from data_infracao) = 21 then true
        when extract(month from data_infracao) = 5 and extract(day from data_infracao) = 1 then true
        when extract(month from data_infracao) = 9 and extract(day from data_infracao) = 7 then true
        when extract(month from data_infracao) = 10 and extract(day from data_infracao) = 12 then true
        when extract(month from data_infracao) = 11 and extract(day from data_infracao) = 2 then true
        when extract(month from data_infracao) = 11 and extract(day from data_infracao) = 15 then true
        when extract(month from data_infracao) = 12 and extract(day from data_infracao) = 25 then true
        -- Feriados Móveis 2022
        when extract(year from data_infracao) = 2022 and extract(month from data_infracao) = 3 and extract(day from data_infracao) = 1 then true
        when extract(year from data_infracao) = 2022 and extract(month from data_infracao) = 4 and extract(day from data_infracao) = 15 then true
        when extract(year from data_infracao) = 2022 and extract(month from data_infracao) = 4 and extract(day from data_infracao) = 17 then true
        when extract(year from data_infracao) = 2022 and extract(month from data_infracao) = 6 and extract(day from data_infracao) = 16 then true
        -- Feriados Móveis 2023
        when extract(year from data_infracao) = 2023 and extract(month from data_infracao) = 2 and extract(day from data_infracao) = 21 then true
        when extract(year from data_infracao) = 2023 and extract(month from data_infracao) = 4 and extract(day from data_infracao) = 7 then true
        when extract(year from data_infracao) = 2023 and extract(month from data_infracao) = 4 and extract(day from data_infracao) = 9 then true
        when extract(year from data_infracao) = 2023 and extract(month from data_infracao) = 6 and extract(day from data_infracao) = 8 then true
        -- Feriados Móveis 2024
        when extract(year from data_infracao) = 2024 and extract(month from data_infracao) = 2 and extract(day from data_infracao) = 13 then true
        when extract(year from data_infracao) = 2024 and extract(month from data_infracao) = 3 and extract(day from data_infracao) = 29 then true
        when extract(year from data_infracao) = 2024 and extract(month from data_infracao) = 3 and extract(day from data_infracao) = 31 then true
        when extract(year from data_infracao) = 2024 and extract(month from data_infracao) = 5 and extract(day from data_infracao) = 30 then true
        else false
    end as is_feriado
from base