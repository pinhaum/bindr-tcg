# Pendências Specification

## Problem Statement

As Fases 1–3 fecharam com pendências registradas no *Handoff* do `STATE.md` e sem
feature que as trate: a pasta estoura a largura de 360px que o Req. 2.5 exige, o
foco do teclado se perde depois de `+`/`−`, a arte de amostra ("SAMPLE") fica presa
no cache para sempre, o 502 da imagem não registra o motivo, o login não limita
tentativas, um login de quem já está autenticado deixa sessão órfã, o subtotal
`US$ 0,00` se repete em ~70 sets sem dizer que falta preço e o nome do set aparece
cru como vem da fonte. Esta feature fecha esse lote antes de abrir uma Fase 4.

## Goals

- [ ] A pasta cabe em 360px sem scroll horizontal (Req. 2.5), provado por medição e travado por teste.
- [ ] Depois de `+`/`−` na coleção, o foco do teclado continua no controle acionado.
- [ ] Arte em cache é rebuscada depois de 7 dias, sem quebrar a imagem quando a fonte falha.
- [ ] O login recusa a 11ª tentativa em 3 minutos do mesmo IP, com contagem compartilhada entre containers.
- [ ] O nome do set aparece na forma curta derivada na ingestão, com o nome da fonte preservado.

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Sets com lançamento futuro no topo da ordem "mais recentes" | Decisão do dono (2026-10-10): manter como está; o placeholder é aceito até o lançamento. Req. 2.4 e SRC-15 seguem sem emenda |
| Leitura de "US$" e "market" por leitor de tela pt-BR | Dono deixou fora (2026-10-10); achado de severidade baixa |
| `config.hosts` em produção | Exige o domínio de produção, que não existe ainda |
| Versão do `psql` no runner do CI | Infraestrutura de CI, sem relação com comportamento do app |
| Teto de decks por usuário | Dívida de design da `decks`, não listada pelo dono para este lote |
| Push dos commits das Fases 2 e 3 | Ação do dono, sem código |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Subtotal de set sem cópia com preço | Texto "sem preço" no lugar de `US$ 0,00`; set cujas cópias têm preço `0` real continua `US$ 0,00` | Decisão do dono (B); distingue ausência de preço de preço zero, como `counter` NULL ≠ 0 | y — dono, 2026-10-10 |
| Renovação da arte em cache | Arquivo com mais de 7 dias é rebuscado; `max-age` do navegador cai para 7 dias; rake `images:purge SETS=` força a troca | Decisão do dono (D); `max-age` de 1 ano manteria a amostra no navegador mesmo com o disco renovado | y — dono, 2026-10-10 |
| Rebusca falha com arquivo antigo em disco | Serve o arquivo antigo e registra o motivo | Uma amostra é melhor que um placeholder; a falha não pode piorar o que o usuário já via | y — dono, 2026-10-10 |
| Parâmetros do limite de login | 10 tentativas por IP em 3 minutos, só no `create` da sessão (valores do template do Rails 8) | Sem preferência do dono; o template é a referência que o comentário de `sessions_controller.rb` já discute | y — dono, 2026-10-10 |
| Store do limite de login | `solid_cache` sobre o PostgreSQL do app, o mesmo em todos os containers | O comentário de `sessions_controller.rb` exige store compartilhado; o projeto não tem Redis e o Postgres já existe | y — dono, 2026-10-10 |
| Mensagem do limite de login | "Muitas tentativas de login. Tente de novo em alguns minutos." | Mensagem ao usuário em português (convenção do projeto) | y — dono, 2026-10-10 |
| Regra do nome curto do set | Ver PND-21..24: tira o prefixo `Extra Booster: `, o prefixo `ST-NN: Starter Deck NN ` / `ST-NN: Ultra Deck `, e extrai o miolo de `XXX -Nome- [XX-NN]`; o resto fica igual | Cobre os padrões do catálogo atual (banco de dev em 2026-10-10) sem reescrever nomes que não seguem padrão | y — dono, 2026-10-10 |
| Onde o nome curto aparece | Em todo texto visível que hoje mostra `card_sets.name`; o nome da fonte continua no `aria-label` do link do set na pasta e em `card_sets.name` | Canvas (Mobile:38) mostra o nome curto; o nome completo segue disponível sem mudar a chave natural | y — dono, 2026-10-10 |
| Sessão anterior no login de quem já está autenticado | A `Session` do cookie atual é apagada antes de criar a nova | É o caso que deixa linha órfã; o `reset_session` já descarta o id antigo | y — dono, 2026-10-10 |
| Asserções vacuosas do Fix 7 | Reforçar as de `ingestion_remap_task_test`, `ingestion_compare_snapshots_task_test` e `set_progress_numbers_test` citadas no `validation.md` da `fonte-apitcg` | Lista fechada pelo Verifier daquela feature; não é varredura da suíte | y — dono, 2026-10-10 |
| Foco depois de `+`/`−` | ⚠️ VERIFICAR antes de codar: por que o foco cai (botão desabilitado pelo Turbo durante o envio ou botão substituído pelo Turbo Stream) | A causa decide a correção; registrar em `design.md` | y — dono, 2026-10-10 |

