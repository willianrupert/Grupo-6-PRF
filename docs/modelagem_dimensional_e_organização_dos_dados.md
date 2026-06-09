
## Projeto de Integração — Multas PRF (2022–2024)

> **Disciplina:** CIN0137 – Banco de Dados — UFPE / CIn **Grupo:** 6 **Tema:** Multas aplicadas pela Polícia Rodoviária Federal (PRF)

---

## 1. Visão Geral

Este documento descreve o **Data Warehouse** construído pelo grupo a partir dos dados públicos de multas aplicadas pela Polícia Rodoviária Federal (PRF), abrangendo os anos de **2022, 2023 e 2024**.

| Item                        | Descrição                                                                                                                                        |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Fonte dos dados**         | [Portal de Dados Abertos da PRF](https://www.gov.br/prf/pt-br/acesso-a-informacao/dados-abertos/dados-abertos-da-prf) — Sistema SISCOM / AUTOPRF |
| **Período coberto**         | Janeiro/2022 a Dezembro/2024 (3 anos completos)                                                                                                  |
| **Volume total aproximado** | Mais de 14 milhões de autuações registradas                                                                                                      |
| **Tecnologias**             | PostgreSQL (hospedado em servidor próprio Oracle), Python (pandas, SQLAlchemy), dbt                                                              |
| **Modelo adotado**          | Esquema Estrela (Star Schema)                                                                                                                    |

---

## 2. Justificativa do Modelo Dimensional

A escolha do **Esquema Estrela** baseou-se em três razões principais:

**1. Foco em análise (OLAP), não em transações (OLTP).** O sistema operacional da PRF é otimizado para registrar autuações no dia a dia, ou seja, é um banco transacional. Já o Data Warehouse é construído para responder perguntas analíticas como _"quantas multas por UF em 2023?"_ ou _"qual a evolução de infrações por trimestre?"_. Essas consultas envolvem leituras grandes, agregadas, sobre dados históricos. Essas duas frentes têm requisitos opostos: o transacional exige normalização (3FN) para evitar redundância em escritas, já o analítico exige desnormalização para minimizar JOINs em leituras.

**2. Simplicidade e performance em consultas.** O Star Schema reduz o número de JOINs necessários em consultas analíticas. Em vez de navegar várias tabelas normalizadas, basta unir a tabela fato com as dimensões necessárias.

**3. Aderência ao modelo cognitivo de análise.** Análises são pensadas em termos de "métricas por dimensão", como *quantas multas (métrica) por UF (dimensão)? Por mês (dimensão)?* O Star Schema é reflexo desse pensamento, facilitando a tradução de perguntas de negócio em consultas SQL.

---

## 3. Diagrama do Star Schema

```
                       ┌─────────────────────┐
                       │       Tempo         │
                       │  (Dim. temporal)    │
                       └──────────┬──────────┘
                                  │
                                  │ id_tempo
                                  │
┌─────────────────────┐           ▼          ┌─────────────────────┐
│    Localizacao      │   ┌──────────────┐   │      Infrator       │
│  (Dim. geográfica)  │◄──┤  Fato_Multa  ├──►│  (Dim. veículo)     │
└─────────────────────┘   │   (Fato)     │   └─────────────────────┘
        id_localizacao    └──────┬───────┘   id_infrator
                                 │
                                 │ id_infracao
                                 │
                       ┌─────────▼───────────┐
                       │      Infracao       │
                       │  (Dim. da regra)    │
                       └─────────────────────┘
```
---

## 4. Descrição das Tabelas

### 4.1 Tabela Fato — `fato_multa`

> Cada linha representa **uma autuação registrada pela PRF**.

No nosso caso, descer mais (por exemplo, a nível de cobrança) seria possível, mas os dados públicos não disponibilizam essa granularidade. Subir mais (por exemplo, agregar por mês/UF) limitaria as análises possíveis.

**Papel:** Centralizar os eventos de multa, conectando-se às quatro dimensões e armazenando as métricas quantitativas associadas a cada autuação.

**Métricas (campos numéricos agregáveis):**

- `Qts_Infracoes` — quantidade de infrações em uma autuação
- `Medicao_Infracao` — valor medido pelo equipamento (radar, etilômetro)
- `Medicao_Considerada` — valor considerado para o registro da infração
- `Excesso_Verificado` — excesso aferido por equipamento de medição

**Campos descritivos não-dimensionais:** São atributos pontuais do evento que não justificam uma dimensão própria, isto é, manter como dimensão criaria tabelas minúsculas e JOINs desnecessários. Em modelagem dimensional, esses são chamados de _degenerate dimensions_ (dimensões degeneradas):

- `Numero_Auto` — identificador único do auto (vem do CSV original)
- `Indicador_Abordagem` — se houve ou não abordagem física
- `Assinatura_Auto` — se o auto foi assinado pelo infrator
- `Sentido_Trafego` — sentido crescente ou decrescente da rodovia

**Chaves estrangeiras:**

- `ID_Tempo` → `Tempo`
- `ID_Infracao` → `Infracao`
- `ID_Infrator` → `Infrator`
- `ID_Localizacao` → `Localizacao`

---

### 4.2 Dimensão `dim_tempo`

**Papel:** descrever os atributos temporais de cada autuação, permitindo análises por dia, mês, trimestre, ano, dia da semana e feriado.

**Particularidade:** os atributos `Dia`, `Mes`, `Ano`, `Trimestre`, `Dia_Semana` e
`Is_Feriado` são pré-computados a partir do campo `Data_Infracao` durante o
ETL/ELT. Essa desnormalização é proposital: evita o uso de funções de data
nas consultas analíticas, melhorando performance.

**OBS:** o campo `Is_Feriado` requer uma fonte externa de calendário de feriados nacionais e esse tratamento foi definido como parte da etapa de transformação.

---

### 4.3 Dimensão `dim_localizacao`

**Papel:** descrever **onde** ocorreu a infração — Unidade Federativa, rodovia (BR), quilômetro e município.

**Particularidade:** a combinação `UF + BR + KM + Município` define unicamente cada registro de localização. Essa combinação tem ordem de grandeza muito menor que a tabela fato, provavelmente algumas dezenas de milhares de combinações distintas para milhões de autuações.

---

### 4.4 Dimensão `dim_infracao`

**Papel:** descrever **o tipo de infração cometida**, qual regra do Código de Trânsito Brasileiro foi violada, qual o código de enquadramento, e qual o período de vigência da regra.

**Particularidade:** o campo `Fim_Vigencia` veio **100% nulo** nos 3 anos analisados. Durante o ETL/ELT esse campo será removido por não trazer informação. Detalhes no item 6.1.

---

### 4.5 Dimensão `dim_veiculo`

**Papel:** descrever **o veículo associado à autuação**, origem da placa, se é estrangeiro, espécie, marca, tipo e modelo do veículo.

**Observação:** A base PRF **não disponibiliza dados pessoais do condutor** (sigilo previsto na LAI e na LGPD). Os atributos disponíveis caracterizam exclusivamente o **veículo envolvido**.

---

## 5. Dicionário de Dados
 
> **Fontes:**
>
> 1. **Nome no Dicionário PRF:** nomenclatura oficial documentada pela PRF no _Dicionário de Variáveis – Infrações_ (Setembro/2016).
> 2. **Nome no CSV:** nome real da coluna nos arquivos brutos baixados.
> 3. **Nome no DW:** nome final adotado no Data Warehouse após padronização pelo pipeline ETL.
 
> ⚠️ **Atenção:** o dicionário oficial da PRF teve última atualização em 2016 e alguns campos presentes nos CSVs atuais (2022–2024) **não estão documentados oficialmente** — esses casos estão marcados como `(não documentado em 2016)`. As descrições foram inferidas pelo grupo a partir dos dados.
 
---
 
### 5.1 Tabela Fato — `fato_multa`
 
> Cada linha representa **uma autuação registrada pela PRF**. As métricas numéricas ficam aqui; os atributos descritivos são resolvidos via JOIN com as dimensões.
 
| Campo no DW             | Tipo          | Nome no CSV              | Nome PRF (2016)             | Descrição                                                              |
| ----------------------- | ------------- | ------------------------ | --------------------------- | ---------------------------------------------------------------------- |
| `id_multa_sk`           | BIGSERIAL PK  | —                        | —                           | Surrogate key gerada no DW                                             |
| `id_tempo_sk`           | INTEGER FK    | —                        | —                           | Referência à `dim_tempo`                                               |
| `id_localizacao_sk`     | INTEGER FK    | —                        | —                           | Referência à `dim_localizacao`                                         |
| `id_veiculo_sk`         | INTEGER FK    | —                        | —                           | Referência à `dim_veiculo`                                             |
| `id_infracao_sk`        | INTEGER FK    | —                        | —                           | Referência à `dim_infracao`                                            |
| `numero_auto`           | VARCHAR(20)   | Número do Auto           | _(não documentado em 2016)_ | Identificador do auto de infração (dimensão degenerada)                |
| `hora_infracao`         | VARCHAR(10)   | Hora Infração            | _(não documentado em 2016)_ | Hora em que a infração ocorreu                                         |
| `qtd_infracoes`         | INTEGER       | Qtd Infrações            | _(não documentado em 2016)_ | Quantidade de infrações registradas no auto                            |
| `excesso_verificado_kmh`| NUMERIC(8,2)  | Excesso Verificado       | `exc_verificado`            | Excesso de velocidade aferido por equipamento de medição (em km/h)     |
| `medicao_infracao`      | NUMERIC(8,2)  | Medição Infração         | `med_realizada`             | Valor bruto registrado pelo equipamento (radar, etilômetro, balança)   |
| `medicao_considerada`   | NUMERIC(8,2)  | Medição Considerada      | `med_considerada`           | Valor considerado para o registro da infração após margem de tolerância|
 
---
 
### 5.2 Dimensão `dim_tempo`
 
> Descreve os atributos temporais de cada autuação. Todos os campos derivados (`dia`, `mes`, `ano`, etc.) são pré-computados durante o ETL a partir de `data`, eliminando o uso de funções de data em tempo de consulta.
 
| Campo no DW    | Tipo        | Origem                                | Descrição                                                                 |
| -------------- | ----------- | ------------------------------------- | ------------------------------------------------------------------------- |
| `id_tempo_sk`  | INTEGER PK  | gerado (`YYYYMMDD` da data)           | Surrogate key no formato numérico de data                                 |
| `data`         | DATE        | "Data da Infração (DD/MM/AAAA)" / `dat_infracao` | Data da infração                                             |
| `dia`          | INTEGER     | derivado de `data`                    | Dia do mês (1–31)                                                         |
| `mes`          | INTEGER     | derivado de `data`                    | Mês (1–12)                                                                |
| `nome_mes`     | VARCHAR(20) | derivado de `data`                    | Nome do mês por extenso (ex: "Janeiro")                                   |
| `trimestre`    | INTEGER     | derivado de `data`                    | Trimestre (1–4)                                                           |
| `ano`          | INTEGER     | derivado de `data`                    | Ano com 4 dígitos                                                         |
| `dia_semana`   | VARCHAR(15) | derivado de `data`                    | Dia da semana por extenso (ex: "Segunda-feira")                           |
| `fim_de_semana`| BOOLEAN     | derivado de `data`                    | `True` se a infração ocorreu em sábado ou domingo                         |
 
---
 
### 5.3 Dimensão `dim_localizacao`
 
> Descreve onde ocorreu a infração. A combinação `(uf_infracao, br_infracao, km_infracao, municipio)` identifica unicamente cada registro, resultando em algumas dezenas de milhares de combinações distintas para milhões de autuações.
 
| Campo no DW         | Tipo         | Nome no CSV   | Nome PRF (2016)   | Descrição                                                    |
| ------------------- | ------------ | ------------- | ----------------- | ------------------------------------------------------------ |
| `id_localizacao_sk` | INTEGER PK   | —             | —                 | Surrogate key                                                |
| `uf_infracao`       | CHAR(2)      | UF Infração   | `uf_infracao`     | Unidade federativa onde ocorreu a infração                   |
| `br_infracao`       | VARCHAR(5)   | BR Infração   | `num_br_infracao` | Identificador numérico da rodovia federal                    |
| `km_infracao`       | FLOAT        | Km Infração   | `num_km_infracao` | Quilômetro da rodovia (aceita decimais; nulos viram `None`)  |
| `municipio`         | VARCHAR(100) | Município     | `nom_municipio`   | Nome do município em maiúsculas                              |
| `regiao`            | VARCHAR(15)  | —             | —                 | Região geográfica derivada da UF (Norte, Nordeste, etc.)     |
| `sentido_trafego`   | VARCHAR(20)  | Sentido Trafego | `ind_sentido_trafego` | Sentido da via: "Crescente", "Decrescente" ou "Não informado" |
 
---
 
### 5.4 Dimensão `dim_infracao`
 
> Descreve o tipo de infração cometida conforme o Código de Trânsito Brasileiro. O campo `gravidade` é derivado automaticamente do texto de `enquadramento_infracao` durante o ETL.
 
| Campo no DW              | Tipo         | Nome no CSV                  | Nome PRF (2016)             | Descrição                                                                  |
| ------------------------ | ------------ | ---------------------------- | --------------------------- | -------------------------------------------------------------------------- |
| `id_infracao_sk`         | INTEGER PK   | —                            | —                           | Surrogate key                                                              |
| `codigo_infracao`        | VARCHAR(10)  | Código da Infração           | _(não documentado em 2016)_ | Código numérico da infração conforme o CTB                                 |
| `descricao_infracao`     | VARCHAR(300) | Descrição Abreviada Infração | `descricao_abreviada`       | Descrição abreviada da infração                                            |
| `enquadramento_infracao` | VARCHAR(300) | Enquadramento da Infração    | `enquadramento`             | Texto completo do enquadramento conforme o CTB                             |
| `gravidade`              | VARCHAR(20)  | —                            | —                           | Derivada do enquadramento: "Gravíssima", "Grave", "Média", "Leve" ou "Não classificada" |
| `tipo_auto`              | VARCHAR(50)  | Assinatura do Auto           | `ind_assinou_auto`          | Tipo do documento: "Auto de Infração", "Auto de Infração de Trânsito" ou "Aviso de Notificação de Infração" |
| `inicio_vigencia`        | DATE         | Início Vigência da Infração  | `data_inicio_vigencia`      | Data de início de vigência da regra                                        |
| `fim_vigencia`           | DATE         | Fim Vigência Infração        | `data_fim_vigencia`         | Data de fim de vigência — **100% nulo** nos 3 anos analisados              |
 
---
 
### 5.5 Dimensão `dim_veiculo`
 
> Descreve o veículo autuado. A PRF não disponibiliza dados pessoais do condutor (sigilo pela LAI/LGPD), portanto todos os atributos desta dimensão são relativos ao veículo. O campo `tipo_abordagem` é decodificado durante o ETL a partir do código de 1 letra do CSV original.
 
| Campo no DW               | Tipo        | Nome no CSV                   | Nome PRF (2016)             | Descrição                                                            |
| ------------------------- | ----------- | ----------------------------- | --------------------------- | -------------------------------------------------------------------- |
| `id_veiculo_sk`           | INTEGER PK  | —                             | —                           | Surrogate key                                                        |
| `especie_veiculo`         | VARCHAR(50) | Descrição Especie Veículo     | `especie`                   | Espécie do veículo (ex: "Automóvel", "Motocicleta")                  |
| `tipo_veiculo`            | VARCHAR(50) | Descrição Tipo Veículo        | _(não documentado em 2016)_ | Tipo do veículo                                                      |
| `marca_veiculo`           | VARCHAR(50) | Descrição Marca Veículo       | `nome_veiculo_marca`        | Marca do veículo                                                     |
| `modelo_veiculo`          | VARCHAR(50) | Descrição Modelo Veículo      | `nom_modelo_veiculo`        | Modelo do veículo                                                    |
| `tipo_abordagem`          | VARCHAR(30) | Indicador de Abordagem        | `tip_abordagem`             | Decodificado: "Abordagem presencial", "Equipamento eletrônico", "Denúncia" ou "Não informado" |
| `veiculo_estrangeiro`     | BOOLEAN     | Indicador Veiculo Estrangeiro | `ind_veiculo_estrangeiro`   | `True` se estrangeiro — ver §6.2 sobre mudança de formato em 2024    |
| `uf_placa`                | CHAR(2)     | UF Placa                      | `uf_placa`                  | UF da placa; valores inválidos normalizados para `EX` (estrangeiro) ou `N/I` |

 ---
 
## 6. Considerações sobre Diferenças entre Anos
 
Durante a fase de diagnóstico exploratório, foram identificadas mudanças relevantes entre as três bases anuais. Esta seção documenta cada inconsistência encontrada e o tratamento aplicado em cada pipeline.
 
---
 
### 6.1 Campo `fim_vigencia` totalmente nulo
 
Em **todos os 3 anos** (2022, 2023, 2024), **100% dos registros** têm o campo `Fim Vigência Infração` como NULL. O campo não foi removido do schema — ele existe na `dim_infracao` — mas o parser nunca encontra uma data válida no formato `dd/mm/yyyy`, então todos os registros resultam em `None`/`NULL`.
 
| Pipeline | Comportamento |
|----------|---------------|
| ETL      | O campo é lido e parseado; como nenhum valor passa pela validação de formato, `fim_vigencia` é sempre `None` na `dim_infracao` |
| ELT (dbt)| O campo `fim_vigencia_infracao` foi excluído dos modelos `dim_infracao_dbt` — não aparece na tabela final |
 
A presença do campo no ETL é mantida por completude com o schema original da PRF. Para análises, o campo não possui valor informativo.
 
---
 
### 6.2 `Indicador Veículo Estrangeiro` mudou de semântica em 2024
 
Esta é a diferença **mais relevante** entre as bases, pois afeta diretamente a comparabilidade temporal.
 
| Ano  | Valores observados | Interpretação |
|------|--------------------|---------------|
| 2022 | `S`, `N` | Indicador binário (Sim / Não) |
| 2023 | `S`, `N`, `/` | Indicador binário com valor inválido |
| 2024 | `BR`, `AR`, `BO`, `CL`, `GY`, `MX`, `PY`, `UY`, `VE`, `N`, `S`, `99` | **Código ISO do país de origem** do veículo |
 
A partir de 2024, a PRF passou a registrar o código ISO do país em vez do indicador binário. Os dois pipelines tratam essa mudança de formas distintas:
 
**ETL (Python):** converte para BOOLEAN — `True` para estrangeiro, `False` para nacional. Qualquer código diferente de `BR` é tratado como estrangeiro; `N` e `BR` como nacional. Valores como `99` e nulos resultam em `None`.
 
```python
def clean_veiculo_estrangeiro(val):
    if val in ['S']: return True
    if val in ['N', 'BR']: return False
    if val in ['AR', 'BO', 'CL', 'GY', 'MX', 'PY', 'UY', 'VE', '99']: return True
    return None  # nulo para casos não mapeados
```
 
**ELT (dbt):** converte para `'S'`/`'N'` (VARCHAR) usando a mesma lógica via CASE SQL, mantendo o padrão dos anos anteriores.
 
> **Observação:** os dois pipelines convergem para a mesma semântica binária (estrangeiro / não estrangeiro), mas com tipos diferentes — BOOLEAN no ETL e CHAR no ELT. Isso deve ser considerado ao cruzar resultados entre os dois.
 
---
 
### 6.3 `Assinatura do Auto` vs. `tipo_auto` — campos com funções distintas nos pipelines
 
Este campo apresenta comportamento diferente entre os dois pipelines, o que gerou uma divergência intencional na modelagem.
 
| Ano  | Valores |
|------|---------|
| 2022 | `S`, `N` |
| 2023 | `S`, `N` |
| 2024 | `S`, `N`, `N/I` |
 
**No ETL**, o campo `Assinatura do Auto` foi repurposado para identificar o **tipo do documento de autuação** (`AI`, `AIT`, `ANI`), sendo armazenado como `tipo_auto` na `dim_infracao` com os valores decodificados: "Auto de Infração", "Auto de Infração de Trânsito" ou "Aviso de Notificação de Infração". O valor `N/I` de 2024, nesse contexto, resulta em `'Não informado'`.
 
**No ELT (dbt)**, o campo `assinatura_auto` é preservado como string sem normalização, passando direto pela camada intermediária `int_multas_preparados` para a `fato_multa`.
 
---
 
### 6.4 Registros corrompidos em 2022
 
O arquivo `infrações2022_10.csv` foi salvo com encoding incorreto, causando perda dos acentos nos cabeçalhos. Aproximadamente **300 mil linhas** vieram com todas as colunas nulas por causa do mapeamento falho de nomes de colunas.
 
**Tratamento:** ambos os pipelines filtram registros sem `numero_auto` válido antes da carga na tabela fato. O mapeamento `HEADER_FIX` foi construído manualmente para cobrir os cabeçalhos corrompidos (ex: `'munic\uFFFDpio'` → `'município'`), recuperando parte dos registros afetados.
 
---
 
### 6.5 Valores inválidos em `UF Placa`
 
Foram identificados valores fora do padrão de siglas de estados brasileiros no campo `UF Placa`: `'-1`, `'/'`, sequências numéricas como `00`–`99`, `N/I`, entre outros.
 
O ELT aplica a seguinte lógica de normalização:
 
| Valor original | Resultado |
|----------------|-----------|
| Sigla de UF válida (AC, SP, etc.) | Mantida sem alteração |
| `N/I` | → `EX` (tratado como estrangeiro) |
| String de 2 chars com dígito (ex: `99`) | → `EX` |
| `'-1` ou variações com hífen/aspas | → `N/I` |
| `/` | Registro **removido** do dataset |
| Demais inválidos | → `N/I` |
 
A lógica preserva a autuação — descartando apenas registros com placa `/` — e registra a impossibilidade de identificação da origem sem perder o evento.
 
---
 
### 6.6 Datas lidas como string
 
Nos três anos, as datas chegam nos CSVs no formato `DD/MM/YYYY` como texto, e o Pandas não as converte automaticamente por causa do separador `;` e do `dtype=str` forçado na leitura.
 
**Tratamento no ETL:** validação via regex antes do parse — apenas strings no formato `^\d{2}/\d{2}/\d{4}$` são convertidas com `pd.to_datetime(format='%d/%m/%Y')`; demais resultam em exclusão da linha da tabela fato (o filtro `df_mes = df_mes[df_mes['data...'].str.match(...)]` rejeita datas malformadas antes do processamento).
 
**Tratamento no ELT (dbt):** conversão via CASE no `int_multas_preparados` — apenas strings no formato `YYYY-MM-DD` (após carga bruta) são convertidas com `::DATE`; demais resultam em `NULL`, e registros com `data_infracao IS NULL` são excluídos na última CTE do modelo intermediário.

## 7. Volumetria

|Ano|Registros brutos|Observações|
|---|---|---|
|2022|a confirmar|~300k linhas corrompidas em `infraçoes2022_10.csv`|
|2023|5.946.483|Sem grandes inconsistências|
|2024|8.710.022|Mudança no formato de `indicador_veiculo_estrangeiro`|

> Os volumes finais (após limpeza) serão consolidados após a execução completa dos pipelines ETL e ELT.

---

## 8. Referências

- **Portal de Dados Abertos da PRF:** https://www.gov.br/prf/pt-br/acesso-a-informacao/dados-abertos/dados-abertos-da-prf
- **Dicionário de Variáveis – Infrações** (PRF, Setembro/2016) — utilizado como fonte primária para nomenclatura e descrições oficiais dos campos.
- **Código de Trânsito Brasileiro (CTB)** — Lei nº 9.503/1997, base do enquadramento das infrações.
- **Kimball, Ralph & Ross, Margy.** _The Data Warehouse Toolkit: The Definitive Guide to Dimensional Modeling._ 3rd ed. Wiley, 2013. — referência clássica para conceitos de Star Schema, grão da tabela fato e dimensões degeneradas.

---

_Documento elaborado pelo Grupo 6 — CIN0137 (Banco de Dados) — UFPE/CIn_
