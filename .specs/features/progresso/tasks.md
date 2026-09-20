# Plano de execução — Progresso por set (Fase 5)

Espelha `.context/tasks.md` §5.1. A fonte de verdade da ordem é
`.context/tasks.md`; este documento acrescenta dependências, gate e teste
explícitos por task (AD-005). **Ao concluir uma task, marcar o checkbox nos dois
planos e commitar junto com o código.** A §5.1 só fecha quando todas as tasks
que ela cobre fecharem — ela cobre T1–T8 e fecha na T8.

A feature é governada por **AD-003**. A decisão da spec sobre o Req. 9.5 está
tomada e **não se reabre nesta fase**: denominador = `sets.base_set_size`;
numerador = variantes possuídas com `art_kind IN ('base','other')`; parallels em
métrica separada. Corrigir a classificação de `art_kind` na ingestão está em
Out of Scope.

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
  próprio arquivo, como em `app/models/card_set.rb`.
- Toda consulta parte de `Current.user`, nunca de id vindo do request.
  `CollectionItem.for_user` exige o objeto `User`.
- Esta feature **não deve precisar de migração**: `sets.base_set_size` e
  `sets.total_set_size` já existem e estão populadas (`db/structure.sql`).

## Test Coverage Matrix

| Camada | Tipo de teste | Onde |
|---|---|---|
| Agregação de progresso e regras de domínio | unit | `test/queries/set_progress_query_test.rb` |
| Plano de execução e número de consultas | unit | `test/queries/set_progress_plan_test.rb` |
| Fluxo HTTP, autorização e HTML renderizado | integration | `test/integration/` — `get`, `assert_select` |
| Navegação para o catálogo filtrado | integration | `test/integration/` — segue o link e asserta o conjunto |

O projeto **não usa fixtures YAML**: cada teste cria seus registros no `setup`.
A suíte roda em paralelo (`parallelize(workers: :number_of_processors)`).

## Gate Check Commands

| Gate | Comando |
|---|---|
| quick | `docker compose exec app bin/rails test test/models test/queries` |
| full | `docker compose exec app bin/rails test && docker compose exec app bin/rubocop` |
| build | `docker compose build` |

`RAILS_ENV` posicional não é lido pelo `bin/rails` — usar `env RAILS_ENV=test
bin/rails ...`. Gem nova exige `docker compose run --rm --no-deps app bundle
install`; esta feature não prevê gem nova.

## Execution Plan

### Phase 1: Agregação

O cálculo inteiro, provado por unidade antes de existir qualquer tela. É aqui que
moram as decisões de denominador, numerador, parallels e denominador ausente.

```
T1 → T2 → T3
```

### Phase 2: Página

Exposição do que a Fase 1 calcula. Abre com a dependência que atravessa a
fronteira: T4 precisa da agregação que T3 fecha.

```
T3 → T4 → T5 → T6
```

### Phase 3: Provas não-funcionais

Isolamento entre usuários, custo da página e viewport. Não acrescentam informação
ao usuário; são o que torna as fases anteriores corretas e utilizáveis.

```
T6 → T7 → T8
```

## Task Breakdown

### T1: `SetProgressQuery` — possuídas, total e contagem distinta ✅

**What**: Query object que devolve, por set, as variantes distintas possuídas pelo usuário e o total de variantes do set, contando variantes e nunca cópias.
**Where**: `app/queries/set_progress_query.rb`
**Depends on**: None
**Reuses**: `CollectionItem.for_user` e o scope `owned` (`app/models/collection_item.rb`); a agregação por `card_variants.set_id`, o mesmo eixo que `CatalogQuery::VARIANT_FILTERS` documenta
**Requirement**: PRG-01, PRG-04, PRG-07, PRG-08

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] O objeto recebe o **objeto** `User` (ou `nil`) e nunca um id; nenhum caminho leva de parâmetro de request a usuário
- [x] Devolve, por set, a quantidade de variantes **distintas** possuídas e o total de variantes daquele set
- [x] Teste prova que uma variante com quantidade 5 conta **1** no progresso e **5** em `CollectionItem.total_copies_for` — as duas métricas medidas lado a lado no mesmo cenário
- [x] Teste prova que variante com `quantity = 0` não entra no numerador, e que o resultado é o mesmo de não haver registro
- [x] Teste prova que a agregação usa `card_variants.set_id` (set da impressão) e não `cards.set_id` (set de estreia), com uma variante impressa em set diferente do set de estreia da carta
- [x] Teste prova que `nil` devolve todos os sets com numerador zero, sem erro
- [x] Teste prova que `SetProgressQuery.new(id_numérico)` levanta `ArgumentError` pela barreira de `CollectionItem.for_user`

