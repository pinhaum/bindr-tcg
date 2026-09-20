# Progresso por set — Validação

**Date**: 2026-09-20
**Spec**: `.specs/features/progresso/spec.md`; fonte de verdade
`.context/requirements.md` Req. 9 e §5.1 de `.context/tasks.md` (AD-005)
**Feature governada por**: AD-003 (denominador = variantes base; parallels em
métrica separada)
**Diff range**: `59c6db0..87af059` — `bb9c035` (T1), `7f6fb3d` (T2), `9569ac8`
(T3), `013fdd1` (T4), `19c964b` (T5), `0a5edc4` (T6), `03b2229` (T7), `14f8dce`
(correções de a11y, não é task do plano), `87af059` (T8)
**Verifier**: subagente independente (autor ≠ verificador)
**Veredito**: ✅ **PASS**, com **2 lacunas** registradas (nenhuma bloqueante) e
**1 defeito de teste** de severidade MEDIUM (não bloqueante, não afeta produção)

---

## Nota sobre o escopo

1. A notação `A..B` excluiria `bb9c035` (T1). Os critérios da T1 foram
   verificados contra o **estado atual** de `app/queries/set_progress_query.rb`,
   não contra o diff isolado — o que é o correto, já que T2 e T3 estenderam o
   mesmo arquivo (colunas `FILTER` no mesmo `SELECT`).
2. O commit `14f8dce` **não é task do plano**: é a correção dos achados da
   revisão de a11y sobre a view entregue nas T5/T6. Nenhum checkbox foi marcado
   por ele, e o `tasks.md` registra isso explicitamente. Verifiquei os quatro
   achados mesmo assim, por tocarem código da feature.
3. A **decisão do dono do produto** sobre o Req. 9.5 (denominador
   `sets.base_set_size`, numerador `art_kind IN ('base','other')`, parallels
   exclusivamente `art_kind = 'parallel'`) é premissa desta verificação, não
   objeto dela. Verifiquei **conformidade do código com ela**; não a reabri.
4. `.context/tasks.md` §5.1 aparece marcada (`- [x] **5.1 Progresso por set**`,
   `.context/tasks.md:196`). Os quatro bullets foram verificados um a um abaixo.

### Estado medido por mim

| Medição | Resultado |
| ------- | --------- |
| `docker compose exec app bin/rails test` | **501 runs, 1819 assertions, 0 failures, 0 errors, 0 skips** |
| `docker compose exec app bin/rubocop` | **88 files inspected, no offenses detected** |
| Árvore de trabalho ao final das mutações | limpa (`git status --porcelain` vazio; os cinco arquivos de produção conferidos idênticos por `diff`) |
| Estabilidade da suíte | **12 execuções completas: 10 verdes, 2 com 1 falha** — ver L3, flake identificado e reproduzido |

A suíte cresceu de 395 (fim da `colecao`) para **501 testes**: **106 testes
novos** nesta feature, distribuídos em 5 arquivos.

### Fatos do banco re-medidos por mim (não copiados da spec)

Rodei a medição de forma independente contra o banco de desenvolvimento. **Todas
as afirmações quantitativas da spec se confirmaram**:

| Afirmação da spec | Medido por mim | Confere |
| ----------------- | -------------- | ------- |
| 63 sets, 4917 variantes, 2818 cartas | `sets=63 variants=4917 cards=2818` | ✅ |
| 62 dos 63 sets têm `base_set_size` | `com base_set_size=62` | ✅ |
| Exatamente um set sem denominador: `PRB9cd8`, nome `"X"` | `sem base_set_size: [["PRB9cd8", "X"]]` | ✅ |
| `base_set_size` vs. `count(art_kind='base')` diverge em **21 de 62** | `divergencia=21` | ✅ |
| `base_set_size` vs. `count(base,other)` diverge em **1 de 62** (ST16: 7 contra 6) | `divergencia=1 [["ST16", 7, 6]]` | ✅ |
| `FamilyDeckSet`: `base_set_size=49`, `count(base)=0`, `other=49` | `bss=49 base=0 other=49` | ✅ |
| `PRB01`: `base_set_size=113`, `count(base)=1` | `bss=113 base=1` | ✅ |
| 1643 variantes `parallel` no catálogo | `parallel total=1643` | ✅ |

E o comportamento do query object contra o catálogo **real**, não só contra o
cenário de teste:

```
linhas=63
PRB9cd8: owned=0 total=3 base_size=nil pct=nil known=false
ST16: base_size=7 total=14 par=8
soma parallel_variants=1643
sets sem parallel=12
indisponiveis=1
consultas da agregacao=1
```

**Uma consulta para os 63 sets**, exatamente um set com percentual indisponível,
e o `PRB9cd8` exibido com a posse real e `nil` no percentual. É a spec cumprida
no dado de produção, não apenas no cenário sintético.

---

## Task Completion

| Task | Status | Notas |
| ---- | ------ | ----- |
| T1 | ✅ Done | Agregação única com `GROUP BY sets.id`; condição de posse no `ON`, não no `WHERE` |
| T2 | ✅ Done | Denominador `base_set_size`; `nil` ≠ `0.0` preservado até o `Row`; teto por `min` |
| T3 | ✅ Done | Parallels em duas colunas `FILTER`, disjuntas do percentual; 1 sobrevivente **explicado** pelo schema |
| T4 | ✅ Done | Proteção por omissão, provada estruturalmente pelo par simétrico |
| T5 | ✅ Done | Três números distintos exibidos e discriminados; 1 sobrevivente **explicado** pelo parser |
| T6 | ✅ Done | Teste **segue** o `href` real; achado de `hidden` virou asserção nova |
| T7 | ✅ Done | Isolamento provado pela marcação, não por `view_assigns`; 13 testes, nenhum defeito achado |
| T8 | ✅ Done | PRG-11 medido pela diferença entre cenários; PRG-12 com `SPEC_DEVIATION` — ver L1 |

---

## Verificação ancorada no spec

### Critérios de aceitação da spec — História P1: Progresso de conclusão por set

