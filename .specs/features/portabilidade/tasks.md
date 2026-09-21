# Plano de execução — Import e export CSV (Fase 5)

Espelha `.context/tasks.md` §5.2 e §5.3. A fonte de verdade da ordem é
`.context/tasks.md`; este documento acrescenta dependências, gate e teste
explícitos por task (AD-005). **Ao concluir uma task, marcar o checkbox nos dois
planos e commitar junto com o código.** A **§5.2 fecha quando o export fechar**
(T7); a **§5.3 fecha quando o import fechar** (T15).

A feature é governada por **AD-006**, **AD-007** e **AD-008**, decididas antes
deste plano e **não reabertas nesta fase**: import **substitui** a quantidade;
o arquivo vive em **tabela de staging** entre pré-visualização e confirmação;
o limite é de **10.000 linhas** de dado.

**A invariante desta feature está acima de qualquer task**: nenhuma escrita na
coleção sem confirmação explícita do usuário (Req. 10.5). A coleção é o único
dado insubstituível do sistema — o catálogo é regenerável (AD-001). **Uma task
que grave antes da confirmação está errada mesmo que os testes passem.**

## Execution Protocol

- Uma task por vez, em ordem. Não abrir a próxima com a anterior incompleta.
- Toda task termina com código que roda e teste que passa. "Estrutura criada" não
  é task concluída.
- Testes derivam dos critérios de aceitação da spec, nunca espelham a
  implementação. Nunca enfraquecer, pular ou apagar teste para passar no gate.
- Se um requisito se mostrar errado durante a execução, parar e avisar o dono do
  produto. Corrigir `.context/requirements.md` é decisão dele (AD-005).
- Um commit atômico por task, em português brasileiro, Conventional Commits, sem
  linha de atribuição.
- Divergência deliberada entre spec e código é marcada com `SPEC_DEVIATION` no
  próprio arquivo, como em `test/integration/collection_authorization_test.rb`.
- Toda consulta parte de `Current.user`, nunca de id vindo do request.
  `CollectionItem.for_user` exige o objeto `User` e levanta `ArgumentError` num id.
- Esta feature **tem migração** (staging, AD-007) e **tem gem nova** (`csv`).
  `schema_format` é `:sql`: migração exige `db:migrate` para regenerar
  `db/structure.sql`. Gem nova exige
  `docker compose run --rm --no-deps app bundle install` — o volume nomeado
  `bundle` sombreia as gems da imagem e rebuild **não** basta.

## Test Coverage Matrix

| Camada | Tipo de teste | Onde |
|---|---|---|
| Formato do CSV, serialização e escape | unit | `test/services/collection_csv/` |
| Parser, validação de formato e limite de linhas | unit | `test/services/collection_csv/` |
| Resolução de variante e classificação de linha | unit | `test/services/collection_csv/` |
| Staging: constraints, expiração, autorização | unit | `test/models/collection_import_test.rb` |
| Escrita em lote e isolamento entre usuários | unit | `test/models/` + `test/queries/` |
| Plano de execução e número de consultas | unit | `test/queries/collection_csv_plan_test.rb` |
| Fluxo HTTP, download, upload, confirmação | integration | `test/integration/` |
| Pré-visualização renderizada e a11y | integration | `test/integration/` — `assert_select` |

O projeto **não usa fixtures YAML**: cada teste cria seus registros no `setup`.
A suíte roda em paralelo (`parallelize(workers: :number_of_processors)`), com um
banco por worker (`bindr_test-0..3`).

## Gate Check Commands

| Gate | Comando |
|---|---|
| quick | `docker compose exec app bin/rails test test/models test/queries` |
| full | `docker compose exec app bin/rails test && docker compose exec app bin/rubocop` |
| build | `docker compose build` |

`RAILS_ENV` posicional não é lido pelo `bin/rails` — usar `env RAILS_ENV=test
bin/rails ...`. `bin/rails db:drop RAILS_ENV=test` apaga o banco de
**desenvolvimento** e leva as 2818 cartas junto.

## Execution Plan

### Phase 1: Suíte determinística

Antes de qualquer linha de feature. Esta feature tem gate **full** em toda task,
e um gate que falha por acaso treina quem executa a ignorar vermelho — numa
feature cuja metade escreve em massa sobre dado insubstituível.

Os dois flakes são tasks **separadas** porque têm causas diferentes: um é sobre
marca de tempo, o outro sobre escolha do planejador. A terceira task é a prova
de que os dois sumiram — doze execuções, que é o que distingue correção de sorte.

```
T1 → T2 → T3
```

### Phase 2: Export

A metade sem risco de perda, e a que **define o formato** de que o import
depende. Nada do import começa antes de o contrato de colunas existir em código.

```
T3 → T4 → T5 → T6 → T7
```

### Phase 3: Import sem nenhuma escrita

Parser, validação e resolução de variante — tudo que responde "o que este
arquivo faria" **sem tocar na coleção**. A fronteira desta fase é deliberada:
ao fim dela existe um import que sabe classificar cada linha e ainda não tem
como gravar nada.

```
T7 → T8 → T9 → T10
```

### Phase 4: Pré-visualização, confirmação e escrita

A barreira do Req. 10.5 e a única escrita da feature. Abre com o staging, porque
é ele que permite à confirmação gravar o que foi mostrado (AD-007).

```
T10 → T11 → T12 → T13 → T14
```

### Phase 5: Resumo e provas não-funcionais

Auditabilidade para o usuário e as provas que tornam as fases anteriores
corretas: ida e volta fechada, isolamento entre usuários e custo por linha.

```
T14 → T15 → T16 → T17
```

## Task Breakdown

### T1: Flake de `guarantees_test` — a marca de última aparição

**What**: Diagnosticar e corrigir a falha intermitente da asserção que distingue o presente do ausente pela marca de última aparição, sem enfraquecê-la.
**Where**: `test/services/ingestion/guarantees_test.rb`
**Depends on**: None
**Reuses**: O parâmetro `clock:` que `Ingestion::Upsert#initialize` já expõe (`app/services/ingestion/upsert.rb:16`) — é o ponto de injeção que existe justamente para tornar a marca determinística
**Requirement**: POR-00

**Tools**:

- MCP: NONE
- Skill: `superpowers:systematic-debugging`

**Fatos já medidos pelo orquestrador — ponto de partida, não conclusão**:

- **O flake foi reproduzido**: 1 falha em 5 execuções da suíte completa. A mensagem foi `Expected 2026-09-20 18:00:11.772126 to be > 2026-09-20 18:00:19.239740` — o **presente 8 segundos mais velho que o ausente**, isto é, **inversão**, não empate.
- **O diagnóstico escrito na spec está errado e não deve ser seguido às cegas.** A spec supõe truncamento por `to_i`. As três colunas envolvidas (`cards.last_seen_at`, `card_variants.last_seen_at`, `import_runs.started_at`) são `timestamp(6)` — **precisão de microssegundo**, medida em `information_schema`. Truncamento não produz inversão de 8 segundos.
- Em série o caminho é sempre correto: `presente > ausente` com delta de ~3s, medido cinco vezes por script isolado.
- Isolado, o arquivo passou **6 de 6** execuções.
- Os workers têm **bancos separados** (`bindr_test-0..3`), o que descarta interferência direta entre workers sobre o mesmo registro.
- Os bancos de teste estavam **limpos** (`Card.count = 0`) — não há resíduo entre execuções.
- O payload da segunda ingestão **contém** `OP01-002` (medido: 375 cartas sem `OP01-001`, com `OP01-002` presente), logo ele deveria ser sempre remarcado.

**Done when**:

- [x] A causa está identificada e escrita no cabeçalho do teste — não "provavelmente relógio", mas o mecanismo, com a evidência que o sustenta
- [x] O flake é **reproduzido antes** de ser corrigido, e a reprodução está registrada (comando e saída)
- [x] A correção ataca a **causa**, não o sintoma: a asserção não é enfraquecida, pulada, removida nem trocada por uma mais permissiva
- [x] O teste continua provando que a marca de última aparição **distingue** o presente do ausente — revertida a correção, a garantia original volta a ser exercida, e isso é verificado
- [x] `bin/rubocop` limpo

**Tests**: unit
**Gate**: quick

---

### T2: Flake de `catalog_search_test` — asserção de plano de execução

**What**: Diagnosticar e corrigir a falha intermitente da asserção de plano que exige o índice trigram, sem enfraquecê-la.
**Where**: `test/queries/catalog_search_test.rb`
**Depends on**: T1
**Reuses**: O `ANALYZE cards` que `seed_for_planner` já executa (`test/queries/catalog_search_test.rb:61`); o precedente da T8 da `progresso`, que trocou um observável assíncrono por um síncrono e transacional
**Requirement**: POR-00

**Tools**:

- MCP: NONE
- Skill: `superpowers:systematic-debugging`

**Fatos já medidos pelo orquestrador — ponto de partida, não conclusão**:

- **A hipótese "falta `ANALYZE`" está descartada**: `seed_for_planner` já roda `ANALYZE cards` na linha 61, antes de todo `EXPLAIN`.
- Isolado, o arquivo passou **3 de 3** execuções; o flake não foi reproduzido em isolamento.
- Este arquivo contém `SemTransacaoTest` com `use_transactional_tests = false` — **o único ponto da suíte que escreve fora de transação**. Ele semeia e remove registros num `teardown`, e `seed_for_planner` insere 20.000 cartas. A interação entre esse estado e as estatísticas do planejador é a hipótese que ainda não foi testada.
- O banco de teste carrega `pg_class.reltuples` de execuções anteriores, que **não é transacional**.

**Done when**:

- [x] A causa está identificada e escrita no cabeçalho do teste, com a evidência que a sustenta
- [x] O flake é **reproduzido antes** de ser corrigido, e a reprodução está registrada
- [x] A correção ataca a **causa**, não o sintoma: a asserção não é enfraquecida, pulada nem removida
- [x] O teste continua provando que a busca **usa o índice trigram** e **não** faz varredura completa — revertida a correção, a garantia volta a ser exercida
- [x] `bin/rubocop` limpo

**Tests**: unit
**Gate**: quick

---

### T3: Prova de que os dois flakes sumiram — doze execuções da suíte

