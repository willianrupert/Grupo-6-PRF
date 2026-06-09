{{ config(materialized='table') }}

with locais_unicos as (
    select distinct
        uf_infracao as uf_infracao,
        br_infracao,
        km_infracao,
        municipio,
        regiao_infracao,
        sentido_trafego
    from {{ ref('int_multas_preparados') }}
)

select
    row_number() over (order by uf_infracao, municipio, br_infracao, km_infracao) as id_localizacao_sk,
    uf_infracao,
    br_infracao,
    km_infracao,
    municipio,
    regiao_infracao,
    sentido_trafego
from locais_unicos