| Critério (spec.md) | Resultado definido pelo spec | `file:line` + asserção | Result |
| ------------------ | ---------------------------- | ---------------------- | ------ |
| 1. Variantes distintas possuídas e total do set, por set | PRG-01 / Req. 9.1 | `set_progress_query_test.rb:174` — `assert_equal 2, a.owned_variants` + `:175` `assert_equal 5, a.total_variants`. Na página: `progress_ui_test.rb:110` — `assert_select ".progress-set__owned", text: "4"` e `:111` `.progress-set__total", text: "7"` | ✅ PASS |
| 2. Percentual calculado sobre as variantes base conforme AD-003 | PRG-02 / Req. 9.2 | `set_progress_query_test.rb:392` — `assert_equal 50.0, d.completion_percent` com `base_owned=2`/`base_size=4`; na página `progress_ui_test.rb:150` — `assert_select ".progress-set__percent", text: /60/` | ✅ PASS |
| 3. Uma variante com quantidade 5 conta exatamente 1 | PRG-04 / Req. 9.4 | `set_progress_query_test.rb:211-236` — as duas métricas **lado a lado**: `assert_equal 1, apenas_cinco.owned.count` e `assert_equal 5, apenas_cinco.owned.sum(:quantity)`; `:223` `assert_operator copias, :>, variantes` | ✅ PASS |
| 4. Quantidade zero é tratada como não possuída no numerador | PRG-07 / Req. 7.3 | `set_progress_query_test.rb:253` — `assert_equal 2, a.owned_variants` com `@v_zerada` presente; `:260` — quantidade zero dá resultado **idêntico** a não haver registro; `:270` — zerar **diminui** o numerador | ✅ PASS |
| 5. Denominador é `base_set_size`, nunca o total de impressões | PRG-05 / Req. 9.5 | `set_progress_query.rb:197` — `sets.base_set_size AS base_size`; `set_progress_query_test.rb:364` — `assert_equal 4, d.base_size` contra `:365` `assert_equal 6, d.total_variants` + `:366` `assert_not_equal` entre os dois | ✅ PASS |
| 6. Numerador conta o mesmo universo do denominador, excluindo `parallel` | PRG-02 / decisão do dono | `set_progress_query.rb:195-196` — `FILTER (WHERE card_variants.art_kind IN ('base','other'))`; `set_progress_query_test.rb:415` (conta `other`) e `:426` (exclui `parallel`: `assert_equal 0, e.base_owned_variants`) | ✅ PASS |
| 7. Set sem `base_set_size` é exibido, sem percentual, e nunca 0% nem 100% | PRG-10 | `set_progress_query_test.rb:455` — `assert_not_nil f` + `assert_equal 1, f.owned_variants` + `assert_nil f.completion_percent`; `:470` — os quatro `assert_not_equal` contra `0`, `0.0`, `100`, `100.0`; na página `progress_ui_test.rb:169` e `:192` | ✅ PASS |

**A distinção entre os três números parecidos é a decisão certa e está travada
por teste.** `owned_variants` (posse do set inteiro), `base_owned_variants`
(numerador do percentual) e `total_variants` (total de impressões) são três
valores que a view exibe juntos, e o cenário da T5 os faz **todos diferentes**
de propósito — 4, 3 e 7 para `@set_a` (`progress_ui_test.rb:44-52`). Confirmei
por mutação (V1 e V2 abaixo) que trocar um pelo outro derruba 8 e 7 testes
respectivamente. Era o ponto que eu mais esperava encontrar frouxo, e não está.

### Critérios de aceitação da spec — História P1: Parallels como métrica separada

| Critério (spec.md) | Resultado definido pelo spec | `file:line` + asserção | Result |
| ------------------ | ---------------------------- | ---------------------- | ------ |
| 1. Contagem de variantes `parallel` possuídas, por set | PRG-06 / Req. 9.6 | `set_progress_query.rb:198-199` — `COUNT(DISTINCT owned_items.card_variant_id) FILTER (WHERE art_kind = 'parallel')`; `set_progress_query_test.rb:552` — `assert_equal 1, e.parallel_owned_variants` | ✅ PASS |
| 2. Métrica separada, nunca somada ao numerador nem ao denominador | PRG-06 / AD-003 | Numerador: `set_progress_query_test.rb:426` — `assert_equal 0, e.base_owned_variants` com posse só de parallel. Denominador: `:588` — `assert_equal 2, e.base_size` com `parallel_variants=1` e `total_variants=2` | ✅ PASS |
| 3. Possuir parallels mantém o percentual do set inalterado | PRG-06 | `set_progress_query_test.rb:436` — `assert_equal antes, progress["OPp2d"].completion_percent` após acrescentar parallel; e o par `:602` — acrescentar uma base move **só** o percentual (0.0→50.0) com parallels intactos | ✅ PASS |
| 4. Set sem nenhuma variante `parallel` apresenta a métrica como zero, sem ocultá-la | PRG-06 | `progress_ui_test.rb:261` — `assert_select ".progress-set__parallel-owned", text: "0"` e `.progress-set__parallel-total", text: "0"` para `@set_b` | ✅ PASS |

**A separação é estrutural na marcação, não só textual.**
`progress_ui_test.rb:253` exige que `.progress-set__parallel-owned` **não**
exista dentro de `.progress-set__percent`, e `:256` exige que o texto do
percentual não carregue a contagem. Verifiquei no banco real: nenhuma contagem
de parallels cai dentro do elemento do percentual em nenhum dos 63 sets.

### Critérios de aceitação da spec — História P2: Navegação para o catálogo filtrado

| Critério (spec.md) | Resultado definido pelo spec | `file:line` + asserção | Result |
| ------------------ | ---------------------------- | ---------------------- | ------ |
| 1. Link por set para o catálogo filtrado | PRG-03 / Req. 9.3 | `index.html.erb:158` — `link_to catalog_path(sets: [ row.set_code ])`; `progress_ui_test.rb:324` — `assert_select "a.progress-set__catalog-link", 3` **e** o `href` presente em cada um dos 3 sets | ✅ PASS |
| 2. Parâmetro `sets` do contrato de `design.md` §4.2, com o **código** do set | PRG-03 | `progress_ui_test.rb:354` — `assert_equal catalog_path(sets: [ @set_a.code ]), href_do_catalogo(@set_a)` + `assert_no_match(/#{@set_a.id}/, ...)` — o id é proibido explicitamente | ✅ PASS |
| 3. Seguir o link apresenta só cartas daquele set | PRG-03 | `progress_ui_test.rb:364` — segue o `href` **extraído do HTML**, `assert_select ".catalog__chips .filter-chip__label", text: "Set: OPp5a"`; `:379` — carta do set **presente** (`count: 1`) e de outro set **ausente** (`count: 0`); `:395` — o par simétrico pelo `@set_b` | ✅ PASS |