**Tests**: unit
**Gate**: quick

**Decisões da execução:**

- **Uma agregação com `GROUP BY sets.id`, e o `FILTER` é o que abre espaço para
  T2 e T3.** A consulta é um `LEFT JOIN` de `sets` para `card_variants` com um
  único `GROUP BY`; cada métrica é uma coluna agregada sobre **o mesmo** grupo.
  Foi a forma escolhida justamente porque o percentual da T2 (denominador
  `sets.base_set_size`, numerador `art_kind IN ('base','other')`) e os parallels
  da T3 entram como mais colunas `COUNT(...) FILTER (WHERE art_kind ...)` no
  mesmo `SELECT` — nenhuma consulta nova por set, nenhuma reescrita da forma.
  Verificado no banco de desenvolvimento antes de fechar a task: as colunas
  `FILTER` devolvem `base+other` igual a `base_set_size` em EB01/EB02/EB03 e os
  parallels separados. A extensão **não** foi implementada aqui: T2 e T3 são
  outras tasks.
- **A condição de posse mora no `ON` do `LEFT JOIN`, nunca no `WHERE`.** Com ela
  no `WHERE`, o set em que o usuário não possui nada perde todas as linhas e
  **some do resultado** — a página exibiria só os sets já iniciados, o oposto do
  Edge Case ("todos os sets aparecem com numerador zero; a página é informativa,
  não vazia"). Trocar o `LEFT` por `INNER` foi uma das mutações testadas e
  derruba 6 testes. O mesmo vale para o join de `sets` para `card_variants`: set
  sem variante nenhuma continua listado com total zero.
- **Nenhuma migração, e isso é o resultado esperado.** `sets.base_set_size` e
  `sets.total_set_size` já existem e estão populadas; a T1 sequer as lê (são da
  T2). A agregação consome o schema vigente e o `schema_format: :sql` não foi
  tocado.
- **`nil` é numerador vazio, não caso de erro.** `CollectionItem.for_user(nil)`
  é `none`, a subconsulta do `LEFT JOIN` fica vazia e todos os sets saem com
  numerador zero e denominador intacto. O denominador é do catálogo e não
  depende de quem olha — há teste separado para isso.
- **Sensor de discriminação rodado sobre cópia do arquivo (`cp`, nunca `git
  stash`).** Quatro mutações, todas capturadas: somar `quantity` em vez de
  `COUNT(DISTINCT ...)` (8 falhas), agregar por `cards.set_id` em vez de
  `card_variants.set_id` (10 falhas), tratar posse por existência de registro
  em vez de `owned` (8 falhas) e trocar o `LEFT JOIN` da coleção por `INNER`
  (5 falhas + 1 erro). O arquivo foi restaurado e a suíte reconferida verde.
- **Asserção de número de consultas já na T1, embora PRG-11 seja da T8.** A T8
  mede a página inteira; aqui o teste apenas trava a **forma**: acrescentar
  cinco sets ao cenário não pode custar consulta a mais. É o que impede a
  regressão silenciosa para um `count` por set, que é a forma N+1 que a spec
  mediu em ~213ms contra ~8ms.

---

### T2: Percentual com denominador `base_set_size`

**What**: Percentual de conclusão por set, com denominador `sets.base_set_size` e numerador restrito ao mesmo universo (`art_kind IN ('base','other')`), mais o tratamento de denominador ausente, zero e numerador excedente.
**Where**: `app/queries/set_progress_query.rb`
**Depends on**: T1
**Reuses**: as colunas `sets.base_set_size` e `sets.total_set_size`, já populadas
**Requirement**: PRG-02, PRG-05, PRG-10

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [ ] O denominador é `sets.base_set_size`, nunca o total de impressões do set e nunca uma contagem local de `art_kind = 'base'`
- [ ] O numerador do percentual conta as variantes possuídas com `art_kind IN ('base','other')`, excluindo `parallel`
- [ ] Teste prova o percentual com denominador e numerador conhecidos, inclusive um set em que `base_set_size` diverge de `count(art_kind = 'base')` — o caso medido em 21 de 62 sets
- [ ] Teste prova que set sem `base_set_size` é **exibido** com contagem de possuídas e percentual indisponível, e que o resultado não é `0` nem `100`
- [ ] Teste prova que denominador zero não executa divisão e cai no mesmo caminho do denominador ausente
- [ ] Teste prova que numerador maior que o denominador é apresentado limitado a cem por cento, sem erro
- [ ] Comentário no arquivo registra a decisão de denominador/numerador da spec e a divergência medida, para que a escolha não pareça arbitrária a quem ler depois

**Tests**: unit
**Gate**: quick

---

### T3: Parallels como métrica separada

**What**: Contagem de variantes `art_kind = 'parallel'` possuídas por set, exibida como métrica própria e fora do numerador e do denominador do percentual.
**Where**: `app/queries/set_progress_query.rb`
**Depends on**: T2
**Reuses**: a mesma agregação por set da T1, sem consulta adicional por set
**Requirement**: PRG-06

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [ ] Cada set traz a contagem de parallels possuídos e o total de parallels do set
- [ ] Teste prova que posse **apenas** de parallels mantém o percentual de conclusão em zero e a contagem de parallels refletindo a posse
- [ ] Teste prova que acrescentar uma variante base ao mesmo cenário altera **só** o percentual, deixando a contagem de parallels intacta
- [ ] Teste prova que set sem nenhuma variante `parallel` apresenta a métrica como zero, sem ocultá-la e sem erro
- [ ] Nenhuma consulta nova por set: a métrica sai da mesma agregação

**Tests**: unit
**Gate**: quick

---

### T4: `ProgressController` e rota, com sessão exigida

**What**: Controller e rota da página de progresso, herdando o default protegido de `ApplicationController`, sem `allow_unauthenticated_access`.
**Where**: `app/controllers/progress_controller.rb`
**Depends on**: T3
**Reuses**: o concern `Authentication` incluído em `ApplicationController`; a rota entra em `config/routes.rb` como uma linha `get "progress"`, inseparável da action que ela expõe
**Requirement**: PRG-08, PRG-09

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] O controller **não** declara `allow_unauthenticated_access`
- [ ] A action monta a consulta a partir de `Current.user`; nenhum identificador de usuário é lido do request
- [ ] Teste prova que anônimo é redirecionado para a autenticação, sem 200 e sem dado de coleção no corpo
- [ ] Teste prova que, após autenticar, o usuário retorna à página de progresso
- [ ] Teste prova que `?user_id=` de outro usuário é ignorado e o número exibido é o do usuário da sessão
- [ ] Teste estrutural prova que `require_authentication` está entre os callbacks do controller — um 302 sozinho não distingue "filtro presente" de "rota inexistente"