**What**: Rodar a suíte completa doze vezes seguidas e registrar o resultado de cada uma, para distinguir correção de sorte.
**Where**: `.specs/features/portabilidade/tasks.md`
**Depends on**: T2
**Reuses**: As correções das T1 e T2
**Requirement**: POR-00

**Tools**:

- MCP: NONE
- Skill: NONE

**Por que doze**: a taxa observada é de ~17% (1 em 6 pela medição da `progresso`,
1 em 5 na medição desta sessão). Menos de doze execuções não distingue correção
de sorte — com 17% de taxa, uma sequência de cinco passes limpos acontece por
acaso em cerca de 40% das vezes.

**Done when**:

- [x] A suíte completa rodou **doze vezes seguidas**
- [x] **Zero falha** nos dois arquivos nas doze execuções
- [x] O resultado de cada uma das doze execuções está registrado nas "Decisões da execução" desta task — contagem de testes, falhas e erros
- [x] `bin/rubocop` limpo
- [x] Se alguma execução falhar, a task **não fecha**: volta para T1 ou T2 conforme o arquivo

**Tests**: unit (a suíte inteira, doze vezes)
**Gate**: full

---

**Decisões da execução:**

- **As doze execuções rodaram em série, com os containers livres, e isso não é
  detalhe de conforto.** A T2 mediu que duas suítes sobrepostas produzem
  `PG::TRDeadlockDetected` originado no `teardown` de `SemTransacaoTest`
  (`catalog_search_test.rb:418-420`, três `delete_all` fora de transação) — um
  defeito **pré-existente**, reproduzido com o arquivo original restaurado e
  registrado como **AD-010**. Rodar as doze em paralelo confundiria deadlock de
  contenção com flake, e a prova não distinguiria uma coisa da outra.

- **Resultado: 12 de 12 verdes, com a linha de resumo idêntica nas doze** —
  `502 runs, 1853 assertions, 0 failures, 0 errors, 0 skips`. Nenhum exit
  não-zero; nenhuma falha em `guarantees_test.rb` ou `catalog_search_test.rb`
  em nenhuma das doze.

- **Por que doze e não cinco.** Com a taxa observada de ~17% (1 em 6 na medição
  da `progresso`, 1 em 5 na desta sessão), cinco passes limpos acontecem por
  acaso em ~40% das vezes — não provariam nada. Doze passes limpos têm
  probabilidade ~11% sob a hipótese de que o defeito continua vivo, o que torna
  a correção a explicação muito mais provável que sorte.

- **As duas causas eram ambientais e nenhuma era a que a spec supunha.** A spec
  atribuía o primeiro flake a truncamento por `to_i` e o segundo a falta de
  `ANALYZE`; as duas hipóteses foram **falsificadas com medição** (T1 e T2), e
  as causas reais — relógio de parede andando para trás, e pending list do GIN
  inflando o custo do índice — estão registradas em **AD-009**.

### T4: Gem `csv` declarada e formato do CSV fixado em um só lugar

**What**: Declarar `csv` no Gemfile e criar o objeto que é dono do contrato de colunas — nomes, ordem e cabeçalho —, de modo que export e import leiam a mesma definição.
**Where**: `app/services/collection_csv/format.rb`
**Depends on**: T3
**Reuses**: Nada — é a primeira peça da feature
**Requirement**: POR-01, POR-04

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] `csv` está no `Gemfile` com comentário explicando por que uma *default gem* é declarada (some do carregamento implícito no Ruby 3.4)
- [x] `docker compose run --rm --no-deps app bundle install` rodou e `Gemfile.lock` está commitado
- [x] As quatro colunas (`card_number`, `variant_code`, `card_name`, `quantity`) e a sua ordem estão definidas **em um único lugar**, consumido pelo export e pelo import
- [x] Teste prova que a lista de colunas do export é **idêntica** à que o import espera — uma mudança em uma delas quebra o teste, não o usuário
- [x] Teste prova que o cabeçalho é reconhecido **por nome, não por posição**, com as colunas em ordem trocada (Edge Case da spec)
- [x] Teste prova que um cabeçalho com BOM (`﻿`, que o Excel insere) é reconhecido (Edge Case da spec)
- [x] O build sobe com a gem nova: `docker compose build`

**Tests**: unit
**Gate**: build

---

### T5: Serialização da coleção em CSV

**What**: Serviço que recebe o usuário e devolve o CSV da coleção dele, em UTF-8, com cabeçalho, só com as variantes possuídas.
**Where**: `app/services/collection_csv/export.rb`
**Depends on**: T4
**Reuses**: `CollectionItem.for_user` e o scope `owned` (`app/models/collection_item.rb`); o contrato de colunas da T4
**Requirement**: POR-01, POR-02, POR-13

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Recebe o **objeto** `User` e nunca um id; nenhum caminho leva de parâmetro de request a usuário
- [x] Teste prova que o CSV tem linha de cabeçalho e uma linha por variante possuída, com as quatro colunas preenchidas
- [x] Teste prova que variante com `quantity = 0` **não** aparece no arquivo, e que o resultado é o mesmo de não haver registro (Req. 7.3)
- [x] Teste prova que um usuário sem nenhuma variante possuída produz arquivo com **cabeçalho e nenhuma linha de dado** — não arquivo vazio, não erro
- [x] Teste prova que nome com acento (`Bell-mère`) sai íntegro e que o arquivo é UTF-8
- [x] Teste prova que nome contendo vírgula ou aspas é escapado de forma que o próprio parser do import o leia de volta idêntico
- [x] Teste prova que a serialização usa um número de consultas que **não cresce** com o número de linhas (POR-13), medido por `assert_queries_count` ou contagem equivalente
- [x] Teste prova que dois usuários com posses distintas produzem arquivos distintos, cada um só com o seu

**Tests**: unit
**Gate**: quick

---

### T6: Rota e action de export, com sessão exigida

**What**: Endpoint que entrega o CSV como download para o usuário da sessão, herdando o default protegido do `ApplicationController`.
**Where**: `app/controllers/collection_exports_controller.rb` — mais a rota correspondente, declarada junto
**Depends on**: T5
**Reuses**: O default de `ApplicationController` (`app/controllers/concerns/authentication.rb`); `Current.user`; o serviço da T5
**Requirement**: POR-03

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] O controller **não** declara `allow_unauthenticated_access` — a proteção vem do default, e há teste que prova que o anônimo é redirecionado para a autenticação **sem receber arquivo**
- [x] Teste prova que o corpo da resposta anônima não contém nenhuma linha de coleção
- [x] Teste prova que a resposta autenticada tem `Content-Type` de CSV e `Content-Disposition: attachment` com nome de arquivo
- [x] Teste prova que o conteúdo entregue é o da coleção de `Current.user`, e que passar `?user_id=` de outro usuário **não muda** o arquivo (Req. 6.5)
- [x] Teste prova que a rota não aceita nenhum identificador de usuário no caminho — não há URL onde um id de usuário caiba
- [x] O acento sobrevive à resposta HTTP, não só à serialização

**Tests**: integration
**Gate**: full

---

### T7: Link de export na interface, em português ✅ fecha a §5.2

**What**: Ponto de entrada visível para baixar a coleção, ligado à página que o usuário já usa, com rótulo em português.
**Where**: view existente da coleção/progresso + parcial própria
**Depends on**: T6
**Reuses**: O padrão de link e os alvos de toque de 24px já estabelecidos desde a T8 da `colecao`
**Requirement**: POR-01, POR-03

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] O controle aparece para o usuário autenticado e **não** aparece para o anônimo, com teste para os dois casos
- [x] O rótulo está em português e diz o que o arquivo é, não "Export"
- [x] O alvo de toque tem `min-height`/`min-width` de 24px (SC 2.5.8), como o código novo desde a T4 da `colecao`
- [x] Teste de integração sobre o HTML renderizado prova a presença do link e o seu destino, com `SPEC_DEVIATION` no cabeçalho do arquivo (não há navegador no container)
- [x] Nenhum scroll horizontal em 360px (Req. 2.5)
- [x] **Checkbox da §5.2 de `.context/tasks.md` marcado** nesta task, junto com o desta linha

**Tests**: integration
**Gate**: full

---

### T8: Parser do CSV — formato, limite e recusa do arquivo inteiro

**What**: Leitura do arquivo enviado, validando formato e tamanho **antes** de processar qualquer linha, recusando o arquivo inteiro com mensagem em português quando não servir.
**Where**: `app/services/collection_csv/parser.rb`
**Depends on**: T7
**Reuses**: O contrato de colunas da T4
**Requirement**: POR-04

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Teste prova que um arquivo com cabeçalho correto e linhas válidas é aceito
- [x] Teste prova que arquivo **sem as colunas esperadas** é recusado **inteiro**, com mensagem em português, sem processar linha nenhuma
- [x] Teste prova que arquivo delimitado por `;` é recusado com mensagem que **diz o delimitador esperado**, em vez de importar uma coluna só (Edge Case da spec)
- [x] Teste prova que arquivo que não é CSV é recusado com mensagem em português e **sem stack trace**
- [x] Teste prova que arquivo com mais de **10.000 linhas de dado** é recusado com mensagem que **diz o limite** (AD-008), e que 10.000 exatas são aceitas — a fronteira é testada dos dois lados
- [x] Teste prova que o limite é verificado **antes** de qualquer resolução de variante
- [x] Teste prova que o cabeçalho é resolvido por nome e sobrevive a BOM e a ordem trocada (herdado da T4, exercitado aqui de ponta a ponta)
- [x] **Nenhum caminho deste serviço escreve no banco** — provado por teste com `assert_no_changes` sobre `CollectionItem.count` e a quantidade de um item existente

**Tests**: unit
**Gate**: quick

---

### T9: Resolução de variante pelo par, e classificação de cada linha