**O teste segue o `href` real em vez de remontar a URL, e isso é o que o torna
uma prova.** `href_do_catalogo` (`progress_ui_test.rb:315`) lê de `css_select` e
nunca reconstrói. Montar `get catalog_path(sets: ["OPp5a"])` à mão passaria
intacto com a view emitindo o id, um nome de parâmetro errado ou nenhum
parâmetro — link quebrado e suíte verde. O teste simétrico de `:395` fecha o
flanco restante: sem ele, um link **sem filtro nenhum** passaria por acaso,
porque o catálogo completo também contém a carta do set A.

### Critérios de aceitação da spec — História P2: Isolamento e desempenho

| Critério (spec.md) | Resultado definido pelo spec | `file:line` + asserção | Result |
| ------------------ | ---------------------------- | ---------------------- | ------ |
| 1. Todo cálculo deriva do usuário da sessão | PRG-08 / Req. 6.5 | `progress_controller.rb:32` — `SetProgressQuery.new(Current.user)`; `progress_authorization_test.rb:146` — os dez valores exibidos comparados entre `@nami` e `@zoro`, nenhum coincidindo exceto os do catálogo | ✅ PASS |
| 2. Identificador informado na requisição é ignorado | PRG-08 | `progress_authorization_test.rb:265` (`?user_id=`), `:291` (**seis** formas: `user_id`, `user`, `id`, e-mail, lista, hash aninhado), `:316` (**cabeçalho** `X-User-Id`, a porta que `params` não cobre), `:280` (o `?user_id=` do **próprio** usuário, que impede "consertar" o teste anterior) | ✅ PASS |
| 3. Anônimo é redirecionado sem exibir dado de coleção | PRG-09 / Req. 6.4 | `progress_test.rb:83` — `assert_redirected_to new_session_path` **mais** `assert_no_match @set.code, response.body`: a asserção é sobre o **corpo**, não só o status | ✅ PASS |
| 4. Dois usuários no mesmo set veem cada um o seu | PRG-08 | `progress_authorization_test.rb:160-162` — `assert_equal({owned:"2", total:"9", percent:"17%", ...})` contra `{owned:"5", ..., percent:"50%", ...}`, lidos **da marcação**; `:177` — o total **não** varia; `:249` — trocar de sessão na mesma conexão troca o dono | ✅ PASS |
| 5. Número de consultas não cresce com a quantidade de sets | PRG-11 / Req. 11.1 | `set_progress_plan_test.rb:152` — `assert_equal pequeno.size, grande.size` entre 1 e 40 sets; `:175` — descontadas nominalmente `Session Load`/`User Load`, resta **exatamente 1**, contendo `GROUP BY` | ✅ PASS |
| 6. Viewport de 360px sem scroll horizontal | PRG-12 / Req. 2.5 | `set_progress_plan_test.rb:347`, `:376`, `:392`, `:414`, `:430` — cinco asserções sobre causas declaráveis, com `SPEC_DEVIATION` em `:322` | ⚠️ **PASS parcial** — ver L1 |

### Edge Cases da spec

| Edge Case | `file:line` + asserção | Result |
| --------- | ---------------------- | ------ |
| Usuário sem posse vê todos os sets com zero; página informativa, não vazia | `progress_ui_test.rb:272` — `assert_select ".progress-set", 3` + `owned="0"` + `total="7"` | ✅ PASS |
| Set sem `base_set_size` exibido com posse e percentual indisponível | `set_progress_query_test.rb:455`; `progress_ui_test.rb:169` | ✅ PASS |
| Denominador zero não executa divisão; mesmo caminho do ausente | `set_progress_query_test.rb:493` — `assert_equal f.completion_percent_known?, g.completion_percent_known?`; `:506` — `assert_nothing_raised` + `assert_not_equal Float::INFINITY` | ✅ PASS |
| Posse zerada diminui o numerador | `set_progress_query_test.rb:270` | ✅ PASS |
| Numerador excedente limitado a 100%, sem erro | `set_progress_query.rb:142` — `[ ..., 100.0 ].min`; `set_progress_query_test.rb:519` — numerador 3 contra denominador 1, `assert_equal 100.0` **e** `assert h.completion_percent_known?` (continua conhecido) | ✅ PASS |
| Variante conta no set da **impressão**, não no de estreia | `set_progress_query_test.rb:285` — `@carta_reimpressa` estreou em `@set_a`, variante impressa em `@set_b`; `assert_equal 2` nos dois sets, números que só batem com o eixo certo | ✅ PASS |
| Sessão expirada leva à autenticação e retorna depois | `progress_test.rb:134` — `assert_redirected_to progress_url` + `follow_redirect!` + `assert_response :success` | ✅ PASS |
| Ingestão entre visitas muda o denominador sem afetar posse | Não há teste próprio — é propriedade de Req. 1.7/AD-001, já coberta pela ingestão | ✅ PASS (fora do escopo desta feature) |
| Variante marcada como ausente da fonte continua contando | Não há teste próprio — a ingestão não deleta (Req. 1.7); o `LEFT JOIN` não filtra por marcação | ⚠️ Ver L2 |

### "Done when" das 8 tasks

#### T1 — `SetProgressQuery`: possuídas, total e contagem distinta

| Critério (Done when) | `file:line` + asserção | Result |
| -------------------- | ---------------------- | ------ |
| Recebe o **objeto** `User` (ou `nil`), nunca um id | `set_progress_query.rb:214` — `CollectionItem.for_user(@user)`; `set_progress_query_test.rb:344` — `assert_raises(ArgumentError)` + `assert_match(/for_user/, ...)` | ✅ PASS |
| Devolve possuídas distintas e total por set | `set_progress_query_test.rb:170` — `assert_equal 2, a.owned_variants` / `assert_equal 5, a.total_variants` | ✅ PASS |
| Quantidade 5 conta **1** no progresso e **5** em `total_copies_for`, no mesmo cenário | `set_progress_query_test.rb:211-236` — as duas métricas medidas lado a lado; `:229` `assert_equal 8, excedente` | ✅ PASS |
| `quantity = 0` não entra, e dá o mesmo que não haver registro | `set_progress_query_test.rb:253` e `:260` — `assert_equal com_zerada, progress["OPp1a"].owned_variants` | ✅ PASS |
| Agrega por `card_variants.set_id`, não `cards.set_id` | `set_progress_query.rb:205` — `LEFT JOIN card_variants ON card_variants.set_id = sets.id`; `set_progress_query_test.rb:285` e `:297` | ✅ PASS |
| `nil` devolve todos os sets com numerador zero, sem erro | `set_progress_query_test.rb:329` — `assert_includes` os três códigos + `assert_equal 0` no numerador + `assert_equal 5` no total | ✅ PASS |
| `SetProgressQuery.new(id)` levanta `ArgumentError` | `set_progress_query_test.rb:344`, `:351`, `:355` (id, id antes de `call`, string) | ✅ PASS |

