
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
| **Tecnologias**             | PostgreSQL (hospedado no Neon), Python (pandas, SQLAlchemy), dbt                                                                                 |
| **Modelo adotado**          | Esquema Estrela (Star Schema)                                                                                                                    |

---

## 2. Justificativa do Modelo Dimensional

A escolha do **Esquema Estrela** baseou-se em três razões principais:

**1. Foco em análise (OLAP), não em transações (OLTP).** O sistema operacional da PRF é otimizado para registrar autuações no dia a dia, ou seja, é um banco transacional. Já o Data Warehouse é construído para responder perguntas analíticas como _"quantas multas por UF em 2023?"_ ou _"qual a evolução de infrações por trimestre?"_. Essas consultas envolvem leituras grandes, agregadas, sobre dados históricos. Essas duas frentes têm requisitos opostos: o transacional exige normalização (3FN) para evitar redundância em escritas, já o analítico exige desnormalização para minimizar JOINs em leituras.

**2. Simplicidade e performance em consultas.** O Star Schema reduz o número de JOINs necessários em consultas analíticas. Em vez de navegar várias tabelas normalizadas, basta unir a tabela fato com as dimensões necessárias.

**3. Aderência ao modelo cognitivo de análise.** Analistas pensam em termos de "métricas por dimensão", *como quantas multas (métrica) por UF (dimensão)? Por mês (dimensão)?* O Star Schema é reflexo desse pensamento, facilitando a tradução de perguntas de negócio em consultas SQL.

---

## 3. Diagrama do Star Schema

```
                       ┌─────────────────────┐
                       │       Tempo         │
                       │  (Dim. temporal)    │
                       └──────────┬──────────┘
                                  │
                                  │ ID_Tempo
                                  │
┌─────────────────────┐           ▼          ┌─────────────────────┐
│    Localizacao      │   ┌──────────────┐   │      Infrator       │
│  (Dim. geográfica)  │◄──┤  Fato_Multa  ├──►│  (Dim. veículo)     │
└─────────────────────┘   │   (Fato)     │   └─────────────────────┘
        ID_Localizacao    └──────┬───────┘   ID_Infrator
                                 │
                                 │ ID_Infracao
                                 │
                       ┌─────────▼───────────┐
                       │      Infracao       │
                       │  (Dim. da regra)    │
                       └─────────────────────┘
```

> Uma versão visual mais elaborada do diagrama será produzida no Draw.io e disponibilizada em `docs/diagrama_star_schema.png`.

**Observação sobre convenção de nomenclatura:** os identificadores no banco usam **português sem acentos** e seguem o padrão PascalCase para as tabelas (`Fato_Multa`) e snake_case para as colunas (`ID_Tempo`, `UF_Infracao`). 

---

## 4. Descrição das Tabelas

### 4.1 Tabela Fato — `Fato_Multa`

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

### 4.2 Dimensão `Tempo`

**Papel:** descrever os atributos temporais de cada autuação, permitindo análises por dia, mês, trimestre, ano, dia da semana e feriado.

**Particularidade:** os atributos `Dia`, `Mes`, `Ano`, `Trimestre`, `Dia_Semana` e
`Is_Feriado` são pré-computados a partir do campo `Data_Infracao` durante o
ETL/ELT. Essa desnormalização é proposital: evita o uso de funções de data
nas consultas analíticas, melhorando performance.

**OBS:** o campo `Is_Feriado` requer uma fonte externa de calendário de feriados nacionais e esse tratamento foi definido como parte da etapa de transformação.

---

### 4.3 Dimensão `Localizacao`

**Papel:** descrever **onde** ocorreu a infração — Unidade Federativa, rodovia (BR), quilômetro e município.

**Particularidade:** a combinação `UF + BR + KM + Município` define unicamente cada registro de localização. Essa combinação tem ordem de grandeza muito menor que a tabela fato, provavelmente algumas dezenas de milhares de combinações distintas para milhões de autuações.

---

### 4.4 Dimensão `Infracao`

**Papel:** descrever **o tipo de infração cometida**, qual regra do Código de Trânsito Brasileiro foi violada, qual o código de enquadramento, e qual o período de vigência da regra.

**Particularidade:** o campo `Fim_Vigencia` veio **100% nulo** nos 3 anos analisados. Durante o ETL/ELT esse campo será removido por não trazer informação. Detalhes no item 6.1.

---

### 4.5 Dimensão `Infrator`

**Papel:** descrever **o veículo associado à autuação**, origem da placa, se é estrangeiro, espécie, marca, tipo e modelo do veículo.

**Observação importante sobre o nome da dimensão:** A base PRF **não disponibiliza dados pessoais do condutor** (sigilo previsto na LAI e na LGPD). Os atributos disponíveis caracterizam exclusivamente o **veículo envolvido**. Por isso a dimensão se chama "Infrator" no modelo, mas seus atributos são todos relativos ao veículo.

---

## 5. Dicionário de Dados

