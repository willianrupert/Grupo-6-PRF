-- Como o volume de infrações variou em cada região do país?
SELECT
    t.ano,
    CASE l.uf
        WHEN 'AC' THEN 'Norte'    --definição de região baseada na sigla do estado
        WHEN 'AM' THEN 'Norte'
        WHEN 'AP' THEN 'Norte'    
        WHEN 'PA' THEN 'Norte'
        WHEN 'RO' THEN 'Norte'    
        WHEN 'RR' THEN 'Norte'
        WHEN 'TO' THEN 'Norte'
        WHEN 'AL' THEN 'Nordeste' 
        WHEN 'BA' THEN 'Nordeste'
        WHEN 'CE' THEN 'Nordeste' 
        WHEN 'MA' THEN 'Nordeste'
        WHEN 'PB' THEN 'Nordeste' 
        WHEN 'PE' THEN 'Nordeste'
        WHEN 'PI' THEN 'Nordeste' 
        WHEN 'RN' THEN 'Nordeste'
        WHEN 'SE' THEN 'Nordeste'
        WHEN 'DF' THEN 'Centro-Oeste' 
        WHEN 'GO' THEN 'Centro-Oeste'
        WHEN 'MS' THEN 'Centro-Oeste' 
        WHEN 'MT' THEN 'Centro-Oeste'
        WHEN 'ES' THEN 'Sudeste'  
        WHEN 'MG' THEN 'Sudeste'
        WHEN 'RJ' THEN 'Sudeste'  
        WHEN 'SP' THEN 'Sudeste'
        WHEN 'PR' THEN 'Sul'      
        WHEN 'RS' THEN 'Sul'
        WHEN 'SC' THEN 'Sul'
        ELSE 'Não identificado'
    END AS regiao,
    COUNT(*) AS total_autos,
    SUM(f.qtd_infracoes) AS total_infracoes,
    -- LAG pega o valor do ano anterior dentro da mesma região
    ROUND(
        100.0 * (SUM(f.qtd_infracoes) - LAG(SUM(f.qtd_infracoes))
                 OVER (PARTITION BY l.uf ORDER BY t.ano))
        / NULLIF(LAG(SUM(f.qtd_infracoes))
                 OVER (PARTITION BY l.uf ORDER BY t.ano), 0),
    2) AS variacao_pct_ano_anterior
FROM fato_multa_dbt f
JOIN dim_tempo_dbt      t ON t.id_tempo_sk      = f.id_tempo_sk
JOIN dim_localizacao_dbt l ON l.id_localidade_sk = f.id_localidade_sk
WHERE l.uf NOT IN ('N/I', 'EX')
GROUP BY t.ano, l.uf
ORDER BY regiao, t.ano;