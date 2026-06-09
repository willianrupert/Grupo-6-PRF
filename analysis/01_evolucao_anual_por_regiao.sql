-- Como o volume de infrações variou em cada região do país?
SELECT
    t.ano,
    CASE l."uf infração"
        WHEN 'AC' THEN 'Norte'
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
    SUM(f."qtd infrações") AS total_infracoes,
    ROUND(
        100.0 * (
            SUM(f."qtd infrações") -
            LAG(SUM(f."qtd infrações")) OVER (PARTITION BY l."uf infração" ORDER BY t.ano)
        ) / NULLIF(
            LAG(SUM(f."qtd infrações")) OVER (PARTITION BY l."uf infração" ORDER BY t.ano)
        , 0),
    2) AS variacao_pct_ano_anterior
FROM fato_multa f
JOIN dim_tempo t ON t.id_tempo_sk = f.id_tempo_sk
JOIN dim_localizacao l ON l.id_localizacao_sk = f.id_localizacao_sk
WHERE l."uf infração" NOT IN ('N/I', 'EX')
GROUP BY t.ano, l."uf infração"
ORDER BY regiao, t.ano;