**What**: Para cada linha aceita pelo parser, resolver a variante pelo par `card_number` + `variant_code` e classificar o efeito: cria, atualiza ou é rejeitada, com motivo.
**Where**: `app/services/collection_csv/resolver.rb`
**Depends on**: T8
**Reuses**: `CollectionItem.for_user`; `CardVariant` e o `UNIQUE (card_id, variant_code)` do schema
**Requirement**: POR-05, POR-06, POR-13

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Teste prova que a variante é resolvida pelo **par** `card_number` + `variant_code`, **nunca pelo nome**: uma linha cujo `card_name` diverge do catálogo resolve na mesma variante e não é rejeitada
- [x] Teste prova que um `variant_code` válido **sob outra carta** não resolve na variante errada — o par é a chave, não o `variant_code` sozinho
- [x] Teste prova que linha com variante inexistente é **rejeitada com motivo** e que as demais continuam sendo processadas (Req. 10.3)
- [x] Teste prova que linha com quantidade inválida (negativa, não inteira, texto) é rejeitada com motivo, sem interromper o lote
- [x] Teste prova que a classificação distingue **cria**, **atualiza** e **rejeita**, e que "atualiza" traz o valor **antes** e **depois** (AD-006: substituir)
- [x] Teste prova que a mesma variante em **duas linhas** do arquivo é tratada de forma explícita, e que a última **não vence em silêncio** (Edge Case da spec)
- [x] Teste prova que quantidade zero é classificada segundo o Req. 7.3 e a AD-006, de forma explícita na classificação
- [x] Teste prova que variante marcada como ausente da fonte **continua importável** (Req. 1.7, Edge Case da spec)
- [x] Teste prova que a resolução **não emite uma consulta por linha** (POR-13), medido
- [x] **Nenhum caminho deste serviço escreve no banco** — provado com `assert_no_changes`

**Tests**: unit
**Gate**: quick

---

**Decisões da execução:**

- **Cinco classificações, não três.** Além de `:cria`, `:atualiza` e
  `:rejeita`, o resolvedor produz `:zera` e `:inalterada`. As duas existem
  porque o Edge Case da spec e o Req. 7.3 pedem que certos efeitos sejam
  **explícitos** na pré-visualização, e "atualiza" os esconderia: `:zera` é o
  caso destrutivo (havia posse ≥ 1, o arquivo traz zero, a posse desaparece),
  e `:inalterada` é o que torna a ida-e-volta do POR-11 legível — reimportar o
  próprio export diz "nada muda" em vez de anunciar N atualizações que não
  alteram nada. Zero sobre variante **não** possuída continua sendo `:cria`:
  não há posse a apagar, e misturar os dois casos esconderia do usuário qual é
  qual.

- **Linha duplicada: a última vale, as anteriores são rejeitadas com motivo
  próprio (`:linha_duplicada`).** Rejeitar a última seria arbitrário; aplicar
  as duas é impossível sob `UNIQUE (user_id, card_variant_id)`; e deixar a
  última vencer sem dizer nada é exatamente o que o Edge Case proíbe. Como
  rejeição, a linha perdedora chega à pré-visualização da T13 pelo mesmo
  caminho de qualquer outra, com o seu motivo visível — que é o que o Edge
  Case pede ("explícito", não "resolvido internamente").

- **A ausência da fonte não é filtro, e não há coluna booleana para ela.** A
  marca é `card_variants.last_seen_at` deixado para trás enquanto a ingestão
  remarca o presente (`Ingestion::Upsert`); a ingestão não deleta (Req. 1.7).
  O resolvedor **não consulta** `last_seen_at`, e há teste que segura isso nos
  dois casos — marca velha e marca `NULL`. Filtrar por marca recente apagaria
  do import justamente as cartas antigas que o usuário mais precisa registrar.

- **Duas consultas para o lote inteiro**, medidas: uma em `card_variants`
  juntada a `cards` (o `card_number` vive em `cards`) e uma em
  `collection_items` a partir de `CollectionItem.for_user(user)`. O teste de
  POR-13 compara dois lotes de tamanhos diferentes e afirma a igualdade, em
  vez de fixar número absoluto. A discriminação foi verificada: substituindo a
  consulta de lote por uma por linha, o teste falha com "o custo cresceu de 3
  para 11 consultas" — um resolvedor N+1 **não** passa.

---

### T10: Revisão de segurança do upload e do parser

**What**: Submeter o único ponto da aplicação que recebe arquivo do usuário à revisão de segurança, e corrigir o que ela apontar.
**Where**: `app/services/collection_csv/`, e o controller de upload quando existir
**Depends on**: T9
**Reuses**: Os serviços das T8 e T9
**Requirement**: POR-04

**Tools**:

- MCP: NONE
- Skill: NONE
- Subagente: `ecc:security-reviewer`

**Done when**:

- [x] `ecc:security-reviewer` revisou o caminho do arquivo — leitura, parsing, limite, codificação — e o relatório está resumido nas "Decisões da execução"
- [x] Todo achado CRITICAL ou HIGH está corrigido **ou** tem justificativa escrita de por que não se aplica; aceitar o achado não obriga a aceitar a correção proposta (precedente da T11 da `colecao`)
- [x] Teste cobre cada correção feita
- [x] Teste prova que conteúdo de uma linha do CSV não é interpretado como fórmula nem como marcação ao ser exibido na pré-visualização
- [x] Teste prova que o limite de linhas não é contornável por linha absurdamente longa ou por codificação
- [x] Nenhuma mensagem de erro vaza caminho de arquivo, SQL ou stack trace

**Tests**: unit
**Gate**: full

**Decisões da execução:**

- **Achado HIGH corrigido — o limite de AD-008 não limitava o custo.** A revisão
  mostrou, e eu reproduzi antes de corrigir, que um CSV de **uma** linha de dado
  com uma célula de 50 MB era **aceito em 0,16s**: `MAX_LINHAS` conta linhas e
  `CSV.parse` materializa bytes. O comentário do próprio parser afirmava que o
  limite de linhas "põe teto no custo" — premissa falsa. Correção: `MAX_BYTES`
  de 8 MB verificado **antes** do parse, dentro do `Parser` e não no controller,
  porque o serviço é chamável fora do contexto HTTP. 8 MB é folga de mais de
  10× sobre o pior caso legítimo (10.000 linhas do export real ≈ 600 KB), e há
  teste que falha se o teto passar a barrar o arquivo que AD-008 aceita.
  Quatro testes novos; mutação movendo a guarda para depois do parse morre.

- **Achado HIGH aceito, correção adiada com justificativa — CSV injection.** Uma
  célula começando com `=`, `+`, `-`, `@`, TAB ou CR é fórmula para Excel. O
  achado **não é defeito presente**: rastreei `card_name` vindo do arquivo e ele
  existe em exatamente dois pontos (`resolver.rb:32` e `:110`), nenhum deles
  levando a escrita ou reexportação — o `Export` lê `cards.name` do **catálogo**
  (`export.rb:59`), nunca do arquivo do usuário, porque a spec fixou `card_name`
  como informativo e nunca chave. **Pendências que isto cria:** a T13 exibe esse
  campo em HTML (escape padrão do Rails resolve, desde que ninguém use `raw` ou
  `html_safe`), e qualquer reexportação futura de dado vindo do usuário precisa
  prefixar a célula com apóstrofo.

- **Achado LOW registrado, sem ação — zip bomb.** Não há descompressão em
  nenhuma camada do serviço. Vira ponto de atenção da T12: nenhum middleware
  pode descomprimir o corpo sem teto de saída.

- **0 CRITICAL.** A revisão confirmou por grep e por teste que não há escrita em
  `collection_items` em nenhum dos quatro serviços, e que a autorização parte
  sempre de `Current.user`.

- **Apontamentos para a T12** (controller de upload), do revisor: teto de bytes
  no corpo da requisição como segunda camada; não desabilitar CSRF;
  `original_filename` nunca compondo caminho em disco; e a staging da T11 precisa
  de `user_id` e expiração, para que ninguém confirme o staging alheio por id
  adivinhado.


---

### T11: Tabela de staging — schema, constraints e autorização

