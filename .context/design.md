# Design — Galeria de Cartas OPTCG (Fase 1)

## 1. Visão geral

O sistema tem três subsistemas com responsabilidades bem separadas:

```
┌──────────────────┐
│  Fonte externa   │  (API comunitária, scraping ou dataset — P1 pendente)
└────────┬─────────┘
         │  execução manual/agendada
         ▼
┌──────────────────┐
│    INGESTÃO      │  Normaliza → faz upsert → registra resumo
│  (jobs em bg)    │  Nunca toca em dados do usuário
└────────┬─────────┘
         ▼
┌──────────────────────────────────────────────┐
│                  CATÁLOGO                    │
│  sets · cards · card_variants                │  Somente-leitura pro usuário
│  Read-heavy, busca e filtros                 │
└────────┬─────────────────────────────────────┘
         │  referenciado por
         ▼
┌──────────────────────────────────────────────┐
│                  COLEÇÃO                     │
│  users · collection_items · wishlist_items   │  Escrita frequente, granular
└──────────────────────────────────────────────┘
```

A separação importa por um motivo prático: o catálogo é substituível e
regenerável, a coleção é **insubstituível**. Todo o design de ingestão gira em
torno de nunca deixar o primeiro corromper o segundo (Requisito 1.7).

---

## 2. Avaliação de stack

Você não decidiu a stack, então esta seção compara as opções e propõe um default.

### Características da carga de trabalho

Antes de comparar, o que o app realmente é:

- **Read-heavy**, com um dataset pequeno em termos de banco de dados. Estimativa:
  ordem de alguns milhares de cartas e variantes por agora. ⚠️ Não tenho o número
  real de cartas lançadas — mas mesmo com folga generosa, isto é um dataset que
  cabe confortavelmente em Postgres sem nenhuma técnica especial.
- Escritas do usuário são **muitas e pequenas** (incrementar quantidade).
- A interação central é **filtrar uma grade** — precisa parecer instantânea.
- Muito uso em celular, mas via navegador é aceitável no MVP.

Conclusão relevante: o gargalo aqui **não é escala**. É a latência percebida no
filtro e a velocidade com que você consegue construir.

### Comparativo

| Critério                          | Rails + Hotwire                                     | SPA (React/Vue) + API                      | Mobile (React Native/Flutter)           |
| --------------------------------- | --------------------------------------------------- | ------------------------------------------ | --------------------------------------- |
| Velocidade de entrega pra você    | **Alta** — território conhecido                     | Média — dois deploys, dois modelos mentais | Baixa — build, assinatura, distribuição |
| Filtro instantâneo na grade       | Bom com Turbo Frames; ida ao servidor por interação | **Ótimo** — estado no cliente              | Ótimo                                   |
| Reaproveitamento p/ mobile futuro | Adicionar endpoints JSON depois                     | API já existe de graça                     | É o mobile                              |
| Complexidade operacional          | **Baixa** — um app, um deploy                       | Média                                      | Alta                                    |
| Custo de aprendizado              | Baixo                                               | Médio                                      | Alto                                    |
| Uso offline                       | Não                                                 | Parcial (PWA)                              | Sim                                     |

### Recomendação (default proposto)

**Rails 8 + Hotwire + PostgreSQL**, com as rotas de catálogo já respondendo
também em JSON.

Justificativa honesta: a decisão dominante aqui é a sua produtividade, não a
arquitetura. Você já opera Rails, Docker e CI. Uma SPA compraria uma experiência
de filtro marginalmente melhor ao custo de dobrar a superfície do projeto — em um
projeto pessoal, esse é o tipo de custo que faz o projeto morrer na metade.

Sobre o filtro: `debounce` + Turbo Frame por cima de uma consulta indexada em
Postgres, com um dataset deste tamanho, é rápido o suficiente. **Mas isto é uma
estimativa, não uma medição** — a task 3.4 em `tasks.md` existe justamente para
validar contra o Requisito 11.1. Se falhar, a saída é hidratar os filtros no
cliente com Stimulus, não trocar a stack.

Quando **não** seguir esta recomendação:

- Se o objetivo paralelo for aprender front-end moderno → SPA, e o custo extra
  passa a ser benefício.
- Se uso offline for essencial (abrir boosters sem sinal) → nesse caso Hotwire não
  resolve, e a conversa muda para PWA ou app nativo. **Isso não está nos
  requisitos atuais.** Se for importante pra você, precisa virar requisito antes
  de virar código.

