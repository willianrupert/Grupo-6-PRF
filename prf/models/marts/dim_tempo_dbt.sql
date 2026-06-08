{{ config(materialized='table') }}

WITH base AS (
    SELECT DISTINCT 
        data_infracao 
    -- aponta para o modelo onde limpamos os dados das multas
    FROM {{ ref('int_multas_preparados') }} 
    WHERE data_infracao IS NOT NULL
)

SELECT
    -- SK sequencial baseada na ordenação da data
    -- OVER basicamente pega todas as datas de infração distintas da sua CTE base.
    -- Colocá-las em ordem cronológica (da mais antiga para a mais recente).
    -- E só depois disso, o ROW_NUMBER() vai passar carimbando o número 1 na primeira data, o número 2 na segunda...
    ROW_NUMBER() OVER (ORDER BY data_infracao) AS id_tempo_sk,
    data_infracao,
    CAST(EXTRACT(DAY FROM data_infracao) AS INTEGER) AS dia,
    CAST(EXTRACT(MONTH FROM data_infracao) AS INTEGER) AS mes,
    CAST(EXTRACT(YEAR FROM data_infracao) AS INTEGER) AS ano,
    CAST(EXTRACT(QUARTER FROM data_infracao) AS INTEGER) AS trimestre,
    
    -- mapeamento manual como a gente fez em int_multas_preparados
    CASE EXTRACT(ISODOW FROM data_infracao)
        WHEN 1 THEN 'Segunda-feira'
        WHEN 2 THEN 'Terça-feira'
        WHEN 3 THEN 'Quarta-feira'
        WHEN 4 THEN 'Quinta-feira'
        WHEN 5 THEN 'Sexta-feira'
        WHEN 6 THEN 'Sábado'
        WHEN 7 THEN 'Domingo'
    END AS dia_semana
FROM base