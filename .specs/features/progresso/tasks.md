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

### T2: Percentual com denominador `base_set_size` ✅

**What**: Percentual de conclusão por set, com denominador `sets.base_set_size` e numerador restrito ao mesmo universo (`art_kind IN ('base','other')`), mais o tratamento de denominador ausente, zero e numerador excedente.
**Where**: `app/queries/set_progress_query.rb`
**Depends on**: T1
**Reuses**: as colunas `sets.base_set_size` e `sets.total_set_size`, já populadas
**Requirement**: PRG-02, PRG-05, PRG-10

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] O denominador é `sets.base_set_size`, nunca o total de impressões do set e nunca uma contagem local de `art_kind = 'base'`
- [x] O numerador do percentual conta as variantes possuídas com `art_kind IN ('base','other')`, excluindo `parallel`
- [x] Teste prova o percentual com denominador e numerador conhecidos, inclusive um set em que `base_set_size` diverge de `count(art_kind = 'base')` — o caso medido em 21 de 62 sets
- [x] Teste prova que set sem `base_set_size` é **exibido** com contagem de possuídas e percentual indisponível, e que o resultado não é `0` nem `100`
- [x] Teste prova que denominador zero não executa divisão e cai no mesmo caminho do denominador ausente
- [x] Teste prova que numerador maior que o denominador é apresentado limitado a cem por cento, sem erro
- [x] Comentário no arquivo registra a decisão de denominador/numerador da spec e a divergência medida, para que a escolha não pareça arbitrária a quem ler depois

**Tests**: unit
**Gate**: quick

**Decisões da execução:**

- **Indisponível é `nil`; zero por cento é `0.0`. A distinção é do tipo, não de
  convenção.** O Edge Case proíbe apresentar set sem denominador como `0%` ou
  `100%`, e um sentinela numérico (`0`, `-1`, `100`) seria silenciosamente
  formatável como percentual pela view da T5 — o defeito voltaria pela porta
  que a spec fechou. `nil` torna a confusão impossível em Ruby: `nil != 0`,
  `nil` não responde a comparação numérica e `nil.zero?` levanta
  `NoMethodError`. Acrescentei `completion_percent_known?` para que a T5
  pergunte pela disponibilidade em vez de espalhar `nil?` pela marcação. Há
  teste que compara o set indisponível (`OPp2f`) com o set zerado (`OPp1c`)
  lado a lado e exige que os dois valores **difiram**.
- **`base_size` chega ao `Row` sem `to_i`, e isso é deliberado.** Todas as
  outras colunas agregadas levam `.to_i` (nulo do `LEFT JOIN` é zero de fato);
  `base_size` não pode, porque ali nulo e zero são estados **diferentes** que
  PRG-10 exige preservar. Um `.to_i` nessa linha é a mutação que converte
  "indisponível" em "não comecei" — foi testada no sensor e derruba um teste.
  O comentário está na própria linha para que a assimetria não pareça descuido.
- **Denominador ausente e denominador zero compartilham o caminho, e o guarda
  é anterior à divisão.** `completion_percent_known?` é
  `!base_size.nil? && base_size.positive?`, não um `rescue ZeroDivisionError`:
  nenhuma divisão chega a ser executada, e não há como sair `Infinity` nem
  `NaN`. O schema permite zero — `sets.base_set_size` é nullable e não tem
  `CHECK` — mesmo que hoje nenhum set real esteja nesse estado.
- **O limite de cem por cento é `min`, não `round`.** Numerador maior que o
  denominador é alcançável hoje (ST16: `base_set_size = 7` contra 6 não-parallel),
  e a divergência de classificação pode inverter o sinal em outro set após uma
  reingestão. `[ pct, 100.0 ].min` apresenta o teto sem erro e sem esconder que
  o percentual é conhecido — `completion_percent_known?` continua `true`.
- **`sets.base_set_size` entra no `SELECT` sem agregação, por dependência
  funcional.** O `GROUP BY` é `sets.id`, a chave primária, e o Postgres permite
  selecionar qualquer coluna de `sets` sob esse agrupamento. Escrevi
  `MAX(sets.base_set_size)` primeiro e troquei: o `MAX` sugeriria falsamente
  que o denominador varia dentro do grupo.