> ✅ VERIFICADO (task 1.1) — `rails generate authentication` existe em
> railties 8.0 e **atende o Requisito 6**, sem biblioteca externa:
>
> | Critério | Como é atendido |
> | -------- | --------------- |
> | 6.1 criar conta, autenticar, encerrar sessão | `SessionsController` + `PasswordsController` gerados; `User` com `has_many :sessions` |
> | 6.2 senha só como hash | `has_secure_password` → bcrypt |
> | 6.3 catálogo aberto a anônimo | `allow_unauthenticated_access` no concern `Authentication` |
> | 6.4 mutação exige sessão | `before_action :require_authentication` é o default; opt-out é explícito |
> | 6.5 ninguém lê coleção alheia | `Current.session` resolve o usuário a partir do cookie assinado, nunca de um ID do request — é a base que o Req. 6.5 pede |
>
> O gerador ainda **não foi executado**: ele cria `User` e `Session`, que são da
> Fase 4. Rodar na task correspondente, não aqui.
>
> **Solid Queue / Solid Cache foram descartados** (`rails new --skip-solid`).
> A Fase 1 não tem job assíncrono nem cache de aplicação: a ingestão roda sob
> demanda (Req. 1.1) e os alvos de latência do Req. 11.1 são de consulta ao
> Postgres. Três tabelas e um segundo serviço de infraestrutura sem consumidor
> seriam custo sem contrapartida. Quando a Fase 2 ou 3 precisar de job em
> background, reintroduzir com `bin/rails solid_queue:install`.

> **P4 DECIDIDA (task 0.3):** Rails 8 + Hotwire + PostgreSQL — ver
> `docs/adr/002-stack-set-completo-e-imagens.md`. Postgres é o fator decisivo:
> `pg_trgm`, `unaccent` e GIN sobre arrays sustentam os Req. 3 e 4 inteiros.
> O restante deste documento segue agnóstico de framework, o que mantém a troca
> barata caso a medição da task 3.4 contrarie a premissa.

---

## 3. Modelo de dados

### 3.1 A decisão central: `Card` ≠ `CardVariant`

Este é o ponto que mais frequentemente é modelado errado em app de TCG, e o que
mais custa para corrigir depois.

- Um **Card** é a carta do jogo. Identificada por `card_number` (`OP01-001`). É a
  entidade sobre a qual as regras e os textos falam.
- Um **CardVariant** é uma impressão física específica: arte base, arte
  alternativa, parallel, promo, manga rare. Mesmo `card_number`, mesmo efeito —
  **objeto de coleção completamente diferente**, com raridade e valor próprios.

Coleção e wishlist referenciam **variantes**. Busca e filtros operam sobre
**cartas**, exibindo variantes agregadas.

Se você colapsar as duas entidades, perde a capacidade de dizer "tenho a base do
Luffy, quero a alternativa" — que é metade do sentido do produto.

### 3.2 Entidades

```
sets
  id
  code                text    UNIQUE     -- "OP01", "ST01", "EB01"
  name                text
  kind                enum               -- booster | starter | extra_booster | promo | other
  released_on         date    NULL
  timestamps

cards
  id
  set_id              FK sets            -- set de estreia da carta
  card_number         text    UNIQUE     -- "OP01-001"
  name                text
  card_type           enum               -- leader | character | event | stage
  colors              text[]             -- ["red"] ou ["red","green"]
  cost                integer NULL       -- NULL para leader
  life                integer NULL       -- só leader
  power               integer NULL       -- leader e character
  counter             integer NULL       -- NULL = sem counter (≠ counter 0)
  attributes          text[]             -- ["slash"]
  traits              text[]             -- ["Straw Hat Crew"]
  effect_text         text    NULL
  trigger_text        text    NULL
  timestamps

card_variants
  id
  card_id             FK cards
  set_id              FK sets            -- set desta impressão específica
  variant_code        text               -- identificador estável da impressão
  rarity              text               -- ver ⚠️ abaixo
  art_kind            enum               -- base | alternate_art | parallel | manga | promo | other
  image_url           text    NULL
  image_url_large     text    NULL
  illustrator         text    NULL
  timestamps
  UNIQUE (card_id, variant_code)

users
  id
  email               text    UNIQUE (case-insensitive)
  password_digest     text
  timestamps

collection_items
  id
  user_id             FK users
  card_variant_id     FK card_variants
  quantity            integer  CHECK (quantity >= 0)
  timestamps
  UNIQUE (user_id, card_variant_id)          -- Requisito 7.8

wishlist_items
  id
  user_id             FK users
  card_variant_id     FK card_variants
  target_quantity     integer  CHECK (target_quantity >= 1)
  timestamps
  UNIQUE (user_id, card_variant_id)

import_runs
  id
  source              text
  source_revision     text               -- Requisito 1.10; commit ou tag imutável
  status              enum               -- running | succeeded | failed
  started_at          datetime
  finished_at         datetime NULL
  created_count       integer  DEFAULT 0
  updated_count       integer  DEFAULT 0
  failed_count        integer  DEFAULT 0
  error_log           jsonb    NULL       -- Requisito 1.5
```

