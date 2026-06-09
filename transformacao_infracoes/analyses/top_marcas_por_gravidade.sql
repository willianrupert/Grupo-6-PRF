-- =============================================================================
-- Análise: Marcas Campeãs de Infrações (Top 10 Marcas x Gravidade)
-- Objetivo: Descobrir quais marcas/modelos lideram as infrações por gravidade
-- Tabelas: fato_multa_dbt ⟶ dim_veiculo_dbt, dim_infracao_dbt
-- Insight útil para campanhas educativas segmentadas por perfil de veículo
-- =============================================================================

WITH ranking AS (
    SELECT
        veic.descricao_marca_veiculo,
        veic.descricao_modelo_veiculo,

        COUNT(fato.numero_auto)  AS total_multas,

        ROW_NUMBER() OVER (
            ORDER BY COUNT(fato.numero_auto) DESC
        ) AS rank_geral

    FROM {{ ref('fato_multa_dbt') }} AS fato
    INNER JOIN {{ ref('dim_infrator_dbt') }} AS veic
        ON fato.id_infrator_sk = veic.id_infrator_sk

    WHERE veic.descricao_marca_veiculo IS NOT NULL AND veic.descricao_marca_veiculo != 'NÃO INFORMADO'

    GROUP BY
        veic.descricao_marca_veiculo,
        veic.descricao_modelo_veiculo
)

SELECT
    rank_geral  AS ranking,
    descricao_marca_veiculo,
    descricao_modelo_veiculo,
    total_multas

FROM ranking
WHERE rank_geral <= 10

ORDER BY
    rank_geral
