-- =============================================================================
-- Análise: Infrações em Feriados vs. Dias Normais
-- Objetivo: Comparar o volume e o perfil das multas em feriados x dias úteis
-- Tabelas: fato_multa_dbt ⟶ dim_tempo_dbt, dim_infracao_dbt
-- Insight: Feriados concentram más infrações de excesso de velocidade?
-- =============================================================================

SELECT
    tempo.is_feriado,
    tempo.dia_semana,
    inf.gravidade,

    COUNT(fato.numero_auto)                                          AS total_multas,

    -- Soma do excesso verificado (para infrações de velocidade)
    ROUND(AVG(fato.excesso_verificado), 2)                          AS media_excesso_velocidade_kmh

FROM {{ ref('fato_multa_dbt') }} AS fato
INNER JOIN {{ ref('dim_tempo_dbt') }} AS tempo
    ON fato.id_tempo_sk = tempo.id_tempo_sk
INNER JOIN {{ ref('dim_infracao_dbt') }} AS inf
    ON fato.id_infracao_sk = inf.id_infracao_sk

GROUP BY
    tempo.is_feriado,
    tempo.dia_semana,
    inf.gravidade

ORDER BY
    tempo.is_feriado DESC,
    total_multas DESC
