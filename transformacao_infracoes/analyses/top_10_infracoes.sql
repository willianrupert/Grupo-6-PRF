-- =============================================================================
-- Análise: Top 10 Infrações Mais Cometidas
-- Objetivo: Identificar quais infrações geram mais multas, com gravidade e % do total
-- Tabelas: fato_multa_dbt ⟶ dim_infracao_dbt
-- =============================================================================

SELECT
    inf.codigo_infracao,
    inf.descricao_infracao,
    inf.gravidade,
    inf.enquadramento_infracao,

    COUNT(fato.numero_auto)                                          AS total_multas,
    ROUND(
        COUNT(fato.numero_auto) * 100.0
        / SUM(COUNT(fato.numero_auto)) OVER ()
    , 2)                                                             AS pct_do_total

FROM {{ ref('fato_multa_dbt') }} AS fato
INNER JOIN {{ ref('dim_infracao_dbt') }} AS inf
    ON fato.id_infracao_sk = inf.id_infracao_sk

GROUP BY
    inf.codigo_infracao,
    inf.descricao_infracao,
    inf.gravidade,
    inf.enquadramento_infracao

ORDER BY total_multas DESC
LIMIT 10