### 3.3 Notas de modelagem

- **`counter` nulo vs zero.** Semanticamente diferentes: "não tem counter" não é
  "counter de 0". Manter `NULL` e nunca usar `0` como sentinela.
- **`colors` como array.** Postgres `text[]` + índice GIN resolve o Requisito 4.5
  ("cartas multicoloridas aparecem no filtro de cada cor") com uma expressão
  simples de sobreposição de arrays. Tabela de junção seria mais ortodoxa; para um
  domínio de 6 valores fixos que nunca muda, é complexidade sem retorno. Se você
  precisar de metadados por cor no futuro, migre então.
- **`traits` como array.** Mesma lógica, mas aqui a cardinalidade é alta e os
  valores vêm de texto livre da fonte externa. Risco real: `"Straw Hat Crew"` vs
  `"Straw hat crew"` viram traits distintos e o filtro fica furado. Mitigação:
  normalizar na ingestão e, se o filtro por trait virar central, promover a
  tabela própria com dicionário canônico.
- **`variant_code`** precisa ser estável entre execuções da ingestão, senão o
  Requisito 1.3 (idempotência) quebra e o usuário perde o vínculo com sua coleção.
  Se a fonte externa não fornecer um identificador estável de impressão, derive um
  determinístico de `card_number + rarity + art_kind` e **documente essa decisão**
  — é a parte mais frágil do design.
- **`rarity` como texto, não enum.** ⚠️ Não tenho a lista completa e confirmada de
  raridades do OPTCG (§`product.md` 6). Enum com lista incompleta faz a ingestão
  explodir quando um valor novo aparecer. Use texto validado contra uma lista
  configurável em código, e converta para enum depois que a lista real for
  confirmada.

### 3.4 Índices

Alinhados ao Requisito 11.3:

| Índice                                               | Serve                              |
| ---------------------------------------------------- | ---------------------------------- |
| `cards (card_number)` UNIQUE                         | Req. 3.4 — match exato prioritário |
| GIN em `cards (colors)`                              | Req. 4.1, 4.5                      |
| GIN em `cards (traits)`                              | Req. 4.1                           |
| GIN em `cards (attributes)`                          | Req. 4.1                           |
| `cards (card_type)`                                  | Req. 4.1                           |
| `cards (cost)`, `cards (power)`, `cards (counter)`   | Req. 4.2 — faixas                  |
| `card_variants (set_id, rarity)`                     | Req. 4.1, Req. 9                   |
| `collection_items (user_id, card_variant_id)` UNIQUE | Req. 7.6, 7.8                      |
| Trigram em `cards (name)`                            | Req. 3.2, 3.3                      |

---

## 4. Busca e filtros

### 4.1 Estratégia proposta

Fazer tudo em PostgreSQL, sem serviço de busca dedicado.

- **Nome (Req. 3.2, 3.3):** extensão `pg_trgm` com índice GIN usando o operador
  de similaridade trigram. Isso dá tolerância a erro de digitação. Para
  insensibilidade a acento, a extensão `unaccent` — **mas não diretamente**:
  `unaccent` é `STABLE`, não `IMMUTABLE`, e por isso o Postgres recusa usá-la
  tanto em coluna gerada quanto em índice de expressão. É preciso envolvê-la em
  uma função `IMMUTABLE` própria com o dicionário fixado explicitamente. Ver
  4.1.1.
- **Texto de efeito (Req. 3.1):** busca full-text via `tsvector` em coluna gerada,
  com índice GIN.
- **Match exato de `card_number` (Req. 3.4):** consulta separada, resultado
  prependido antes dos demais. Não tente resolver ranking exato dentro do
  full-text — é mais simples e mais previsível fazer duas consultas. A
  comparação é contra a coluna crua (`card_number = ?`), com o termo passado em
  maiúsculas pelo Ruby: `upper(card_number) = upper(?)` descarta o índice único
  e vira varredura completa. Todos os 2815 `card_number` do catálogo já são
  maiúsculos.
- **Substring de `card_number` (Req. 3.1):** o termo também casa por
  substring, o que exige índice GIN trigram em `card_number` — ver 4.1.2.

### 4.1.2 A busca só é indexável com GIN trigram em `card_number`

