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

### T6: Link para o catálogo filtrado por set ✅

**What**: Link de cada set para o catálogo já filtrado por aquele set, pelo parâmetro `sets` do contrato de `design.md` §4.2.
**Where**: `app/views/progress/index.html.erb`
**Depends on**: T5
**Reuses**: `CatalogQuery::VARIANT_FILTERS`, que mapeia `sets` para `sets.code`; parâmetro já exercido em `test/queries/catalog_query_test.rb`
**Requirement**: PRG-03

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Cada set exibido oferece link para o catálogo filtrado por ele
- [x] O link usa `catalog_path(sets: [ code ])` — o **código** do set, pelo contrato existente; nenhum parâmetro novo é inventado
- [x] Teste de integração **segue** o link e confere que o catálogo responde 200 com o filtro ativo
- [x] Teste prova que o conjunto devolvido corresponde ao set: uma carta daquele set presente e uma de outro set ausente
- [x] O texto do link identifica o set para quem usa leitor de tela, sem depender de contexto visual

**Tests**: integration
**Gate**: full

**Decisões da execução:**

- **O teste extrai o `href` do HTML e faz a requisição seguinte com ele.** É a
  diferença entre provar o que a **view emite** e provar o que o catálogo
  **filtra** — este último `test/queries/catalog_query_test.rb` já prova. Montar
  `get catalog_path(sets: [ "OPp5a" ])` à mão passaria intacto com a view
  emitindo o id do set, um parâmetro de nome errado ou nenhum parâmetro: o link
  quebrado e a suíte verde. O helper `href_do_catalogo` é o único ponto por onde
  a URL entra no teste, e ele lê de `css_select`, nunca reconstrói.

- **Duas requisições encadeadas, e a segunda asserção é sobre o conjunto.** O
  `200` sozinho não discrimina: o catálogo responde 200 para qualquer filtro,
  inclusive para um que não casa nada. A prova é uma carta do set **presente** e
  uma de outro set **ausente** — e há um teste simétrico seguindo o link do
  `@set_b`, porque sem ele um link **sem filtro nenhum** passaria por acaso: o
  catálogo completo também contém a carta do set A.

- **Texto visível curto, `aria-label` com o nome do set.** São 63 sets na página
  real. Um texto visível repetido 63 vezes é o que a lista de links de um leitor
  de tela mostra, e nela não há contexto ao redor para desempatar (WCAG 2.4.4) —
  63 entradas "Ver no catálogo" são inescolhíveis. O texto visível pode ser curto
  porque **ali** o contexto existe: o `<h2>` do set está na mesma caixa, três
  linhas acima. É o precedente de `catalog/_card_tile`, que resolve "3 impressões"
  numa grade de 24 tiles do mesmo jeito. O `aria-label` **começa** com o texto
  visível ("Ver no catálogo as cartas de …") para não quebrar o SC 2.5.3: quem
  usa comando de voz e diz "ver no catálogo" continua acertando o link.

- **Sensor de discriminação: oito mutações sobre cópia dos arquivos (`cp`/`diff`,
  nunca `git stash`), oito capturadas.** Id do set em vez do código (4 falhas),
  `sets` trocado por `set` (4), link sem filtro nenhum (4), `sets` escalar em vez
  de lista (1), `aria-label` fixo sem nomear o set (2), link renderizado uma vez
  fora do laço (7), link removido de todos os sets (7) e `hidden` no próprio `<a>`
  (1). A view foi restaurada e conferida idêntica por `diff`; a suíte foi
  reconferida verde.

- **Uma mutação sobreviveu à primeira rodada e virou asserção nova, não
  justificativa.** Esconder o link de 62 dos 63 sets com `hidden` não derrubava
  nada: `css_select` encontra o elemento escondido, e "presente no DOM" não é
  "oferecido ao usuário" — `hidden` remove o link da tela **e** da árvore de
  acessibilidade. O teste
  "os links dos sets são oferecidos de fato, não apenas presentes no DOM" fechou
  o buraco em `[hidden]` no `<a>` e no contêiner, mais `aria-hidden="true"`. Com
  ela as oito mutações morrem. O achado é de a11y de verdade, não artefato do
  sensor: era uma forma de o link existir para o teste e não para quem usa a
  página.

