{{ config(materialized='table') }}

WITH base AS (
    -- puxa do modelo intermediário, onde os dados já foram limpos e normalizados
    SELECT DISTINCT
        descricao_especie_veiculo,
        descricao_tipo_veiculo,
        descricao_marca_veiculo,
        descricao_modelo_veiculo,
        indicador_abordagem,
        indicador_veiculo_estrangeiro,
        uf_placa
    FROM {{ ref('int_multas_preparados') }}
    WHERE descricao_especie_veiculo IS NOT NULL
)

SELECT
    -- mesma lógica de SK da dim_tempo: ordena e carimba 1, 2, 3...
    ROW_NUMBER() OVER (
        ORDER BY descricao_especie_veiculo, descricao_tipo_veiculo,
                 descricao_marca_veiculo, descricao_modelo_veiculo
    ) AS id_veiculo_sk,

    descricao_especie_veiculo  AS especie_veiculo,
    descricao_tipo_veiculo     AS tipo_veiculo,
    descricao_marca_veiculo    AS marca_veiculo,
    descricao_modelo_veiculo   AS modelo_veiculo,

    -- decodifica o código de 1 letra para texto legível
    CASE indicador_abordagem
        WHEN 'A' THEN 'Abordagem presencial'
        WHEN 'E' THEN 'Equipamento eletrônico'
        WHEN 'D' THEN 'Denúncia'
        ELSE 'Não informado'
    END AS tipo_abordagem,

    indicador_veiculo_estrangeiro,  -- já vem como 'S'/'N' do intermediário
    uf_placa                         -- já vem normalizada do intermediário
FROM base