- **Nenhuma consulta nova, como a T1 previu.** As duas métricas entraram como
  colunas no mesmo `SELECT` (uma `COUNT(...) FILTER (...)` e uma coluna
  direta), sobre o mesmo `GROUP BY`. O teste de número de consultas da T1
  continua verde com os cinco sets novos do cenário, e o `EXPLAIN` não ganhou
  passada pelo banco.
- **Duas asserções da T1 foram tornadas relativas, sem enfraquecê-las.** Os
  sets novos do cenário acrescentam posse e deslocaram o total absoluto de
  `CollectionItem.total_copies_for` (era 9, virou 17). Em vez de reescrever o
  número — que voltaria a quebrar na T3 —, as asserções passaram a medir a
  **diferença** entre somar cópias e contar variantes, que é exatamente o que
  elas discriminam. A mutação `count` → `sum(:quantity)` continua sendo pega.
- **Sensor de discriminação: nove mutações sobre cópia do arquivo (`cp`, nunca
  `git stash`), todas capturadas.** Denominador pela contagem local de
  `art_kind = 'base'` (12 falhas), denominador pelo total de impressões
  (12 falhas), numerador restrito a `'base'` (3 falhas), numerador sem excluir
  `parallel` (2 falhas), `base_size.to_i` (1 falha), indisponível como `0.0`
  (5 falhas), indisponível como `100.0` (5 falhas), sem o limite de cem por
  cento (1 falha) e guarda só para `nil`, deixando zero dividir (2 falhas). O
  arquivo foi restaurado por `diff` e a suíte reconferida verde.
- **Conferido contra o banco de desenvolvimento, não só contra o cenário de
  teste**: 63 sets, exatamente um indisponível (`PRB9cd8`, `base_size` nulo,
  percentual `nil`), 21 sets em que `base_set_size` diverge de
  `count(art_kind = 'base')`, e os dois casos extremos da spec com o
  denominador certo — `FamilyDeckSet` com 49 (a contagem local daria 0 e
  divisão por zero) e `PRB01` com 113 (daria 1 e exibiria 100%).

---

### T3: Parallels como métrica separada ✅

**What**: Contagem de variantes `art_kind = 'parallel'` possuídas por set, exibida como métrica própria e fora do numerador e do denominador do percentual.
**Where**: `app/queries/set_progress_query.rb`
**Depends on**: T2
**Reuses**: a mesma agregação por set da T1, sem consulta adicional por set
**Requirement**: PRG-06

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Cada set traz a contagem de parallels possuídos e o total de parallels do set
- [x] Teste prova que posse **apenas** de parallels mantém o percentual de conclusão em zero e a contagem de parallels refletindo a posse
- [x] Teste prova que acrescentar uma variante base ao mesmo cenário altera **só** o percentual, deixando a contagem de parallels intacta
- [x] Teste prova que set sem nenhuma variante `parallel` apresenta a métrica como zero, sem ocultá-la e sem erro
- [x] Nenhuma consulta nova por set: a métrica sai da mesma agregação

**Tests**: unit
**Gate**: quick

**Decisões da execução:**

- **Duas colunas, e a assimetria entre elas é o ponto.**
  `parallel_owned_variants` conta sobre `owned_items` (o `LEFT JOIN` da
  coleção) e `parallel_variants` conta sobre `card_variants` (o catálogo). A
  primeira depende de quem olha, a segunda não — é a mesma assimetria que
  `owned_variants` e `total_variants` já tinham na T1, e há teste que a trava:
  o total de parallels de `@set_d` é 2 tanto para o dono da posse quanto para o
  outro usuário. Contar o total sobre `owned_items` foi uma das mutações
  testadas e derruba 2 testes.
- **Contagem absoluta, sem percentual próprio, e a razão está no arquivo.** O
  Req. 9.6 pede "a contagem de parallels possuídos". Um percentual exigiria um
  `parallelSetSize` que a fonte não fornece; seria derivado de `art_kind`, a
  classificação que a própria spec mediu como divergente em 21 dos 62 sets.
  Não acrescentei `parallel_percent` nem predicado análogo a
  `completion_percent_known?`: não há requisito, e o número não existiria sem
  inventar denominador.