- **`sets` como lista (`[ code ]`) e não escalar.** O saneador do query object
  trabalha sobre `Array(...)`, então o escalar funciona hoje — a mutação M4
  derruba apenas 1 teste, o da igualdade exata do `href`, e não a navegação. A
  lista é a forma do contrato (`OU` dentro da categoria) e é a que continua certa
  se um segundo valor entrar na URL; o escalar é coincidência de implementação do
  saneador, não contrato.

**Correções da revisão de a11y** (pós-T6, sobre a view entregue nas T5/T6 — não é
task nova do plano, nenhum checkbox foi marcado por ela):

- **CRITICAL — foco visível (SC 2.4.11 / SC 2.4.7).** O
  `.progress-set__catalog-link` era o único controle interativo do projeto fora
  do realce reforçado: herdava o outline default do navegador, fino e sumindo
  sobre o fundo do item do set — exatamente o que o comentário da folha registra
  como motivo do reforço. Ele entrou **no seletor agrupado existente** dos
  controles de wishlist, e não numa regra nova: duas regras com a mesma
  declaração é como elas divergem no dia em que alguém ajusta a espessura numa
  só, e o ponto do reforço é ser o mesmo contorno em todo lugar. O agrupamento
  torna a divergência impossível em vez de detectável — e há teste que compara o
  corpo da regra do link com o dos controles de posse e exige que sejam iguais.

- **HIGH — alvo de toque (SC 2.5.8).** `min-height: 24px` declarado. A altura
  calculada já passava (0.875rem × `line-height: 1.5` = 21px, mais 0.375rem de
  padding em cima e embaixo ≈ **33px**), mas a convenção do projeto, registrada
  em `catalog.css` no bloco do `.wishlist-mark__input`, é declarar e não depender
  de cálculo: fonte do usuário e `line-height` herdado mudam o resultado.

- **`min-width` deliberadamente não declarado.** O alvo é um link de **texto em
  fluxo**, cuja largura é a da frase "Ver no catálogo" e nunca chega perto de
  24px. Declarar `min-width` num `inline-block` de texto não protege nada e
  passaria a mentir se o texto virasse ícone — aí o certo seria declarar os dois,
  como em `.ownership__button`, que é alvo quadrado de verdade. A justificativa
  está no comentário da regra, não só aqui.

- **O comentário dos 44px estava errado e foi corrigido.** A folha afirmava que
  "a área de toque de 44px sai do `padding` vertical": com `padding: 0.375rem 0`
  sobre fonte de 0.875rem, o `padding` contribui 12px e o total chega a ~33px —
  o CSS não entregava 44px em configuração nenhuma, e nenhum ajuste só de padding
  chegaria lá. Comentário que afirma um número que o código não entrega é pior
  que comentário nenhum, porque a próxima pessoa confia nele e não mede.

- **MEDIUM — `<ul>` sem nome acessível (SC 1.3.1).** `aria-labelledby` na
  `<ul class="progress__list">` apontando para um `id` novo no `<h1>`. Quem
  navega por lista (tecla "l" no NVDA) chega na `<ul>` sem passar pelo título e
  ouvia só "lista, 63 itens". O rótulo **reaproveita** o `<h1>` em vez de repetir
  a frase num `aria-label`: duas fontes para o mesmo texto é como elas divergem
  depois.

- **Há teste separado exigindo que o alvo do `aria-labelledby` exista.** Um
  `aria-labelledby` apontando para id inexistente deixa o elemento **sem nome
  nenhum** — pior que não ter o atributo, porque parece resolvido na leitura do
  código. É a diferença entre rótulo de fato e rótulo de fachada, e sem essa
  asserção apagar o `id` do `<h1>` não derrubava nada.