Medido na T11 contra o catálogo real, e **corrigido na verificação do B2**: a
primeira redação deste parágrafo atribuía ao `UNION` um efeito que pertence ao
índice.

Os três caminhos do Req. 3.1 (nome, efeito, `card_number`) num único
`WHERE ... OR ... OR ...` produziam **Seq Scan**. A causa é uma só:

- `card_number ILIKE '%termo%'` só é indexável com **GIN trigram em
  `card_number`** (migração `20260919120300`). O índice único btree não serve:
  criado com a collation padrão, nem `LIKE` ancorado o usa. Buscar código
  parcial é caso real — "OP01" casa 121 cartas, 13 delas em
  `LimitedProductCard`, que o filtro de set sozinho não acharia.

Com esse índice presente, o `OR` planeja como `BitmapOr` sobre os três
`Bitmap Index Scan`, sem Seq Scan — verificado por `EXPLAIN`. Ou seja: **o
`UNION` não é o que resolve a indexabilidade.**

A consulta continua usando `UNION` de subconsultas, uma por índice, porque
cada ramificação é planejada isoladamente e o resultado independe de o
planejador escolher o `BitmapOr`. É uma escolha de previsibilidade, não o
remédio para o Seq Scan. Trocar por `OR` hoje também funcionaria; o que **não**
pode sumir é o índice.

### 4.1.3 Tolerância a typo exige `word_similarity`, não `similarity`

Medido na T11 contra as 2815 cartas reais. O par default do `pg_trgm`
(`%` com `similarity_threshold = 0.3`) **não atende o Req. 3.3**:

```
similarity('Zorro', 'Roronoa Zoro')      = 0.286   < 0.3   → não casa
word_similarity('Zorro', 'Roronoa Zoro') = 0.571   < 0.6   → não casa no default
```

A similaridade da string inteira é diluída pelo sobrenome que o termo não tem.
`word_similarity` (operador `<%`) compara o termo contra a melhor extensão do
nome e não sofre essa diluição. O limiar vai a **0.5** via
`set_config('pg_trgm.word_similarity_threshold', '0.5', true)` — local à
transação, não vaza para outra conexão do pool. Verificado com typos reais:
`Zorro`→Zoro, `Namy`→Nami, `Luffi`→Luffy, `Belmere`→Bell-mère. O operador `<%`
continua usando o índice GIN trigram.

### 4.1.1 `unaccent` não é indexável sem wrapper

Verificado na T4 contra o PostgreSQL 17.11 — este parágrafo substitui um
`⚠️ VERIFICAR` que a verificação **refutou**, e a suposição original estava
errada:

```sql
SELECT proname, provolatile FROM pg_proc WHERE proname = 'unaccent';
-- unaccent | s   (STABLE, nas duas assinaturas)
```

Índice de expressão e coluna gerada exigem `IMMUTABLE`; as duas formas foram
testadas e as duas falham. `unaccent` é `STABLE` porque o dicionário de
tradução pode ser redefinido em runtime. Fixando o dicionário, a função passa
a ser determinística e o wrapper pode declarar `IMMUTABLE` honestamente:

```sql
CREATE FUNCTION immutable_unaccent(text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS
$$ SELECT public.unaccent('public.unaccent'::regdictionary, $1) $$;

CREATE INDEX index_cards_on_unaccent_name_trgm
  ON cards USING gin (immutable_unaccent(name) gin_trgm_ops);
```

A consulta precisa chamar `immutable_unaccent(name)`, e não `unaccent(name)`,
senão o índice não é usado. Isso vale para a T11 (busca textual).

> ⚠️ VERIFICAR — `gin_trgm_ops` e a forma de dois argumentos de `to_tsvector`
> foram conferidos na documentação do PostgreSQL 17 na T4 (só a forma de dois
> argumentos de `to_tsvector` é `IMMUTABLE`, portanto indexável). O restante da
> sintaxe continua valendo a regra: **não escreva de memória** — confira na
> documentação da versão em uso.

**Por que não Elasticsearch/Meilisearch/OpenSearch:** o dataset é pequeno e as
consultas são estruturadas, não linguagem natural. Um serviço de busca
adicionaria um container, um índice para sincronizar e uma classe de bug novo
(divergência entre índice e banco) sem ganho perceptível nesta escala. Reavalie se
e quando o Req. 11.1 falhar por causa de busca — não antes.

### 4.2 Contrato do query object

Um único ponto de entrada traduz parâmetros da URL em consulta. Serve tanto o HTML
quanto o JSON, e é o único lugar que precisa de teste de filtro.

Parâmetros aceitos (Req. 4.7 — tudo vem da URL):

