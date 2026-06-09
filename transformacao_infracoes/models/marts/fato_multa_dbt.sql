{{ config(materialized='table') }}

WITH source AS (
    -- Puxa os dados da tabela intermediária já limpa
    SELECT * FROM {{ ref('int_multas_preparados') }}
),

fato AS (
    SELECT
        -- Chaves Estrangeiras (Ligando o miolo às pontas da estrela)
        t.id_tempo_sk,
        l.id_localidade_sk,
        inf.id_infracao_sk,
        v.id_veiculo_sk,

        -- Chave do Fato (O identificador único da multa)
        s.numero_auto,

        -- Fatos e Medidas (Os números e características que sobraram para análise)
        s.hora_infracao,
        s.qtd_infracoes,
        s.medicao_considerada,
        s.excesso_verificado,
        s.assinatura_auto,
        s.sentido_trafego

    FROM source s

    -- Cruzamento com a Dimensão Tempo
    LEFT JOIN {{ ref('dim_tempo_dbt') }} t
        ON s.data_infracao = t.data_infracao

    -- Cruzamento com a Dimensão Localizacao (usando os nomes do arquivo dele)
    LEFT JOIN {{ ref('dim_localizacao_dbt') }} l
        ON s.municipio = l.municipio
        AND s.uf_infracao = l.uf

    -- Cruzamento com a Dimensão Infracao
    LEFT JOIN {{ ref('dim_infracao_dbt') }} inf
        ON s.codigo_infracao = inf.codigo_infracao

    -- Cruzamento com a Dimensão Veiculo (cruzando todas as propriedades do carro e da abordagem)
    LEFT JOIN {{ ref('dim_veiculo_dbt') }} v
        ON s.descricao_especie_veiculo = v.especie_veiculo
        AND s.descricao_tipo_veiculo = v.tipo_veiculo
        AND s.descricao_marca_veiculo = v.marca_veiculo
        AND s.descricao_modelo_veiculo = v.modelo_veiculo
        AND s.indicador_veiculo_estrangeiro = v.indicador_veiculo_estrangeiro
        AND s.uf_placa = v.uf_placa
)

SELECT * FROM fato