- **O filtro é `art_kind = 'parallel'` e mais nada — `other` fica de fora.**
  `other` já entra no numerador e no universo do denominador do percentual
  principal (decisão da T2); trazê-lo para cá o tiraria de lá e reintroduziria
  a incoerência aritmética que a T2 resolveu. Os dois conjuntos são disjuntos
  por construção, e é isso que o Req. 9.6 quer dizer com "nunca somada ao
  percentual". A mutação que faz a métrica contar `base,other,parallel` derruba
  6 testes.
- **Nenhuma consulta nova, como T1 e T2 previram.** As duas métricas entraram
  como colunas `COUNT(...) FILTER (...)` no mesmo `SELECT`, sobre o mesmo
  `GROUP BY sets.id`. O teste de número de consultas da T1 continua verde, e a
  medição contra o banco de desenvolvimento confirma: **1 consulta** para os 63
  sets, com `parallel_variants` somando exatamente 1643 — o número medido de
  `art_kind = 'parallel'` no catálogo real. 12 sets reais não têm parallel
  nenhum e continuam listados com a métrica em zero.
- **O cenário discriminante é `@set_e`, e ele já existia desde a T2.** A posse
  única ali é `@v_e_par` (`parallel`): percentual **0.0** contra contagem de
  parallels **1** — dois números diferentes, sem os quais nenhuma asserção
  distinguiria "não somou" de "somou". O par do teste acrescenta `@v_e_base` ao
  **mesmo** cenário e exige que só o percentual se mova (0.0 → 50.0) com a
  contagem de parallels intacta. `@v_e_par` tem 2 cópias de propósito: é o que
  prova que a métrica conta variantes distintas e não cópias.
- **Sensor de discriminação: sete mutações sobre cópia do arquivo (`cp`/`diff`,
  nunca `git stash`), seis capturadas.** Parallels somados ao numerador do
  percentual (5 falhas), somados ao denominador (7 falhas), métrica contando
  `base` em vez de `parallel` (8 falhas), métrica contando `base,other,parallel`
  (6 falhas), total de parallels contado sobre a posse em vez do catálogo
  (2 falhas) e parallels possuídos somando cópias em vez de contar variantes
  (5 falhas).
- **Uma mutação sobreviveu, e ela não é da T3.** Remover o `DISTINCT` de
  `COUNT(DISTINCT owned_items.card_variant_id)` não derruba teste nenhum —
  **nem na coluna nova nem na `base_owned_variants` da T2**, conferido nas duas.
  Não é teste fraco: a subconsulta de posse seleciona só `card_variant_id` de
  `collection_items`, onde `UNIQUE (user_id, card_variant_id)` garante uma
  linha por variante, então `COUNT` e `COUNT(DISTINCT)` coincidem por
  **construção do schema**. O `DISTINCT` fica como defesa contra uma mudança
  futura na forma do join, não como a garantia de distinção — essa é da
  constraint. Registrado aqui em vez de escrever um teste que não teria como
  falhar.

---

### T4: `ProgressController` e rota, com sessão exigida ✅

**What**: Controller e rota da página de progresso, herdando o default protegido de `ApplicationController`, sem `allow_unauthenticated_access`.
**Where**: `app/controllers/progress_controller.rb`
**Depends on**: T3
**Reuses**: o concern `Authentication` incluído em `ApplicationController`; a rota entra em `config/routes.rb` como uma linha `get "progress"`, inseparável da action que ela expõe
**Requirement**: PRG-08, PRG-09

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] O controller **não** declara `allow_unauthenticated_access`
- [x] A action monta a consulta a partir de `Current.user`; nenhum identificador de usuário é lido do request
- [x] Teste prova que anônimo é redirecionado para a autenticação, sem 200 e sem dado de coleção no corpo
- [x] Teste prova que, após autenticar, o usuário retorna à página de progresso
- [x] Teste prova que `?user_id=` de outro usuário é ignorado e o número exibido é o do usuário da sessão
- [x] Teste estrutural prova que `require_authentication` está entre os callbacks do controller — um 302 sozinho não distingue "filtro presente" de "rota inexistente"