```
q                  busca textual livre
colors[]           OU dentro da categoria
card_types[]
sets[]
rarities[]
attributes[]
traits[]
cost_min, cost_max
power_min, power_max
counter_min, counter_max
owned              all | owned | missing        (Req. 7.6, exige sessão)
sort               card_number | name | cost | power
dir                asc | desc
page, per_page
```

Retorna: coleção paginada + `total_count` (Req. 4.8) + filtros ativos
normalizados, para renderizar os chips removíveis do Req. 4.6.

Regra de robustez: parâmetro desconhecido ou com valor inválido é **ignorado**,
não causa erro. Uma URL compartilhada nunca deve dar 500 porque um filtro foi
renomeado.

---

## 5. Ingestão

### 5.1 Estrutura em três estágios

```
Fetch → Normalize → Upsert
```

Cada estágio isolado, porque cada um falha de forma diferente:

1. **Fetch** — única parte que toca a rede. Busca uma **revisão imutável** da
   fonte (commit ou tag, nunca `main` — Req. 1.9) e salva o payload bruto em
   disco antes de processar. Isso permite reprocessar sem refazer a chamada e é
   o que torna possível o Req. 11.5 (teste sem rede: o payload salvo vira
   fixture).
2. **Normalize** — mapeia o formato externo para o modelo interno. Todo
   conhecimento sobre o formato da fonte vive **aqui e só aqui**. Trocar de fonte
   de dados deve significar escrever um normalizador novo, nada mais.
3. **Upsert** — grava com idempotência por chave natural (`card_number` para
   cartas, `card_id + variant_code` para variantes).

### 5.2 Garantias

| Requisito               | Como é atendido                                                                                   |
| ----------------------- | ------------------------------------------------------------------------------------------------- |
| 1.4 idempotência        | Upsert por chave natural, nunca `create` cego                                                     |
| 1.5 erro isolado        | Cada registro em transação própria; falha registrada em `import_runs.error_log` e o loop continua |
| 1.7 não destrói coleção | A ingestão **não tem operação de delete.** Carta ausente da fonte é marcada, nunca removida       |
| 1.8 falha explícita     | Se o Fetch falhar, o processo aborta antes de qualquer escrita no banco                           |
| 1.9 revisão fixada      | Fetch resolve a revisão configurada (commit/tag); referência móvel é rejeitada na configuração    |
| 1.10 revisão auditável  | A revisão usada é gravada em `import_runs.source_revision` junto ao resumo da execução            |

Sobre 1.7: se uma carta sai da fonte externa, o correto é adicionar um campo de
"visto na última execução" e sinalizar na UI, não deletar. Deletar uma variante
apagaria em cascata o registro de coleção do usuário — perda de dado
irrecuperável a partir de um erro da fonte externa. **Nenhuma foreign key da
coleção deve usar delete em cascata.**

Sobre 1.9 e 1.10: a fonte é um scraper de terceiro com CI semanal que commita em
`main` (ADR 001). Puxar `main` significa que uma mudança de formato upstream
entra na ingestão sem aviso, no meio de uma execução. Fixar commit ou tag torna
a atualização da fonte uma decisão datada e revisável: quando o pin sobe, o
diff do payload bruto é inspecionável antes de qualquer escrita. Registrar a
revisão em `import_runs` é o que permite responder "de qual versão veio este
dado" depois do fato — sem isso, uma carta errada no catálogo não tem origem
rastreável.

---

## 6. Autenticação e autorização

- Sessão baseada em cookie, com hash de senha (Req. 6.2). Sem OAuth no MVP.
- Autorização é trivial e por isso deve ser feita de forma trivialmente correta:
  **toda** consulta a coleção ou wishlist parte do usuário da sessão, nunca de um
  ID vindo do request. Isso satisfaz o Req. 6.5 por construção, em vez de por
  verificação.
- Catálogo é público (Req. 6.3). Mutação exige sessão (Req. 6.4).

---

## 7. Imagens

Restrição de origem: ver `product.md` §5.1.

> **Revisado em 2026-09-22 — AD-012 supersede a P6 / AD-004.** O hotlink nunca
> funcionou em navegador: a fonte responde `Cross-Origin-Resource-Policy:
> same-site` em toda imagem, e o navegador descarta a resposta fora de
> `*.onepiece-cardgame.com`. O texto abaixo é o desenho vigente.

**A aplicação serve as imagens, sob demanda, com cache em disco.**

- Rota pública `GET /card_images/:variant_code` (catálogo é público, §6). O
  `<img>` da grade e do detalhe aponta para ela, nunca para `image_url`.
