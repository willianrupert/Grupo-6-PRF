-- view pq é mais eficiente
{{
    config(
        materialized='view'
    )
}}

-- ai vamos pegar o nosso modelo de staging
with stg_multas AS (
        SELECT * FROM {{ ref('stg_multas_unificados') }}
    ),

    tratamento_nulos_tipos AS (
        SELECT
    ),