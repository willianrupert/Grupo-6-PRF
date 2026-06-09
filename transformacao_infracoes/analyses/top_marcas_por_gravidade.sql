-- =============================================================================
-- Análise: Marcas Campeãs de Infrações (Top 10 Marcas x Gravidade)
-- Objetivo: Descobrir quais marcas/modelos lideram as infrações por gravidade
-- Tabelas: fato_multa_dbt ⟶ dim_veiculo_dbt, dim_infracao_dbt
-- Insight útil para campanhas educativas segmentadas por perfil de veículo
-- =============================================================================

WITH ranking AS (
    SELECT
        veic.marca_veiculo,
        veic.modelo_veiculo,
        inf.gravidade,

        COUNT(fato.numero_auto)  AS total_multas,

        ROW_NUMBER() OVER (
            PARTITION BY inf.gravidade
            ORDER BY COUNT(fato.numero_auto) DESC
        ) AS rank_por_gravidade

    FROM {{ ref('fato_multa_dbt') }} AS fato
    INNER JOIN {{ ref('dim_infrator_dbt') }} AS veic
        ON fato.id_infrator_sk = veic.id_infrator_sk
    INNER JOIN {{ ref('dim_infracao_dbt') }} AS inf
        ON fato.id_infracao_sk = inf.id_infracao_sk

    WHERE veic.marca_veiculo IS NOT NULL

    GROUP BY
        veic.marca_veiculo,
        veic.modelo_veiculo,
        inf.gravidade
)

SELECT
    gravidade,
    rank_por_gravidade  AS ranking,
    marca_veiculo,
    modelo_veiculo,
    total_multas

FROM ranking
WHERE rank_por_gravidade <= 10

ORDER BY
    gravidade,
    rank_por_gravidade
