-- Quais tipos de veículo têm maior excesso de velocidade médio?
-- Veículos estrangeiros se comportam diferente?

SELECT
    v.especie_veiculo,
    v.tipo_veiculo,
    v.indicador_veiculo_estrangeiro AS estrangeiro, -- 'S' ou 'N'
    COUNT(*) AS total_infracoes,
    ROUND(AVG(f.excesso_verificado), 2) AS media_excesso_kmh,
    MAX(f.excesso_verificado) AS maior_excesso_kmh
FROM fato_multa_dbt f
JOIN dim_veiculo_dbt v ON v.id_veiculo_sk = f.id_veiculo_sk
WHERE
    f.excesso_verificado > 0       -- só infrações com excesso verificado
    AND v.especie_veiculo <> 'N/I'
    AND v.tipo_veiculo    <> 'N/I'
GROUP BY
    v.especie_veiculo,
    v.tipo_veiculo,
    v.indicador_veiculo_estrangeiro
HAVING COUNT(*) >= 100             -- filtra combinações sem volume representativo
ORDER BY media_excesso_kmh DESC;