- Primeira requisição: busca a variante por `variant_code`, baixa `image_url`
  servidor-a-servidor (CORP não se aplica fora do navegador), grava em
  `storage/card_images/<variant_code>.<ext>` e serve. Seguintes: servem do disco.
- Resposta com cache HTTP longo. O arquivo muda só se a fonte trocar a arte sob o
  mesmo `variant_code`, caso em que apagar o arquivo basta.
- **Falha é placeholder.** Variante inexistente, sem `image_url`, erro ou timeout
  da fonte → resposta de erro sem corpo de imagem; o placeholder em CSS que já
  fica atrás do `<img>` (Req. 2.3) aparece. Falha não é gravada em disco — a
  próxima requisição tenta de novo.

Invariantes:

- **A URL de saída nunca vem do request.** Só `variant_code` entra; a URL é lida
  do banco. O host é conferido contra o da fonte antes do fetch — sem isso o
  endpoint é SSRF assim que a ingestão gravar uma URL inesperada.
- `variant_code` é validado por formato antes de virar nome de arquivo (nada de
  `/` ou `..`). Ele é único globalmente e estável (AD-001, §9), por isso é chave
  suficiente para o arquivo sem tabela de mapeamento.
- Escrita atômica: arquivo temporário + `rename`, para que duas requisições
  simultâneas da mesma carta nunca sirvam arquivo pela metade.
- Nada de bytes no Postgres nem Active Storage: a imagem é regenerável de
  `image_url`, e o banco guarda o único dado insubstituível (a coleção).
- `storage/card_images/` é ignorado pelo git (o `.gitignore` já cobre
  `/storage/*`).

Riscos que continuam:

- A fonte pode mudar URLs → a imagem quebra até a próxima ingestão (e até o
  arquivo em disco ser apagado, se a arte mudou sob o mesmo código).
- A primeira visualização de cada carta paga a latência da fonte.
- O cache é local ao processo/container; mais de um container de produção
  duplica downloads.

`image_url_large` segue sem fonte: a fixture não traz campo de imagem maior, e a
coluna está vazia nas 4933 variantes. O Req. 5.1 ("imagem em resolução maior")
não é atendido hoje — pendência separada desta decisão.

---

## 8. Estratégia de testes

| Camada       | O que testar                                                                    | Por quê                                                    |
| ------------ | ------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Modelo       | Constraints de unicidade e `CHECK` de quantidade                                | Req. 7.4, 7.8 — no banco, não só na aplicação              |
| Query object | Cada filtro isolado + duas combinações + `OU` dentro de categoria               | Req. 4.3, 4.4 são a lógica mais fácil de errar em silêncio |
| Ingestão     | Idempotência (rodar 2x, contar registros), erro isolado, preservação de coleção | Req. 1.4, 1.5, 1.7                                         |
| Ingestão     | Rodar sobre fixture em disco, sem rede                                          | Req. 11.5                                                  |
| Integração   | Fluxo de posse do catálogo, autorização entre usuários                          | Req. 6.5, 7.5                                              |
| Performance  | Plano de execução dos filtros; medição do p95                                   | Req. 11.1, 11.3                                            |

Teste que eu destacaria como o mais valioso do projeto: **rodar a ingestão duas
vezes com um item de coleção existente e verificar que a quantidade continua
intacta.** É o teste que protege o único dado insubstituível do sistema.

---

## 9. Decisões pendentes

**Nenhuma. P1–P7 estão todas decididas** (tasks 0.1, 0.2 e 0.3, em 2026-09-19).
Ver `docs/adr/001-fonte-de-dados-do-catalogo.md` e
`docs/adr/002-stack-set-completo-e-imagens.md`.

| #   | Decisão                                            | Status | Resolução                                                  |
| --- | -------------------------------------------------- | ------ | ---------------------------------------------------------- |
| P1  | Fonte de dados do catálogo                         | ✅ | `hugoprudente/optcgjson` (`output/*.json`), sem auth, scraping do site oficial da Bandai com CI semanal. ADR 001. |
| P2  | Campos, raridades, sets e attributes reais do jogo | ✅ | Extraídos da amostra real; glossário em `product.md` §6 corrigido. Raridades: C, UC, R, SR, SEC, L, P, SP CARD, TR. |
| P3  | Definição de "set completo"                        | ✅ | **Variantes base** (`baseSetSize`) como denominador; parallels em métrica separada. Ambos os números vêm da fonte. ADR 002. |
| P4  | Stack                                              | ✅ | **Rails 8 + Hotwire + PostgreSQL.** ADR 002. |
| P5  | `variant_code` estável                             | ✅ | **Sem hash derivado.** A fonte fornece `id` estável (`OP01-001_p1`). Usar direto. |
| P6  | Cache de imagens na Fase 1                         | ✅ | ~~Não; hotlink.~~ **Revista em 2026-09-22 (AD-012):** hotlink bloqueado por CORP `same-site`; a aplicação serve a imagem com cache em disco sob demanda. §7. |
| P7  | `DON!!` entra no catálogo?                         | ✅ | Não. A fonte não traz cartas DON!!, então não há decisão a tomar na Fase 1. |