#### T2 — Percentual com denominador `base_set_size`

| Critério (Done when) | `file:line` + asserção | Result |
| -------------------- | ---------------------- | ------ |
| Denominador é `sets.base_set_size`, nunca total nem contagem local | `set_progress_query.rb:197`; `set_progress_query_test.rb:361` e `:373` — `assert_not_equal base_locais, d.base_size` com `base_locais = 1` e `base_size = 4` | ✅ PASS |
| Numerador conta `base` + `other`, excluindo `parallel` | `set_progress_query.rb:195-196`; `set_progress_query_test.rb:415`, `:426` | ✅ PASS |
| Teste com set em que `base_set_size` diverge de `count(base)` | `set_progress_query_test.rb:373` — `@set_d` reproduz a divergência (`base_set_size=4`, 1 base, 3 other): o retrato de `PRB01` em escala de teste | ✅ PASS |
| Set sem `base_set_size` exibido, percentual indisponível, nem 0 nem 100 | `set_progress_query_test.rb:455` e `:470` | ✅ PASS |
| Denominador zero não divide e cai no mesmo caminho | `set_progress_query.rb:149` — `!base_size.nil? && base_size.positive?` (guarda **anterior** à divisão, não `rescue`); `set_progress_query_test.rb:493`, `:506` | ✅ PASS |
| Numerador maior que denominador limitado a 100%, sem erro | `set_progress_query.rb:142`; `set_progress_query_test.rb:519` | ✅ PASS |
| Comentário registra a decisão e a divergência medida | `set_progress_query.rb:53-84` — a tabela das duas divergências, os dois casos extremos e o Out of Scope | ✅ PASS |

**`base_size` chega ao `Row` sem `to_i`, e essa assimetria é o ponto.** Todas as
outras colunas levam `.to_i` (`set_progress_query.rb:163-170`); a linha `:168`
não, com comentário na própria linha explicando que ali `nil` e `0` são estados
**diferentes**. Confirmei por mutação (V4) que afrouxar o guarda derruba teste.

#### T3 — Parallels como métrica separada

| Critério (Done when) | `file:line` + asserção | Result |
| -------------------- | ---------------------- | ------ |
| Cada set traz parallels possuídos e total de parallels do set | `set_progress_query.rb:198-201`; `set_progress_query_test.rb:552` | ✅ PASS |
| Posse só de parallels mantém percentual zero e contagem refletindo a posse | `set_progress_query_test.rb:569` — `assert_equal 0.0, e.completion_percent` **e** `assert_equal 1, e.parallel_owned_variants` + `:584` `assert_not_equal` entre os dois | ✅ PASS |
| Acrescentar uma base altera **só** o percentual | `set_progress_query_test.rb:602` — 0.0→50.0 com `assert_equal antes.parallel_owned_variants, depois.parallel_owned_variants` | ✅ PASS |
| Set sem `parallel` apresenta a métrica como zero, sem ocultar | `progress_ui_test.rb:261` | ✅ PASS |
| Nenhuma consulta nova por set | Medido por mim contra o banco real: **1 consulta** para 63 sets | ✅ PASS |

#### T4 — `ProgressController` e rota, com sessão exigida

| Critério (Done when) | `file:line` + asserção | Result |
| -------------------- | ---------------------- | ------ |
| Não declara `allow_unauthenticated_access` | `progress_controller.rb:21` — a classe abre sem nenhuma declaração; `progress_test.rb:114` — o teste cobre **os dois nomes** (`allow_unauthenticated_access` e `skip_before_action`) | ✅ PASS |
| Monta a consulta de `Current.user`; nenhum id vem do request | `progress_controller.rb:32`; `progress_test.rb:192` — AST via `Ripper.sexp`, `refute_includes identificadores, "params"` | ✅ PASS |
| Anônimo redirecionado, sem 200 e sem dado no corpo | `progress_test.rb:83` — redirect **e** `assert_no_match` sobre o corpo | ✅ PASS |
| Após autenticar, retorna à página de progresso | `progress_test.rb:134` | ✅ PASS |
| `?user_id=` de outro usuário é ignorado | `progress_test.rb:160` — precedido de `assert_equal 2, linha_do_set(@zoro).owned_variants` para provar que o cenário discrimina | ✅ PASS |
| Teste estrutural prova `require_authentication` entre os callbacks | `progress_test.rb:95` — `assert_includes ProgressController._process_action_callbacks...` **e** `refute_includes CatalogController...` — o par simétrico | ✅ PASS |

**O par simétrico é o que dá valor à asserção.** Só o lado positivo passaria
também se o filtro estivesse instalado em tudo, inclusive no catálogo público —
e é exatamente essa hipótese que o `refute_includes` quebra. É a mesma forma de
`authentication_test.rb`, invertida.

#### T5 — View de progresso

| Critério (Done when) | `file:line` + asserção | Result |
| -------------------- | ---------------------- | ------ |
| Cada set exibe nome, possuídas, total e percentual | `progress_ui_test.rb:98` — nome + `owned="4"` + `total="7"`; `:142` — percentual | ✅ PASS |
| Parallels visivelmente separados do percentual | `progress_ui_test.rb:241` — `assert_select ".progress-set__percent .progress-set__parallel-owned", false` (separação **estrutural**) + `:256` (o texto do percentual não carrega a contagem) | ✅ PASS |
| Set sem denominador exibe posse e indisponível, nem 0% nem 100% | `progress_ui_test.rb:169` + `:192` (nem elemento vazio: `.progress-set__percent-value", false`) + `:206` (comparação lado a lado com o set de 0%, exigindo que **difiram**) | ✅ PASS |
| Entrada no cabeçalho, só para quem tem sessão | `application.html.erb:56` — dentro do `if authenticated?`; `progress_ui_test.rb:288` (presente) e `:298` (ausente para anônimo, **com a wishlist conferida junto** para provar que o cenário é anônimo de fato) | ✅ PASS |
| Teste de integração sobre HTML renderizado, com `SPEC_DEVIATION` | `progress_ui_test.rb:3-17` | ✅ PASS |
| Usuário autenticado sem posse vê todos os sets com zero | `progress_ui_test.rb:272` | ✅ PASS |