**Open questions:** none — todas resolvidas ou registradas acima (spec aprovado pelo dono em 2026-10-10).

---

## User Stories

### P1: Pasta cabe em 360px ⭐ MVP

**User Story**: Como colecionador no celular, quero ler a pasta sem rolar para o lado, para ver código, nome, contagem e valor de cada set.

**Why P1**: Viola o Req. 2.5, requisito aprovado da Fase 1.

**Acceptance Criteria**:

1. WHEN a pasta é renderizada em viewport de 360px com o set de nome mais longo do catálogo e valor de 7 dígitos THEN the system SHALL manter `document.documentElement.scrollWidth` menor ou igual a 360. <!-- PND-01 -->
2. The system SHALL declarar, para todo elemento da linha de set com `white-space: nowrap`, `overflow: hidden` ou `min-width: 0` no mesmo bloco, condição travada por teste de CSS. <!-- PND-02 -->

**Independent Test**: Medir `scrollWidth` da pasta a 360px no Chromium do Playwright no host, antes (> 360) e depois (≤ 360).

---

### P1: Foco preservado depois de `+`/`−` ⭐ MVP

**User Story**: Como usuário de teclado, quero continuar no mesmo controle depois de mudar a quantidade, para ajustar várias cópias seguidas.

**Why P1**: Achado de a11y aberto desde a `colecao`; cada clique devolve o foco ao topo da página.

**Acceptance Criteria**:

1. WHEN o usuário aciona `+` ou `−` de uma variante na grade, no detalhe ou na pasta e a resposta Turbo Stream chega THEN the system SHALL manter o elemento com o mesmo `id` do botão acionado presente e habilitado no DOM. <!-- PND-03 -->
2. WHEN a resposta Turbo Stream de `+`/`−` é aplicada THEN the system SHALL atualizar a quantidade exibida sem substituir o elemento do botão acionado. <!-- PND-04 -->

**Independent Test**: No Chromium do host, focar `+`, pressionar Enter e conferir que `document.activeElement` é o mesmo botão.

---

### P1: Motivo do 502 da imagem registrado ⭐ MVP

**User Story**: Como dono do app, quero saber por que uma arte não veio, para distinguir 403 do CDN de timeout.

**Why P1**: Sem o motivo, a pendência de sets futuros (403) só foi descoberta à mão.

**Acceptance Criteria**:

1. IF `CardImageCache` levanta `Unavailable` THEN the system SHALL registrar no log, em nível `warn`, o `variant_code` e a mensagem da exceção, e responder 502. <!-- PND-05 -->

**Independent Test**: Cliente HTTP falso respondendo 403; o log capturado contém o `variant_code` e "status 403".

---

### P2: Arte em cache se renova

**User Story**: Como colecionador, quero ver a arte final quando a fonte troca a amostra, sem esperar um ano.

**Why P2**: O OP17 inteiro está em cache com marca "SAMPLE".

**Acceptance Criteria**:

1. WHEN a imagem pedida tem arquivo em disco com mais de 7 dias THEN the system SHALL buscar a arte de novo na fonte e substituir o arquivo. <!-- PND-06 -->
2. WHEN a imagem pedida tem arquivo em disco com 7 dias ou menos THEN the system SHALL servir o arquivo sem consultar a fonte. <!-- PND-07 -->
3. IF a rebusca de um arquivo com mais de 7 dias falhar THEN the system SHALL servir o arquivo existente e registrar o motivo em nível `warn`. <!-- PND-08 -->
4. The system SHALL responder a imagem com `Cache-Control` público e `max-age` de 7 dias (604800 segundos). <!-- PND-09 -->
5. WHEN o rake `images:purge SETS=OP17,EB05` é executado THEN the system SHALL apagar do disco os arquivos das variantes desses sets, e só deles, e imprimir quantos apagou. <!-- PND-10 -->
6. IF `images:purge` é executado sem `SETS` THEN the system SHALL sair com código diferente de zero, sem apagar arquivo nenhum. <!-- PND-11 -->

**Independent Test**: Gravar arquivo com `mtime` de 8 dias, pedir a imagem com cliente falso devolvendo bytes novos e conferir o arquivo trocado.

---

### P2: Subtotal "sem preço"

**User Story**: Como colecionador, quero saber quando um set não tem valor por falta de preço, e não por valer zero.

**Why P2**: ~70 sets mostram `US$ 0,00` na pasta.

**Acceptance Criteria**:

1. IF nenhuma cópia possuída de um set tem preço THEN the system SHALL exibir "sem preço" no subtotal desse set. <!-- PND-12 -->
2. WHEN as cópias com preço de um set somam zero THEN the system SHALL exibir `US$ 0,00` no subtotal desse set. <!-- PND-13 -->
3. The system SHALL continuar calculando o valor e os subtotais numa única consulta agregada (Req. 15.16, AD-021). <!-- PND-14 -->

**Independent Test**: Set A sem preço → "sem preço"; set B com uma cópia de preço `0` → `US$ 0,00`; set C com `US$ 1,70` → `US$ 1,70`.

---

### P2: Limite de tentativas de login

**User Story**: Como dono de conta, quero que tentativas em massa de senha sejam barradas.

**Why P2**: Dívida aberta desde a T4 da `colecao`.

**Acceptance Criteria**:

1. WHEN o mesmo IP faz a 11ª tentativa de login em 3 minutos THEN the system SHALL recusar sem verificar a senha, redirecionar ao formulário de login e exibir "Muitas tentativas de login. Tente de novo em alguns minutos.". <!-- PND-15 -->
2. The system SHALL contar as tentativas num store compartilhado entre processos e containers, sobre o PostgreSQL do app. <!-- PND-16 -->
3. WHEN passam 3 minutos desde a primeira tentativa contada THEN the system SHALL aceitar nova tentativa do mesmo IP. <!-- PND-17 -->
4. The system SHALL aplicar o limite só ao `create` da sessão; cadastro, logout e páginas públicas não são contados. <!-- PND-18 -->

**Independent Test**: 10 POSTs com senha errada e o 11º com a senha certa → recusado; avançar 3 minutos → aceito.

---

### P2: Login sem sessão órfã

**User Story**: Como dono de conta, quero que só existam no banco as sessões que estão em uso.

**Why P2**: Achado baixo da revisão de segurança de 2026-10-05.

**Acceptance Criteria**:

1. WHEN um usuário já autenticado faz login de novo THEN the system SHALL apagar a `Session` do cookie anterior antes de criar a nova, deixando o total de `Session` do usuário igual. <!-- PND-19 -->
2. The system SHALL afirmar valor concreto em cada teste listado no Fix 7 da `fonte-apitcg`, de modo que o mutante correspondente falhe. <!-- PND-20 -->

**Independent Test**: Login, login de novo com o mesmo cookie → `user.sessions.count` igual a 1.

---

### P3: Nome curto do set

**User Story**: Como colecionador, quero ler "Memorial Collection" e não "Extra Booster: Memorial Collection", como no canvas.

**Why P3**: Pendência D12 da `conformidade`; cosmético.

**Acceptance Criteria**:

1. WHEN a ingestão normaliza um set de nome `Extra Booster: <X>` THEN the system SHALL gravar `<X>` como nome curto. <!-- PND-21 -->
2. WHEN a ingestão normaliza um set de nome `ST-NN: Starter Deck NN <X>` ou `ST-NN: Ultra Deck <X>` THEN the system SHALL gravar `<X>` como nome curto. <!-- PND-22 -->
3. WHEN a ingestão normaliza um set de nome `<PALAVRAS> -<X>- [<XX>-<NN>]` THEN the system SHALL gravar `<X>` como nome curto. <!-- PND-23 -->
4. IF o nome não casa com nenhum padrão ou a extração resulta vazia THEN the system SHALL gravar o nome da fonte como nome curto. <!-- PND-24 -->
5. The system SHALL exibir o nome curto em todo texto visível que hoje mostra o nome do set, mantendo `card_sets.name` e `card_sets.code` inalterados. <!-- PND-25 -->

**Independent Test**: Normalize sobre a fixture: `EB01` → "Memorial Collection", `ST01` → "Straw Hat Crew", `EB04` → "EGGHEAD CRISIS", `OP01` → "Romance Dawn".

---

## Edge Cases

- IF o relógio do arquivo em disco estiver no futuro THEN the system SHALL tratá-lo como tendo 7 dias ou menos (PND-07).
- IF `images:purge` recebe um código de set inexistente THEN the system SHALL apagar zero arquivos desse código e seguir com os demais.
- WHEN o IP do request vem de proxy THEN the system SHALL contar pelo `request.remote_ip` do Rails (PND-15).
- IF o nome curto derivado ficar só com espaços THEN the system SHALL usar o nome da fonte (PND-24).

---

## Implicit-requirement sweep

| Dimensão | Cobertura |
| -------- | --------- |
| Input validation & bounds | PND-11 (`SETS` obrigatório), PND-24 (nome vazio) |
| Failure / partial-failure | PND-05, PND-08 |
| Idempotency / retry | PND-06/07 (rebusca idempotente por idade); nome curto recalculado a cada import |
| Auth & rate limits | PND-15..18, PND-19 |
| Concurrency / ordering | Rebusca concorrente do mesmo arquivo: `persist` já grava em temporário e renomeia; N/A além disso |
| Data lifecycle / expiry | PND-06, PND-09, PND-10, PND-17 |
| Observability | PND-05, PND-08 |
| External-dependency failure | PND-08 |
| State-transition integrity | N/A porque nenhuma pendência cria máquina de estados |

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| PND-01 | P1: Pasta 360px | - | Pending |
| PND-02 | P1: Pasta 360px | - | Pending |
| PND-03 | P1: Foco | - | Pending |
| PND-04 | P1: Foco | - | Pending |
| PND-05 | P1: 502 logado | - | Pending |
| PND-06 | P2: Cache de arte | - | Pending |
| PND-07 | P2: Cache de arte | - | Pending |
| PND-08 | P2: Cache de arte | - | Pending |
| PND-09 | P2: Cache de arte | - | Pending |
| PND-10 | P2: Cache de arte | - | Pending |
| PND-11 | P2: Cache de arte | - | Pending |
| PND-12 | P2: Subtotal | - | Pending |
| PND-13 | P2: Subtotal | - | Pending |
| PND-14 | P2: Subtotal | - | Pending |
| PND-15 | P2: Limite de login | - | Pending |
| PND-16 | P2: Limite de login | - | Pending |
| PND-17 | P2: Limite de login | - | Pending |
| PND-18 | P2: Limite de login | - | Pending |
| PND-19 | P2: Sessão órfã | - | Pending |
| PND-20 | P2: Sessão órfã | - | Pending |
| PND-21 | P3: Nome curto | - | Pending |
| PND-22 | P3: Nome curto | - | Pending |
| PND-23 | P3: Nome curto | - | Pending |
| PND-24 | P3: Nome curto | - | Pending |
| PND-25 | P3: Nome curto | - | Pending |

**Coverage:** 25 total, 0 mapped to tasks, 25 unmapped ⚠️ (tasks ainda não escritas)

---

## Success Criteria

- [ ] `scrollWidth` da pasta a 360px ≤ 360 no Chromium do host, com o catálogo real do banco de dev.
- [ ] Rodar `images:purge SETS=OP17` no dev e recarregar o detalhe de uma carta do OP17 traz a arte atual da fonte.
- [ ] Gate full verde (`bin/rails test && bin/rubocop`), mais `bin/brakeman` limpo.
- [ ] Emendas no `.context/requirements.md`: Req. 15.13 (subtotal "sem preço") e requisitos novos para cache de arte, limite de login e nome curto, antes do código que os implementa.