### Consequências para a ingestão (achadas na amostra)

Dois casos-limite reais que viram teste na task 2.4/2.5:

1. **Variante em dois sets.** `P-029_r1` aparece em PRB01 e ST16, mesma imagem e
   raridade. `variant_code` é único **globalmente**, mas variante↔set não é 1:1 —
   a ingestão não pode assumir dono exclusivo ao carregar `AllSets.json`.
2. **`attribute: "?"`** em OP13-079 (Imu) é valor real publicado pela Bandai.
   Confirma `rarity` e attributes como texto, nunca enum.

Como a fonte já entrega `color`, `attribute` e `feature` em arrays, o Normalize
**não precisa de split por `;`** — a normalização de caixa/espaçamento de
`feature` continua valendo.

---

## 10. O que a Fase 1 deixa preparado (sem construir)

Para não pagar retrabalho nas fases futuras:

- **Deck builder (Fase 2):** as regras de deck precisam de `colors` do Leader,
  `card_number` para o limite de cópias, e `card_type`. Tudo já está no modelo.
  Um deck referencia `cards` (regra do jogo), enquanto a coleção referencia
  `card_variants` — essa distinção já está resolvida pelo §3.1.
  > ⚠️ VERIFICAR — entendo que as regras são 1 Leader, 50 cartas no deck principal,
  > máximo 4 cópias por `card_number` e cores compatíveis com o Leader. **Confirme
  > no regulamento oficial** antes de implementar validação. Regra de jogo errada
  > num validador é pior que validador nenhum.
- **Preços (Fase 3):** preço é atributo de `card_variant`, não de `card`. Nada a
  fazer agora além de não colapsar as duas entidades. Continua sendo a fase mais
  incerta do roadmap, por depender de uma fonte de mercado que talvez não exista
  de forma confiável.

---

## 11. Camada de apresentação

Origem: design system **Bindr**, mantido fora do repositório como artifact
(`claude.ai/artifact/S2bVbVwhKiYym2Uw3wYtNq`). Ele é **proposta derivada dos
requisitos de UI** (Req. 2, 4, 7, 11), escrita antes de existir CSS no projeto —
não foi extraído do código. Os valores abaixo são a cópia normativa: em
divergência com o artifact, vale o que está aqui, pela mesma regra que faz
`.context/` vencer `.specs/` (AD-005).

### 11.1 Princípio

**A arte da carta é o conteúdo; a interface é a moldura.** Nenhum elemento de
interface compete em croma com a arte de uma carta. É isso que justifica cada
decisão seguinte, e é o critério para resolver qualquer caso que os tokens não
cubram.

### 11.2 Tema único

Um tema, escuro. Fundo azul-petróleo porque a arte é saturada e a tela é olhada
com o celular perto do rosto, em mesa de loja. `color-scheme: dark`, sem
`prefers-color-scheme` — um tema claro exigiria valor novo para `on-accent` (hoje
ele **é** o `surface-base`) e `danger` já está no limite: sobre estes fundos todo
vermelho escuro o bastante para parecer grave reprova em 4.5:1.

### 11.3 Tokens de cor

| Token | Valor | Uso |
|---|---|---|
| `surface-base` | `#051b23` | Fundo da página |
| `surface-raised` | `#102b36` | Tile, barra de filtros, painel de detalhe |
| `surface-sunken` | `#011018` | Poço da imagem e placeholder do Req. 2.3 |
| `border` | `#1c3a47` | Hairline **decorativa** — 1.47:1, nunca em controle |
| `border-strong` | `#717e84` | Borda de controle — 4.23:1 sobre base |
| `ink` | `#e9f0f3` | Texto primário — 15.35:1 sobre base |
| `ink-muted` | `#9ba7ad` | Texto secundário — 7.18:1 sobre base |
| `accent` | `#ff9e14` | Única cor de ação — 8.55:1 sobre base |
| `on-accent` | `#051b23` | Texto sobre `accent` e sobre `danger` |
| `danger` | `#ff5448` | Apenas ação destrutiva confirmada — 5.57:1 |