**`number_to_percentage(nil)` devolve string vazia, e há teste separado só para
isso** (`progress_ui_test.rb:192`). Sem o predicado, o elemento existiria sem
dizer nada e o set ficaria com "concluído" solto ao lado de um denominador
ausente. Separar esse teste do de `:169` é correto: asserção que falha aborta o
método, e os dois provam coisas diferentes.

#### T6 — Link para o catálogo filtrado

| Critério (Done when) | `file:line` + asserção | Result |
| -------------------- | ---------------------- | ------ |
| Cada set oferece link para o catálogo filtrado | `progress_ui_test.rb:324` | ✅ PASS |
| Usa `catalog_path(sets: [ code ])`, sem inventar parâmetro | `index.html.erb:158`; `progress_ui_test.rb:354` | ✅ PASS |
| Teste **segue** o link e confere 200 com filtro ativo | `progress_ui_test.rb:364` — o chip de filtro ativo é a prova de que o saneador aceitou o parâmetro | ✅ PASS |
| Conjunto devolvido corresponde ao set (uma presente, uma ausente) | `progress_ui_test.rb:379` e `:395` | ✅ PASS |
| Texto do link identifica o set para leitor de tela | `progress_ui_test.rb:411` — `aria-label` contém o nome do set e "catálogo"; `:427` — os nomes acessíveis são **distintos entre si** | ✅ PASS |

**O achado de `hidden` virou asserção, não justificativa** (`:339`). `css_select`
encontra elemento escondido, então "presente no DOM" não é "oferecido ao
usuário" — `hidden` o remove da tela **e** da árvore de acessibilidade. A
asserção cobre `[hidden]` no `<a>`, no contêiner, e `aria-hidden="true"`. É um
achado de a11y real, não artefato do sensor.

#### T7 — Isolamento entre usuários

| Critério (Done when) | `file:line` + asserção | Result |
| -------------------- | ---------------------- | ------ |
| Dois usuários no mesmo set veem números diferentes | `progress_authorization_test.rb:146` — os dois hashes de cinco valores | ✅ PASS |
| Posses de tamanhos distintos, para que a troca mude o número | `:160-162` + `:165-167` — três `assert_not_equal` que **falham antes** se alguém igualar o cenário | ✅ PASS |
| `?user_id=` do outro não altera o número | `:265` | ✅ PASS |
| A coleção de um não vaza para o total de parallels do outro | `:199` — em teste próprio, porque os parallels saem de coluna `FILTER` separada e um recorte perdido só ali deixaria o percentual correto | ✅ PASS |
| Usuário sem posse alguma não vê número de quem tem | `:232` — `@usopp` tem linha **zerada** sobre variante de `@zoro`: discrimina "posse por existência de registro" (daria 1) de "ignorar usuário" (daria 7) | ✅ PASS |

**A leitura é da marcação, não de `view_assigns`** (`numeros_exibidos`,
`:120`). A T4 já provou que `@rows` é do usuário da sessão; o que faltava era
provar que é esse número que chega aos olhos. Um vazamento **na view** não
apareceria em `view_assigns` — e minha mutação V5 confirma que essa camada é
necessária.

#### T8 — Número fixo de consultas e viewport de 360px

| Critério (Done when) | `file:line` + asserção | Result |
| -------------------- | ---------------------- | ------ |
| Conta consultas com **duas** quantidades de sets e prova que não varia | `set_progress_plan_test.rb:152` — 1 contra 40 sets, `assert_equal pequeno.size, grande.size` | ✅ PASS |
| Consultas de sessão descontadas ou asserção sobre a diferença | `:175` — **ambas**: a diferença (`:152`) e o desconto nominal de `Session Load`/`User Load` restando exatamente 1 com `GROUP BY` | ✅ PASS |
| Plano medido com volume realista e registrado no cabeçalho | `:41-70` — 200 sets, 12.000 variantes, 51 usuários, 20.400 itens; `EXPLAIN` transcrito; `:214` asserta o plano; `:224` **guarda o próprio seed** | ✅ PASS |
| Índice só entra se a medição reprovar | Nenhuma migração criada; `:308` — asserta que **não** existe índice parcial por `quantity`, registrando a decisão medida | ✅ PASS |
| Marcação sem largura fixa >360px nem `nowrap` em bloco largo, com `SPEC_DEVIATION` | `:347`, `:376`, `:392`, `:414`, `:430`, `:444`; `SPEC_DEVIATION` em `:322` | ⚠️ **PASS parcial** — ver L1 |
| `.context/tasks.md` §5.1 marcado | `.context/tasks.md:196` — `- [x] **5.1 Progresso por set**` | ✅ PASS |

**A asserção sobre a diferença é a escolha certa, e a auxiliar fecha o ponto
cego.** Travar `assert_equal 3` seria frágil pela razão errada. Mas a subtração
sozinha deixaria passar duas consultas de catálogo **constantes** — e é isso que
`:175` impede, nomeando o que desconta. As duas juntas cobrem o requisito.

**A troca de `reltuples` por `last_analyze` está correta e é um acerto real.**
`pg_class.reltuples` não é transacional e sobrevive ao rollback, então a
asserção passaria por resíduo de execução anterior. `last_analyze` comparado com
`clock_timestamp()` do início do teste prova que o `ANALYZE` rodou **nesta**
execução. O raciocínio procede — **mas a implementação dessa asserção tem um
defeito de concorrência que reproduzi**: ver L3.

### Os quatro bullets da §5.1 de `.context/tasks.md`

| Bullet | Evidência | Result |
| ------ | --------- | ------ |
| "Por set: variantes distintas possuídas, total de variantes, percentual" | `index.html.erb:95-112`; `progress_ui_test.rb:98`, `:142` | ✅ Entregue |
| "Contar variantes distintas, não cópias" | `set_progress_query.rb:193-194` (`COUNT(DISTINCT ...)`); `set_progress_query_test.rb:211` | ✅ Entregue |
| "Link para o catálogo já filtrado por aquele set" | `index.html.erb:158`; `progress_ui_test.rb:364`, `:379` | ✅ Entregue |
| "Denominador = `baseSetSize`; parallels como métrica separada (P3)" | `set_progress_query.rb:197`, `:198-201`; `set_progress_query_test.rb:361`, `:569` | ✅ Entregue |