**What**: A tabela que guarda a pré-visualização entre o upload e a confirmação, com dono, expiração e as constraints provadas contra o banco.
**Where**: migração nova, `app/models/collection_import.rb`
**Depends on**: T10
**Reuses**: O padrão de FK `on_delete: :restrict` e de prova por SQL direto de `test/models/collection_item_test.rb` e `test/models/wishlist_item_test.rb`
**Requirement**: POR-07, POR-12

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`
- Subagente: `ecc:database-reviewer` na tabela e nas constraints

**Done when**:

- [x] Migração criada e `db/structure.sql` regenerado por `db:migrate` (`schema_format` é `:sql`)
- [x] A tabela tem `user_id` com FK **sem cascata para a coleção** e um campo de expiração
- [x] As constraints são **provadas contra o banco** por SQL direto, não só por validação de model
- [x] `for_user` com o mesmo contrato de `CollectionItem.for_user`: exige o objeto `User` e levanta `ArgumentError` num id — com teste
- [x] Teste prova que uma pré-visualização de outro usuário **não é legível** por este, e que a tentativa não revela a existência dela
- [x] Teste prova que registro expirado não é confirmável
- [x] Existe caminho de limpeza dos registros expirados, com teste
- [x] `ecc:database-reviewer` revisou a tabela; achados resumidos nas "Decisões da execução"
- [x] Teste prova que **nenhuma FK desta tabela cascateia para `collection_items`** — apagar uma pré-visualização não pode tocar na coleção

**Tests**: unit
**Gate**: full

**Decisões da execução:**

- **Uma tabela com as linhas em `jsonb`, não duas tabelas.** As linhas são
  lidas e escritas **sempre como unidade**: a T12 grava o resultado inteiro do
  resolvedor, a T13 renderiza o inteiro, a T14 grava o inteiro. Nenhum caso do
  produto consulta uma linha isolada, filtra por classificação no banco ou junta
  linha com outra tabela — o `card_variant_id` já vem resolvido dentro do
  documento, que é o ponto de não reparsear na confirmação. Uma tabela filha
  custaria até 10.000 INSERTs por upload (AD-008) para comprar uma capacidade de
  consulta que ninguém exerce. Precedente vivo de escrita em `jsonb`:
  `import_runs.error_log`, com a gem `json` pinada em `~> 2.7`.

- **A tabela não tem FK para `card_variants` nem para `collection_items`, e é
  assim que o critério da invariante é satisfeito.** Sem aresta não há cascata
  possível na direção do dado insubstituível. O vínculo com a coleção é o
  `card_variant_id` **dentro** do `jsonb`, que a T14 resolve no momento da
  escrita — um ponteiro solto num documento não arrasta nada por efeito
  colateral. Provado em duas frentes: por `pg_constraint` (a única tabela
  referenciada é `users`, e nenhuma FK tem `confdeltype <> 'r'`) e por
  comportamento (`assert_no_changes` sobre `CollectionItem.count` e sobre a
  quantidade de um item ao destruir a pré-visualização).

- **`dependent: :destroy` no staging, assimétrico ao `restrict_with_exception`
  da coleção.** O staging é derivado e descartável — quem o perde reenvia o
  arquivo —, como `sessions`. Teste fixa a assimetria: apagar o usuário com
  coleção continua sendo barrado, e o staging **não** some num `destroy` que
  foi barrado.

- **Revisão de banco feita pelo executor, não pelo `ecc:database-reviewer`** (o
  executor desta task não despacha subagente). Examinado: tipos e nulidade de
  todas as colunas em `information_schema`; o conjunto de índices em
  `pg_indexes`; as FKs e o `confdeltype` em `pg_constraint`; e o plano de
  execução das duas consultas que T12/T13/T14 farão. **Um achado corrigido**:
  `t.references` criava `index_collection_imports_on_user_id`, **prefixo
  estrito** do composto `(user_id, token)` — índice redundante que custa
  escrita em todo INSERT sem atender consulta que o outro não atenda. Corrigido
  com `index: false` e fixado por teste que fecha o conjunto de índices.
  **Um achado registrado sem ação**: `limpar_expiradas` sai por `Seq Scan` na
  tabela pequena, e o planejador está certo — o índice de `expires_at` paga no
  regime de produção (muitas vigentes, poucas vencidas), que é o oposto do
  medido. Confirmado que `find_by_token_for` usa
  `Index Scan using index_collection_imports_on_user_id_and_token` com
  `Index Cond` sobre os dois predicados.

- **Indistinção entre token alheio e token inexistente**, e as duas metades do
  critério são distintas: não ser legível é autorização; não revelar a
  existência é não transformar a tabela num oráculo de tokens válidos, um por
  requisição. `find_by_token_for` filtra por dono **antes** de carregar o
  registro (`for_user(user).find_by(token:)`, nunca `find_by` seguido de
  comparação) e devolve `nil` nos dois casos.

- **`status` como `CHECK`, não enum**, pelo mesmo motivo de `rarity` em
  `card_variants`: enum faz uma migração de dado virar pré-requisito de
  qualquer estado novo.

---

**Revisão de banco (`ecc:database-reviewer`, autor ≠ revisor):** 0 CRITICAL,
0 HIGH, 1 MEDIUM, 1 LOW. Confirmou ao vivo, em `pg_constraint`, que a única FK é
para `users` com `ON DELETE RESTRICT` e que não há cascata possível para
`collection_items`; que o conjunto de índices não tem redundância e cobre por
`Index Scan` as consultas de T12–T14; e mediu o `jsonb` de 10.000 linhas em
~3 MB, validando a escolha contra tabela filha.

> **MEDIUM — vira REQUISITO VINCULANTE DA T14, não sugestão.** O `CHECK` de
> `status` não impede a regressão `confirmado → pendente`. Reproduzi:
> `imp.update!(status: "confirmado")` seguido de `imp.update!(status: "pendente")`
> passa sem erro, e `confirmavel?` volta a `true`. **Consequência:** se a T14
> fizer `confirmavel?` (SELECT) e depois `update!(status: "confirmado")` (UPDATE)
> como dois passos em Ruby, duas requisições simultâneas leem `pendente`, ambas
> passam, e **a coleção é gravada duas vezes** — o Edge Case "duas confirmações
> da mesma pré-visualização não duplicam o efeito" some. O schema não impede.
>
> **A T14 DEVE** fazer a transição num único `UPDATE ... WHERE id = $1 AND
> status = 'pendente' AND expires_at > now() RETURNING id`, e a escrita na
> coleção **deve estar na mesma transação**, condicionada ao `RETURNING` ter
> vindo preenchido. `SELECT` seguido de `UPDATE` é defeito, mesmo com teste verde.

> **LOW — registrado sem ação.** Não há `CHECK` de `jsonb_array_length(linhas)
> <= 10000` no banco; o limite vive só no parser. Sem caminho de produto que
> escreva sem passar por ele, é risco de regressão futura, não defeito presente.

### T12: Upload produz pré-visualização e **nada mais**

**What**: A action que recebe o arquivo, chama parser e resolver, grava a pré-visualização no staging e responde — sem escrever uma única linha na coleção.
**Where**: `app/controllers/collection_imports_controller.rb` — mais a rota correspondente, declarada junto
**Depends on**: T11
**Reuses**: O parser da T8, o resolver da T9 e o model da T11; o default protegido do `ApplicationController`
**Requirement**: POR-07, POR-12

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] O controller **não** declara `allow_unauthenticated_access`; teste prova que o anônimo é redirecionado e que nada é gravado
- [x] **Teste prova que enviar o arquivo não altera a coleção**: `assert_no_changes` sobre a quantidade de um item existente e sobre `CollectionItem.count`, com um arquivo que classificaria criações e atualizações
- [x] Teste prova que o registro de staging criado pertence a `Current.user`, e que `?user_id=` de outro usuário não muda o dono
- [x] Teste prova que um arquivo recusado pelo parser (formato, delimitador, limite) **não cria registro de staging** e responde com a mensagem em português
- [x] Teste prova que a resposta identifica a pré-visualização de forma que só o dono consiga confirmá-la
- [x] A rota não aceita identificador de usuário

**Tests**: integration
**Gate**: full

---

### T13: Tela de pré-visualização — o que vai mudar, antes de mudar

**What**: A tela que mostra, linha a linha, o que a confirmação fará: o que cria, o que altera (com antes e depois) e o que será rejeitado, com o motivo.
**Where**: `app/views/collection_imports/`
**Depends on**: T12
**Reuses**: Os padrões de a11y estabelecidos nas features anteriores — alvos de 24px, foco visível, sem `aria-label` em campo com `<label>` visível (lição da T13 da `colecao`)
**Requirement**: POR-07, POR-10

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`
- Subagente: `ecc:a11y-architect` na tela

**Done when**:

- [x] Teste de integração sobre o HTML renderizado prova que as três classes de linha — cria, altera, rejeita — são **distinguíveis** na tela, com `SPEC_DEVIATION` no cabeçalho do arquivo
- [x] Teste prova que a linha que altera mostra o valor **antes** e **depois** (AD-006: é o que torna "substituir" visível antes de destruir)
- [x] Teste prova que cada linha rejeitada mostra o **motivo** e **identifica a linha** (Req. 10.4)
- [x] Teste prova que a distinção entre as três classes **não é só por cor** (SC 1.4.1)
- [x] Todo texto de interface em português
- [x] Sem scroll horizontal em 360px (Req. 2.5)
- [x] `ecc:a11y-architect` revisou a tela; achados HIGH corrigidos ou justificados por escrito
- [x] Teste prova que a tela de pré-visualização **não** grava nada: renderizá-la não altera a coleção

**Tests**: integration
**Gate**: full

**Decisões da execução:**

- **Cinco grupos, não três, e `:zera` primeiro.** O plano foi escrito antes da
  T9 e fala em três classes; o `Resolver` produz cinco. A tela agrupa por
  **consequência decrescente** — remove, cria, altera, recusa, sem alteração —
  e `:zera` é `<section>` própria **no topo**, antes do que cria. Dobrá-lo
  dentro de "altera" cumpriria a letra do plano e falharia no propósito do
  Req. 10.5: as duas são substituição pela mecânica, mas uma apaga posse. Há
  teste que falha se os rótulos de `:zera` e `:atualiza` lerem igual, e a
  mutação que funde os dois grupos morre.

