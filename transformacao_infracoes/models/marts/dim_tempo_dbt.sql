{{ config(materialized='table') }}

-- fixação de tipo de dado
WITH base AS (
    SELECT DISTINCT 
        data_infracao::DATE AS data_infracao
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
    END AS dia_semana,

    -- LÓGICA DE FERIADOS ADICIONADA: Verifica se é feriado fixo ou móvel (2022 a 2024)
    CASE 
        -- Feriados Fixos
        WHEN EXTRACT(MONTH FROM data_infracao) = 1 AND EXTRACT(DAY FROM data_infracao) = 1 THEN TRUE
        WHEN EXTRACT(MONTH FROM data_infracao) = 4 AND EXTRACT(DAY FROM data_infracao) = 21 THEN TRUE
        WHEN EXTRACT(MONTH FROM data_infracao) = 5 AND EXTRACT(DAY FROM data_infracao) = 1 THEN TRUE
        WHEN EXTRACT(MONTH FROM data_infracao) = 9 AND EXTRACT(DAY FROM data_infracao) = 7 THEN TRUE
        WHEN EXTRACT(MONTH FROM data_infracao) = 10 AND EXTRACT(DAY FROM data_infracao) = 12 THEN TRUE
        WHEN EXTRACT(MONTH FROM data_infracao) = 11 AND EXTRACT(DAY FROM data_infracao) = 2 THEN TRUE
        WHEN EXTRACT(MONTH FROM data_infracao) = 11 AND EXTRACT(DAY FROM data_infracao) = 15 THEN TRUE
        WHEN EXTRACT(MONTH FROM data_infracao) = 12 AND EXTRACT(DAY FROM data_infracao) = 25 THEN TRUE
        -- Feriados Móveis 2022
        WHEN EXTRACT(YEAR FROM data_infracao) = 2022 AND EXTRACT(MONTH FROM data_infracao) = 3 AND EXTRACT(DAY FROM data_infracao) = 1 THEN TRUE
        WHEN EXTRACT(YEAR FROM data_infracao) = 2022 AND EXTRACT(MONTH FROM data_infracao) = 4 AND EXTRACT(DAY FROM data_infracao) = 15 THEN TRUE
        WHEN EXTRACT(YEAR FROM data_infracao) = 2022 AND EXTRACT(MONTH FROM data_infracao) = 4 AND EXTRACT(DAY FROM data_infracao) = 17 THEN TRUE
        WHEN EXTRACT(YEAR FROM data_infracao) = 2022 AND EXTRACT(MONTH FROM data_infracao) = 6 AND EXTRACT(DAY FROM data_infracao) = 16 THEN TRUE
        -- Feriados Móveis 2023
        WHEN EXTRACT(YEAR FROM data_infracao) = 2023 AND EXTRACT(MONTH FROM data_infracao) = 2 AND EXTRACT(DAY FROM data_infracao) = 21 THEN TRUE
        WHEN EXTRACT(YEAR FROM data_infracao) = 2023 AND EXTRACT(MONTH FROM data_infracao) = 4 AND EXTRACT(DAY FROM data_infracao) = 7 THEN TRUE
        WHEN EXTRACT(YEAR FROM data_infracao) = 2023 AND EXTRACT(MONTH FROM data_infracao) = 4 AND EXTRACT(DAY FROM data_infracao) = 9 THEN TRUE
        WHEN EXTRACT(YEAR FROM data_infracao) = 2023 AND EXTRACT(MONTH FROM data_infracao) = 6 AND EXTRACT(DAY FROM data_infracao) = 8 THEN TRUE
        -- Feriados Móveis 2024
        WHEN EXTRACT(YEAR FROM data_infracao) = 2024 AND EXTRACT(MONTH FROM data_infracao) = 2 AND EXTRACT(DAY FROM data_infracao) = 13 THEN TRUE
        WHEN EXTRACT(YEAR FROM data_infracao) = 2024 AND EXTRACT(MONTH FROM data_infracao) = 3 AND EXTRACT(DAY FROM data_infracao) = 29 THEN TRUE
        WHEN EXTRACT(YEAR FROM data_infracao) = 2024 AND EXTRACT(MONTH FROM data_infracao) = 3 AND EXTRACT(DAY FROM data_infracao) = 31 THEN TRUE
        WHEN EXTRACT(YEAR FROM data_infracao) = 2024 AND EXTRACT(MONTH FROM data_infracao) = 5 AND EXTRACT(DAY FROM data_infracao) = 30 THEN TRUE
        ELSE FALSE
    END AS is_feriado
FROM base