A marcação da §5.1 na T8 é **legítima**: os quatro bullets estão entregues e
cobertos por teste. A §5.1 cobre T1–T8 e a T8 é de fato a que a fecha.

---

## Cobertura dos 12 requisitos `PRG-01..PRG-12`

| ID | Requisito | Evidência principal | Result |
| -- | --------- | ------------------- | ------ |
| PRG-01 | Possuídas e total por set (Req. 9.1) | `set_progress_query_test.rb:170`; `progress_ui_test.rb:98` (`owned="4"`, `total="7"`) | ✅ PASS |
| PRG-02 | Percentual de conclusão (Req. 9.2) | `set_progress_query_test.rb:386` (50.0), `:395` (66.67); `progress_ui_test.rb:142` (60%) | ✅ PASS |
| PRG-03 | Link para o catálogo filtrado (Req. 9.3) | `progress_ui_test.rb:364` (segue o href), `:379` (o conjunto corresponde) | ✅ PASS |
| PRG-04 | Variantes distintas, não cópias (Req. 9.4) | `set_progress_query_test.rb:211` (as duas métricas lado a lado); `:239` (aumentar quantidade não move o progresso) | ✅ PASS |
| PRG-05 | Denominador = `base_set_size` (Req. 9.5, AD-003) | `set_progress_query.rb:197`; `set_progress_query_test.rb:361`, `:373` | ✅ PASS |
| PRG-06 | Parallels como métrica separada (Req. 9.6, AD-003) | `set_progress_query.rb:198-201`; `set_progress_query_test.rb:569`, `:588`, `:602` | ✅ PASS |
| PRG-07 | Quantidade zero não é posse (Req. 7.3) | `set_progress_query_test.rb:253`, `:260`, `:270`; `progress_authorization_test.rb:232` (`@usopp` com linha zerada) | ✅ PASS |
| PRG-08 | Progresso parte do usuário da sessão (Req. 6.5) | `progress_authorization_test.rb:146`, `:291`, `:316`, `:331`, `:350`, `:373` — comportamento **e** três provas estruturais | ✅ PASS |
| PRG-09 | Página exige sessão (Req. 6.4) | `progress_test.rb:83` (corpo sem dado), `:95` (par simétrico de callbacks), `:114` (os dois nomes de declaração pública) | ✅ PASS |
| PRG-10 | Percentual indisponível sem denominador | `set_progress_query.rb:139-150`; `set_progress_query_test.rb:455`, `:470`, `:479`; `progress_ui_test.rb:169`, `:192`, `:206` | ✅ PASS |
| PRG-11 | Consultas não crescem com a quantidade de sets (Req. 11.1) | `set_progress_plan_test.rb:152`, `:175`, `:197`; medido por mim: **1 consulta para 63 sets** | ✅ PASS |
| PRG-12 | Viewport de 360px sem scroll horizontal (Req. 2.5) | `set_progress_plan_test.rb:347`, `:376`, `:392`, `:414`, `:430`, `:444` | ⚠️ **PASS parcial** — L1 |

**12 requisitos, 12 cobertos, 0 órfãos.** PRG-12 passa com lacuna registrada.

---

## Sensor de discriminação — mutações que eu desenhei

Mutações **minhas**, não reaproveitadas dos autores. Escolhi mirando o que julguei
mais frágil: a confusão entre os três números parecidos, a fronteira
`nil`/`0.0`, o teto de 100%, a autorização passando **por baixo** da barreira de
tipo, e a asserção de 360px — que é onde um `SPEC_DEVIATION` costuma esconder
cobertura menor do que aparenta.

Rodadas sobre **cópia** dos arquivos (`cp`/`diff`), **nunca `git stash`**.
Árvore restaurada e conferida idêntica por `diff` nos cinco arquivos ao final;
`git status --porcelain` vazio.

| # | Mutação | Testes mortos | Conclusão |
| - | ------- | ------------- | --------- |
| V1 | `owned_variants` → `base_owned_variants` na linha de possuídas da view (`index.html.erb:96`) | **8** | A troca "invisível numa leitura rápida" entre os três números **está travada**. O cenário com 4/3/7 distintos é o que a pega. |
| V2 | `total_variants` → `base_size` na mesma linha (`index.html.erb:98`) | **7** | A segunda troca possível entre os três números também morre. Os dois números diferem no cenário de propósito (7 contra 5). |
| V3 | Teto de 100% removido (`[ pct, 100.0 ].min` → `pct`) | **1** | Coberto, pelo teste dedicado de numerador excedente (`:519`). Uma falha só, mas é a asserção desenhada exatamente para isso. |
| V4 | Guarda afrouxado: `!base_size.nil? && base_size.positive?` → `!base_size.nil?` (denominador zero passa a dividir) | **2** | A fronteira entre "ausente", "zero" e "conhecido" **está coberta nos três estados**, não só em dois. |
| V5 | Usuário vindo de `params[:user_id]` como **objeto `User` real** (`User.find_by`), de modo que a barreira de tipo de `for_user` **não dispara** | **4** | O caminho que contorna a barreira de tipo **é pego assim mesmo** — pelos testes de comportamento **e** pela prova estrutural de AST. A autorização não depende de uma única linha de defesa. |
| V6a | `min-width: 40rem` em `.progress-set` (= 640px, quase o dobro do viewport) | **0** — **SOBREVIVEU** | **Lacuna real (L1).** Confirmado contra a suíte **inteira**: 501 runs, 0 failures. |
| V6b | O mesmo defeito escrito em `px` (`min-width: 640px`) — controle | **1** | Confirma que a asserção funciona **na unidade que ela conhece**. O buraco é a unidade, não a propriedade. |
| V6c | `min-width: 50em` em `.progress` | **0** — **SOBREVIVEU** | Mesma lacuna, segunda unidade. Generaliza L1 para `em`. |