Duas matizes e mais nada: azul-petróleo 228° e âmbar 66°, separados por 158°.
`danger` (28°) é a exceção controlada — o que o separa de `accent` é a dupla
diferença de matiz (38°) e luminosidade (0.10), já que ambos são quentes.

`surface-raised` fica a **1.20:1** de `surface-base`: preenchimento sozinho não
delimita, sempre acompanhar de `border` ou `border-strong`.

### 11.4 Tipografia

Pilha do sistema, **sem webfont**: a grade carrega 2815 cartas com imagens
hotlinkadas (Req. 11.2), e um arquivo de fonte na rota crítica competiria com o
recurso que já é o gargalo.

| Estilo | Métrica | Uso |
|---|---|---|
| `display` | 700 28px/32px | Título de página, nome da carta no detalhe |
| `title` | 600 20px/26px | Cabeçalho de seção |
| `body` | 400 15px/22px | Texto corrido, estados vazios |
| `body-strong` | 600 15px/22px | Nome no tile, label de campo |
| `caption` | 400 13px/18px | Metadado em `ink-muted` |
| `code` | 500 13px/18px mono | **Exclusivo** de `card_number` e `variant_code` |

`code` sempre, inclusive inline no meio de frase: são identificadores lidos
caractere a caractere, onde `0`/`O` e `1`/`l` precisam se distinguir, e o Req. 3.4
faz do `card_number` alvo de busca exata.

### 11.5 Espaçamento e raio

Base 4px, quatro passos: `space-1` 4px, `space-2` 8px, `space-3` 16px,
`space-4` 24px. Escala curta é o que impede a grade de estourar os 360px do
Req. 2.5 — a 360px a conta é `360 − 2×24` de margem `− 8` de gutter = **152px por
tile**, duas colunas. Toda decisão de tamanho se verifica contra essa conta.

Raios: `radius-sm` 4px (chip, input, badge de raridade), `radius-md` 8px (tile,
poço, botão), `radius-full` (**apenas** badge de quantidade — o tile é retangular
porque a carta é).

### 11.6 Regras que nenhum token expressa

- **Sem sombra, sem gradiente.** Sombra sobre fundo escuro não separa e custa
  pintura numa grade longa; gradiente quebraria a leitura de par frio/quente.
- **Posse não é cor.** Variante possuída recebe badge `radius-full` em `accent`
  com a quantidade; faltante **não recebe badge nenhum**. Proibido usar dois
  níveis de âmbar — a distinção precisa sobreviver a quem não discrimina cor.
- **`accent` é raro por construção.** Se o âmbar aparecer em mais de dois lugares
  na mesma tela, algo está usando `accent` como decoração.
- **Anel de foco:** 2px sólido em `accent`, 2px de deslocamento, nunca translúcido
  — precisa manter 3:1 sobre as três superfícies, e mantém (7.15:1 no pior caso).
- **`danger`** só em ação destrutiva já confirmada. Nunca em validação, alerta
  informativo ou botão primário.
- **Sem emoji, sem ícone.** Não há conjunto escolhido; até haver, escreva a
  palavra. Quando houver: traço único monocromático herdando `ink`/`ink-muted`,
  20px na interface e 16px em chip.
- **Termo do jogo nunca é traduzido** — `Leader`, `Character`, `Trigger`, `DON!!`,
  raridades e códigos de set saem como a Bandai publica, inclusive a caixa. O
  rótulo em volta é traduzido.
- **Chip das seis cores do jogo:** fill é a própria cor do jogo, selecionado ou
  não; seleção é anel de 2px em `accent` mais rótulo em `body-strong`. **Nunca
  preencher chip de cor com `accent`.** Chip de raridade, tipo ou set é o
  contrário: seleção com fill `accent` e texto `on-accent`. Os hexadecimais das
  seis cores são a pendência **P8** e não existem — enquanto isso, tratamento
  neutro com `border-strong` mais rótulo.

### 11.7 Restrição de implementação

`app/assets/stylesheets/catalog.css` é **objeto de teste**, não só folha de
estilo: seis arquivos em `test/` asseveram sobre o seu texto, lendo com
`File.read` e filtrando regras por prefixo de seletor (`progress-*`,
`import-preview*`, `import-summary*`). Acrescentar a camada de tokens não pode
reorganizar, renomear nem dividir o arquivo — isso quebraria os testes por
construção, sem que a página mudasse.

A verificação dos 360px continua sendo **textual**, não renderizada: nenhum teste
mede scroll horizontal de verdade, e `STATE.md` registra que o Req. 2.5 foi
conferido à mão em Chromium e que uma regressão de layout passaria no CI. Isso
permanece dívida aberta, fora do escopo desta camada.
