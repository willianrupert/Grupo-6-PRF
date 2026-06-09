{{ config(materialized='table') }}

WITH base AS (
    SELECT DISTINCT
        descricao_especie_veiculo,
        descricao_tipo_veiculo,
        descricao_marca_veiculo,
        descricao_modelo_veiculo,
        indicador_veiculo_estrangeiro,
        uf_placa
    FROM {{ ref('int_multas_preparados') }}
    WHERE descricao_especie_veiculo IS NOT NULL
)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY descricao_especie_veiculo, descricao_tipo_veiculo,
                 descricao_marca_veiculo, descricao_modelo_veiculo
    ) AS id_veiculo_sk,

    descricao_especie_veiculo  AS especie_veiculo,
    descricao_tipo_veiculo     AS tipo_veiculo,
    descricao_marca_veiculo    AS marca_veiculo,
    descricao_modelo_veiculo   AS modelo_veiculo,

    indicador_veiculo_estrangeiro,
    uf_placa
FROM base