**V5 é o resultado que mais me interessava e o mais tranquilizador.** A
justificativa da feature apoia-se fortemente em "`for_user` levanta
`ArgumentError` para um id, logo Req. 6.5 vale por construção". Isso é
verdadeiro, mas só cobre o caminho em que alguém passa um **id**. Desenhei a
mutação para passar um `User` **de verdade** vindo do request — o caminho que a
barreira de tipo não vê. Ela morre em 4 testes assim mesmo, incluindo o
estrutural de AST (`progress_test.rb:192`), que pega a leitura de `params`
independentemente do que se faça com ela. A defesa é em camadas, não numa só.

**Sobre os dois sobreviventes que os autores registraram**, conferi que a
explicação estrutural procede e **não** é advocacia da implementação:

- **`COUNT(DISTINCT)` sem `DISTINCT` (T3)**: a subconsulta de posse seleciona
  `card_variant_id` de `collection_items`, onde `UNIQUE (user_id, card_variant_id)`
  garante uma linha por variante. `COUNT` e `COUNT(DISTINCT)` coincidem por
  construção do schema. Um teste que falhasse exigiria violar a constraint.
  **Explicação correta**; o `DISTINCT` é defesa contra mudança futura na forma
  do join, e registrá-lo em vez de escrever teste impossível é a conduta certa.
- **`<p>` de parallels dentro do `<p>` do percentual (T5)**: o parser HTML fecha
  o `<p>` aberto ao encontrar o seguinte; os dois viram irmãos no DOM de
  qualquer forma. Nenhum teste sobre o DOM os distinguiria. A asserção existente
  pega a forma que o parser **preserva** (aninhar num `<span>`). **Explicação
  correta** — e usar `<p>` por métrica é o que torna o erro impossível em vez de
  detectável, que é melhor que cobri-lo.

---

## `SPEC_DEVIATION` — julgamento

Cinco `SPEC_DEVIATION` na feature, todos pela **mesma** causa raiz: não há
navegador no container (`CLAUDE.md`), logo não há system test.

| # | Onde | Veredito |
| - | ---- | -------- |
| 1 | `progress_test.rb:11` (T4) | ✅ Justificado. Nenhum critério da T4 depende de layout — só de qual número chega ao corpo e de quem é redirecionado. |
| 2 | `progress_ui_test.rb:3` (T5) | ✅ Justificado, e **exemplar por declarar o que fica de fora**: cobre quais números chegam ao corpo e sob quais rótulos; não cobre renderização visual. |
| 3 | `progress_ui_test.rb:441` (a11y) | ✅ Justificado, com limite escrito no próprio teste: um `outline: none` posterior em seletor de maior especificidade passaria. O que travam é que a declaração existe e que o link **não ficou fora do agrupamento** — que é o defeito que a revisão encontrou. |
| 4 | `progress_authorization_test.rb:4` (T7) | ✅ Justificado. A leitura da marcação é a maior fidelidade disponível e é **mais forte** que `view_assigns` para o que a task prova. |
| 5 | `set_progress_plan_test.rb:322` (T8, PRG-12) | ⚠️ **Honesto, mas a cobertura não é a melhor possível sem navegador** — ver L1. |

### O `SPEC_DEVIATION` de PRG-12 é honesto, e ainda assim incompleto