**Tests**: integration
**Gate**: full

**Decisões da execução:**

- **A proteção é por omissão, e é isso que se prova.** O controller não declara
  nada: `ApplicationController` inclui `Authentication`, cujo `before_action
  :require_authentication` torna a action protegida ao nascer. Não acrescentei
  `authenticated?` na action — ele é o remendo que o `CatalogController` precisa
  por ser **público**, e chamá-lo aqui por reflexo sugeriria falsamente que a
  sessão ainda não está resolvida quando a action começa. O
  `WishlistItemsController` é o precedente exato, e o comentário do controller
  registra a razão para quem ler depois.

- **A asserção estrutural é um par simétrico, não uma asserção.**
  `require_authentication` **presente** em `ProgressController` e **ausente** em
  `CatalogController`. Só o primeiro lado passaria também se o filtro estivesse
  instalado em tudo, inclusive onde não deveria — e é justamente o catálogo
  público que essa hipótese quebraria. É a mesma forma que
  `authentication_test.rb` usa, invertida: lá o par prova que o catálogo **pula**
  um filtro que existe; aqui, que o progresso **herda** um filtro que o catálogo
  pula.

- **As duas provas estruturais são por AST (`Ripper.sexp`), nunca por regex
  sobre o texto.** Escrevi as duas primeiro como `refute_match` sobre a fonte e
  **as duas falharam no verde** — casando com a própria palavra dentro dos
  comentários que explicam por que a construção não deve existir. O defeito não
  era cosmético: um regex de `/params/` tem falso positivo em comentário e falso
  negativo em `params.dig(:user_id)`, `params.to_unsafe_h[:user_id]` e
  `chave = :user_id; params[chave]` — as formas idiomáticas que alguém
  escreveria sem saber que existe um teste a respeito. `Ripper.sexp` descarta
  comentário e enxerga o identificador em qualquer forma de acesso. O precedente
  e o helper vêm de `collection_authorization_test.rb`.

- **Aqui a asserção sobre `params` é mais forte que a do
  `CollectionItemsController`.** Lá o teste irmão admite `:card_variant_id`,
  porque a variante é catálogo público e precisa vir da URL. Nesta página não há
  **nenhum** parâmetro legítimo: é sempre "o progresso de quem está na sessão",
  sem filtro, paginação ou recorte. Por isso a asserção é a ausência total do
  identificador `params`, e não uma lista de chaves permitidas.

- **Rota `get "progress"`, sem id e sem `resource`.** Nenhum identificador de
  usuário cabe na URL — é o que torna `?user_id=` inócuo por desenho e não por
  checagem (Req. 6.5). `resource :progress` geraria `new`/`edit`/`create` que
  nunca serão escritos; só existe leitura. O helper é `progress_path`, e o
  `as: :progress` é o que o concern precisa para devolver o usuário à origem
  depois de autenticar.

- **View mínima de propósito, e a T5 continua inteira.** A action precisa
  renderizar para os testes rodarem, então `app/views/progress/index.html.erb`
  traz só o `<h1>`. Lista de sets, percentuais, parallels e marcação a11y são da
  T5; o link para o catálogo filtrado é da T6. Os testes desta task leem
  `@rows` por `view_assigns` em vez de assertar marcação, justamente para não
  travarem a forma da página que a T5 ainda vai escolher.

- **`SPEC_DEVIATION` registrado no cabeçalho do arquivo de teste**: não há
  navegador no container, então a verificação de comportamento de página é
  teste de integração sobre HTML renderizado. É o precedente de
  `collection_ownership_ui_test.rb` e o que a spec já prevê em "Verificação de
  comportamento visual". Nenhum critério da T4 depende de layout.

