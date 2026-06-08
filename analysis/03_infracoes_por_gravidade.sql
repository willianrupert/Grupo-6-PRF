-- Quais são as infrações mais cometidas e qual o excesso de velocidade médio associado?
SELECT
    i.gravidade,
    i.codigo_infracao,
    i.descricao_infracao,
    COUNT(*) AS total_autuacoes,
    ROUND(AVG(NULLIF(f.excesso_verificado, 0)), 2) AS media_excesso_kmh,
    MAX(f.excesso_verificado) AS maior_excesso_kmh
FROM fato_multa_dbt f
JOIN dim_infracao_dbt i ON i.id_infracao_sk = f.id_infracao_sk
WHERE i.codigo_infracao <> 'N/I'
GROUP BY
    i.gravidade,
    i.codigo_infracao,
    i.descricao_infracao
ORDER BY total_autuacoes DESC
LIMIT 20;