{{ config(materialized='table') }}

with base as (
    select
        codigo_infracao,
        max(descricao_abreviada_infracao) as descricao_abreviada_infracao,
        max(enquadramento_infracao) as enquadramento_infracao
    from {{ ref('int_multas_preparados') }}
    group BY codigo_infracao
)

select
    row_number() over (order by codigo_infracao) as id_infracao_sk,
    codigo_infracao,
    descricao_abreviada_infracao as descricao_infracao,
    enquadramento_infracao
from base