- **Sensor de discriminação: seis mutações sobre cópia dos arquivos
  (`cp`/`diff`, nunca `git stash`), todas capturadas.** Declarar
  `allow_unauthenticated_access` (6 falhas), declarar `skip_before_action
  :require_authentication` — a forma expandida em que o primeiro se traduz
  (6 falhas), ler o usuário de `params[:user_id]` (2 falhas), lê-lo por
  `params.dig(:user_id)` (2 falhas), montar a consulta com `nil` em vez de
  `Current.user` (2 falhas) e remover a rota (5 erros). Os arquivos foram
  restaurados e conferidos idênticos por `diff`; a suíte foi reconferida verde.

- **Anônimo sai sem número no corpo, e o teste olha o corpo.** Um controller que
  renderizasse a página e só depois redirecionasse ainda seria 302, então o
  `assert_redirected_to` sozinho não bastaria: a asserção exige que o código do
  set não apareça na resposta. O cenário dá a `@nami` uma variante e a `@zoro`
  duas, de propósito — com posses do mesmo tamanho, obedecer ao `?user_id=` e
  ignorá-lo dariam o mesmo número e nada discriminaria.

---

### T5: View de progresso ✅

**What**: Página que lista os sets com possuídas, total, percentual e parallels, e apresenta o percentual indisponível como indisponível.
**Where**: `app/views/progress/index.html.erb`
**Depends on**: T4
**Reuses**: as convenções de marcação e o cabeçalho de `app/views/layouts/application.html.erb`
**Requirement**: PRG-01, PRG-02, PRG-06, PRG-10

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Cada set exibe nome, possuídas, total e percentual
- [x] Parallels aparecem como métrica visivelmente separada do percentual
- [x] Set sem denominador exibe a posse e o percentual como indisponível, em texto que não é `0%` nem `100%`
- [x] Entrada para a página no cabeçalho, visível só para quem tem sessão — como "Lista de desejos"
- [x] Teste de integração sobre o HTML renderizado confere os números de um cenário conhecido, com `SPEC_DEVIATION` no cabeçalho do arquivo registrando a ausência de navegador
- [x] Usuário autenticado sem nenhuma posse vê todos os sets com zero, e não uma página vazia

**Tests**: integration
**Gate**: full

**Decisões da execução:**

- **Lista (`<ul>`), não tabela, e a razão é o Req. 2.5 antes de ser semântica.**
  Cinco números por set em 360px só caberiam numa tabela com `overflow-x: auto`,
  que é exatamente o scroll horizontal que o requisito proíbe — o remédio usual
  seria a violação. A semântica confirma a escolha: cada set é um **registro
  independente**, não uma célula cruzando duas dimensões; nada aqui se lê "na
  coluna X, linha Y". A `<ul>` ainda faz o leitor de tela anunciar quantos sets
  existem, informação que uma sequência de `<div>` não daria. É a mesma forma de
  `wishlist_items/index`, pelo mesmo motivo. A T8 vai medir 360px e não herda
  dívida: nenhuma largura fixa, nenhum `white-space: nowrap` em bloco largo,
  `min-width: 0` e `overflow-wrap: anywhere` no nome do set.

- **Cada número vem numa frase, porque em leitura linear não existe coluna.**
  "3 7 60 1" é ruído para leitor de tela. A marcação emite "4 de 7 variantes",
  "60% concluído", "1 de 2 parallels" — e há teste que **exige as frases**, não
  só os números. Os `<span>` com classe existem para o CSS e para o teste mirar
  o valor; retirá-los deixaria o texto igualmente legível, que é o critério de
  que o significado não está na marcação. Mesma lição de
  `catalog/_owned_total`. Plural explícito (`variante`/`variantes`,
  `parallel`/`parallels`, `set`/`sets`), nunca `pluralize`: o inflector do Rails
  é inglês.

- **Sem `aria-live` e sem `role="status"`, deliberadamente.** A página não tem
  interação: nenhum número muda sem recarregar. A T11 da `colecao` fixou que
  região viva é para o que muda em resposta a uma ação do usuário; declará-la
  aqui faria o leitor de tela reanunciar a página inteira sem que nada tivesse
  acontecido.

