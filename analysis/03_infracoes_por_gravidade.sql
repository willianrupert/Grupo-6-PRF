-- Quais são as infrações mais cometidas e qual o excesso de velocidade médio associado?
SELECT
    v.descricao_especie,
    v.descricao_tipo,
    f."excesso verificado"::NUMERIC AS excesso_kmh
FROM fato_multa f
JOIN infrator v ON v.id_infrator = f.id_infrator_sk
WHERE f."excesso verificado" > 200
ORDER BY excesso_kmh DESC
LIMIT 20;