{{ config(materialized='view') }}

with source as (
    select * from {{ ref('int_multas_preparados') }}
),

fato as (
    select
        -- Surrogate Keys (Relacionamentos Estrela)
        t.id_tempo_sk,
        l.id_localizacao_sk,
        inf.id_infracao_sk,
        inf_sk.id_infrator_sk,


        -- Chave e Métricas da Fato
        s.numero_auto,
        s.qtd_infracoes,
        s.medicao_considerada,
        s.excesso_verificado,
        s.indicador_abordagem,
        s.assinatura_auto,
        s.sentido_trafego
    from source s

    left join {{ ref('dim_tempo_dbt') }} t
        on s.data_infracao = t.data_infracao

    left join {{ ref('dim_localizacao_dbt') }} l
        on s.uf_infracao = l.uf_infracao
        and s.br_infracao = l.br_infracao
        and s.km_infracao = l.km_infracao
        and s.municipio = l.municipio
        and s.regiao_infracao = l.regiao_infracao
        and s.sentido_trafego = l.sentido_trafego

    left join {{ ref('dim_infracao_dbt') }} inf
        on s.codigo_infracao = inf.codigo_infracao

    left join {{ ref('dim_infrator_dbt') }} inf_sk
        on s.indicador_veiculo_estrangeiro = inf_sk.indicador_veiculo_estrangeiro
        and s.uf_placa = inf_sk.uf_placa
        and s.descricao_especie_veiculo = inf_sk.descricao_especie_veiculo
        and s.descricao_marca_veiculo = inf_sk.descricao_marca_veiculo
        and s.descricao_tipo_veiculo = inf_sk.descricao_tipo_veiculo
        and s.descricao_modelo_veiculo = inf_sk.descricao_modelo_veiculo
        and s.indicador_abordagem = inf_sk.indicador_abordagem
        and s.assinatura_auto = inf_sk.assinatura_auto
)

select * from fato