**Tests**: integration
**Gate**: full

---

### T5: View de progresso

**What**: Página que lista os sets com possuídas, total, percentual e parallels, e apresenta o percentual indisponível como indisponível.
**Where**: `app/views/progress/index.html.erb`
**Depends on**: T4
**Reuses**: as convenções de marcação e o cabeçalho de `app/views/layouts/application.html.erb`
**Requirement**: PRG-01, PRG-02, PRG-06, PRG-10

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Cada set exibe nome, possuídas, total e percentual
- [ ] Parallels aparecem como métrica visivelmente separada do percentual
- [ ] Set sem denominador exibe a posse e o percentual como indisponível, em texto que não é `0%` nem `100%`
- [ ] Entrada para a página no cabeçalho, visível só para quem tem sessão — como "Lista de desejos"
- [ ] Teste de integração sobre o HTML renderizado confere os números de um cenário conhecido, com `SPEC_DEVIATION` no cabeçalho do arquivo registrando a ausência de navegador
- [ ] Usuário autenticado sem nenhuma posse vê todos os sets com zero, e não uma página vazia

**Tests**: integration
**Gate**: full

---

### T6: Link para o catálogo filtrado por set

**What**: Link de cada set para o catálogo já filtrado por aquele set, pelo parâmetro `sets` do contrato de `design.md` §4.2.
**Where**: `app/views/progress/index.html.erb`
**Depends on**: T5
**Reuses**: `CatalogQuery::VARIANT_FILTERS`, que mapeia `sets` para `sets.code`; parâmetro já exercido em `test/queries/catalog_query_test.rb`
**Requirement**: PRG-03

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Cada set exibido oferece link para o catálogo filtrado por ele
- [ ] O link usa `catalog_path(sets: [ code ])` — o **código** do set, pelo contrato existente; nenhum parâmetro novo é inventado
- [ ] Teste de integração **segue** o link e confere que o catálogo responde 200 com o filtro ativo
- [ ] Teste prova que o conjunto devolvido corresponde ao set: uma carta daquele set presente e uma de outro set ausente
- [ ] O texto do link identifica o set para quem usa leitor de tela, sem depender de contexto visual

