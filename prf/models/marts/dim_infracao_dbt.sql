{{ config(materialized='table') }}

WITH base AS (
    -- DISTINCT ON (codigo): pega 1 linha por código de infração
    -- (o mesmo código sempre carrega a mesma descrição e enquadramento)
    SELECT DISTINCT ON (codigo_infracao)
        codigo_infracao,
        descricao_abreviada_infracao,
        enquadramento_infracao,
        inicio_vigencia_infracao
    FROM {{ ref('int_multas_preparados') }}
    WHERE codigo_infracao <> 'N/I'
    ORDER BY codigo_infracao
)

SELECT
    ROW_NUMBER() OVER (ORDER BY codigo_infracao) AS id_infracao_sk,

    codigo_infracao,
    descricao_abreviada_infracao AS descricao_infracao,
    enquadramento_infracao,

    -- gravidade derivada do texto do enquadramento (classificação do CTB)
    CASE
        WHEN UPPER(enquadramento_infracao) LIKE '%GRAVISSIMA%'
          OR UPPER(enquadramento_infracao) LIKE '%GRAVÍSSIMA%' THEN 'Gravíssima'
        WHEN UPPER(enquadramento_infracao) LIKE '%GRAVE%'      THEN 'Grave'
        WHEN UPPER(enquadramento_infracao) LIKE '%MEDIA%'
          OR UPPER(enquadramento_infracao) LIKE '%MÉDIA%'      THEN 'Média'
        WHEN UPPER(enquadramento_infracao) LIKE '%LEVE%'       THEN 'Leve'
        ELSE 'Não classificada'
    END AS gravidade,

    inicio_vigencia_infracao AS inicio_vigencia
FROM base