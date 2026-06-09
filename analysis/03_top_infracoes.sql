-- Quais são as infrações mais cometidas e qual o excesso de velocidade médio associado?
SELECT
    i."código da infração"           AS codigo_infracao,
    i."descrição abreviada infração" AS descricao_infracao,
    COUNT(*) AS total_autuacoes,
    ROUND(AVG(NULLIF(f."excesso verificado", 0))::numeric, 2) AS media_excesso_kmh,
    MAX(f."excesso verificado") AS maior_excesso_kmh
FROM fato_multa f
JOIN dim_infracao i ON i.id_infracao_sk = f.id_infracao_sk
GROUP BY
    i."código da infração",
    i."descrição abreviada infração"
ORDER BY total_autuacoes DESC
LIMIT 20;