> **Fontes:**
> 
> 1. **Nome no Dicionário PRF:** nomenclatura oficial documentada pela PRF no _Dicionário de Variáveis – Infrações_ (Setembro/2016).
> 2. **Nome no CSV:** nome real da coluna nos arquivos baixados.
> 3. **Nome no DW:** nome final adotado no Data Warehouse após padronização.

> ⚠️ **Atenção:** o dicionário oficial da PRF teve última atualização em 2016 e alguns campos presentes nos CSVs atuais (2022–2024) **não estão documentados oficialmente** — esses casos estão marcados como `(não documentado em 2016)` na tabela. As descrições desses campos foram inferidas pelo grupo a partir dos dados.

### 5.1 Tabela Fato — `Fato_Multa`

| Campo no DW           | Tipo        | Nome no CSV            | Nome PRF (2016)             | Descrição                                                              |
| --------------------- | ----------- | ---------------------- | --------------------------- | ---------------------------------------------------------------------- |
| `ID_Fato_Multa`       | SERIAL PK   | —                      | —                           | Surrogate key gerada no DW                                             |
| `ID_Tempo`            | INT FK      | —                      | —                           | Referência à dimensão Tempo                                            |
| `ID_Infracao`         | INT FK      | —                      | —                           | Referência à dimensão Infracao                                         |
| `ID_Infrator`         | INT FK      | —                      | —                           | Referência à dimensão Infrator                                         |
| `ID_Localizacao`      | INT FK      | —                      | —                           | Referência à dimensão Localizacao                                      |
| `Numero_Auto`         | VARCHAR(20) | Número do Auto         | _(não documentado em 2016)_ | Identificador do auto de infração                                      |
| `Qts_Infracoes`       | INT         | Qtd Infrações          | _(não documentado em 2016)_ | Quantidade de infrações no auto                                        |
| `Medicao_Infracao`    | INT         | Medição Infração       | `med_realizada`             | Medição registrada por equipamento (radar, etilômetro, balança, trena) |
| `Medicao_Considerada` | INT         | Medição Considerada    | `med_considerada`           | Medição considerada para o registro da infração                        |
| `Excesso_Verificado`  | INT         | Excesso Verificado     | `exc_verificado`            | Excesso verificado nas infrações com equipamento de medição            |
| `Indicador_Abordagem` | CHAR(1)     | Indicador de Abordagem | `tip_abordagem`             | C = houve abordagem do veículo; S = não houve abordagem                |
| `Assinatura_Auto`     | CHAR(1)     | Assinatura do Auto     | `ind_assinou_auto`          | S = infrator assinou; vazio/N = não assinou                            |
| `Sentido_Trafego`     | CHAR(1)     | Sentido Trafego        | `ind_sentido_trafego`       | C = sentido crescente; D = sentido decrescente                         |

### 5.2 Dimensão `Tempo`

|Campo no DW|Tipo|Origem|Descrição|
|---|---|---|---|
|`ID_Tempo`|SERIAL PK|gerado|Surrogate key|
|`Hora_Infracao`|INT|"Hora Infração" do CSV|Hora em que a infração ocorreu (0–23)|
|`Data_Infracao`|DATE|"Data da Infração (DD/MM/AAAA)" / `dat_infracao`|Data da infração no formato dd/mm/aaaa|
|`Dia`|INT|derivado|Dia do mês (1–31)|
|`Mes`|INT|derivado|Mês (1–12)|
|`Ano`|INT|derivado|Ano com 4 dígitos|
|`Trimestre`|INT|derivado|Trimestre (1–4)|
|`Dia_Semana`|VARCHAR(15)|derivado|Dia da semana por extenso|
|`Is_Feriado`|BOOLEAN|derivado (lookup externo)|Indica se a data é feriado nacional|

### 5.3 Dimensão `Localizacao`

| Campo no DW      | Tipo         | Nome no CSV | Nome PRF (2016)   | Descrição                                  |
| ---------------- | ------------ | ----------- | ----------------- | ------------------------------------------ |
| `ID_Localizacao` | SERIAL PK    | —           | —                 | Surrogate key                              |
| `UF_Infracao`    | CHAR(2)      | UF Infração | `uf_infracao`     | Unidade federativa onde ocorreu a infração |
| `BR_Infracao`    | VARCHAR(5)   | BR Infração | `num_br_infracao` | Identificador numérico da BR               |
| `KM_Infracao`    | INT          | Km Infração | `num_km_infracao` | Quilômetro da rodovia onde ocorreu         |
| `Municipio`      | VARCHAR(100) | Município   | `nom_municipio`   | Nome do município                          |

### 5.4 Dimensão `Infracao`

