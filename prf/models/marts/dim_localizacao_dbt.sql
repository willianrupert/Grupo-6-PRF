-- ele usa isso para saber que deve salvar como uma tabela no postgress
-- esse arquivo será construido dps de int multas preparados
{{ config(materialized='table') }}

WITH base AS (
    SELECT * FROM {{ ref('int_multas_preparados') }}
),

locais_unicos AS (
    SELECT DISTINCT
        municipio,
        uf_infracao AS uf
    FROM base
    WHERE municipio IS NOT NULL AND uf_infracao IS NOT NULL
)

SELECT
    ROW_NUMBER() OVER (ORDER BY uf, municipio) AS id_localidade_sk,
    municipio,
    uf
FROM locais_unicos