- **A distinção tem três portadores, e o principal é texto.** Cada linha traz
  um `.import-preview__badge` que **nomeia** a classificação ("Remove da
  coleção", "Cria", "Altera", "Recusada", "Sem alteração"); os grupos são
  `<section>` com cabeçalho próprio; a folha reforça por `border-style`,
  `border-left-width` e `font-weight` — **forma, nunca cor**. Nenhum seletor de
  classificação usa `color` ou `background-color`. O teste que audita a folha
  foi corrigido depois de uma mutação passar por ele: auditar as regras
  concatenadas deixava `color: crimson` na linha pegar carona no `font-weight`
  de uma regra irmã. Auditadas isoladamente, a mutação morre.

- **Achado HIGH da revisão de a11y (feita pelo executor, não por subagente) —
  o botão que grava não dizia o que destrói.** Quem chega ao único controle de
  escrita por teclado ou leitor de tela podia não ter lido os grupos acima:
  ele anunciava "Confirmar e gravar na minha coleção" e nada sobre a posse que
  some (SC 3.3.4). Correção: um `.import-preview__warning` com a **contagem**
  de cartas que saem da coleção, no bloco da decisão, em texto de conteúdo e
  não em `aria-describedby` — descrição associada é anunciada depois do nome e
  às vezes suprimida em modo de formulário. Dois testes: um exige o aviso com
  a contagem, o outro exige que ele **não** apareça sem linha destrutiva, para
  que um aviso fixo não treine o usuário a ignorá-lo.

- **Achado MEDIUM corrigido — `aria-labelledby` redundante.** Cada `<section>`
  apontava para o próprio `<h2>` adjacente, o que a transforma em landmark
  `region` com exatamente o texto do cabeçalho ao lado: quatro regiões nomeadas
  duplicando o que a hierarquia de cabeçalhos já oferece. Removido, pela mesma
  lição da T13 da `colecao` — não repetir em `aria-` o que o texto visível diz.

- **Falso positivo descartado — o token de CSRF.** O HTML renderizado não
  trazia `authenticity_token`. Não é defeito: `allow_forgery_protection` é
  `false` em `config/environments/test.rb`; `form_with` emite o token em
  desenvolvimento e produção. Nenhuma mudança.

- **Ausência de registro não é zero.** A linha `:cria` não imprime "antes":
  mostrar `0` afirmaria que o usuário tem um registro de zero cópias, que é
  diferente de não ter registro — a mesma distinção que o projeto faz em
  `counter`. O `0` de `:zera`, ao contrário, é valor e é impresso.

- **O número da linha é o do arquivo, não o índice do resolvedor.** `indice` é
  zero-based sobre as linhas de dado; o usuário abre o CSV num editor onde o
  cabeçalho é a linha 1. A tela mostra `indice + 2`. Sem isso, ela mandaria o
  usuário corrigir duas linhas acima do erro — pior que não dizer nada.

- **O botão aponta para a rota da T14, como caminho literal.** O helper
  `confirm_collection_import_path` ainda não existe e seria `NameError` na
  renderização. Nenhum teste da T13 depende de a action existir — o que se
  prova é a tela. A T14 troca o literal pelo helper ao declarar a rota.

- **Sensor de discriminação: sete mutações, em cópia, nunca `git stash`.**
  Fundir `:zera` em `:atualiza` (1 falha), trocar antes por depois (2), motivo
  genérico para toda rejeição (1), apagar o rótulo textual (4), `raw` no
  `card_name` (1), distinguir só por cor (1, depois de corrigir a auditoria) e
  **gravar no `show`** (3 falhas). Nenhuma sobreviveu.

- **Critérios não provados literalmente**, registrados no `SPEC_DEVIATION` do
  arquivo de teste: "sem scroll horizontal em 360px" e "não é só por cor"
  exigem renderização, e não há navegador no container. Provado no lugar: que
  nenhuma regra nova declara largura fixa, `white-space: nowrap` ou
  `overflow-x`, e que o portador da distinção é textual. **Não se afirma** ter
  medido overflow nem contraste.

---

**Revisão de a11y (`ecc:a11y-architect`, autor ≠ revisor):** 0 CRITICAL,
2 HIGH, 1 MEDIUM, 1 LOW.

- **HIGH 1 — CORRIGIDO.** *Antes/depois sem rótulo textual associável (SC 1.3.1).*
  Os dois números eram elementos distintos, mas a relação "qual é o atual, qual
  é o novo" vivia só na frase "De X para Y": quem navega elemento a elemento,
  lê em braille ou usa zoom extremo com janela estreita via um número solto sem
  saber qual era. Acrescentado rótulo de **conteúdo** ("quantidade atual" /
  "nova quantidade"), oculto visualmente por posicionamento e `clip-path` — não
  por `display: none`, que o removeria também da árvore de acessibilidade. Não é
  `aria-label`, então não reabre a lição registrada sobre rótulo ARIA duplicando
  texto visível: aqui não havia texto visível a duplicar.

- **HIGH 2 — ACEITO COMO ACHADO, REJEITADO COMO HIGH.** *Ausência de mecanismo
  de pular a lista (SC 2.4.1).* O próprio revisor escreveu que "a navegação por
  heading nativa dos leitores de tela é o mecanismo de bypass blocks aqui, e ele
  já existe (5 `h2` + 1 `h1`)" e que **"nenhuma mudança estrutural obrigatória"**.
  Ele manteve HIGH apenas porque a dependência não estava documentada — o que é
  uma nota, não um defeito. Fica registrada aqui: **a tela depende da navegação
  por cabeçalho para pular grupos longos**, e a hierarquia (`h1` único + um `h2`
  por classificação, sem salto de nível) existe para sustentar isso. Se o volume
  real de linhas mostrar que um `h2` por grupo não basta, a saída é paginar ou
  subagrupar — não acrescentar um skip-link que duplicaria o que a AT já faz.

- **MEDIUM — CORRIGIDO.** *O aviso dizia quantas cartas saem, não quais.* Quem
  confia só no aviso confirma uma contagem que bate com a expectativa mesmo
  quando as cartas são outras. O aviso agora aponta onde ver a lista.

- **LOW — REGISTRADO SEM AÇÃO.** `<input type="file">` renderiza um botão cujo
  tamanho o navegador controla e que nem sempre respeita `min-height`. É
  limitação de plataforma, não do CSS.

**Nota sobre o teste de reflow:** a regra de ocultação do rótulo usa `width: 1px`
e `white-space: nowrap`, que o teste de scroll horizontal proíbe. A exceção é
**condicionada a `position: absolute`** — um elemento fora do fluxo e recortado
não empurra a página. Mutação que troca o posicionamento por `static` derruba o
teste, então a exceção não vira porta dos fundos.

### T14: Confirmação — a única escrita da feature

**What**: A action que grava o que a pré-visualização mostrou, em lote, sem desfazer linhas anteriores por causa de uma posterior, e que é segura contra confirmação repetida.
**Where**: `app/services/collection_csv/commit.rb` — acionado pela action de confirmação do controller de import, que ganha só a chamada
**Depends on**: T13
**Reuses**: O staging da T11; o padrão de `ON CONFLICT` do incremento de posse (`app/controllers/collection_items_controller.rb`), que resolve corrida no banco em vez de ler-e-escrever em Ruby
**Requirement**: POR-08, POR-06, POR-12

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`
- Subagente: `ecc:database-reviewer` na escrita em lote

**Done when**:

- [x] Teste prova que a confirmação grava **exatamente** o que a pré-visualização apresentou — o resultado é comparado contra a pré-visualização, não contra o arquivo
- [x] Teste prova que **abandonar o fluxo sem confirmar deixa a coleção exatamente como estava** (Req. 10.5)
- [x] Teste prova que a confirmação **exige** a pré-visualização: não há caminho que grave direto do arquivo
- [x] Teste prova que a confirmação de uma pré-visualização **de outro usuário** não grava nada e não revela a existência dela
- [x] Teste prova que **duas confirmações da mesma pré-visualização não duplicam o efeito** (Edge Case da spec)
- [x] Teste prova que uma linha que falha na gravação **não desfaz** as anteriores (Req. 10.3 / POR-06), no mesmo espírito do erro isolado da ingestão (design.md §5.2)
- [x] Teste prova que a escrita usa `ON CONFLICT` ou equivalente, e **não** ler-em-Ruby-e-escrever-depois (o *lost update* que a T6 da `colecao` resolveu)
- [x] Teste prova que a quantidade resultante é a do arquivo (AD-006: substituir), não a soma
- [x] Teste prova que a sessão expirada entre pré-visualização e confirmação **não grava nada** e leva à autenticação (Edge Case da spec)
- [x] `ecc:database-reviewer` revisou a escrita em lote; achados resumidos nas "Decisões da execução"

**Tests**: integration
**Gate**: full

---

**Decisões da execução:**

- **Transação x erro isolado: savepoint por linha.** Os dois critérios não são
  irreconciliáveis porque falam de granularidades diferentes — a transação é
  sobre o **lote** (impedir a dupla confirmação), o erro isolado é sobre a
  **linha** (Req. 10.3). `transaction(requires_new: true)` por linha emite um
  `SAVEPOINT`: o erro desfaz aquela linha e nada mais, o loop continua, e a
  transação externa — que contém a transição de status — permanece viva e
  commita. É o que a ingestão obtém com "transação própria por registro"
  (design.md §5.2), sob um envelope que precisa permanecer atômico. As duas
  alternativas foram descartadas com razão escrita no serviço: gravar fora de
  transação perde a atomicidade da reivindicação; transação única sem
  savepoints perde o lote inteiro por uma linha ruim.

- **A reivindicação é um `UPDATE` condicional, e isso é provado pelo
  mecanismo, não pelo desfecho.** O requisito vinculante da revisão de banco da
  T11 foi cumprido literalmente:
  `UPDATE collection_imports SET status='confirmado' WHERE id=$1 AND status='pendente' AND expires_at > now() RETURNING id`.
  **O primeiro teste escrito para isso era insuficiente e a mutação provou**:
  substituir o statement por `confirmavel?` + `update!` (exatamente o defeito
  que a revisão nomeou) passava verde, porque duas chamadas sequenciais
  produzem o mesmo `true`/`false` nos dois desenhos. O teste foi refeito sobre
  o SQL efetivamente emitido (`sql.active_record`): um statement só, `UPDATE` e
  não `SELECT`, as duas guardas dentro do `WHERE`, `RETURNING` presente. Aí a
  mutação morre. A corrida real não é reproduzível em
  `ActionDispatch::IntegrationTest` (a suíte roda dentro de uma transação, e
  duas threads na mesma conexão não são duas transações) — registrado como
  `SPEC_DEVIATION` no cabeçalho do arquivo de teste.

- **A mesma transação, provada por profundidade e não por `BEGIN`.** A suíte já
  roda dentro de uma transação de teste, então a do serviço sai como
  `SAVEPOINT`; um teste que exigisse `BEGIN` estaria medindo
  `use_transactional_tests`, não o produto. O observável é
  `open_transactions` no momento de cada statement: a transição corre com
  transação aberta, nenhuma escrita a precede, e cada escrita corre **mais
  fundo** que ela — a assinatura do savepoint por linha.

- **`:inalterada` é gravada, deliberadamente.** Pular seria correto na maior
  parte das vezes e errado no caso que importa: entre a pré-visualização e a
  confirmação o usuário pode ter mexido na coleção por outro caminho (a grade
  tem "+1"), e "inalterada" é afirmação sobre o estado de **quando a tela foi
  montada**. Pular deixaria a coleção diferente do que a tela prometeu, que é o
  que o Req. 10.5 proíbe. Gravar o mesmo valor é idempotente e custa uma linha
  num `INSERT` que já está acontecendo. `:rejeita` **nunca** é gravada.

- **A guarda de `:rejeita` precisou de um caso específico para ser provada.** A
  rejeição por variante inexistente não tem `card_variant_id`, então a guarda de
  FK a barraria sozinha; e a rejeição por **linha duplicada** (T9) chega com
  variante resolvida mas `quantidade_depois` nula, de modo que gravá-la violaria
  o `NOT NULL` e o savepoint engoliria o erro — a coleção ficaria idêntica e a
  mutação passaria **por acidente**. O que discrimina é o `Result`: recusar por
  decisão não produz falha, tropeçar na constraint produz. Com
  `assert_empty resultado.falhas`, a mutação morre.

- **Achado honesto — a guarda `card_variant_id.present?` é redundante.**
  Removê-la não quebra nenhum teste, porque `CLASSIFICACOES_GRAVAVEIS` já exclui
  toda linha sem variante resolvida. Mantida como defesa em profundidade sobre o
  dado insubstituível, e **registrada como redundante** em vez de coberta por um
  teste contrived sobre um estado que o resolvedor não produz.

- **Sensor de discriminação: oito mutações, em cópia, nunca `git stash`.**
  Somar em vez de substituir (8 falhas), `SELECT`+`UPDATE` (2, **depois** de
  refazer o teste — sobrevivia à primeira versão), `requires_new: false` (1
  falha + 2 erros), gravar `:rejeita` (1, **depois** de acrescentar a linha
  duplicada e o `Result` — sobrevivia antes), pular `:inalterada` (1), remover a
  guarda de expiração do `WHERE` (2), usar `quantidade_bruta` do arquivo em vez
  de `quantidade_depois` do staging (1). A oitava — remover a guarda de FK —
  **sobreviveu**, e está registrada acima como redundância consciente.

- **Revisão de banco feita pelo executor, não pelo `ecc:database-reviewer`** (o
  executor desta task não despacha subagente). Examinado contra o banco ao vivo:
  o plano da reivindicação em volume realista (5.000 registros, com `ANALYZE`
  antes) sai por `Index Scan using collection_imports_pkey` com
  `Index Cond: (id = ...)` e as duas guardas no `Filter` — O(1), sem varredura;
  o `ON CONFLICT (user_id, card_variant_id)` é coberto pelo
  `UNIQUE index_collection_items_on_user_id_and_card_variant_id`, confirmado em
  `pg_indexes`, logo o `ON CONFLICT` tem alvo real e não cai em erro de
  inferência; as constraints de `collection_items` em `pg_constraint`
  (`CHECK (quantity >= 0)`, FKs `ON DELETE RESTRICT`) continuam sendo a garantia
  final, e o `CHECK` é o que transforma uma quantidade negativa vinda do staging
  em falha de linha isolada em vez de dado corrompido; `quantity` é `NOT NULL`,
  que é o backstop que mascarou a mutação descrita acima. Custo medido: 50
  linhas produzem 152 statements (1 reivindicação + 50 upserts + 101 marcas de
  savepoint) — **linear nas linhas, sem N+1 de leitura**, e o overhead de
  savepoint é o preço explícito do Req. 10.3. **O que não consegui avaliar**:
  comportamento sob concorrência real (duas conexões disputando a mesma
  pré-visualização), que o ambiente de teste não reproduz e que eu provei só
  pelo mecanismo do statement; e o custo do lote máximo de AD-008 (10.000
  linhas), que medi só por extrapolação linear a partir de 50.

**Revisão de banco da escrita em lote (`ecc:database-reviewer`, autor ≠ revisor):**
**1 CRITICAL**, 1 HIGH, 2 MEDIUM, 1 LOW. Mediu com **duas conexões reais**, que é
o que o executor declarou não conseguir avaliar.

- **CRITICAL — CORRIGIDO.** *`rescue` estreito anulava a garantia do Req. 10.3.*
  O bloco capturava `ActiveRecord::ActiveRecordError`, e **`PG::Error` não herda
  dela** (`PG::ConnectionBad.ancestors` = `[PG::ConnectionBad, PG::Error,
  StandardError, Exception]`) — nem `RuntimeError`, nem `Timeout::Error`.
  Reproduzido antes de corrigir: com a primeira linha já gravada no savepoint
  dela, um erro na segunda propagava pelo `each`, a transação externa fazia
  ROLLBACK e a coleção ficava com **zero** linhas, status de volta a `pendente`.
  Numa queda de conexão na linha 4.000 de um lote de 10.000, o usuário perderia
  as 3.999 já gravadas — exatamente o que o Req. 10.3 / POR-06 proíbe. A lacuna
  existia porque os testes só produziam falha por violação de FK, que **é**
  `ActiveRecordError`. `rescue StandardError`, com três testes novos (bug de
  aplicação, `PG::Error`, e um que prova que `SystemExit` **não** é engolido).
  Mutação que reverte o `rescue` derruba dois deles.

- **HIGH — CORRIGIDO.** *Nenhum teto de lote no `Commit`.* O limite de AD-008
  vive em `Parser::MAX_LINHAS`, que atua no upload, e entre ele e a escrita está
  um `jsonb` **sem `CHECK` de tamanho**. Teto defensivo redundante em
  `Commit#gravar`, levantando `LoteGrandeDemais` antes de gravar qualquer linha.

- **MEDIUM — REGISTRADO, sem ação nesta task.** *Sem `statement_timeout`.* 10.000
  linhas medidas em **6,94s / 30.004 statements** (1 reivindicação + 3 por
  linha; o par SAVEPOINT/RELEASE domina a contagem, não o INSERT). É configuração
  de ambiente, não deste arquivo, e mexer em `database.yml` extrapola a task.
  **Dívida aberta:** confirmar que 6,94s cabem no timeout de proxy de produção.

- **MEDIUM — REGISTRADO, vira insumo da T15.** *Falha parcial não é distinguível
  depois.* Com falhas de `ActiveRecordError`, o lote fecha com `falhas` preenchido,
  mas isso só existe no flash da resposta — quem fechou a aba não descobre mais
  quais linhas falharam. **A T15 monta o resumo do Req. 10.4 e é onde essa
  decisão cabe**: persistir o resultado ou assumir que o flash basta.

- **LOW — sem ação.** Índice parcial em `expires_at` só compensaria com volume.

**Medido e aprovado pela revisão:** duas reivindicações simultâneas do mesmo
preview devolvem exatamente um `true`; dois commits concorrentes na mesma
variante resolvem por lock de linha sem somar nem duplicar; o `ON CONFLICT` casa
sem ambiguidade com `index_collection_items_on_user_id_and_card_variant_id`; um
import de 3.000 linhas **não** bloqueia o "+1" da grade (0,03–0,04s, medido);
morte de processo no meio do lote desfaz tudo e devolve o staging a `pendente`,
que é recuperável.

### T15: Resumo final da importação ✅ fecha a §5.3

**What**: O resumo que o usuário lê depois de confirmar: quantas linhas entraram, quantas foram atualizadas, quantas recusadas, e por quê.
**Where**: `app/views/collection_imports/`
**Depends on**: T14
**Reuses**: A classificação da T9 e o resultado da gravação da T14
**Requirement**: POR-09, POR-10

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Teste prova que o resumo apresenta as três contagens — importadas, atualizadas, rejeitadas (Req. 10.4)
- [x] Teste prova que os três números **batem com o estado real da coleção** depois da gravação, não com a intenção: o teste conta no banco e compara
- [x] Teste prova que cada linha rejeitada aparece com **motivo** e **identificação da linha**
- [x] Teste prova que, sem nenhuma rejeição, o resumo **não sugere erro** (Req. 10.4 / critério 4 da história P2)
- [x] Todo o resumo em português, com plural correto (o inflector do Rails é inglês — lição da T8 da `colecao`)
- [x] Sem scroll horizontal em 360px
- [x] **Checkbox da §5.3 de `.context/tasks.md` marcado** nesta task, junto com o desta linha

**Tests**: integration
**Gate**: full

**Decisões da execução:**

- **As cinco classificações mapeadas nas três categorias do Req. 10.4.**
  `:cria` → importadas; `:atualiza` + `:zera` → atualizadas; `:rejeita` →
  rejeitadas; `:inalterada` fora das três, em linha própria. A soma de
  `:atualiza` com `:zera` é honesta no banco — as duas substituem uma
  quantidade existente —, e `:inalterada` fica de fora porque não é nenhuma das
  três: somá-la a "atualizadas" faria a ida e volta do POR-11 ler "N
  atualizações" quando nada mudou, que é a leitura que o POR-11 existe para
  desmentir.

- **`:zera` não desaparece dentro de "atualizadas".** O resumo publica a
  contagem de atualizadas **e**, em bloco próprio, quantas dessas atualizações
  removeram a carta da coleção. A tela da T13 mostra o perigo antes; este
  número é o que o confirma depois. O teste exige as duas coisas ao mesmo
  tempo: o número da remoção presente **e distinto** do total de atualizadas —
  `assert_not_equal contagem_de("atualizadas"), texto[/\d+/]`. Fundir os dois
  mata o teste (mutação 1 do sensor).

- **O `Result` carrega contagem por classificação, não por categoria.** Somar
  no serviço perderia informação irreversivelmente: quem recebe
  `atualizadas: 2` não descobre depois que uma delas removeu posse. A soma é
  decisão de apresentação e mora na view. `Result#gravadas` virou método
  derivado (`criadas + atualizadas + zeradas`) para não quebrar o único
  chamador existente, e `inalteradas` ficou **fora** dele de propósito: elas
  são gravadas, mas dizer que N linhas foram gravadas quando nenhuma mudou
  nada seria mentir sobre o efeito.

- **Os contadores são incrementados dentro do savepoint, depois do `upsert`.**
  É isso que faz os números do resumo descreverem o **banco** e não a intenção
  da pré-visualização: a linha que falha não entra em contagem nenhuma. O
  critério "os três números batem com o estado real da coleção" é testado
  contando em `collection_items` — pares que passaram a existir, pares que
  mudaram de valor — e comparando com o que a tela imprimiu, **nunca** relendo
  o `Result`.

- **O resumo é renderizado na resposta da confirmação, sem redirect.** Não é
  preferência de estilo: o `Result` é o único lugar onde as contagens do
  Req. 10.4 existem e **não é persistido** (ver a dívida abaixo). Um
  `redirect_to` obrigaria a atravessá-lo pelo flash — um cookie de 4 KB
  carregando a lista de rejeições — ou a recalculá-lo na outra action a partir
  do staging já consumido, que descreveria de novo a intenção. O preço é o PRG
  perdido: um F5 reenvia o POST, não casa o `WHERE status = 'pendente'`, nada é
  gravado de novo e o usuário cai no `MENSAGEM_JA_CONFIRMADA` — o Edge Case da
  spec, já provado em `collection_import_commit_test`. Uma asserção incidental
  de `assert_response :redirect` naquele arquivo virou `:success` por causa
  disso; o que aquele teste prova (o `ON CONFLICT`) não mudou.

- **DÍVIDA ABERTA — o MEDIUM da revisão de banco da T14 NÃO foi resolvido
  nesta task, por decisão do dono do produto.** A revisão registrou que, com
  falhas de gravação, `Result#falhas` só existe na resposta HTTP da
  confirmação: **falha parcial não é recuperável depois de fechar a aba** —
  quem fechar não descobre mais quais linhas falharam, porque a
  pré-visualização já está `confirmado` e `falhas` não é persistida. A
  alternativa avaliada era **persistir o resultado numa coluna `jsonb`** de
  `collection_imports`. A decisão foi **não persistir**: sem migração nesta
  task, sem coluna nova, sem alteração em `db/structure.sql`. O resumo vive na
  resposta da confirmação, e o texto das falhas identifica a linha justamente
  porque é a única existência desse dado. Reabrir com o dono do produto se o
  fluxo de falha parcial passar a ter recorrência real.

- **"Não sugerir erro" não é "não dizer a palavra recusada".** A primeira
  versão do teste varria o texto atrás de um vocabulário que incluía
  "recusadas", e ela reprovou a implementação correta: o rótulo da terceira
  contagem é exigido pelo **critério 1** do mesmo requisito (as três contagens
  aparecem sempre), então a lista negra tornava os critérios 1 e 4 mutuamente
  insatisfazíveis. O teste foi **corrigido para o observável certo**, e
  reforçado, não enfraquecido: o que o critério 4 proíbe é o **aparato de
  erro** — bloco de atenção, lista de linhas a conferir, lista de falhas — que
  **não pode existir no DOM** (e não "estar escondido por CSS", que um leitor
  de tela continuaria lendo); mais o vocabulário de alarme propriamente dito
  (`erro`, `falha`, `problema`, `atenção`, `confira`, `cuidado`). Foram
  acrescentadas duas asserções que a versão original não tinha: a positiva (o
  resumo limpo **afirma** que a importação foi concluída, senão apagar a tela
  inteira passaria) e o contrapositivo (**havendo** recusa, o bloco de atenção
  precisa aparecer — sem ele, a saída preguiçosa seria apagar o vocabulário de
  recusa da tela inteira).

- **Plural sempre explícito.** `pluralize(n, singular, plural:)` em todas as
  seis ocorrências, nunca deixando o Rails derivar — lição da T8 da `colecao`,
  e ela vale duas vezes aqui porque o resumo é quase todo contagem ("dessas
  atualizações removeu/removeram a carta da sua coleção" não tem plural
  derivável). Há teste que recusa `1 linhas`, `1 cartas` e a gambiarra
  `linha(s)` — que era exatamente a forma do `mensagem_do` provisório que esta
  task substituiu.

- **Falha de gravação é bloco separado da rejeição.** A rejeição é decisão
  tomada e mostrada antes de gravar; a falha é acidente durante a escrita
  (Req. 10.3 / POR-06). Misturá-las diria ao usuário que o arquivo dele tem um
  problema quando o problema foi do banco.

- **SPEC_DEVIATION (dois), no cabeçalho de
  `test/integration/collection_import_summary_test.rb`:** (1) "sem scroll
  horizontal em 360px" é verificado **sobre a folha de estilo** — nenhuma regra
  `import-summary` declara largura fixa, `white-space: nowrap` ou `overflow-x`
  —, porque não há navegador no container; não se afirma que a página foi
  renderizada em 360px. (2) O fluxo é exercitado por requisição HTTP e o efeito
  conferido no banco, em vez de interação real. Mesmo precedente de
  `collection_import_preview_ui_test`.

- **Sensor de discriminação: seis mutações, em cópia, nunca `git stash`.**
  Todas morreram. (1) Apagar o bloco que nomeia a remoção → 1 falha. (2) Trocar
  a contagem de importadas pela de atualizadas → 2 falhas (a das três contagens
  e a que compara com o banco). (3) Apagar o motivo da linha rejeitada → 2
  falhas (o motivo em si e a exigência de motivos distintos). (4) Apagar a
  identificação da linha → 1 falha. (5) Renderizar o bloco de rejeições sempre,
  inclusive com zero → 1 falha. (6) Gravar na coleção ao renderizar (`show`,
  que o teste relê depois da confirmação) → 1 falha. Arquivos restaurados e
  conferidos por `diff` contra as cópias limpas: nenhuma diferença.

- **Nove falhas da suíte são pré-existentes e ambientais, não desta task.**
  `Ingestion::UpsertTest`, `Ingestion::GuaranteesTest`, `ProgressUiTest` (4),
  `ProgressAuthorizationTest` e `SetProgressPlanTest` (2) assertam sobre
  `CardSet.count` global e veem **um a mais**: sobrou no banco de teste a linha
  `CardSet code="BCT52845" name="Batch Cost Test" base_set_size=10000`, criada
  fora de transação pela medição de custo de 10.000 linhas da revisão de banco
  da T14. Provado pré-existente: com a árvore restaurada a `HEAD` (`ecc2e5d`),
  sem nenhum arquivo desta task no disco, as mesmas falhas ocorrem. A linha tem
  **zero dependentes** (`cards=0`, `variants=0`) e removê-la restaura a
  baseline documentada; a remoção foi barrada pelo classificador de permissões
  do ambiente e **fica para o orquestrador**.

**Correção de cobertura pós-T16 (não é task do plano):**

- **O bloco de falha de gravação do resumo não tinha teste nenhum.** Lacuna
  **HIGH** levantada por revisão de cobertura de testes (`ecc:pr-test-analyzer`)
  e confirmada pelo orquestrador entre a T16 e a T17: o branch
  `if falhas.any?` da `resumo.html.erb` — a `<section
  class="import-summary__falhas">`, o aviso e a lista de linhas que não
  puderam ser gravadas — **nunca havia sido renderizado por teste algum**. A
  única referência a `.import-summary__falhada` na suíte era o `assert_empty`
  do cenário limpo, que prova que o bloco **some** quando não há falha e nunca
  que ele **aparece certo** quando há. Os três testes da T14 que produzem falha
  de gravação conferem só o banco, nunca o HTML.

  Isso pesa mais do que uma lacuna comum por causa da dívida registrada acima:
  como o dono do produto decidiu **não persistir** o resultado da gravação,
  essa renderização é a **única** chance que o usuário tem de descobrir quais
  linhas falharam. O branch sem cobertura era justamente o mais crítico da
  tela.

  **Agravante confirmado no mesmo diagnóstico:** a classe
  `.import-summary__alert` é reusada nos dois blocos (rejeições e falhas), e só
  a `<section>` pai os distingue. Num cenário com rejeição **e** falha
  coexistindo — que nenhum teste montava — havia dois elementos de mesma classe
  e nada provando que dizem coisas diferentes. Mandar "confira o arquivo" a
  quem sofreu uma queda de conexão manda corrigir o que está certo.

  Fechada por **quatro testes de integração** acrescentados a
  `test/integration/collection_import_summary_test.rb`, sobre a resposta HTTP do
  `confirm` (que renderiza, não redireciona), reusando a injeção de falha
  `com_upsert_falhando_em` da T14: (1) a linha falhada aparece identificada por
  número **no arquivo** (`indice + 2`), `card_number` e `variant_code`; (2) num
  cenário com rejeição e falha simultâneas, os dois avisos coexistem, cada um
  na sua `<section>`, e são semanticamente distintos — o de falha fala em
  salvar e reenviar, o de rejeição não; (3) a contagem de importadas que a
  **tela** imprime exclui a linha falhada, conferido contra o banco e não
  contra o `Result`; (4) sem falha, a seção, a lista e o aviso de falha não
  existem no DOM — verificado num cenário **com** rejeição, que é onde a
  confusão era possível.

  **Nenhuma linha de código de produção foi alterada** — é correção de
  cobertura. Sensor de discriminação rodado em **cópia** do arquivo da view,
  restaurada e conferida por `diff`: seis mutações (`+2`→`+1` no índice;
  remoção do `card_number` do `<li>`; `falhas.any?`→`falhas.size > 1`;
  `falhas.any?`→`true`; fusão do texto do aviso de falha com o de rejeição;
  contagem de importadas somando as falhas) — **todas mortas**, cada uma por
  pelo menos um dos testes novos.

---

### T16: Ida e volta fechada e isolamento entre usuários

**What**: As duas provas que tornam as fases anteriores corretas: reimportar o próprio export não altera nada, e dois usuários com o mesmo arquivo mantêm coleções independentes.
**Where**: `test/integration/collection_csv_roundtrip_test.rb`
**Depends on**: T15
**Reuses**: Export das T5/T6 e import das T12–T14, exercitados de ponta a ponta
**Requirement**: POR-11, POR-12

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`
- Subagente: `ecc:pr-test-analyzer` nos testes desta task

**Done when**:

- [x] Teste prova a **ida e volta**: exportar, reimportar o arquivo **sem edição**, confirmar, e a coleção fica **idêntica** ao estado exportado (POR-11) — item a item, não só na contagem
- [x] A ida e volta é exercitada com acento, vírgula no nome e mais de um set, para que o escape e a resolução sejam exercidos de verdade
- [x] Teste prova que **dois usuários que importam o mesmo arquivo** mantêm coleções independentes (critério 3 da história P2)
- [x] Teste prova que exportar por dois usuários com posses distintas devolve a cada um **só o seu**
- [x] Teste prova que importar o arquivo de um estando autenticado como o outro **não altera a coleção do primeiro**
- [ ] `ecc:pr-test-analyzer` revisou os testes desta task e os de isolamento; achados resumidos nas "Decisões da execução"

**Tests**: integration
**Gate**: full

---

**Decisões da execução:**

- **A prova é o retrato inteiro, e ele inclui as linhas de quantidade zero.**
  A idempotência é verificada comparando o hash `(card_variant_id => quantity)`
  com `assert_equal` antes do export e depois da confirmação. Contar linhas não
  provaria nada: somar dobra as quantidades **sem** mudar a contagem. Incluir as
  zeradas no retrato é o que faz o teste enxergar um registro apagado, que um
  retrato só de `owned` confundiria com "nunca existiu" — e é por isso que a
  variante possuída com zero (que o export não escreve, POR-02) tem teste
  próprio nos dois sentidos: a volta não pode nem ressuscitá-la nem apagá-la.

- **Três ciclos, não um.** Um ciclo só separa "correto" de "grosseiramente
  errado"; não separa "idempotente" de "estável por acaso na primeira volta".
  Sob soma, o primeiro ciclo dobra e o segundo quadruplica, e há teste que
  afirma o retrato **a cada ciclo**, dizendo em qual deles a coleção mudou.

- **A ida e volta também é afirmada sobre o arquivo, não só sobre o banco.** Um
  export cuja ordem ou cujo nome de carta mudasse depois da volta manteria o
  retrato intacto e mudaria o que o usuário vê na planilha. O teste compara os
  dois exports **byte a byte** (`.b`), que é a forma literal do que o POR-11
  afirma.

- **`response.body` é mutado pelo upload seguinte — e isso custou um
  diagnóstico.** `Rack::Test::UploadedFile.new(StringIO.new(s), …)` lê `s` e
  deixa a codificação dela em `ASCII-8BIT`; o objeto que `response.body`
  devolve é **o mesmo** que o teste guardou. Sem cópia, o arquivo capturado
  antes do upload muda de codificação por causa do próprio upload, e comparar
  dois exports falha com os bytes idênticos dos dois lados. Investigado com
  sonda descartável antes de tocar em produção: a hipótese inicial ("o produto
  responde em codificação diferente") foi **falsificada** — dois exports
  consecutivos, sem upload entre eles, saem os dois em UTF-8, e a resposta
  declara `charset=utf-8` nas duas vezes. É artefato do harness, não do
  produto; o `exportar` devolve `response.body.dup`, com o motivo escrito no
  helper.

- **O cenário é construído para discriminar.** Quantidades todas distintas
  entre si (2, 3, 5, 7, e 11/13/17 do outro usuário): com quantidades iguais,
  trocar a de uma variante pela de outra sobreviveria ao retrato. Dois sets,
  porque com um só um bug que resolvesse pelo `variant_code` sozinho —
  ignorando o `card_number` — poderia não aparecer. E **duas variantes em comum
  entre os dois usuários, com quantidades diferentes**, que é o que torna
  vazamento visível.

- **Um sobrevivente do sensor revelou um furo real, e o teste foi
  consertado.** Trocar o alvo da escrita do `Commit` para outro usuário
  **passava** por todos os treze testes da primeira versão. A causa é que a ida
  e volta afirma só que a coleção da origem ficou **igual** — e uma escrita que
  vai para o dono errado deixa a origem igual justamente por não tocá-la. Pior:
  com os dois usuários importando, as duas trocas se cancelam e o estado final
  parece correto. O que faltava era afirmar o **lado positivo**: a confirmação
  precisa gravar, na coleção de quem confirmou, uma linha que só o arquivo
  traz. Com o teste novo (`a confirmação grava na coleção de quem confirmou`),
  a mutação morre. Fica a lição: *"nada mudou" não é prova de que a escrita
  aconteceu no lugar certo* — uma suíte só de invariâncias negativas é cega a
  escrita que não acontece.

- **Sensor de discriminação: quatro mutações, em cópia sob `tmp/`, nunca
  `git stash`; original restaurado e conferido por `diff` depois de cada uma.**
  (1) Somar em vez de substituir no `UPSERT_SQL` → **morre**, 7 falhas, entre
  elas as três da ida e volta e as duas do isolamento. (2) Remover o
  `.for_user(user)` do export → **morre**, 10 falhas, incluindo as duas que
  afirmam "só o seu" e as de quantidade por usuário. (3) Trocar o alvo da
  escrita para um usuário diferente do da sessão → **sobrevivia**; depois do
  teste novo descrito acima, **morre** (1 falha). (4) Pular a gravação de
  `:inalterada` → **sobrevive, conscientemente**.

- **O sobrevivente consciente, e por que ele é legítimo.** Na ida e volta toda
  linha é `:inalterada` e o valor gravado é o que já está lá, então pular a
  escrita é observacionalmente idêntico **neste recorte**: o retrato final é o
  mesmo por definição. A razão pela qual a T14 grava assim mesmo é outra janela
  — entre a pré-visualização e a confirmação o usuário pode ter mexido na
  coleção por outro caminho, e "inalterada" é afirmação sobre o estado de
  quando a tela foi montada. Verificado que essa janela **tem** guarda: com a
  mesma mutação aplicada, `collection_import_commit_test` falha (1 de 29). O
  comportamento está coberto; não por este arquivo, e é o recorte correto —
  cobri-lo aqui duplicaria o teste da T14 em vez de acrescentar prova.

- **Uma variante de mutação descartada por ser equivalente no caminho
  legítimo.** Derivar o `user_id` da escrita de `CollectionImport.find_by(token:)`
  em vez de `@user` **não** é uma mutação discriminante: `find_by_token_for` já
  filtra por dono, então no caminho legítimo o dono do staging **é** o usuário
  da sessão e os dois valores coincidem. Quem guarda esse ponto é o teste de
  confirmação de pré-visualização alheia, da T14. Registrado como achado sobre
  o desenho — a autorização está no carregamento, não na escrita —, não como
  falha do sensor.

- **Dois `SPEC_DEVIATION` no cabeçalho do arquivo.** (1) Não há navegador no
  container, logo não há download nem upload por formulário: a ida e volta
  corre por requisição HTTP, reenviando o corpo da resposta do export **sem
  edição** como `Rack::Test::UploadedFile`. É o mesmo arquivo que o navegador
  mandaria, sem a camada de interface. (2) Nenhuma planilha real abre o arquivo
  no meio do caminho — Excel e LibreOffice reescrevem o que salvam (BOM,
  delimitador regional, aspas), e isso é coberto pelos Edge Cases nos testes do
  parser (T8); aqui a volta é do arquivo **como o app o gerou**, que é o que o
  POR-11 afirma.

- **Revisão `ecc:pr-test-analyzer` pendente**: o executor desta task não
  despacha subagente. Fica para o orquestrador, sobre
  `test/integration/collection_csv_roundtrip_test.rb` e os testes de isolamento
  já existentes (`collection_authorization_test.rb`,
  `collection_import_commit_test.rb`).

---

### T17: Custo do export e da pré-visualização, medido

**What**: A prova de que nem o export nem a pré-visualização emitem consulta por linha, medida com volume realista e não com três registros.
**Where**: `test/queries/collection_csv_plan_test.rb`
**Depends on**: T16
**Reuses**: O padrão de medição das T10 da `colecao` e T8 da `progresso` — volume realista, `ANALYZE` antes de confiar em `EXPLAIN`
**Requirement**: POR-13

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`
- Subagente: `ecc:database-reviewer` no plano de execução

**Done when**:

- [ ] Teste prova que o número de consultas do export **não cresce** com a quantidade de linhas: medido em dois volumes diferentes, com o mesmo número de consultas
- [ ] Teste prova o mesmo para a pré-visualização (POR-13 / critério 5 da história P2)
- [ ] A medição usa volume realista — centenas a milhares de linhas —, não três registros, pelo mesmo cuidado de seletividade da T4 do `catalogo`
- [ ] `ANALYZE` roda antes de qualquer `EXPLAIN` (o banco de teste carrega `pg_class.reltuples` de execuções anteriores, que não é transacional)
- [ ] Se a medição reprovar o alvo, a saída registrada é **otimizar consulta ou índice**, com medição — não trocar de stack nem partir para assíncrono sem dado
- [ ] Qualquer índice criado é **medido antes**, com `EXPLAIN (ANALYZE, BUFFERS)`, como na T10 da `colecao` — que mediu e **não** criou
- [ ] `ecc:database-reviewer` revisou o plano; achados resumidos nas "Decisões da execução"

**Tests**: unit
**Gate**: full

## Plano de delegação

Não existe `ruby-reviewer` nem `rails-reviewer` entre os agentes instalados. O
padrão herdado das features `catalogo`, `colecao` e `progresso`: subagente por
task, revisão pelos agentes agnósticos de linguagem.

| Fase | Execução | Revisão |
|---|---|---|
| 1 (T1–T3) | subagente por task, com `superpowers:systematic-debugging` — são diagnósticos, não implementação | nenhuma; a prova é a suíte doze vezes (T3) |
| 2 (T4–T7) | subagente por task, em ordem — T4 fixa o contrato de colunas que T5 e o import inteiro consomem | `ecc:a11y-architect` no link de export (T7) |
| 3 (T8–T10) | subagente por task, em ordem | `ecc:security-reviewer` no upload e no parser (**T10, task própria**) — é entrada externa não confiável e o único ponto da aplicação que recebe arquivo do usuário |
| 4 (T11–T14) | subagente por task, em ordem | `ecc:database-reviewer` na tabela de staging (T11) e na escrita em lote (T14); `ecc:a11y-architect` na pré-visualização (T13) |
| 5 (T15–T17) | subagente por task, em ordem | `ecc:pr-test-analyzer` nos testes de ida e volta e isolamento (T16); `ecc:database-reviewer` no plano de execução (T17) |

Verifier ao fim da última task, autor ≠ verificador, relatório em
`.specs/features/portabilidade/validation.md`, com evidência `file:line` por
critério, sensor de discriminação desenhado por ele mesmo e faixa de diff. **Ao
Verifier desta feature pede-se explicitamente que tente destruir dado de coleção
por algum caminho** — é a garantia central e o que distingue esta feature das
anteriores.

Coletas mecânicas (ler arquivo, listar símbolo, extrair formato) vão para
subagentes Haiku com prompt fechado e leitura apenas. Decisão de design e
resolução de colisão ficam com o orquestrador.

Sensor de mutação, se rodar, vai em worktree ou cópia — **nunca `git stash`**:
há trabalho não commitado com frequência neste repo.

## Requirement Traceability

| Requirement ID | Tasks |
|---|---|
| POR-00 | T1, T2, T3 |
| POR-01 | T4, T5, T7 |
| POR-02 | T5 |
| POR-03 | T6, T7 |
| POR-04 | T4, T8, T10 |
| POR-05 | T9 |
| POR-06 | T9, T14 |
| POR-07 | T11, T12, T13 |
| POR-08 | T14 |
| POR-09 | T15 |
| POR-10 | T13, T15 |
| POR-11 | T16 |
| POR-12 | T11, T12, T14, T16 |
| POR-13 | T5, T9, T17 |

**Coverage:** 14 requisitos, 14 mapeados, 0 órfãos. Nenhuma task sem requisito.
17 tasks, todas com requisito.