**Tests**: integration
**Gate**: full

---

### T7: Isolamento entre usuários

**What**: Prova de que o progresso de cada usuário sai da própria coleção e de que nenhum identificador vindo do request altera o resultado.
**Where**: `test/integration/progress_authorization_test.rb`
**Depends on**: T6
**Reuses**: o padrão de `test/integration/collection_authorization_test.rb`
**Requirement**: PRG-08

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Teste prova que dois usuários com posse **no mesmo set** veem números diferentes, cada um o seu
- [ ] Os dois usuários têm posses de tamanhos distintos, para que uma troca de usuário mude o número visível — com posses iguais nenhuma asserção discriminaria
- [ ] Teste prova que `?user_id=` do outro usuário não altera o número exibido
- [ ] Teste prova que a coleção de um usuário não vaza para o total de parallels do outro
- [ ] Teste prova que usuário sem posse alguma não vê número de quem tem

**Tests**: integration
**Gate**: full

---

### T8: Número fixo de consultas e viewport de 360px

**What**: Medir que a página resolve em número de consultas que não cresce com a quantidade de sets, e que a marcação não impõe scroll horizontal em 360px.
**Where**: `test/queries/set_progress_plan_test.rb`
**Depends on**: T7
**Reuses**: o precedente da T10 da `colecao` — medir antes, criar índice depois, e só se necessário
**Requirement**: PRG-11, PRG-12

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Teste conta as consultas emitidas pela requisição com **duas** quantidades de sets diferentes e prova que o número **não varia** com a quantidade
- [ ] A contagem mede a agregação, não a página inteira: consultas de sessão e de layout são identificadas e descontadas, ou a asserção é sobre a diferença entre os dois cenários
- [ ] O plano da agregação é medido com dado semeado em volume realista e registrado no cabeçalho do teste
- [ ] Índice só entra se a medição reprovar; se entrar, a migração é aditiva e `db/structure.sql` é regenerado por `db:migrate`
- [ ] Marcação sem largura fixa maior que 360px nem `white-space: nowrap` em bloco largo; asserção sobre a folha de estilo ou sobre a marcação renderizada, com `SPEC_DEVIATION` registrando que a ausência de navegador impede medir o scroll de fato
- [ ] `.context/tasks.md` §5.1 marcado nesta task, que é a que a fecha

**Tests**: unit
**Gate**: full

---

## Requirement Traceability

| Requirement ID | Tasks |
|---|---|
| PRG-01 | T1, T5 |
| PRG-02 | T2, T5 |
| PRG-03 | T6 |
| PRG-04 | T1 |
| PRG-05 | T2 |
| PRG-06 | T3, T5 |
| PRG-07 | T1 |
| PRG-08 | T1, T4, T7 |
| PRG-09 | T4 |
| PRG-10 | T2, T5 |
| PRG-11 | T8 |
| PRG-12 | T8 |

**Coverage:** 12 requisitos, 12 mapeados, 0 órfãos. Nenhuma task sem requisito.

## Plano de delegação

Não existe `ruby-reviewer` nem `rails-reviewer` entre os agentes instalados. O
padrão herdado das features `catalogo` e `colecao`: lote por fase, revisão pelos
agentes agnósticos de linguagem.

| Fase | Execução | Revisão |
|---|---|---|
| 1 (T1–T3) | subagente por task, em ordem — T1 fixa a forma da agregação que T2 e T3 estendem | `ecc:database-reviewer` na consulta de agregação (T1–T3) |
| 2 (T4–T6) | subagente por task, em ordem | `ecc:a11y-architect` na view de progresso (T5, T6) |
| 3 (T7–T8) | subagente por task, em ordem | `ecc:pr-test-analyzer` nos testes de isolamento (T7) e de denominador ausente (T2); `ecc:database-reviewer` no plano de execução (T8) |

Verifier ao fim da última task, autor ≠ verificador, relatório em
`.specs/features/progresso/validation.md`, com evidência `file:line` por
critério, sensor de discriminação e faixa de diff.

Coletas mecânicas (ler arquivo, listar símbolo, extrair formato) vão para
subagentes Haiku com prompt fechado e leitura apenas. Decisão de design e
resolução de colisão ficam com o orquestrador.

Sensor de mutação, se rodar, vai em worktree ou cópia — **nunca `git stash`**:
há trabalho não commitado com frequência neste repo.
