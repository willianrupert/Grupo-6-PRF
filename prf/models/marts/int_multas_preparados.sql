-- view pq é mais eficiente
{{
    config(
        materialized='view'
    )
}}

-- nosso modelo de staging
with stg_multas AS (
        SELECT * FROM {{ ref('stg_multas_unificados') }}
    ),

-- CAMPOS VAZIOS E NORMALIZAÇÕES INICIAIS
normalizacao_estrangeiro_e_nulos AS (
SELECT
    *,
    -- Equivalente ao fillna('N/I')
    -- COALESCE(coluna, valor_alternativo)
    COALESCE(uf_infracao, 'N/I') AS uf_infracao_limpa,
    COALESCE(municipio, 'N/I') AS municipio_limpo,
    COALESCE(descricao_especie_veiculo, 'N/I') AS especie_limpa,
    COALESCE(descricao_marca_veiculo, 'N/I') AS marca_limpa,
    COALESCE(descricao_tipo_veiculo, 'N/I') AS tipo_limpa,
    COALESCE(descricao_modelo_veiculo, 'N/I') AS modelo_limpo,
    COALESCE(descricao_abreviada_infracao, 'N/I') AS descricao_infracao_limpa,
    COALESCE(enquadramento_infracao, 'N/I') AS enquadramento_limpo,

    -- normaliza estrangeiro
    CASE 
        WHEN indicador_veiculo_estrangeiro IN ('S', 'AR', 'BO', 'CL', 'GY', 'MX', 'PY', 'UY', 'VE') THEN 'S'
        ELSE 'N'
    END AS estrangeiro_normalizado
FROM 
    stg_multas
),


normalizacao_placa AS (
    SELECT
        *,
        -- como a logica classifica(uf)
        CASE
            -- Se a UF já é válida, mantém
            WHEN uf_placa IN ('AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS',
                            'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC',
                            'SP', 'SE', 'TO') THEN uf_placa
            -- N/I --> EX (Estrangeiro)
            WHEN uf_placa = 'N/I' THEN 'EX'
            -- trata códigos legados ex: se contém números na string de tamanho 2
            -- usamos SIMILAR TO para simular o 'any(c.isdigit())'
            WHEN LENGTH(uf_placa) = 2 AND uf_placa SIMILAR TO '%[0-9]%' THEN 'EX'
            
            -- trantando os valores '-1' ou "'-1" --> 'N/I'
            WHEN REPLACE(REPLACE(uf_placa, '''', ''), '-', '') = '1' THEN 'N/I'

            ELSE 'N/I'
        END AS uf_placa_normalizada
    FROM
        normalizacao_estrangeiro_e_nulos
    -- Filtro que remove registros puramente fantasmas de placa
    WHERE 
        uf_placa != '/'
),

-- conversão correta de tipos numéricos e decimais
conversao_tipos AS (
    SELECT
        numero_auto,
        uf_infracao_limpa AS uf_infracao,
        municipio_limpo AS municipio,
        indicador_abordagem,
        assinatura_auto,
        sentido_trafego,
        estrangeiro_normalizado AS indicador_veiculo_estrangeiro,
        uf_placa_normalizada AS uf_placa,
        especie_limpa AS descricao_especie_veiculo,
        marca_limpa AS descricao_marca_veiculo,
        tipo_limpa AS descricao_tipo_veiculo,
        modelo_limpo AS descricao_modelo_veiculo,
        descricao_infracao_limpa AS descricao_abreviada_infracao,
        enquadramento_limpo AS enquadramento_infracao,
        
        COALESCE(br_infracao, 'N/I') AS br_infracao,
        COALESCE(codigo_infracao, 'N/I') AS codigo_infracao,
        
        COALESCE(medicao_infracao, 'N/I') AS medicao_infracao, -- mantido como VARCHAR/Texto por segurança ("Alcoolemia", etc.)

        -- OBS: CAST é uma função[SQL] utilizada para converter o tipo de dado de uma coluna ou valor em outro tipo
        -- preenchendo nulos com 0
        -- inteiros puros
        CAST(COALESCE(km_infracao, '0') AS INTEGER) AS km_infracao,
        CAST(COALESCE(qtd_infracoes, '1') AS INTEGER) AS qtd_infracoes, 
        CAST(hora_infracao AS INTEGER) AS hora_infracao,

        -- substituição da vírgula por ponto antes do CAST para FLOAT/NUMERIC
        CAST(REPLACE(COALESCE(medicao_considerada, '0'), ',', '.') AS NUMERIC(10,2)) AS medicao_considerada,
        CAST(REPLACE(COALESCE(excesso_verificado, '0'), ',', '.') AS NUMERIC(10,2)) AS excesso_verificado,

        -- Implementação de limpeza rigorosa de dados com regex (~ '^\d{4}-\d{2}-\d{2}$') para converter datas, 
        -- tratando casos como "N/I" e evitando erros de tipo (CAST).
        -- Só converte se for uma data válida, caso contrário vira NULL (evita erro de N/I)
        CASE 
            WHEN data_infracao ~ '^\d{4}-\d{2}-\d{2}$' THEN data_infracao::DATE 
            ELSE NULL 
        END AS data_infracao,
        
        CASE 
            WHEN inicio_vigencia_infracao ~ '^\d{4}-\d{2}-\d{2}$' THEN inicio_vigencia_infracao::DATE 
            ELSE NULL 
        END AS inicio_vigencia_infracao
    FROM
        normalizacao_placa
),

derivacao_tempo AS (
    SELECT
        *,
        EXTRACT(DAY FROM data_infracao) AS dia,
        EXTRACT(MONTH FROM data_infracao) AS mes,
        EXTRACT(YEAR FROM data_infracao) AS ano,
        EXTRACT(QUARTER FROM data_infracao) AS trimestre,
        
        -- Mapeamento e tradução automática dos dias da semana
        -- ISODOWN é o dia da semana padrão ISO
        CASE EXTRACT(ISODOW FROM data_infracao)
            WHEN 1 THEN 'Segunda-feira'
            WHEN 2 THEN 'Terça-feira'
            WHEN 3 THEN 'Quarta-feira'
            WHEN 4 THEN 'Quinta-feira'
            WHEN 5 THEN 'Sexta-feira'
            WHEN 6 THEN 'Sábado'
            WHEN 7 THEN 'Domingo'
        END AS dia_semana
    FROM
        conversao_tipos
    WHERE
        numero_auto IS NOT NULL -- é a nossa chave, n pode ficar null
        AND data_infracao IS NOT NULL
)

SELECT * FROM derivacao_tempo