- **O texto de indisponível é "Percentual indisponível: este set não informa o
  tamanho do set base."** Uma afirmação sobre **o dado**, não sobre a coleção do
  usuário — é a diferença entre "a fonte não diz o tamanho deste set" e "você
  não tem nada". "Sem dados" diria que falta informação sem dizer qual, e um
  traço (`—`) é invisível para leitor de tela. A decisão é tomada por
  `completion_percent_known?` e não por `nil?` na marcação; no ramo indisponível
  **nada** é renderizado no lugar do percentual, nem elemento vazio — há teste
  separado só para isso, porque `number_to_percentage(nil)` devolve string vazia
  e o elemento existiria sem dizer nada.

- **`owned_variants` (posse do set inteiro) e `base_owned_variants` (numerador do
  percentual) são números diferentes e aparecem ambos.** O cenário de teste tem
  4 e 3 para o mesmo set, justamente para que trocá-los na marcação derrube
  asserção. A base do percentual é exibida entre parênteses — "(3 de 5 do set
  base)" — porque um percentual sem a fração que o origina é inauditável pelo
  usuário, e `base_set_size` (5) difere tanto de `total_variants` (7) quanto de
  `owned_variants` (4) no cenário, de propósito.

- **Entrada no cabeçalho ao lado de "Lista de desejos", dentro do mesmo
  `if authenticated?`.** Mesma razão registrada lá: a página exige sessão em toda
  action (PRG-09) e um link que só leva ao login é promessa quebrada. O teste é
  um par simétrico — o link **presente** para quem tem sessão e **ausente** para
  anônimo, com a wishlist conferida junto para provar que o cenário anônimo é
  anônimo de fato.

- **Sensor de discriminação: oito mutações sobre cópia dos arquivos (`cp`/`diff`,
  nunca `git stash`), sete capturadas.** `completion_percent` renderizado sem o
  predicado (2 falhas), set sem denominador omitido da lista (5), contagem de
  parallels somada ao percentual (2), `owned_variants` trocado por
  `total_variants` (5), indisponível exibido como `0%` (2), link do cabeçalho
  visível para anônimo (1) e parallels aninhados no elemento do percentual em
  forma que o parser preserva (1). Os arquivos foram restaurados e conferidos
  idênticos por `diff`; a suíte foi reconferida verde.

- **Uma mutação sobreviveu, e ela é impossível de matar por teste sobre o DOM.**
  Escrever o `<p>` dos parallels **dentro** do `<p>` do percentual não é
  observável: o parser HTML fecha o `<p>` aberto ao encontrar o seguinte, e os
  dois viram irmãos de qualquer jeito. Nenhum teste sobre o DOM poderia
  distinguir os dois arquivos. A asserção estrutural pega a forma que o parser
  **preserva** (aninhar num `<span>`), que é a única em que o defeito existiria
  de fato — e usar `<p>` para cada métrica é, portanto, o que torna o erro
  impossível em vez de detectável. Registrado no comentário da view em vez de
  escrever um teste que não teria como falhar, como a T3 fez com o `DISTINCT`.

- **Duas asserções do teste foram corrigidas contra o contrato real, não contra
  a implementação.** A primeira versão esperava `owned_variants = 3` para um set
  com 3 base possuídas mais 1 parallel possuído, e `total_variants = 4` onde 4 é
  `base_set_size`. As duas eram erro **do cenário**, não da view: `owned_variants`
  é a posse do set inteiro (Req. 9.1) e `total_variants` é o total de impressões.
  A view já distinguia os três números corretamente; foi o teste que os
  conflatava. Corrigido preservando a intenção discriminante — e `@set_b` ganhou
  uma segunda variante para que seu total (2) passasse a diferir do seu
  denominador (4).

- **Conferido contra o banco de desenvolvimento, não só contra o cenário de
  teste**: a view renderiza os 63 sets reais, `PRB9cd8` (nome `"X"`, 3 variantes)
  aparece com "0 de 3 variantes" e "Percentual indisponível", sem `0%` e sem
  `100%` em nenhum ponto do seu item, e nenhuma contagem de parallels cai dentro
  do elemento do percentual.

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