- **`SPEC_DEVIATION` nos dois testes de CSS.** Foco visível e altura de alvo de
  toque são propriedades do que o navegador pinta e mede, e **não há navegador no
  container** — mesma limitação do cabeçalho do arquivo. A asserção é sobre o
  texto da folha, precedente já adotado em `collection_ownership_ui_test` ("os
  botões de posse declaram alvo de toque de 24px") e em `catalog_grid_test`. O
  limite está escrito no próprio teste: um `outline: none` acrescentado depois,
  em seletor de maior especificidade e outro ponto da folha, passaria pelas
  asserções. O que elas travam é que a declaração existe e que o link não ficou
  **de fora do agrupamento** — que é o defeito que a revisão encontrou.

- **Sensor de discriminação: quatro mutações sobre cópia dos arquivos
  (`cp`/`diff`, nunca `git stash`), quatro capturadas.** Link retirado do seletor
  agrupado de `:focus-visible` (2 falhas: a da existência da regra e a da
  igualdade com o realce dos controles de posse), `min-height` removido (1),
  `aria-labelledby` removido da `<ul>` (1 falha + 1 erro), e `id` removido do
  `<h1>` deixando o `aria-labelledby` pendurado (1 — a asserção da existência do
  alvo, a única que pega este caso). Arquivos restaurados e conferidos idênticos
  por `diff`; suíte reconferida verde.

- **Discordância registrada quanto ao escopo do achado CRITICAL.** O revisor
  descreve o link como fora do realce "e também do segundo grupo": não há
  discordância sobre o defeito, mas o remédio proposto ("acrescentar ao seletor
  agrupado existente") tem dois seletores agrupados candidatos na folha. A
  escolha foi o **segundo** (o dos controles de wishlist, vizinho do bloco
  `progress-*`), e não o primeiro, por proximidade física na folha: a regra fica
  a poucas linhas do bloco que ela estiliza, e quem editar `progress-*` a vê. A
  declaração é idêntica nos dois, e o teste de igualdade compara com o **primeiro**
  grupo justamente para travar que os dois não divirjam.

---

### T7: Isolamento entre usuários ✅

**What**: Prova de que o progresso de cada usuário sai da própria coleção e de que nenhum identificador vindo do request altera o resultado.
**Where**: `test/integration/progress_authorization_test.rb`
**Depends on**: T6
**Reuses**: o padrão de `test/integration/collection_authorization_test.rb`
**Requirement**: PRG-08

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Teste prova que dois usuários com posse **no mesmo set** veem números diferentes, cada um o seu
- [x] Os dois usuários têm posses de tamanhos distintos, para que uma troca de usuário mude o número visível — com posses iguais nenhuma asserção discriminaria
- [x] Teste prova que `?user_id=` do outro usuário não altera o número exibido
- [x] Teste prova que a coleção de um usuário não vaza para o total de parallels do outro
- [x] Teste prova que usuário sem posse alguma não vê número de quem tem

**Tests**: integration
**Gate**: full

**Decisões da execução:**

- **Todo número visível difere entre os dois usuários, e isso é o cenário, não
  um detalhe.** `@set_x` tem `base_set_size` 6 e nove impressões (4 `base`, 2
  `other`, 3 `parallel`); `@nami` sai com 2 possuídas, numerador 1, 17% e 1
  parallel, `@zoro` com 5, 3, 50% e 2. Nenhum par coincide, então uma troca de
  usuário em **qualquer** campo derruba asserção — com posses iguais o teste
  passaria idêntico obedecendo ao `?user_id=` e ignorando-o. As posses são
  **disjuntas**: nenhuma variante em comum, de modo que um vazamento infla o
  número em vez de deixá-lo intacto.

- **`total_variants` é a única coincidência, e é obrigatória.** Ele sai do
  catálogo e não pode depender de quem olha. Um teste que só exigisse "números
  diferentes" seria satisfeito por uma implementação que recortasse o **catálogo**
  pelo usuário — o que esconderia do colecionador exatamente as cartas que ele
  ainda não tem, o oposto do produto. Por isso há asserção explícita exigindo que
  `total_variants` e `parallel_variants` **não** variem, ao lado da que exige que
  `owned_variants` varie. É a mesma assimetria que T1 e T3 registraram.

- **A leitura é da marcação, não de `view_assigns`.** A T4 já prova que `@rows`
  é do usuário da sessão; o que faltava provar é que é esse número que chega aos
  olhos de quem abriu a página. Um vazamento **na view** — uma consulta de posse
  feita na marcação, um helper que reconsulta — não apareceria em
  `view_assigns`, e foi exatamente a mutação M6 do sensor.

- **Os parallels ganharam teste próprio, e a soma coincidir com o total é de
  propósito.** `@zoro` tem 2 parallels e `@nami` 1; a soma (3) é o total do set.
  Se a contagem ignorasse o usuário, `@nami` veria "3 de 3" — indistinguível de
  "possuo todos" para quem lê a página. Os parallels saem de uma coluna `FILTER`
  separada no mesmo `SELECT`, então um recorte perdido **só ali** deixaria o
  percentual correto e a métrica errada; a mutação M4 é exatamente isso e mata 4
  testes, dos quais este é o único específico.

- **`@usopp` tem linha zerada sobre uma variante de `@zoro`, não ausência de
  registro.** É o que torna "sem posse alguma" discriminante: uma implementação
  que tratasse posse por **existência de registro** em vez de por `owned` lhe
  daria 1, e uma que ignorasse o usuário lhe daria 7. Zero é linha existente que
  significa "não tenho" (Req. 7.3).

- **`@nami` tem 4 cópias de uma variante, de propósito.** Se o progresso contasse
  cópias em vez de variantes, `@nami` (5 cópias) superaria `@zoro` (5 variantes,
  5 cópias) — o cenário inverte o sinal da comparação, e não só desloca o número.

- **As formas de enfiar identificador vão além do `?user_id=`.** O teste varre
  `user_id`, `user`, `id`, e-mail no lugar do id, lista (`user_id[]`) e hash
  aninhado, mais um teste separado de **cabeçalho** de requisição (`X-User-Id`).
  O cabeçalho é a porta que nenhuma asserção sobre `params` cobre — o limite que
  os testes irmãos registram explicitamente no comentário — e aqui ele é fechado
  pelo efeito. Há também o caso do `?user_id=` apontando para o **próprio**
  usuário: ele passaria intacto mesmo com a leitura do parâmetro, e existe para
  impedir que alguém "conserte" o teste anterior fazendo o parâmetro valer.

- **Três provas estruturais, porque comportamento só cobre o que ele exercita.**
  (1) `SetProgressQuery.new(id)` levanta `ArgumentError` — a barreira de tipo é o
  que torna PRG-08 satisfeito **por construção**, e sem asserção a suíte provaria
  apenas que hoje ninguém escreveu o caminho errado. (2) Nenhuma rota de
  progresso aceita segmento dinâmico, com casamento por **sufixo** do controller
  para que `api/progress` não escape. (3) A **view** não toca `params` nem a
  constante `User`, por AST (`Ripper.sexp`) sobre o Ruby que o ERB compila — a
  T4 cobriu o controller, e a view é a metade que faltava, onde um
  `params[:user_id]` passaria despercebido por não haver revisão de ERB tão
  atenta. Regex não serviria: casaria com a palavra dentro dos próprios
  comentários da view, que são extensos.

- **Todos os 13 testes passaram contra o código existente, sem alterar uma linha
  de produção.** É o resultado previsto: `SetProgressQuery` recebe o objeto
  `User`, `CollectionItem.for_user` levanta `ArgumentError` para um id e a URL
  `/progress` não tem onde um identificador caber. Nenhum defeito de autorização
  foi encontrado.

- **Sensor de discriminação: seis mutações sobre cópia dos arquivos (`cp`/`diff`,
  nunca `git stash`), todas capturadas.** M1 — o query object recebendo
  `User.find(params[:user_id])` (2 falhas). M2 — `for_user` trocado por
  `CollectionItem.all` (11 falhas). M3 — o `LEFT JOIN` perdendo a correlação por
  usuário (11 falhas). M4 — apenas a coluna de parallels sem recorte de usuário
  (4 falhas). M5 — a barreira de tipo de `for_user` aceitando um id em vez de
  levantar (1 falha, a estrutural desenhada para ela). M6 — a view reconsultando
  a posse a partir de `params` (3 falhas). Os arquivos foram restaurados e
  conferidos idênticos por `diff`; a suíte foi reconferida verde.

- **`SPEC_DEVIATION` registrado no cabeçalho do arquivo**: não há navegador no
  container, então a verificação de "o que cada usuário vê" é teste de integração
  sobre HTML renderizado. Mesmo precedente da T4 e da T5.

---

### T8: Número fixo de consultas e viewport de 360px ✅

**What**: Medir que a página resolve em número de consultas que não cresce com a quantidade de sets, e que a marcação não impõe scroll horizontal em 360px.
**Where**: `test/queries/set_progress_plan_test.rb`
**Depends on**: T7
**Reuses**: o precedente da T10 da `colecao` — medir antes, criar índice depois, e só se necessário
**Requirement**: PRG-11, PRG-12

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Teste conta as consultas emitidas pela requisição com **duas** quantidades de sets diferentes e prova que o número **não varia** com a quantidade
- [x] A contagem mede a agregação, não a página inteira: consultas de sessão e de layout são identificadas e descontadas, ou a asserção é sobre a diferença entre os dois cenários
- [x] O plano da agregação é medido com dado semeado em volume realista e registrado no cabeçalho do teste
- [x] Índice só entra se a medição reprovar; se entrar, a migração é aditiva e `db/structure.sql` é regenerado por `db:migrate`
- [x] Marcação sem largura fixa maior que 360px nem `white-space: nowrap` em bloco largo; asserção sobre a folha de estilo ou sobre a marcação renderizada, com `SPEC_DEVIATION` registrando que a ausência de navegador impede medir o scroll de fato
- [x] `.context/tasks.md` §5.1 marcado nesta task, que é a que a fecha

**Tests**: unit
**Gate**: full

**Decisões da execução:**

- **A asserção central é sobre a diferença entre dois cenários, e não sobre um
  número absoluto.** Medido: a requisição emite **3** consultas — `Session Load`,
  `User Load` (as duas do `resume_session`) e uma única `CardSet Load`, que é a
  agregação. Travar `assert_equal 3` seria frágil pela razão errada: mudaria se
  o concern ganhasse um `includes` ou se o layout passasse a exibir um contador,
  e nenhuma dessas é a regressão que PRG-11 proíbe — uma asserção que falha por
  elas é apagada na primeira vez que atrapalha. A asserção compara **1 set
  contra 40**: o custo constante aparece nos dois lados e se cancela na
  subtração, seja ele qual for. Há uma segunda asserção que **desconta
  nominalmente** as duas consultas de sessão e exige que reste exatamente uma,
  contendo `GROUP BY` — ela fecha o ponto cego da subtração, onde duas consultas
  de catálogo constantes também se cancelariam.

- **A medição é da requisição HTTP, e é isso que a distingue da T1.** A T1 já
  trava a forma do query object isolado. Isso não cobre PRG-11: provado pelo
  sensor, um `CardVariant.where(set_id: ...).count` **dentro do laço da view**
  deixa os 44 testes da T1 verdes e a página N+1 — 44 consultas em 40 sets. Só
  a contagem sobre `get progress_path` pega esse caso, e ela o pega com as duas
  asserções de PRG-11.

- **Nenhum índice criado: a medição reprovou o candidato do revisor.** O
  `ecc:database-reviewer` deixou anotado o índice parcial
  `collection_items (user_id, card_variant_id) WHERE quantity >= 1`. Criado
  sobre o seed de volume (200 sets, 12.000 variantes, 51 usuários, 20.400
  itens), o planejador **o ignorou por completo**: mesmo plano, mesmo
  `Index Scan using index_collection_items_on_user_id` com
  `Filter: (quantity >= 1)`, e **custo idêntico — 2096,43 com e sem**. O caso
  assimétrico que a T10 da `colecao` nomeou como o único capaz de reabrir a
  decisão também foi medido — o mesmo usuário com 12.000 itens e **40%** deles
  zerados, muito além dos ~14% daquele seed — e o índice continuou ignorado,
  com o plano **com** ele saindo marginalmente pior (4172,30 contra 4172,27).
  Índice que o planejador não escolhe é custo de escrita sem ganho de leitura.
  Nenhuma migração, `db/structure.sql` intacto, `db:migrate` não foi necessário.

- **Os dois `Seq Scan` do catálogo não são assertados como ausentes, e isso é
  deliberado.** `total_variants` e `parallel_variants` exigem todas as variantes
  de todos os sets: não há predicado seletivo que um índice explore, e o
  `FILTER` roda depois da leitura. Exigir a ausência deles reprovaria o plano
  **certo** e empurraria para um índice que só serviria para satisfazer a
  asserção — o erro exato que a T10 da `colecao` cometeu ao travar um índice
  nominal e teve de corrigir. A asserção é "sem varredura de `collection_items`"
  mais "acesso indexado existe", sem nomear qual índice.

- **A asserção de estatísticas é sobre `last_analyze`, não sobre
  `pg_class.reltuples` — e foi o sensor que impôs a troca.** A primeira versão
  lia `reltuples` e o sensor a reprovou: **`reltuples` não é transacional** e
  sobrevive ao rollback do teste, então uma execução anterior deste mesmo
  arquivo deixa a estimativa povoada e a asserção passa **sem o `ANALYZE`** —
  verde por resíduo, e dependente da ordem da suíte. Confirmado medindo:
  `reltuples` do banco de teste vinha `[12000, 20400, 200]` de uma rodada
  anterior, e zerou só depois de um `ANALYZE` manual sobre as tabelas vazias.
  `last_analyze` é um instante comparado com `clock_timestamp()` do início do
  teste: prova que o `ANALYZE` rodou **nesta** execução, o que nenhum resíduo
  satisfaz. A mutação que remove o `ANALYZE` passou a morrer em duas rodadas
  consecutivas.

- **Sem o `ANALYZE` o plano medido é outro, e essa era a segunda metade do
  buraco.** Medido: sem ele o Postgres estima `rows=1` para `sets` e escolhe
  `Nested Loop Left Join` com `Bitmap Heap Scan on card_variants` por set — um
  plano que nada tem a ver com o que as 12.000 variantes custam. As asserções de
  plano continuavam **verdes** nesse estado, porque o plano desinformado também
  acessa `collection_items` por índice. Era uma asserção que media outra coisa
  sem falhar, exatamente a armadilha que a T10 nomeou para o volume — aqui
  aplicada às estatísticas.

- **PRG-12 é atacado pelas causas declaráveis, não pela largura calculada.** Não
  há navegador, então `scrollWidth > clientWidth` não existe aqui. As asserções
  varrem as regras cujo seletor menciona `progress-*` — por seletor e não por
  faixa de linhas, para que a regra de `:focus-visible`, que vive longe do bloco
  no grupo dos controles de wishlist, continue sendo inspecionada — e proíbem
  três coisas: largura fixa em pixel acima de 360px (`width`, `min-width`,
  `flex-basis`), `white-space: nowrap` em bloco **largo** (os que carregam
  frase; em elemento curto ele é legítimo, por isso a lista explícita) e
  `overflow-x: auto|scroll`, que é o remédio usual e aqui **é** a violação. Uma
  quarta asserção olha a **marcação renderizada** atrás de `style=` embutido,
  onde os três escapariam da folha inteiramente.

- **A forma da página também é assertada, porque ela não aparece em CSS
  nenhum.** Trocar a `<ul>` por `<table>` é a regressão que reintroduz o
  problema que a T5 resolveu escolhendo lista, e nenhuma regra de estilo a
  denuncia. Há asserção exigindo a `<ul class="progress__list"` e proibindo
  `<table>` dentro de `main.progress`.

- **Duas asserções guardam as premissas das outras, no precedente da T10.** A
  primeira trava o **seed** (volume, seletividade do usuário alvo, existência de
  item zerado); a segunda trava que o **bloco `progress-*` foi de fato
  encontrado** na folha — sem ela, renomear o seletor faria as três asserções de
  360px varrerem o vazio e passarem sem ler uma linha. As duas foram
  confirmadas pelo sensor (M9 e M10).

- **Sensor de discriminação: dez mutações sobre cópia dos arquivos (`cp`/`diff`,
  nunca `git stash`), dez capturadas.** M1 — agregação trocada por um `count`
  por set, a forma N+1 (2 falhas na T8, 3 na suíte; 208 consultas contra 4).
  M2 — `ANALYZE` removido do seed (1 falha, em duas rodadas consecutivas, só
  **depois** da troca por `last_analyze`; na versão `reltuples` sobrevivia).
  M3 — `min-width: 420px` no item do set (1). M4 — `white-space: nowrap` na
  linha de parallels (1). M5 — `overflow-x: auto` no contêiner (1). M6 — `<ul>`
  trocada por `<table>` (2). M7 — `style="min-width: 900px"` embutido no item
  (1). M8 — `CardVariant.where(set_id:).count` dentro do laço da view, com o
  query object **intacto** (2 falhas na T8 e **zero** nos 44 testes da T1 — é a
  prova de que esta task cobre o que a T1 não cobria). M9 — seed reduzido a 10
  sets (1). M10 — bloco `progress-*` renomeado na folha (1). Os arquivos de
  produção foram restaurados e conferidos **byte a byte idênticos** por `diff`;
  a suíte foi reconferida verde.

- **`SPEC_DEVIATION` registrado na seção de 360px do arquivo de teste**: não há
  navegador no container, então a verificação de scroll horizontal é asserção
  sobre o texto da folha e sobre a marcação renderizada. O limite está escrito
  no próprio teste: uma tabela de muitas colunas, uma imagem sem `max-width` ou
  uma palavra inquebrável mais larga que a caixa estouram 360px sem violar
  nenhuma destas asserções. O que elas garantem é que as causas **declaráveis**
  não foram introduzidas. Mesmo precedente de `progress_ui_test.rb`,
  `catalog_grid_test.rb` e `collection_ownership_ui_test.rb`.

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
