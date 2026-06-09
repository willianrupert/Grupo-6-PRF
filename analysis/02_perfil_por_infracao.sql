-- Quais tipos de veículo têm maior excesso de velocidade médio?
-- Veículos estrangeiros se comportam diferente?

SELECT
    v.descricao_especie AS especie_veiculo,
    v.descricao_tipo AS tipo_veiculo,
    v.indicador_estrangeiro AS estrangeiro,
    COUNT(*) AS total_infracoes,
    ROUND(AVG(f."excesso verificado"::NUMERIC), 2) AS media_excesso_kmh,
    MAX(f."excesso verificado"::NUMERIC) AS maior_excesso_kmh
FROM fato_multa f
JOIN infrator v ON v.id_infrator = f.id_infrator_sk
WHERE
    f."excesso verificado"::NUMERIC > 0
    AND f."excesso verificado"::NUMERIC <= 150 -- Corte de sanidade física (excesso máximo plausível)
    AND v.descricao_especie NOT IN ('-1', 'Não informado', 'N/I')
    AND v.descricao_tipo NOT IN ('-1', 'Não informado', 'N/I')
GROUP BY v.descricao_especie, v.descricao_tipo, v.indicador_estrangeiro
HAVING COUNT(*) >= 100
ORDER BY media_excesso_kmh DESC;