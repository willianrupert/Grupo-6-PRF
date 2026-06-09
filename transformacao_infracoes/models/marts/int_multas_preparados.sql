{{
    config(
        materialized='table'
    )
}}

with stg_multas as (
    select * from {{ ref('stg_multas_unificados') }}
),

normalizacao_estrangeiro_e_nulos as (
    select
        *,
        coalesce(uf_infracao, 'NÃO INFORMADO') as uf_infracao_limpa,
        coalesce(municipio, 'NÃO INFORMADO') as municipio_limpo,
        coalesce(descricao_especie_veiculo, 'NÃO INFORMADO') as especie_limpa,
        coalesce(descricao_marca_veiculo, 'NÃO INFORMADO') as marca_limpa,
        coalesce(descricao_tipo_veiculo, 'NÃO INFORMADO') as tipo_limpa,
        coalesce(descricao_modelo_veiculo, 'NÃO INFORMADO') as modelo_limpo,
        coalesce(descricao_abreviada_infracao, 'NÃO INFORMADO') as descricao_infracao_limpa,
        coalesce(enquadramento_infracao, 'NÃO INFORMADO') as enquadramento_limpo,

        -- Normalização do indicador veículo estrangeiro mapeando os novos países de 2024
        case 
            when indicador_veiculo_estrangeiro in ('S', 'AR', 'BO', 'CL', 'GY', 'MX', 'PY', 'UY', 'VE') then 'S'
            when indicador_veiculo_estrangeiro in ('N', 'BR') then 'N'
            else 'N/I'
        end as estrangeiro_normalizado
    from stg_multas
),

normalizacao_placa as (
    select
        *,
        case
            when uf_placa in ('AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS',
                            'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC',
                            'SP', 'SE', 'TO') then uf_placa
            when uf_placa in ('N/I', 'EX') then uf_placa
            when uf_placa = '/' then 'N/I'
            when uf_placa in ('-1', '''-1''', '', '/') then 'N/I'
            when length(uf_placa) = 2 and uf_placa similar to '%[0-9]%' then 'EX'
            else 'N/I'
        end as uf_placa_normalizada
    from normalizacao_estrangeiro_e_nulos
),