| Campo no DW              | Tipo         | Nome no CSV                  | Nome PRF (2016)             | Descrição                                                           |
| ------------------------ | ------------ | ---------------------------- | --------------------------- | ------------------------------------------------------------------- |
| `ID_Infracao`            | SERIAL PK    | —                            | —                           | Surrogate key                                                       |
| `Cod_Infracao`           | INT          | Código da Infração           | _(não documentado em 2016)_ | Código numérico da infração                                         |
| `Descricao_Infracao`     | VARCHAR(300) | Descrição Abreviada Infração | `descricao_abreviada`       | Descrição abreviada da infração                                     |
| `Enquadramento_Infracao` | VARCHAR(300) | Enquadramento da Infração    | `enquadramento`             | Enquadramento da infração de acordo com o CTB                       |
| `Inicio_Vigencia`        | DATE         | Início Vigência da Infração  | `data_inicio_vigencia`      | Data de início da vigência da infração                              |
| `Fim_Vigencia`           | DATE         | Fim Vigência Infração        | `data_fim_vigencia`         | Data de fim da vigência (campo 100% nulo nos dados — será removido) |

### 5.5 Dimensão `Infrator`

| Campo no DW             | Tipo        | Nome no CSV                   | Nome PRF (2016)             | Descrição                                                      |
| ----------------------- | ----------- | ----------------------------- | --------------------------- | -------------------------------------------------------------- |
| `ID_Infrator`           | SERIAL PK   | —                             | —                           | Surrogate key                                                  |
| `Indicador_Estrangeiro` | CHAR(1)     | Indicador Veiculo Estrangeiro | `ind_veiculo_estrangeiro`   | Indica veículo estrangeiro — ver §6.2 sobre mudança entre anos |
| `UF_Placa`              | CHAR(2)     | UF Placa                      | `uf_placa`                  | Unidade federativa da placa do veículo                         |
| `Descricao_Especie`     | VARCHAR(20) | Descrição Especie Veículo     | `especie`                   | Espécie do veículo conforme registro                           |
| `Descricao_Marca`       | VARCHAR(50) | Descrição Marca Veículo       | `nome_veiculo_marca`        | Marca do veículo                                               |
| `Descricao_Tipo`        | VARCHAR(20) | Descrição Tipo Veículo        | _(não documentado em 2016)_ | Tipo do veículo                                                |
| `Descricao_Modelo`      | VARCHAR(50) | Descrição Modelo Veiculo      | `nom_modelo_veiculo`        | Modelo do veículo                                              |

---

## 6. Considerações sobre Diferenças entre Anos

Durante a fase de diagnóstico exploratório dos dados, foram identificadas mudanças relevantes entre as três bases. Esta seção documenta cada uma e o tratamento adotado.

### 6.1 Campo `Fim_Vigencia` totalmente nulo

Em **todos os 3 anos** (2022, 2023, 2024), **100% dos registros** têm o campo `Fim Vigência Infração` como NULL. Esse campo será **removido** durante a transformação, pois não traz informação útil.

> Tratamento no ETL: `df.drop(columns=['fim vigência infração'])`

### 6.2 `Indicador Veículo Estrangeiro` mudou de significado em 2024

Esta é a diferença **mais relevante** entre as bases, e exige tratamento especial:

|Ano|Valores observados|Interpretação|
|---|---|---|
|2022|`S`, `N`|Indicador binário (Sim / Não)|
|2023|`S`, `N`, `/`|Indicador binário com inválidos|
|2024|`BR`, `AR`, `BO`, `CL`, `GY`, `MX`, `N`, `PY`, `S`, `UY`, `VE`, `99`, `AR`|**Código do país de origem** do veículo|

A partir de 2024, a PRF passou a registrar o país de origem do veículo (códigos ISO) em vez do indicador binário.

**Tratamento proposto:** padronização para um único formato, converter os valores de 2024 para `S` quando o país for diferente de `BR` (veículo estrangeiro) e `N` quando for `BR`. Os códigos de país podem ser preservados em um campo auxiliar caso futuras análises precisem dessa granularidade.

### 6.3 `Assinatura do Auto` ganhou valor `N/I` em 2024

|Ano|Valores|
|---|---|
|2022|`S`, `N`|
|2023|`S`, `N`|
|2024|`S`, `N`, `N/I`|

Em 2024 surge o valor `N/I` (Não Informado). Durante a transformação, esse valor será mapeado para `N` ou nulo.

### 6.4 Registros corrompidos em 2022

O arquivo `infraçoes2022_10.csv` apresentou problema de encoding com perda de acentos nos cabeçalhos. Aproximadamente **300 mil linhas** vieram completamente nulas. Esses registros serão removidos durante o ETL através do filtro `dropna(subset=['número do auto'])`, garantindo que apenas autuações com identificador válido sejam carregadas no DW.

### 6.5 Valores inválidos em `UF Placa`

Foram identificados valores não-UF no campo, como `'-1`, `/`, `00`–`99`, `N/I`, entre outros. Esses registros terão o campo padronizado para `'NÃO INFORMADO'` durante a transformação, preservando a linha (a infração existe, apenas a placa não pôde ser registrada corretamente).

### 6.6 Formato de datas

Mesmo após a leitura, 100% das datas aparecem como "inválidas" no diagnóstico inicial, indicando que estão sendo lidas como string. Será aplicada conversão explícita via `pd.to_datetime(format='%d/%m/%Y', errors='coerce')`, com datas malformadas convertidas para `NaT` (Not a Time).

---

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