-- Quais tipos de veículo têm maior excesso de velocidade médio?
-- Veículos estrangeiros se comportam diferente?

SELECT
    v.descricao_especie_veiculo AS especie_veiculo,
    v.descricao_tipo_veiculo AS tipo_veiculo,
    v.indicador_veiculo_estrangeiro AS estrangeiro,
    COUNT(*) AS total_infracoes,
    ROUND(AVG(f.excesso_verificado::NUMERIC), 2) AS media_excesso_kmh,
    MAX(f.excesso_verificado::NUMERIC) AS maior_excesso_kmh
FROM fato_multa f
JOIN dim_infrator v ON v.id_infrator_sk = f.id_infrator_sk
WHERE
    f.excesso_verificado::NUMERIC > 0
    AND f.excesso_verificado::NUMERIC <= 150
    AND v.descricao_especie_veiculo NOT IN ('-1', 'Não informado', 'N/I', 'NÃO INFORMADO')
    AND v.descricao_tipo_veiculo NOT IN ('-1', 'Não informado', 'N/I', 'NÃO INFORMADO')
GROUP BY v.descricao_especie_veiculo, v.descricao_tipo_veiculo, v.indicador_veiculo_estrangeiro
HAVING COUNT(*) >= 100
ORDER BY media_excesso_kmh DESC;