conversao_tipos as (
    select
        numero_auto,
        uf_infracao_limpa as uf_infracao,
        municipio_limpo as municipio,
        coalesce(indicador_abordagem, 'NÃO INFORMADO') as indicador_abordagem,
        coalesce(br_infracao, 'NÃO INFORMADO') as br_infracao,
        
        -- Aplicação da função clean_tipo_auto do notebook para a assinatura do auto
        case 
            when upper(trim(assinatura_auto)) = 'AI' then 'Auto de Infração'
            when upper(trim(assinatura_auto)) = 'AIT' then 'Auto de Infração de Trânsito'
            when upper(trim(assinatura_auto)) = 'ANI' then 'Aviso de Notificação de Infração'
            when trim(assinatura_auto) = '' then 'NÃO INFORMADO'
            else coalesce(assinatura_auto, 'NÃO INFORMADO')
        end as assinatura_auto,

        -- Aplicação da função get_sentido_trafego
        case 
            when upper(trim(sentido_trafego)) = 'C' then 'Crescente'
            when upper(trim(sentido_trafego)) = 'D' then 'Decrescente'
            else 'NÃO INFORMADO'
        end as sentido_trafego,

        estrangeiro_normalizado as indicador_veiculo_estrangeiro,
        uf_placa_normalizada as uf_placa,
        
        -- Funções clean_especie_veiculo e clean_tipo_veiculo em lote SQL (Corrigidas as vírgulas)
        CASE 
            -- 1. Se for nulo ou vazio, limpa direto
            WHEN especie_limpa IS NULL OR TRIM(especie_limpa) = '' THEN 'Não Informado'
            
            -- 2. Intercepta os valores fantasmas (Lógica da subfunção)
            WHEN UPPER(TRIM(especie_limpa)) IN ('NAO INFORMADO', 'NÃO ENCONTRADO', 'NA', '-1', '''-1''', 'NÃO INFORMADO', 'N/I') THEN 'NÃO INFORMADO'
            
            -- 3. Mapeia estritamente TRAÇÃO (com e sem acento)
            WHEN UPPER(TRIM(especie_limpa)) IN ('TRACAO', 'TRAÇÃO') THEN 'TRAÇÃO'
            
            -- 4. Mapeia estritamente COLEÇÃO (com e sem acento)
            WHEN UPPER(TRIM(especie_limpa)) IN ('COLECAO', 'COLEÇÃO') THEN 'COLEÇÃO'
            
            -- 5. Mapeia estritamente COMPETIÇÃO (com e sem acento)
            WHEN UPPER(TRIM(especie_limpa)) IN ('COMPETICAO', 'COMPETIÇÃO') THEN 'COMPETIÇÃO'
            
            -- 6. Mantém os demais termos válidos garantindo que fiquem em caixa alta padrão
            WHEN UPPER(TRIM(especie_limpa)) IN ('PASSAGEIRO', 'CARGA', 'ESPECIAL', 'MISTO', 'CORRIDA') THEN UPPER(TRIM(especie_limpa))
            
            -- 7. Caso o dado original seja um texto válido que não mapeamos acima, mantém o texto original limpo ao invés de descartar tudo
            ELSE COALESCE(UPPER(TRIM(especie_limpa)), 'Não Informado')
        END AS descricao_especie_veiculo,

        case 
            when upper(trim(tipo_limpa)) in ('NAO INFORMADO', 'NÃO ENCONTRADO', 'NA', '-1', '''-1''', 'NÃO INFORMADO') then 'NÃO INFORMADO'
            else upper(trim(tipo_limpa))
        end as descricao_tipo_veiculo,

        -- Função clean_marca_veiculo em lote SQL unificada (removida a duplicata de baixo)
        case 
            when upper(trim(marca_limpa)) in ('NAO INFORMADO', 'NÃO ENCONTRADO', 'NA', '-1', '''-1''', 'Não INFORMADO') then 'NÃO INFORMADO'
            else upper(trim(marca_limpa))
        end as descricao_marca_veiculo,

        modelo_limpo as descricao_modelo_veiculo,
        descricao_infracao_limpa as descricao_abreviada_infracao,
        enquadramento_limpo as enquadramento_infracao,
        
        cast(case when coalesce(codigo_infracao, '0') ~ '^-?[0-9]+$' then coalesce(codigo_infracao, '0') else '0' end as integer) as codigo_infracao,
        cast(case when coalesce(km_infracao, '0') ~ '^-?[0-9]+$' then coalesce(km_infracao, '0') else '0' end as integer) as km_infracao,
        cast(case when coalesce(qtd_infracoes, '1') ~ '^-?[0-9]+$' then coalesce(qtd_infracoes, '1') else '1' end as integer) as qtd_infracoes,
        cast(case when coalesce(hora_infracao::text, '0') ~ '^-?[0-9]+$' then hora_infracao::text else '0' end as integer) as hora_infracao,

        cast(case when replace(coalesce(medicao_considerada, '0'), ',', '.') ~ '^-?[0-9]*\.?[0-9]+$' then replace(coalesce(medicao_considerada, '0'), ',', '.') else '0' end as numeric(10,2)) as medicao_considerada,
        cast(case when replace(coalesce(excesso_verificado, '0'), ',', '.') ~ '^-?[0-9]*\.?[0-9]+$' then replace(coalesce(excesso_verificado, '0'), ',', '.') else '0' end as numeric(10,2)) as excesso_verificado,

        case when data_infracao ~ '^\d{4}-\d{2}-\d{2}$' then data_infracao::date else null end as data_infracao
    from normalizacao_placa
),

derivacao_tempo_e_regiao as (
    select
        *,
        extract(day from data_infracao) as dia,
        extract(month from data_infracao) as mes,
        extract(year from data_infracao) as ano,
        extract(quarter from data_infracao) as trimestre,
        
        case extract(isodow from data_infracao)
            when 1 then 'Segunda-feira'
            when 2 then 'Terça-feira'
            when 3 then 'Quarta-feira'
            when 4 then 'Quinta-feira'
            when 5 then 'Sexta-feira'
            when 6 then 'Sábado'
            when 7 then 'Domingo'
        end as dia_semana,

        -- Implementação da função SQL getregiaos baseada na UF da Infração
        case 
            when uf_infracao in ('AC', 'AM', 'AP', 'PA', 'RO', 'RR', 'TO') then 'Norte'
            when uf_infracao in ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') then 'Nordeste'
            when uf_infracao in ('DF', 'GO', 'MS', 'MT') then 'Centro-Oeste'
            when uf_infracao in ('ES', 'MG', 'RJ', 'SP') then 'Sudeste'
            when uf_infracao in ('PR', 'RS', 'SC') then 'Sul'
            else 'NÃO INFORMADO'
        end as regiao_infracao
    from conversao_tipos
    where numero_auto is not null and data_infracao is not null
)

select * from derivacao_tempo_e_regiao