-- =============================================================================
-- Análise: Multas por UF e Ano
-- Objetivo: Ver a evolução temporal das multas por Estado (ranking + tendência)
-- Tabelas: fato_multa_dbt ⟶ dim_localizacao_dbt, dim_tempo_dbt
-- =============================================================================

SELECT
    loc.uf_infracao,
    tempo.ano,
    tempo.trimestre,

    COUNT(fato.numero_auto)  AS total_multas,

    -- Variação em relação ao trimestre anterior (análise de tendência)
    COUNT(fato.numero_auto)
        - LAG(COUNT(fato.numero_auto)) OVER (
            PARTITION BY loc.uf_infracao
            ORDER BY tempo.ano, tempo.trimestre
        )                    AS variacao_trimestre_anterior

FROM {{ ref('fato_multa_dbt') }} AS fato
INNER JOIN {{ ref('dim_localizacao_dbt') }} AS loc
    ON fato.id_localizacao_sk = loc.id_localizacao_sk
INNER JOIN {{ ref('dim_tempo_dbt') }} AS tempo
    ON fato.id_tempo_sk = tempo.id_tempo_sk

GROUP BY
    loc.uf_infracao,
    tempo.ano,
    tempo.trimestre

ORDER BY
    tempo.ano  DESC,
    tempo.trimestre DESC,
    total_multas DESC
