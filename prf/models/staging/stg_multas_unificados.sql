-- Seria bom a gente perguntar se precisar disso, pq teoricamente o nosso já esta unificado
{{ config(materialized='view') }}

SELECT 
    *
FROM {{ source('prf_raw_data', 'raw_multas') }}