**A honestidade é real.** O texto de `set_progress_plan_test.rb:322-345` declara
com precisão o que as asserções garantem ("as causas **declaráveis** não foram
introduzidas") e nomeia três formas de estourar 360px que elas **não** pegam:
tabela de muitas colunas, imagem sem `max-width`, palavra inquebrável. Isso é o
oposto de esconder lacuna, e a asserção que guarda o próprio alvo (`:444` — o
bloco `progress-*` foi de fato encontrado) é a precaução certa contra as três
asserções varrerem o vazio.

**O que faz a cobertura não ser a melhor possível** é que a lista de causas
declaráveis **está incompleta por uma razão que não é a ausência de navegador**:
a regex `LARGURA_EM_PIXEL` (`:341`) casa apenas `px`. Uma largura fixa em `rem`
ou `em` — igualmente estática, igualmente legível na folha, igualmente
declarável — escapa. Isso é corrigível **sem navegador**, com a ferramenta que o
teste já usa, e por isso não cai sob o guarda-chuva do `SPEC_DEVIATION`: o
desvio justifica não medir `scrollWidth`, não justifica ler só uma das unidades
em que a causa declarável se escreve.

---

## Lacunas e achados

### L1 — Largura fixa em `rem`/`em` escapa às asserções de 360px (MEDIUM, não bloqueante)

**Onde**: `test/queries/set_progress_plan_test.rb:341` — a constante
`LARGURA_EM_PIXEL = /\b(?:width|min-width|flex-basis)\s*:\s*(\d+(?:\.\d+)?)px/i`.

**O defeito**: a asserção de PRG-12 mede só `px`. Mutei `.progress-set` para
`min-width: 40rem` (640px no tamanho de fonte raiz padrão — quase o dobro do
viewport exigido) e **a suíte inteira passou**: 501 runs, 1819 assertions, 0
failures. O mesmo defeito escrito `min-width: 640px` morre (V6b, 1 falha), e em
`50em` também sobrevive (V6c). A propriedade está coberta; a **unidade** não.

**Por que importa**: a folha do projeto usa `rem` como unidade padrão em quase
tudo (`font-size: 0.875rem`, `padding: 0.375rem`, `gap: 0.25rem`). Quem
introduzir uma largura fixa nesta página escreverá `rem` por convenção do
próprio arquivo — ou seja, a unidade que escapa é justamente a **mais provável**,
e a que morre é a menos idiomática ali.

**Por que não é bloqueante**: nenhuma largura fixa existe hoje. `.progress-set`
declara `min-width: 0` (`catalog.css:585`) e `.progress-set__name` declara
`overflow-wrap: anywhere` (`:594`), que são o oposto do defeito. A página **está
correta**; o que falta é a rede que impediria a regressão. É lacuna de
cobertura, não defeito de produto.

**Remédio sugerido** (decisão do orquestrador): estender a regex para
`(px|rem|em)` com conversão por `16` nas duas últimas, ou — mais simples e sem
suposição sobre o tamanho de fonte raiz — proibir largura fixa **de qualquer
unidade** no bloco `progress-*`, já que a decisão de design da T5 é justamente
que nada ali tem largura fixa.

### L2 — Dois Edge Cases da spec não têm teste próprio (LOW, não bloqueante)

**Onde**: `spec.md`, Edge Cases — "ingestão rodando entre duas visitas muda o
denominador" e "variante marcada como ausente da fonte continua contando".

Nenhum dos dois tem teste nesta feature. Ambos são propriedades **do subsistema
de ingestão** (Req. 1.7, AD-001: a ingestão não deleta), já cobertas lá, e o
progresso as herda por construção — o `LEFT JOIN` não filtra por marcação de
ausência, então uma variante marcada continua contando sem que nada precise ser
escrito. Registro por completude: a spec os lista como Edge Case desta feature e
a rastreabilidade não os aponta para teste algum. **Não bloqueante**: são
consequências de decisões já testadas noutro subsistema, e testá-las aqui
duplicaria a cobertura da ingestão.

### L3 — O teste de `last_analyze` é instável sob execução paralela (MEDIUM, não bloqueante, defeito de teste)

**Onde**: `test/queries/set_progress_plan_test.rb:265` — teste "o seed atualiza
as estatísticas do planejador nesta execução", asserção da linha `:279`.

**Reproduzido por mim**, em 2 de 12 execuções completas da suíte:

```
Failure:
SetProgressPlanTest#test_o_seed_atualiza_as_estatísticas_do_planejador_nesta_execução
[test/queries/set_progress_plan_test.rb:279]:
o `ANALYZE` de `sets` é anterior a este teste
(2026-09-20 16:13:28 +0000 < 2026-09-20 16:13:38 +0000)
Expected 2026-09-20 16:13:28.938448 +0000 to be > 2026-09-20 16:13:38.042292 +0000.
```

**Mecanismo**: `pg_stat_user_tables` não é transacional e não acompanha o
rollback do teste, e o coletor de estatísticas do Postgres atualiza `last_analyze`
de forma **assíncrona**. A suíte roda com `parallelize(workers: :number_of_processors)`
(`test_helper.rb:8`) e **três** testes deste arquivo chamam `semear_volume_realista`,
cada um executando `ANALYZE` nas mesmas cinco tabelas (`:570`). O teste lê
`clock_timestamp()` no início (`:266`) e compara com um `last_analyze` que pode
ter sido gravado por um `ANALYZE` anterior cujo registro o coletor ainda não
atualizou — daí a diferença de ~10s observada.

**Isolado o arquivo, não reproduz**: 14 runs verdes em 6 seeds diferentes, e 10
execuções verdes do subconjunto de 4 arquivos da feature. Só aparece sob a
contenção da suíte completa, o que é coerente com o mecanismo.

**Por que não é bloqueante**: é defeito **do teste**, não do código de produção.
A asserção que ele guarda continua valendo — o `ANALYZE` de fato roda no seed
(`:570`), e o plano medido é o do cenário. O raciocínio que levou de `reltuples`
a `last_analyze` está **certo** e resolveu um problema real (verde por resíduo);
o que ficou é que `last_analyze` troca aquele modo de falha por um de
concorrência.

**Por que registro mesmo assim**: um teste que falha ~17% das vezes é o tipo de
coisa que se aprende a reexecutar até passar, e então ele deixa de proteger
qualquer coisa. Vale corrigir antes que vire hábito. **Remédio sugerido**
(decisão do orquestrador): comparar `last_analyze` com o instante **imediatamente
anterior à chamada de `ANALYZE`** em vez de com o início do teste, ou tolerar a
latência do coletor com uma reconsulta curta — sem afrouxar a asserção, que é
boa.

---

## Conformidade com a decisão do dono do produto

Verificação direta do que me foi pedido para conferir, sem reabrir a decisão:

| Item da decisão | Código | Confere |
| --------------- | ------ | ------- |
| Denominador = `sets.base_set_size` | `set_progress_query.rb:197` — `sets.base_set_size AS base_size`, coluna direta sem agregação nem contagem local | ✅ |
| Numerador = possuídas com `art_kind IN ('base','other')` | `set_progress_query.rb:195-196` — `COUNT(DISTINCT owned_items.card_variant_id) FILTER (WHERE card_variants.art_kind IN ('base', 'other'))` | ✅ |
| Parallels = métrica separada, exclusivamente `art_kind = 'parallel'` | `set_progress_query.rb:198-201` — duas colunas, ambas com `FILTER (WHERE card_variants.art_kind = 'parallel')`, e mais nada | ✅ |
| `other` **não** entra na métrica de parallels | O filtro é igualdade com `'parallel'`; `other` aparece só no numerador do percentual | ✅ |
| Classificação de `art_kind` na ingestão **não** foi tocada | `git diff --stat 59c6db0..87af059` não lista nenhum arquivo de ingestão nem migração | ✅ |

**O código faz exatamente o que a decisão determina.** Nenhuma divergência.

---

## Conclusão

**Veredito: PASS.**

Os 12 requisitos `PRG-01..PRG-12` estão cobertos, os "Done when" das 8 tasks
estão cumpridos com evidência localizável, e os critérios de aceitação das quatro
histórias da spec têm asserção concreta apontando para arquivo e linha. Todas as
afirmações quantitativas da spec sobre o banco foram re-medidas por mim de forma
independente e **todas se confirmaram**. O código está em conformidade literal
com a decisão do dono do produto sobre o Req. 9.5.

A qualidade dos testes é alta e a razão é estrutural: os cenários são montados
para **discriminar**, com todos os números distintos entre si, e as asserções
frágeis por natureza (número absoluto de consultas, nome de índice) foram
deliberadamente substituídas por asserções sobre diferenças e sobre propriedades.
As duas mutações que eu mais esperava que sobrevivessem — a troca entre os três
números parecidos e a autorização contornando a barreira de tipo — morreram em 8,
7 e 4 testes.

**Lacunas, por severidade:**

1. **L1 (MEDIUM)** — largura fixa em `rem`/`em` escapa às asserções de PRG-12.
   Confirmada por mutação sobrevivente contra a suíte inteira. Corrigível sem
   navegador. Não bloqueante: não há largura fixa hoje.
2. **L3 (MEDIUM)** — o teste de `last_analyze` falha ~17% das vezes sob execução
   paralela. Defeito de teste, não de produção. Não bloqueante.
3. **L2 (LOW)** — dois Edge Cases sem teste próprio, ambos herdados da ingestão
   por construção. Não bloqueante.

**Nenhuma das três bloqueia o encerramento da feature.** As três são registradas
aqui para decisão do orquestrador; nenhuma correção foi aplicada por mim.
