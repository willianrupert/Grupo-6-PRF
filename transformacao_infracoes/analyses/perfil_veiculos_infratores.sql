-- =============================================================================
-- Análise: Perfil dos Veículos Infratores
-- Objetivo: Entender quais espécies e tipos de veículo acumulam mais multas
-- Tabelas: fato_multa_dbt ⟶ dim_veiculo_dbt
-- =============================================================================

SELECT
    veic.especie_veiculo,
    veic.tipo_veiculo,
    veic.tipo_abordagem,

    -- Veículos estrangeiros têm padrão diferente?
    veic.indicador_veiculo_estrangeiro,

    COUNT(fato.numero_auto)                                          AS total_multas,
    ROUND(
        COUNT(fato.numero_auto) * 100.0
        / SUM(COUNT(fato.numero_auto)) OVER ()
    , 2)                                                             AS pct_do_total

FROM {{ ref('fato_multa_dbt') }} AS fato
INNER JOIN {{ ref('dim_veiculo_dbt') }} AS veic
    ON fato.id_veiculo_sk = veic.id_veiculo_sk

GROUP BY
    veic.especie_veiculo,
    veic.tipo_veiculo,
    veic.tipo_abordagem,
    veic.indicador_veiculo_estrangeiro

ORDER BY total_multas DESC
