{{ config(materialized='view') }}

SELECT 
    *
FROM {{ source('prf_raw_data', 'raw_multas') }}