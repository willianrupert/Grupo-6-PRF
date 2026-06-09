{{ config(materialized='table') }}

with base as (
    select distinct
        indicador_veiculo_estrangeiro,
        uf_placa,
        descricao_especie_veiculo,
        descricao_marca_veiculo,
        descricao_tipo_veiculo,
        descricao_modelo_veiculo,
        indicador_abordagem,
        assinatura_auto
    from {{ ref('int_multas_preparados') }}
)

select
    row_number() over (
        order by 
            indicador_veiculo_estrangeiro, 
            uf_placa, 
            descricao_especie_veiculo, 
            descricao_marca_veiculo,
            descricao_tipo_veiculo,
            descricao_modelo_veiculo,
            indicador_abordagem,
            assinatura_auto
    ) as id_infrator_sk,
    
    indicador_veiculo_estrangeiro,
    uf_placa,
    descricao_especie_veiculo,
    descricao_marca_veiculo,
    descricao_tipo_veiculo,
    descricao_modelo_veiculo,
    indicador_abordagem,
    assinatura_auto
from base