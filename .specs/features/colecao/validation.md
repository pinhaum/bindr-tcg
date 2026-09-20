# Coleção — Validação

Este arquivo reserva espaço para os dois lotes da feature `colecao`: **B1**
(T1–T8, Fases 1 e 2) primeiro, **B2** (T9–T13, Fase 3) depois.

---

# Lote B1 — Fase 1 (T1–T4) + Fase 2 (T5–T8)

**Date**: 2026-09-20
**Spec**: `.specs/features/colecao/spec.md`; fonte de verdade
`.context/requirements.md` Req. 5, 6 e 7 (AD-005)
**Diff range**: `e7ffd9a..5e7eee6` — `e7ffd9a`, `a848526`, `231cb49`, `24d1265`,
`f392170` (T1–T4) + `3615e0a` (T5), `e359a21` (T6), `1e4a8d5` (T7), `5e7eee6` (T8)
**Verifier**: subagente independente (autor ≠ verificador)
**Veredito**: ✅ **PASS**, com 2 lacunas de cobertura registradas (nenhuma
bloqueante)

---

## Nota sobre o escopo

1. **A Fase 1 (T1–T4) nunca havia sido verificada** — fechou em sessão anterior
   sem Verifier. Ela entra aqui integralmente.
2. A notação `A..B` excluiria `e7ffd9a` (T1). Os critérios da T1 foram
   verificados contra o **estado atual** de `app/models/user.rb` e
   `test/models/user_password_test.rb`, não contra o diff — o que é o correto,
   já que a T4 alterou o model da T1 (acrescentou `validates :email, uniqueness`
   e o piso de senha).
3. Tasks posteriores ao lote (T9–T13) tocaram arquivos do lote: a T9 e a T11
   acrescentaram `authenticated?` e `owned_total` ao `CatalogController`, e a
   T13 acrescentou `wishlist_targets`. **A verificação é contra o estado atual
   do código**, e as mutações abaixo foram rodadas contra o `HEAD` (`4b0671b`).

### Estado medido por mim

| Medição | Resultado |
| ------- | --------- |
| `docker compose exec app bin/rails test` | **395 runs, 1251 assertions, 0 failures, 0 errors, 0 skips** |
| `docker compose exec app bin/rubocop` | **81 files inspected, no offenses detected** |
| Árvore de trabalho após as mutações | limpa (`git diff --stat` vazio; só os dois `untitled*.md` não rastreados, pré-existentes) |

---

## Task Completion

| Task | Status | Notas |
| ---- | ------ | ----- |
| T1 | ✅ Done | bcrypt, `has_secure_password`, unicidade de e-mail no banco |
| T2 | ✅ Done | Assimetria `cascade`/`restrict` provada nos dois níveis |
| T3 | ✅ Done | Sonda anônima justificada; default invertido provado estruturalmente |
| T4 | ✅ Done | `rate_limit` omitido com justificativa; piso de senha compensa em parte |
| T5 | ✅ Done | Três garantias provadas por SQL direto |
| T6 | ✅ Done | Statements atômicos; piso de zero no `WHERE` |
| T7 | ✅ Done | 1 `SPEC_DEVIATION` — **justificado e migrado de fato** para a T13 |
| T8 | ✅ Done | 1 `SPEC_DEVIATION` — ausência de navegador; 1 lacuna não bloqueante |

---

## Verificação ancorada no spec

### T1 — bcrypt e senha no `User`

| Critério (Done when) | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------------------- | ---------------------------- | ---------------------- | ------ |
| `gem "bcrypt", "~> 3.1.7"` no Gemfile e no lock | Infra da T1 | `Gemfile` + `Gemfile.lock`; consumida pelo teste seguinte, que chama `BCrypt::Password.valid_hash?` | ✅ PASS |
| `User` responde a `authenticate` e `password=` | COL-02 | `test/models/user_password_test.rb:55` — `assert user.authenticate("senha-correta")` + `assert_not user.authenticate("senha-errada")` | ✅ PASS |
| `has_many :collection_items, dependent: :restrict_with_exception` continua | Req. 1.7 | `app/models/user.rb:17`; provado em `test/models/user_password_test.rb:151` — `assert_raises(ActiveRecord::DeleteRestrictionError)` + `assert User.exists?` | ✅ PASS |
| Senha grava digest e nenhuma coluna guarda em claro | Req. 6.2 / COL-02 | `test/models/user_password_test.rb:37` — `BCrypt::Password.valid_hash?`; `:45` varre **a linha inteira** do banco com `row.each_value` | ✅ PASS |
| `authenticate_by` devolve o usuário / `nil` | COL-01 | `test/models/user_password_test.rb:64`, `:70`, `:74` — os três casos (senha certa, senha errada, e-mail inexistente) | ✅ PASS |
| E-mail único sem distinção de caixa, **pelo índice do banco** | Req. 6.1 | `test/models/user_password_test.rb:84` — `INSERT` direto em `uncached`, `assert_raises(ActiveRecord::RecordNotUnique)`; índice confirmado por mim em `db/structure.sql:658` (`CREATE UNIQUE INDEX index_users_on_lower_email ... (lower(email))`) | ✅ PASS |

**O teste é honesto sobre a camada.** `insert_user`
(`test/models/user_password_test.rb:15`) força `connection.uncached`, senão o
cache de consulta devolveria o `INSERT` memoizado e a violação nunca chegaria ao
banco — o mesmo cuidado de `catalog_schema_test.rb`. E o teste de duplicata em
outra caixa (`:118`) usa `save(validate: false)` **de propósito**, contornando a
validação que a T4 acrescentou: se um dia alguém remover o índice confiando na
validação, este teste cai. Afrouxá-lo teria sido o caminho fácil e errado.

### T2 — tabela e model `Session`

| Critério (Done when) | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------------------- | ---------------------------- | ---------------------- | ------ |
| Migração criada e `structure.sql` regenerado | COL-01 | `db/migrate/20260919120300_*`; `db/structure.sql` contém `sessions` com FK `ON DELETE CASCADE` | ✅ PASS |
| `Session belongs_to :user` | COL-01 | `app/models/session.rb:6`; `test/models/session_test.rb:30` — `assert_equal user, session.reload.user` | ✅ PASS |
| `User has_many :sessions, dependent: :destroy` | COL-01 | `app/models/user.rb:30`; `test/models/session_test.rb:39` — `assert_difference -> { Session.count }, -2` | ✅ PASS |
| Apagar usuário apaga sessões e **não** apaga `collection_items` | Req. 1.7 | `test/models/session_test.rb:52` — `assert_raises(DeleteRestrictionError)` seguido de `assert_equal 1, user.sessions.count` e `assert_equal 3, user.collection_items.sole.quantity` | ✅ PASS |
| `structure.sql` não perdeu trigram nem `immutable_unaccent` | Regressão do `catalogo` | Coberto pela suíte de `catalog_indexes_test.rb`, que continua verde nas 395 | ✅ PASS |

**A asserção da recusa é total, não parcial.** `session_test.rb:56-58` não se
contenta com o `raise`: verifica que o usuário **e** a sessão **e** o item
continuam lá. Um `destroy` abortado no meio, que já tivesse apagado as sessões,
passaria num teste que só asserisse a exceção. Além disso, os testes `:63` e
`:76` provam as duas FKs **no banco**, por `DELETE` direto — a assimetria
`cascade`/`restrict` não depende do Active Record.

### T3 — concern `Authentication` com `Current`

| Critério (Done when) | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------------------- | ---------------------------- | ---------------------- | ------ |
| `require_authentication` é `before_action` default | Req. 6.4 / COL-04 | `app/controllers/concerns/authentication.rb:18` + `application_controller.rb:8`; provado em `test/integration/authentication_test.rb:108` — `assert_includes ApplicationController._process_action_callbacks.map(&:filter), :require_authentication` | ✅ PASS |
| `CatalogController` declara `allow_unauthenticated_access`; catálogo, detalhe e busca respondem 200 sem sessão | Req. 6.3 / COL-03 | `catalog_controller.rb:12`; `test/integration/authentication_test.rb:87-97` — 200 em `/catalog`, `/cards/:id`, `?q=Zoro` e `/` | ✅ PASS |
| Sessão resolvida por cookie assinado, **nunca** por id do request | Req. 6.5 | `authentication.rb:45` — `cookies.signed[:session_id]`. Três testes provam a negativa: `:151` (id em `params` ignorado), `:159` (cookie **não** assinado ignorado), `:168` (cookie assinado apontando para sessão destruída não autentica) | ✅ PASS |
| Testes de catálogo existentes continuam passando sem sessão | Regressão | `git diff --stat e7ffd9a~1..5e7eee6 -- test/integration/catalog_grid_test.rb test/integration/card_detail_test.rb test/queries/` retorna **vazio**: nenhuma asserção do catálogo foi tocada no lote inteiro | ✅ PASS |
| Action protegida redireciona anônimo e retorna à origem | Req. 6.4 | `test/integration/authentication_test.rb:122` — `assert_redirected_to new_session_path`; `:132` — `assert_equal protected_probe_url, session[:return_to_after_authenticating]`; `:137` — 200 após `sign_in` | ✅ PASS |

**A asserção estrutural de `authentication_test.rb:107` é o que dá valor ao
resto.** Um 200 no catálogo, sozinho, passaria igualmente se o concern **nunca
tivesse sido incluído** — o teste não distinguiria "pula um filtro que existe"
de "não há filtro nenhum". O par
`assert_includes(ApplicationController...)` / `refute_includes(CatalogController...)`
separa os dois casos. É exatamente o tipo de asserção que costuma faltar.

**A sonda anônima é legítima.** Quando a T3 rodou, não existia nenhuma action
protegida de produção (`SessionsController` é T4, `CollectionItemsController` é
T6). O controller anônimo de `authentication_test.rb:22` é protegido **por
omissão**, que é precisamente o comportamento que a task entrega, e `sign_in`
(`:76`) passa pelo `start_new_session_for` real para que o cookie seja assinado
pelo middleware — o teste não reproduz o salt do Action Dispatch. Padrão correto.

### T4 — `SessionsController` e cadastro

| Critério (Done when) | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------------------- | ---------------------------- | ---------------------- | ------ |
| Rotas `resource :session` e cadastro; layout com entrar/sair | Req. 6.1 / COL-01 | `config/routes.rb` (`resource :session`, `resource :registration`); `test/integration/sessions_test.rb:206` — cabeçalho mostra entrar+criar conta para anônimo e `form[action=session_path]` para autenticado | ✅ PASS |
| `User.authenticate_by(email:)` — sem `email_address` | Decisão de colisão com o gerador | `sessions_controller.rb:33` — `User.authenticate_by(params.permit(:email, :password))` | ✅ PASS |
| Credencial errada reapresenta o formulário, em português, **sem revelar se o e-mail existe** | Req. 6.6 | `sessions_controller.rb:42` — `"E-mail ou senha inválidos."`; `test/integration/sessions_test.rb:89` compara **o corpo inteiro** das duas respostas, neutralizando só o e-mail reapresentado | ✅ PASS |
| `rate_limit` decidido explicitamente e registrado em comentário | Critério de decisão | `app/controllers/sessions_controller.rb:10-21` — justificativa com `file:line` das duas configs (`test.rb:23` `:null_store`, `production.rb:50` comentado) | ✅ PASS |
| Teste de integração cobre criar conta, sair, autenticar e acessar página protegida | Req. 6.1 | `test/integration/sessions_test.rb:34` — o ciclo **inteiro** numa sequência: cadastra, alcança a sonda, `assert_difference Session.count, -1` no logout, verifica que a sonda voltou a redirecionar, entra de novo e alcança | ✅ PASS |

**A comparação de corpo inteiro (`sessions_test.rb:91`) é a asserção certa para
o Req. 6.6.** Um teste que só verificasse a string da mensagem deixaria passar
qualquer diferença estrutural — uma classe CSS a mais, um campo preenchido de
forma diferente — que transformaria o formulário em oráculo de quais e-mails têm
conta. Comparar `neutraliza.call(existente) == neutraliza.call(inexistente)`
fecha a porta.

**O `rate_limit` omitido não é escopo abandonado.** A justificativa é verificável
e eu a confiro: em teste o store é `:null_store` (um teste do limite passaria sem
exercitar nada) e em produção o default é `:file_store` por container. A decisão
foi **compensada na metade que não depende de infraestrutura**: `validates
:password, length: { minimum: 8 }` (`user.rb:62`), com teste próprio de senha
curta (`sessions_test.rb:172`) **separado** do de senha em branco (`:183`) —
distinção correta, já que só o segundo provaria piso nenhum. Fica como dívida
registrada, não como lacuna silenciosa.

### T5 — model `CollectionItem`

| Critério (Done when) | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------------------- | ---------------------------- | ---------------------- | ------ |
| `UNIQUE (user_id, card_variant_id)` é **do banco**, por SQL direto | Req. 7.8 / COL-13 | `test/models/collection_item_test.rb:54` — `assert_raises(ActiveRecord::RecordNotUnique)` + `assert_match(/index_collection_items_on_user_id_and_card_variant_id/)`. Confirmado por mim em `db/structure.sql:637` | ✅ PASS |
| `CHECK (quantity >= 0)` é **do banco**, por SQL direto | Req. 7.4 / COL-09 | `test/models/collection_item_test.rb:84` (INSERT) **e** `:95` (UPDATE direto), ambos `assert_match(/collection_items_quantity_check/)`. Confirmado em `db/structure.sql:163` | ✅ PASS |
| FK recusa apagar variante possuída | Req. 1.7 | `test/models/collection_item_test.rb:113` — `assert_raises(ActiveRecord::InvalidForeignKey)` + `assert_match(/collection_items/, error.message)` | ✅ PASS |
| Quantidade zero é representável e tratada como não possuída | Req. 7.3 / COL-08 | `test/models/collection_item_test.rb:144` — `assert_equal 0` + `assert CollectionItem.exists?`; `:163` — `owned` traz só a de 3 e `unowned` só a de 0 | ✅ PASS |

**O `CHECK` provado duas vezes é o detalhe que importa.** Só o `INSERT` não
distinguiria a constraint da validação do model; o caso que interessa é o
`UPDATE ... SET quantity = quantity - 1` (`:97`), que é exatamente a forma que o
decremento da T6 tomou e que passa por fora de toda validação do Active Record.

**`for_user` exigindo o objeto `User` é a construção que satisfaz o Req. 6.5, e
tem teste.** `collection_item_test.rb:195` — `assert_raises(ArgumentError)` para
`user.id` **e** para `user.id.to_s`. É o que torna
`CollectionItem.for_user(params[:user_id])` impossível de passar despercebido.
O `nil` do anônimo devolve relação vazia (`:186`), não erro — necessário para o
catálogo público.

**O teste de dois usuários (`:63`) asserta coexistência, não ausência de
exceção.** `assert_equal [1, 2], ...pluck(:quantity)` — um `INSERT` que
sobrescrevesse a linha anterior também deixaria de levantar, e um
`assert insert_item(...)` sozinho passaria. Correção de revisão bem aplicada.

### T6 — incremento e decremento por variante

| Critério (Done when) | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------------------- | ---------------------------- | ---------------------- | ------ |
| Uma requisição por operação, sem formulário intermediário | Req. 7.2 / COL-07 | `config/routes.rb` — `POST .../increment` e `.../decrement`, sem `new` nem `edit`; `test/integration/collection_items_test.rb:41` — um `post` cria o registro | ✅ PASS |
| Decremento abaixo de zero é rejeitado, mantém a quantidade anterior | Req. 7.4 / COL-09 | `collection_items_controller.rb:74` — `AND quantity > 0` no `WHERE`; `test/integration/collection_items_test.rb:90` e `:100` | ✅ PASS |
| Decremento de variante sem registro não cria registro negativo | Edge case do spec | `test/integration/collection_items_test.rb:116` — `assert_no_difference CollectionItem.count`; o `UPDATE` não insere linha | ✅ PASS |
| Anônimo é redirecionado e a alteração **não** é aplicada | Req. 6.4 / COL-04 | `test/integration/collection_items_test.rb:137` — `assert_no_difference` + `assert_redirected_to new_session_path`; `:144` — decremento, `assert_equal 2, item.reload.quantity` | ✅ PASS |
| Teste cobre incremento, decremento, piso em zero e anônimo | COL-07 | Os quatro blocos de `collection_items_test.rb` (`:35`, `:76`, `:134`, `:153`) | ✅ PASS |

**A prova do anônimo é pelo estado, não só pelo status.** `:137` e `:144`
asseguram que nenhuma linha mudou — um 302 sozinho passaria se a action tivesse
rodado antes do redirect. Como o controller não declara
`allow_unauthenticated_access`, o `before_action` barra **antes** da action, e o
teste confirma o efeito, não a intenção.

**O `WHERE quantity > 0` cobre os dois casos de rejeição com um statement.** Zero
linha afetada é simultaneamente "já está em zero" e "não existe registro" — e o
`UPDATE` não cria linha, logo não há como produzir negativo. A garantia real
continua sendo o `CHECK` do banco, que a T5 prova.

**O achado de open redirect foi tratado com honestidade.** `redirect_back_with`
(`collection_items_controller.rb:194`) passa `allow_other_host: false`
explicitamente, e o comentário diz que **hoje é redundante** (`load_defaults 8.0`
liga `raise_on_open_redirects`) — a correção entrou por tornar local uma garantia
que era indireta, não por o revisor ter encontrado exploit. Há teste de regressão
(`collection_items_test.rb:202`, `Referer` de `evil.example.com` cai no
`fallback_location`). Registrar que a alegação original do revisor não procedia,
em vez de creditar uma vulnerabilidade inexistente, é a conduta certa.

### T7 — isolamento entre usuários (Req. 6.5, absoluto)

| Critério (Done when) | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------------------- | ---------------------------- | ---------------------- | ------ |
| Dois usuários com a mesma variante veem apenas a própria quantidade | COL-05, critério 3 | `test/integration/collection_authorization_test.rb:138` (quantidades independentes), `:152` (decremento de um não altera o outro), `:166` e `:181` (cada um **recebe de volta** a própria quantidade na resposta) | ✅ PASS |
| Id de item de outro usuário devolve 404 | COL-05, critério 4 | **`SPEC_DEVIATION`** — ver seção própria. Satisfeito por construção aqui + **entregue de fato na T13**: `test/integration/wishlist_items_test.rb:387` (`assert_response :not_found` + `assert WishlistItem.exists?(alheio.id)`), `:415` (404 ≡ id inexistente, o que distingue 404 de 403) e `:424` (o corpo não revela dono nem item) | ✅ PASS (com desvio justificado) |
| `user_id` no request é ignorado; a sessão prevalece | COL-05, critério 2 | `collection_authorization_test.rb:208` (incremento, corpo), `:218` (**decremento**, o caso perigoso), `:231` (query string), `:245` (usuário correto no request, fixa a semântica) | ✅ PASS |
| Nenhuma action lê `params[:user_id]` | COL-05, estrutural | `collection_authorization_test.rb:290` — análise de **AST** via `Ripper.sexp`: `assert_equal [:card_variant_id], simbolos_lidos_de_params(arvore).uniq.sort` | ✅ PASS |

**O critério 4 do Req. 6.5 é absoluto e a prova não é encenada.** Verifiquei os
dois lados:

- **O lado da coleção** não tem rota por id, e a **ausência é testada**, não
  afirmada: `collection_authorization_test.rb:308` percorre
  `Rails.application.routes.routes`, casa o controller **por sufixo** do caminho
  (uma rota futura em `api/collection_items` não escapa) e asserta que
  `rota.path.required_names == ["card_variant_id"]` para **toda** rota do
  controller. Acrescentar `get "collection_items/:id"` quebra a suíte.
- **O lado da wishlist** entrega o 404 de verdade. Confirmei que a migração
  prometida aconteceu: `config/routes.rb` declara `resources :wishlist_items,
  only: %i[index create destroy]`, e `wishlist_items_test.rb:382-434` tem os
  três testes. O de `:415` é o que fecha o requisito de verdade — compara o
  status do id alheio com o de um id **inexistente** e exige que sejam o mesmo,
  que é a definição operacional de "não revela a existência".

**A reescrita do teste estrutural em AST foi necessária e está correta.** Um
regex de `params[:user_id]` é contornado por `params.dig(:user_id)`,
`params.to_unsafe_h[:user_id]` e `params.permit(:user_id)[:user_id]` — as formas
que alguém escreveria **sem saber** que existe um teste a respeito. A versão de
AST (`:79-129`) casa pela subárvore enraizada em `params`, então não depende de
uma lista de métodos mantida à mão. E a asserção é de **igualdade** com
`[:card_variant_id]`, não de ausência de `:user_id`: um acesso por variável
(`chave = :user_id; params[chave]`) produz conjunto vazio, que **também** falha.
Escapar exige remover o acesso legítimo junto.

O limite está declarado no próprio teste (`:287-289`): isto prova que nenhum dado
de request vira usuário **por esta porta** — `request.headers` ou cookie não
assinado não são cobertos aqui, e ficam com os testes de comportamento. Declarar
o limite em vez de deixá-lo implícito é o comportamento correto.

### T8 — posse na grade e no detalhe, sem recarregar

| Critério (Done when) | Resultado definido pelo spec | `file:line` + asserção | Result |
| -------------------- | ---------------------------- | ---------------------- | ------ |
| `importmap:install` executado | Infra | `config/importmap.rb` existe (Turbo pinado para `turbo.js`, Stimulus deliberadamente não); `app/javascript/application.js` existe; `app/views/layouts/application.html.erb:22` — `javascript_importmap_tags` | ✅ PASS |
| Controles na grade e no detalhe, **sempre por variante** | Req. 5.3 / COL-18 | Detalhe: `collection_ownership_ui_test.rb:76` — `assert_select ".ownership", 3` + um `id` e um `form` por variante. Grade: `:93` (variante única, controle presente) e `:108` (múltiplas, **controle ausente**) | ✅ PASS — ver análise abaixo |
| Atualização por Turbo Stream, sem recarregar a página | Req. 7.5 / COL-10 | `collection_ownership_ui_test.rb:137` — `turbo-stream[action="update"][target="ownership_card_variant_N"]`; `:190` — o alvo do Stream é **o mesmo `id`** que a página renderiza | ✅ PASS |
| Sem JavaScript, incremento e decremento continuam funcionando | Edge case do spec | `collection_ownership_ui_test.rb:273` e `:285` — mesma rota sem `Accept` de Stream responde `redirect_back`; `:300` — o controle é `<form method="post">` de verdade | ✅ PASS |
| Alvos de toque com no mínimo 24px | SC 2.5.8 / dívida de `STATE.md` | `collection_ownership_ui_test.rb:314` — lê `catalog.css`, extrai a regra `.ownership__button` e exige `min-height: 24px` **e** `min-width: 24px`. Confirmado em `app/assets/stylesheets/catalog.css:372-373` | ✅ PASS |
| Teste de integração sobre HTML renderizado; `SPEC_DEVIATION` registrado | Ausência de navegador | Cabeçalho de `test/integration/collection_ownership_ui_test.rb:1-31` | ✅ PASS |

#### A decisão de design da grade **satisfaz** o Req. 5.3

Este era o ponto de maior risco do lote, e a análise sustenta a decisão.

O Req. 5.3 de `.context/requirements.md:126` diz: *"QUANDO o usuário registrar
posse ENTÃO o registro DEVE ser feito **por variante**, nunca agregado na
carta."* O requisito governa **como o registro é feito**, não **onde o botão
aparece**. As duas saídas ingênuas falham por motivos opostos:

- Um controle único por tile **agregaria a posse na carta** em 40,1% do catálogo
  (1129 de 2815 cartas com mais de uma variante) — violação literal e direta.
- Empilhar N controles por tile quebraria o Req. 2.5 (360px sem scroll
  horizontal), requisito vigente e já verificado no `catalogo`.

O desenho entregue não agrega em caso nenhum: onde há **uma** variante, o
controle no tile é inequívoco (a carta *é* a variante, não há agregação
possível); onde há **mais de uma**, o tile não oferece controle e leva ao
detalhe, onde cada variante tem o seu. **Nenhuma escrita jamais ocorre sem
variante escolhida** — a rota só aceita `card_variant_id`, e não existe rota por
`card_id`.

O critério "controles na grade e no detalhe" do `tasks.md` é, portanto, cumprido
em ambos os lugares; o que a task fez foi resolver uma tensão entre dois
requisitos vigentes escolhendo a leitura que não viola nenhum. **Não é escopo
abandonado.** Confirmei por mutação (abaixo) que a escolha está travada por teste.

#### O defeito silencioso corrigido na T8 está presente e coberto

`CatalogController` declara `allow_unauthenticated_access`, que remove o
`before_action :require_authentication` — que era quem chamava `resume_session`.
Sem uma chamada explícita, `Current.user` é `nil` na action e **todo usuário
autenticado veria quantidade zero**, com a página respondendo 200.

A correção está presente em três pontos do estado atual:
`catalog_controller.rb:22` (`#index`), `:66` (`#owned_total`, T11) e `:92`
(`#owned_quantities`, T8) — mais `:121` em `#wishlist_targets` (T13). O
comentário de `:80-90` documenta o mecanismo com precisão e nota que
`resume_session` é idempotente (`Current.session ||= ...`), de modo que a chamada
da view não repete a consulta.

**Verificado por mutação** — não aceito pelo comentário (ver seção de sensor).

---

## `SPEC_DEVIATION` — julgamento

### 1. `test/integration/collection_authorization_test.rb` (T7) — 404 por id de item

**Veredito: justificado, e a migração aconteceu de fato.**

O critério 4 da história de isolamento na `spec.md:98` pressupõe uma URL que
aceite id de `collection_item`. A T6 não criou nenhuma, por razão de produto
defensável e documentada: o botão "+1" nasce na grade, onde o registro
normalmente ainda não existe, e exigir id forçaria ler antes para descobrir que
não há o que ler.

Três coisas me fazem classificar isto como desvio legítimo, e não como escopo
abandonado:

1. **O requisito de origem vence (AD-005).** `.context/requirements.md:151` diz
   *"Um usuário NUNCA DEVE conseguir ler ou alterar a coleção de outro usuário"*
   — **não menciona 404 nem id**. O "404 por id" é uma operacionalização que a
   `spec.md` escolheu assumindo um desenho REST que a T6 não adotou. O requisito
   substantivo está satisfeito, e por construção: não há id de item em URL
   nenhuma, logo não há id alheio a recusar.
2. **A ausência é provada, não afirmada.** `collection_authorization_test.rb:308`
   faz da construção uma garantia verificada. Isto é o que separa um desvio
   honesto de um buraco: acrescentar a rota amanhã quebra a suíte com uma
   mensagem que aponta para o `SPEC_DEVIATION`.
3. **A migração para a T13 é real, e lá o teste não é encenado.** Confirmei:
   `resources :wishlist_items, only: %i[index create destroy]` existe em
   `config/routes.rb`, e `wishlist_items_test.rb:387/:415/:424` entregam o 404,
   a indistinguibilidade de id inexistente e a ausência de vazamento no corpo.
   `STATE.md:107-113` registra o critério como entregue.

A alternativa — criar rota por id só para ter o que testar — produziria
superfície de ataque que o produto não usa. A decisão está correta.

### 2. `test/integration/collection_ownership_ui_test.rb` (T8) — ausência de navegador

**Veredito: justificado, com uma lacuna real e declarada.**

Não há chromedriver no container (mesma constatação das T12/T14 do `catalogo`),
e acrescentá-lo é mudança de `Dockerfile.dev`, fora do escopo de uma task de
view. O cabeçalho (`:1-31`) é exemplar por dizer **o que fica coberto e o que
não**:

- Coberto: a resposta é um `<turbo-stream action="update">` mirando só o
  contêiner daquela variante (logo não é a página inteira); o alvo é o **mesmo
  `id`** que a página renderiza (`:190` — um `id` divergente seria uma
  atualização que não acontece, e nenhum teste de status a pegaria); a mesma rota
  sem `Accept` de Stream responde `redirect_back`.
- **Não coberto**: a aplicação do Stream ao DOM por um navegador real.

A lacuna é genuína, está declarada em vez de escondida, e é herdada de uma
limitação de infraestrutura já registrada em `STATE.md:490`. **Não bloqueante**:
a marcação que dispara o comportamento é asserida em todos os seus contratos
observáveis.

---

## Sensor de discriminação — mutações rodadas por mim

Rodadas em cópia de segurança no scratchpad, com `cp`/`diff`, **nunca `git
stash`**. Árvore restaurada e conferida (`git diff --stat` vazio ao final).

| # | Mutação | Testes mortos | Conclusão |
| - | ------- | ------------- | --------- |
| 1 | `authenticated?` removido de `CatalogController#owned_quantities` (reproduz o defeito silencioso da T8) | **2** — `collection_ownership_ui_test.rb:252` (o decremento permanece `aria-disabled` porque a quantidade lida é 0) e mais um em `collection_total_test.rb` | A correção do defeito silencioso **está coberta**. Não é comentário sem teste. |
| 2 | `variants.one?` → `variants.any?` no tile (faz a carta de 3 variantes renderizar controle agregado — a violação do Req. 5.3) | **3** — `:108` (controle oferecido sem escolha de impressão), `:123` (o link de "3 impressões" some) e `:375` (o anônimo passa a ver 2 convites de login onde deveria ver 1) | A decisão de design **está travada por teste**. Agregar posse na carta quebra a suíte. |
| 3 | `turbo_stream.update` → `turbo_stream.replace` | **2** — `:137` e `:172`, ambos exigindo `turbo-stream[action="update"][target=...]` | A distinção `update`/`replace`, que é o que preserva a região `aria-live`, **é asserida**, não só comentada. |

As três mutações que eu escolhi eram as afirmações do autor que mais dependiam de
crédito. Todas se sustentaram.

---

## Lacunas de cobertura

### L1 — A aplicação do Turbo Stream ao DOM não é exercitada (não bloqueante)

**Onde**: `test/integration/collection_ownership_ui_test.rb`, `SPEC_DEVIATION` do
cabeçalho.

O que está provado é que o servidor emite o `<turbo-stream action="update">`
correto, mirando um `id` que a página de fato renderiza. O que **não** está
provado é que o Turbo o aplica no navegador. Uma regressão no carregamento do
importmap (por exemplo, `javascript_importmap_tags` removido do layout) deixaria
o Stream chegar e não ser aplicado, e a suíte continuaria verde — o usuário veria
a página recarregar, violando o Req. 7.5 sem nenhum teste acusar.

**Por que não é bloqueante**: o caminho sem JavaScript continua funcionando
(`:273`, `:285`, `:300`), então o produto não quebra — degrada para o
comportamento que os Edge Cases já exigem suportar. Fechar a lacuna é a mesma
mudança de `Dockerfile.dev` das T12/T14, já registrada em `STATE.md:490`.

### L2 — O piso de senha não é a proteção contra força bruta que falta (não bloqueante)

**Onde**: `app/models/user.rb:62` e `app/controllers/sessions_controller.rb:10-21`.

A T4 omitiu o `rate_limit` com justificativa correta e compensou com
`validates :password, length: { minimum: 8 }`. A compensação é parcial por
construção: um piso de 8 caracteres estreita o espaço de busca, mas **não limita
tentativas**. Não há hoje nenhum teste — nem poderia haver com `:null_store` —
que denuncie a ausência de limite.

**Por que não é bloqueante**: nenhum critério do Req. 6 exige limite de
tentativas, a decisão está documentada com as duas `file:line` que a sustentam, e
está registrada como dívida no `CLAUDE.md` e no `STATE.md` para reabrir junto com
Redis ou `solid_cache`. É uma dívida conhecida, não uma lacuna descoberta.

---

## Success Criteria da `spec.md` — conferidos

| Critério | Evidência | Result |
| -------- | --------- | ------ |
| `bin/rails test` passa inteiro, **sem alteração de asserção** dos testes de catálogo | 395 runs, 0 failures (medido por mim); `git diff --stat` do lote sobre `catalog_grid_test.rb`, `card_detail_test.rb` e `test/queries/` retorna **vazio** | ✅ |
| Existe teste que prova que um usuário não lê nem altera a coleção de outro | `collection_authorization_test.rb` inteiro; 10 testes | ✅ |
| Existe teste que prova que `UNIQUE` e `CHECK` são **do banco** | `collection_item_test.rb:54`, `:84`, `:95` — SQL direto em `uncached` | ✅ |
| A ingestão roda duas vezes com coleção povoada e nenhuma quantidade muda | `test/services/ingestion/guarantees_test.rb:63` — `assert_equal 3, item.quantity, "a ingestão alterou a quantidade possuída"`; reforçado por `:160` (**três** execuções consecutivas), `:172` (variante ausente da fonte não perde o vínculo) e `:216` (o estágio de upsert não contém operação de exclusão) | ✅ |
| `/catalog` responde 200 sem sessão | `authentication_test.rb:87`; `collection_ownership_ui_test.rb:375` | ✅ |
| `bin/rubocop` limpo | 81 files, no offenses (medido por mim) | ✅ |

**Sobre o teste que o `CLAUDE.md` chama de mais valioso do projeto**: ele
continua passando e cobre mais do que promete. `guarantees_test.rb` não se
contenta com a reingestão dupla — verifica que a segunda execução tem
`created_count == 0` e `updated_count == total` (`:45-46`, o que distingue
"atualizou" de "recriou"), que os **ids** das variantes não mudaram (`:55`, o que
provaria perda de vínculo mesmo com contagem idêntica), e que uma variante
**ausente da fonte** não é removida nem perde o vínculo (`:172`). É cobertura
real, não cerimônia.

---

## Defeitos de código encontrados

**Nenhum.** Não corrigi nada, e não havia o que corrigir no escopo do lote.

Dois pontos que examinei com desconfiança e que se sustentaram:

- **`Current.user` no `CollectionItemsController` sem guarda contra `nil`**
  (`:43`, `:71`). A T6 recusou o LOW do revisor que pedia a guarda, e a recusa
  está correta: o `before_action :require_authentication` já barra o anônimo, e
  uma guarda trocaria uma falha barulhenta (`NoMethodError`, se alguém puser
  `allow_unauthenticated_access` aqui por engano) por um incremento silencioso
  que não acontece. Há teste do efeito (`collection_items_test.rb:137`).
- **`redirect_back` com destino vindo do `Referer`.** Coberto por
  `allow_other_host: false` explícito e por teste de regressão
  (`collection_items_test.rb:202`).

---

## Veredito final

✅ **PASS** para o lote B1 (T1–T8).

**Critérios verificados: 40. PASS: 40. FAIL: 0.** (T1: 6, T2: 5, T3: 5, T4: 5,
T5: 4, T6: 5, T7: 4, T8: 6.)

Condições, todas não bloqueantes:

1. **L1** — a aplicação do Turbo Stream ao DOM segue sem cobertura; fecha junto
   com chromedriver no `Dockerfile.dev`, dívida já registrada.
2. **L2** — sem limite de tentativas de login; reabrir junto com um cache store
   real, dívida já registrada.
3. O `SPEC_DEVIATION` da T7 fica **resolvido** pela entrega da T13; quando o lote
   B2 for verificado, vale confirmar que os três testes de 404 da wishlist
   permanecem.

A Fase 1, que nunca havia passado por Verifier, **não escondia nada**: os quatro
critérios mais fáceis de fingir (senha em claro, unicidade de e-mail, default de
autenticação, mensagem que não vaza existência de conta) têm asserção real, e
três deles provam contra o banco ou contra a estrutura do app, não contra o
Active Record.

---

# Lote B2 — Fase 3 (T9–T13)

**Date**: 2026-09-20
**Spec**: `.specs/features/colecao/spec.md`; fonte de verdade
`.context/requirements.md` Req. 7 e 8 (AD-005)
**Diff range**: `5e7eee6..4b0671b` — `cd56e6d` (T9), `315effb` (T10), `c8769f3`
(T11), `b616d01` (T12), `4b0671b` (T13)
**Verifier**: subagente independente (autor ≠ verificador) — não executei
nenhuma destas tasks e não verifiquei o lote B1
**Veredito**: ✅ **PASS**, com 3 lacunas de cobertura registradas (nenhuma
bloqueante)

---

## Nota sobre o escopo e o método

1. A verificação é **contra o estado atual do código** (`HEAD` = `4b0671b`), não
   contra os diffs isolados: tasks posteriores tocaram o que as anteriores
   entregaram (a T13 acrescentou `#wishlist_targets` ao `CatalogController` que
   a T9 e a T11 já haviam alterado).
2. Onde desconfiei, **rodei mutação numa cópia** dos arquivos, com `cp`/`diff`
   para restaurar — nunca `git stash`. Cinco mutações, todas restauradas com
   `diff` limpo e `git diff --stat` vazio ao fim.
3. Não corrigi código e não commitei nada.

### Estado medido por mim

| Medição | Resultado |
| ------- | --------- |
| `docker compose exec app bin/rails test` | **395 runs, 1251 assertions, 0 failures, 0 errors, 0 skips** |
| `docker compose exec app bin/rubocop` | **81 files inspected, no offenses detected** |
| Árvore de trabalho ao fim das mutações | limpa (`git diff --stat` vazio; só `validation.md` e os dois `untitled*.md` não rastreados) |

---

## Task Completion

| Task | Status | Notas |
| ---- | ------ | ----- |
| T9 — `owned` no `CatalogQuery` | ✅ PASS | 6/6 critérios. Partição provada por asserção direta (`owned ∩ missing == ∅` **e** `owned ∪ missing == all`), não por inspeção. |
| T10 — plano de execução do filtro | ✅ PASS | 3/3 critérios. Resultado **negativo** (índice medido e reprovado) — julgado defensável; ver seção própria. |
| T11 — total de cópias possuídas | ✅ PASS | 4/4 critérios. `sum` vs. `count` discriminado de verdade: quantidades semeadas ≠ 1. |
| T12 — tabela e model `wishlist_items` | ✅ PASS | 4/4 critérios. As três garantias provadas por SQL direto contra o banco. |
| T13 — controller e views da wishlist | ✅ PASS | 5/5 critérios. Resolve o `SPEC_DEVIATION` da T7; ver seção própria. |

---

## Verificação ancorada no spec

### T9 — `owned` no `CatalogQuery` (COL-11, Req. 7.6)

| Critério "Done when" | Evidência | Result |
| -------------------- | --------- | ------ |
| Contrato de `design.md` §4.2 respeitado: `all \| owned \| missing` | `app/queries/catalog_query.rb:73` — `OWNERSHIP_VALUES = %w[all owned missing].freeze`, consumida em `:sanitized_ownership` por `include?`. Testes: `test/queries/catalog_ownership_test.rb:78`, `:82`, `:86` asserem os três conjuntos por `assert_equal` de listas nominais, não por contagem | ✅ |
| Valor fora do contrato é ignorado, sem erro | `catalog_ownership_test.rb:169` — `"banana"`, `""` e `[ "owned" ]` (array, não string) todos devolvem `TODAS`; `:175` exige que também **não virem chip** | ✅ |
| Sem usuário, o filtro é ignorado e o catálogo sai completo | `catalog_query.rb:sanitized_ownership` → `return nil if @user.nil?`; `catalog_ownership_test.rb:155` asserta `TODAS` para `owned` **e** `missing` com `user: nil`; `:160` asserta que o filtro descartado não vira chip | ✅ |
| Semântica preservada: OU dentro da categoria, E entre categorias | `catalog_ownership_test.rb:195` (posse × cor), `:201` (missing × cor), `:206` (posse × faixa numérica), `:210` (OU de duas cores **sob** o filtro de posse), `:215` (posse × busca textual, com `assert_empty` no lado `missing`). O `E` é o encadeamento de `where`; a negação incide sobre o `EXISTS` inteiro (`:apply_ownership_filter` → `owned.exists.not`), não vazando para o predicado irmão | ✅ |
| Variante com quantidade zero conta como não possuída | `catalog_ownership_test.rb:112` — `OP01-t9c` fora de `owned` e dentro de `missing`; `:121` é o que **discrimina**: prova que quantidade zero (`t9c`) e ausência de registro (`t9d`) dão o **mesmo** resultado. O predicado parte de `CollectionItem...owned` (`scope :owned, -> { where(quantity: 1..) }`, `collection_item.rb:25`), não de existência de linha | ✅ |
| Teste prova que a URL do catálogo com `owned` responde 200 para anônimo | `test/integration/catalog_grid_test.rb:325` — laço sobre `%w[all owned missing banana]`, cada um com `assert_response :success` **e** `assert_select ".card-tile", 3` (200 com tela vazia não passaria) | ✅ |

**Semântica de partição, julgada contra o spec.** A escolha (`owned` = ao menos
uma variante possuída; `missing` = nenhuma) **não contradiz requisito nenhum**:
o Req. 7.6 pede "somente as que eu tenho" e "somente as que eu não tenho", que
são perguntas opostas, e completude por impressão é o Req. 9, com denominador
próprio em AD-003. A partição tem asserção direta em `catalog_ownership_test.rb:94`
(`assert_empty possuidas & faltantes` + `assert_equal TODAS, (possuidas + faltantes).sort`),
e o teste que **discrimina** as duas leituras possíveis é `:105` — carta com uma
de três variantes possuídas, exigida em `owned` e recusada em `missing`. Sob a
leitura alternativa ela estaria nos dois.

**Isolamento (Req. 6.5).** `catalog_ownership_test.rb:130` (posse alheia não
entra), `:135` (o mesmo catálogo para outro usuário devolve a posse dele — prova
que o filtro funciona, e não que devolve vazio para todos), `:141` e `:147`
(`user_id` na URL), mais `catalog_grid_test.rb:337` na integração anônima.

---

### T10 — filtro de posse sem full table scan (COL-11, Req. 11.3)

| Critério "Done when" | Evidência | Result |
| -------------------- | --------- | ------ |
| O plano do filtro combinado com busca não mostra Seq Scan na tabela de coleção | `test/queries/catalog_owned_plan_test.rb:116` (posse + busca) e `:125` (posse + cor), mais `:103`/`:107` para os modos isolados. A asserção é **dupla** (`assert_collection_access_indexed`, `:203`): `refute_match(/Seq Scan on collection_items/)` **e** `assert_match(COLLECTION_INDEXES)` — a segunda fecha o buraco de um filtro quebrado que não consulta nada e por isso também não varre nada | ✅ |
| Dados semeados com seletividade realista | `catalog_owned_plan_test.rb:140` — o seed **guarda a si mesmo**: `assert_operator total, :>=, 10_000`, `assert_operator fracao, :<, 0.10` (fração do usuário alvo) e `assert_operator ...quantity: 0).count, :>, 0`. Constantes em `:93`: 20.000 cartas, 50 usuários, 400 itens/usuário, `ANALYZE` ao fim do seed | ✅ |
| Se faltar índice, a migração é aditiva e o dump do schema é regenerado | Vacuamente satisfeito por medição: nenhum índice faltou. `git show --stat 315effb` confirma que o commit **não toca** `db/structure.sql` nem `db/migrate/` — só `tasks.md`, `STATE.md` e o teste novo. Coerente com a decisão | ✅ |

**Mutação minha, independente da do autor.** Reescrevi o predicado na forma não
indexável (`CollectionItem.where("(user_id + 0) = ?", ...)` no lugar de
`for_user`) e rodei `test/queries/catalog_owned_plan_test.rb`: **3 falhas**
(o autor reportou 2 — a minha medida é mais forte, não mais fraca). Restaurado
com `diff` limpo. O teste pega a classe de defeito que promete pegar.

#### Julgamento do resultado negativo

**A decisão de não criar o índice é defensável, não é justificativa para
trabalho não feito.** Três razões, todas verificáveis:

1. **A medição está registrada de forma verificável e no lugar certo.** Não
   mora só em `tasks.md`: o cabeçalho de `catalog_owned_plan_test.rb:28-54`
   carrega os números (custo 19.29 com e sem o índice parcial; 2397.84 contra
   2404.20 no cenário de usuário pesado; execução ligeiramente **pior** com ele)
   e **nomeia o cenário que reabriria a decisão** — usuário único com dezenas de
   milhares de itens e fração de `quantity = 0` muito acima dos ~14% do seed.
   Quem for remedir não precisa redescobrir o limite desta medição.
2. **A hipótese foi separada em descrição e problema.** A T9 supôs que o
   `UNIQUE` não filtra `quantity` e empurraria a checagem à heap. Isso se
   **confirmou como descrição** e se **refutou como problema** — distinção que
   um relatório complacente não faria. Índice que o planejador ignora é custo de
   escrita em toda operação de posse sem ganho de leitura.
3. **A não-criação tem asserção, não só prosa.** `catalog_owned_plan_test.rb:160`
   exige que `index_collection_items_on_user_id` e
   `index_collection_items_on_card_variant_id` continuem existindo. Sem ele,
   derrubá-los só apareceria como lentidão em produção.

**Sobre a admissão de que o teste não discrimina ausência de índice.** O autor
registra que derrubar os dois índices não-únicos **não** derruba as asserções de
plano, porque o índice do `UNIQUE (user_id, card_variant_id)` assume o lugar
deles. **Julgo isso honestamente documentado e não enfraquecedor do critério**,
por três motivos:

- Está no **cabeçalho do arquivo de teste** (`:72-90`), não escondido em
  `tasks.md` — quem abrir o teste lê a limitação antes das asserções.
- A afirmação é **verdadeira e é propriedade do schema, não do teste**: aquele
  índice é inseparável da unicidade criada em `20260919120200`, logo
  `collection_items` tem um piso de acesso indexado por `user_id` que nenhuma
  migração remove sem remover antes a própria unicidade. Forçar o teste a
  discriminar ali seria testar condição inatingível.
- O eixo descoberto foi **coberto em outro lugar** (`:160`, existência dos
  índices) em vez de ficar a descoberto. É a resposta correta a um sensor que
  revela um eixo não coberto: cobri-lo por outro meio, não reescrever a
  narrativa.

O critério do "Done when" é "sem full table scan", e é exatamente isso que
`assert_collection_access_indexed` asserta — sem travar um nome de índice, o que
reprovaria o plano invertido (mais barato, custo 1339 contra 2398) que o
planejador escolhe com recorte de cartas muito seletivo.

---

### T11 — total de cópias possuídas (COL-12, Req. 7.7)

| Critério "Done when" | Evidência | Result |
| -------------------- | --------- | ------ |
| Total soma cópias, não variantes distintas | `app/models/collection_item.rb:62` — `for_user(user).owned.sum(:quantity)`. Teste: `test/integration/collection_total_test.rb:64` semeia **3 e 2 cópias** (nenhuma igual a 1, que é o que torna o teste capaz de discriminar) e exige `5`, com `refute_match(/\b2 cópias\b/)` explícito contra a leitura `count`. Reforçado por `:152`, que pagina de um em um com 3+2+8 e exige **13 nas três páginas** | ✅ |
| Variante com quantidade zero não entra no total | `collection_total_test.rb:82` (4 + 0 exibe 4) e `:94` pelo outro lado (coleção **inteiramente** zerada exibe 0, com `refute_match(/\b2\b/)` contra um `count` das linhas) | ✅ |
| Nada é exibido para anônimo | `app/views/catalog/index.html.erb:62` — `<% if authenticated? %>` envolve o `render`. Teste: `collection_total_test.rb:110` — com 7 cópias semeadas de outro usuário, `assert_select ".catalog__owned-total", 0` e a página em 200 | ✅ |
| Teste de integração confere o número com posse conhecida | Os 14 testes do arquivo; além dos acima, `:122` (só a coleção da sessão: 3 exibido, `refute_match` de 12 e de 9), `:136` (`user_id` na URL), `:173` (filtro esvazia a grade e o total fica intacto), `:188` (o total da coleção é distinguível do total do catálogo), `:278` (singular) | ✅ |

**Mutação minha.** `sum(:quantity)` → `count` em `collection_item.rb:62`:
**9 falhas** em `collection_total_test.rb` (o número cai de 5 para 2 e de 13 para
3). Restaurado com `diff` limpo. A discriminação `sum` vs. `count` é real.

**Redundância deliberada de `authenticated?` confirmada como decisão, não como
descuido.** O autor registra que remover só a chamada de `#owned_total`
(`catalog_controller.rb:66`) não mata teste nenhum, porque `#index` já chama no
topo (`:22`), e que remover as **três** mata 7. Isso é a documentação honesta de
uma redundância que existe contra reordenação futura — o mesmo padrão do
`CLAUDE.md` sobre `allow_unauthenticated_access`. Não é cobertura inflada: o
teste que importa (`:110`) prova o **efeito** para o anônimo.

**A recusa de `aria-live` virou asserção**, o que é o padrão correto para uma
decisão de a11y: `collection_total_test.rb:263` exige a **ausência** de
`aria-live` e `role=status` no total **e** a **presença** da região viva no
controle da variante. Uma recusa sem teste viraria regressão silenciosa.

---

### T12 — tabela e model `wishlist_items` (COL-14, COL-17)

| Critério "Done when" | Evidência | Result |
| -------------------- | --------- | ------ |
| `UNIQUE (user_id, card_variant_id)`, `CHECK (target_quantity >= 1)` e FK `on_delete: :restrict` | `db/structure.sql:348` (`CONSTRAINT wishlist_items_target_quantity_check CHECK ((target_quantity >= 1))`), `:679` (`CREATE UNIQUE INDEX index_wishlist_items_on_user_id_and_card_variant_id`), `:710` e o FK irmão — **ambas** as FKs `ON DELETE RESTRICT`. Migração: `db/migrate/20260919120500_create_wishlist_items.rb:20-22`, `:28`, `:39` | ✅ |
| Nenhuma FK em cascata | `test/models/wishlist_item_test.rb:161` usa `confdeltype <> 'r'` (e não `= 'c'`): `SET NULL`/`SET DEFAULT` também reprovam. Como essa asserção é **vacuamente verdadeira numa tabela sem FK nenhuma**, `:176` exige **exatamente duas** FKs — a lacuna está fechada de propósito | ✅ |
| Testes por SQL direto provam que as três garantias são do banco | `wishlist_item_test.rb:50` (unicidade por `INSERT` cru), `:82`/`:92`/`:104` (`CHECK` atacado por baixo: alvo 0, alvo −1 e `UPDATE ... SET target_quantity = target_quantity - 1`), `:120` (atacado **por cima**: alvo 1 tem que ser aceito — sem ele um `CHECK (>= 2)` deixaria os outros três verdes), `:132`/`:147` (FK recusa `DELETE` de variante desejada e de usuário com wishlist). `:64` prova que a unicidade é do **par** e não do usuário | ✅ |
| O teste de garantias da ingestão é estendido: duas execuções com wishlist povoada e nenhum alvo muda | `test/services/ingestion/guarantees_test.rb:84` — alvos semeados **3 e 5** (diferentes entre si e de 1, o que impede que uma sobrescrita uniforme passe despercebida), com asserção de que a reingestão de fato rodou (`:103`); `:106` (variante ausente da fonte não some nem perde o vínculo), `:122` (posse **e** desejo da **mesma** variante sobrevivem juntos — em variantes diferentes o teste seria verde por acaso), `:139` (FKs sem cascata) | ✅ |

**Assimetria `>= 1` contra o `>= 0` da coleção**: verificada como decisão
justificada, não inconsistência. A justificativa mora na migração
(`20260919120500`), que é onde quem comparar as duas tabelas vai procurar, e o
argumento é correto — alvo 0 ficaria **permanentemente "atendido"** quando a T13
derivar o Req. 8.3, virando lixo silencioso na lista.

**`WishlistItem.for_user` (`wishlist_item.rb:32`) replica o contrato de
`CollectionItem.for_user`**, incluindo o `raise ArgumentError` para um id.
Provado por `wishlist_item_test.rb:206`. É a barreira de tipo que faz o Req. 6.5
valer por construção, e a T13 a consome em vez de reinventar autorização.

---

### T13 — wishlist: marcar, listar, remover, sinalizar atendido (COL-14..COL-17)

| Critério "Done when" | Evidência | Result |
| -------------------- | --------- | ------ |
| Marcar com alvo inteiro maior que zero; listar apenas os itens da sessão; remover | `wishlist_items_controller.rb:44` (`create`), `:28` (`index`, por `WishlistItem.for_user(Current.user)`), `:70` (`destroy`). Testes: `test/integration/wishlist_items_test.rb:58` (marcar), `:75`/`:87`/`:103`/`:118` (alvo 0, negativo, não numérico e ausente — todos recusados **com mensagem em português**, sem 500), `:146` (marcar de novo atualiza em vez de duplicar), `:159` e `:176` (lista só do usuário da sessão), `:355` (remover) | ✅ |
| "Atendido" é derivado, nunca persistido como flag | `wishlist_item.rb:67` — `scope :with_fulfillment` com `COALESCE(collection_items.quantity, 0) AS owned_quantity`; `#fulfilled?` (`:92`) compara em Ruby sobre o valor projetado. **Nenhuma coluna**: `wishlist_items_test.rb:298` compara `WishlistItem.column_names` com a lista exata das seis colunas — acrescentar `fulfilled` denuncia. `db/structure.sql:341-348` confirma as seis. Prova comportamental em `:309`: um "+1" na coleção muda o atendimento com `assert_no_changes` no `updated_at` do item — nenhuma escrita na wishlist | ✅ |
| Item cuja variante sumiu da fonte continua listado | `wishlist_items_test.rb:335` — a ausência é `last_seen_at` velho, nunca linha removida (a FK `restrict` da T12 transformaria remoção em erro barulhento) | ✅ |
| Anônimo é redirecionado; id de item de outro usuário devolve 404 | Redirect: `wishlist_items_test.rb:465`, `:471`, `:479` — as três actions, e o controller **não** declara `allow_unauthenticated_access` (`wishlist_items_controller.rb:22`), logo herda o default protegido de `ApplicationController`. 404: `:387`, `:404`, `:424` — ver seção própria abaixo | ✅ |
| Teste de integração cobre alvo 2, posse 1 (não atendido), posse 2 (atendido) e remoção | `wishlist_items_test.rb:196` (posse 0), `:213` (posse 1, não atendido), `:227` (posse 2, atendido), `:241` (posse acima do alvo também atende — o `>=` do "atingir **ou exceder**"), `:255` (posse registrada em zero **não** atende), `:355` (remoção). O roteiro do "Independent Test" da spec está coberto item a item | ✅ |

**O `LEFT JOIN` é mesmo `LEFT`, e verifiquei por mutação.** `wishlist_item.rb:69`
diz `LEFT JOIN collection_items`, com a condição pelo **par completo**
(`card_variant_id` **e** `user_id`, `:70-71`). Troquei por `INNER JOIN` numa
cópia e rodei o arquivo: **6 falhas**, exatamente o número que o autor reportou.
Restaurado com `diff` limpo. O defeito que um `INNER` causaria seria silencioso
— 200 com lista curta demais, sumindo justamente com quem deseja o que nunca
teve, que é o caso normal da wishlist. O `user_id` na condição de join tem teste
próprio (`:269`): a posse de outro usuário não atende o desejo deste.

**N+1**: `wishlist_items_test.rb:501` compara o número de consultas com **2** e
com **8** itens, em vez de fixar um teto. É a forma correta — um teto generoso
deixaria passar um N+1 real, e um teto apertado quebraria quando o layout mudar.

**Acessibilidade**: as duas decisões viraram asserção pelos dois lados — o
`role="group"` com nome acessível no `<form>` e a **ausência** de `aria-label`
no campo (SC 2.5.3, *Label in Name*); e "Atendido" no **texto**, não só na cor
(`app/views/wishlist_items/index.html.erb:60`/`:62`, com "Faltam N" no item
pendente).

---

## Sobre os dois `SPEC_DEVIATION`

### Resolução do `SPEC_DEVIATION` da T7 — a condição deixada pelo lote B1

O B1 pediu confirmação de que os três testes de 404 da wishlist permanecem e
provam o que dizem. **Confirmado: permanecem, provam, e não são encenados.**

| Teste | `file:line` | O que asserta |
| ----- | ----------- | ------------- |
| `remover item de outro usuário devolve 404 e não remove nada` | `test/integration/wishlist_items_test.rb:387` | `assert_no_difference -> { WishlistItem.count }` em volta do `delete`, `assert_response :not_found` **e** `assert WishlistItem.exists?(alheio.id)` — cobre status **e** efeito |
| `id alheio e id inexistente respondem do mesmo jeito` | `:404` | Compara o status do id alheio com o de `id: 999_999_999` e exige que sejam **iguais**, além de exigir que seja `:not_found`. É o que discrimina 404 de 403 |
| `o corpo do 404 não revela nada sobre o item alheio nem sobre o dono` | `:424` | `refute_includes response.body, @outro.email` e `refute_includes response.body, "#{target_quantity} cópia"` — "sem revelar a existência" é sobre a resposta inteira, não só sobre a linha de status |

**Verificado por mutação, não por leitura.** Substituí
`WishlistItem.for_user(Current.user).find(params[:id])`
(`wishlist_items_controller.rb:71`) por `find_by` + checagem de dono com
`head :forbidden` — a implementação ingênua que o comentário do controller diz
ter evitado. Resultado: **exatamente 3 falhas**, as três da tabela acima.
Restaurado com `diff` limpo.

Três condições de sanidade que também conferi, porque um teste de 404 pode ser
verde por motivo errado:

- `@outro` é um `User` **persistido e distinto** (`:21`), e `alheio` é criado com
  `WishlistItem.create!(user: @outro, ...)` — o item existe de verdade, então o
  404 não é de id inexistente disfarçado.
- `config.action_dispatch.show_exceptions = :rescuable`
  (`config/environments/test.rb:26`): o `RecordNotFound` é de fato traduzido em
  404 no ambiente de teste. Com `:none` os testes estourariam em vez de asserir,
  e a asserção seria outra coisa.
- A rota por id existe de verdade: `config/routes.rb:44` —
  `resources :wishlist_items, only: %i[index create destroy], path: "wishlist"`.

**Veredito: o `SPEC_DEVIATION` da T7 está resolvido. Não virou escopo
abandonado.** O critério 4 da história "P1: Isolamento entre usuários" (COL-05)
está cumprido por três testes com discriminação medida, e a migração do critério
da T7 para a T13 é justificada pelo desenho — a posse opera por
`card_variant_id` e não tem URL onde um id de item caiba; a wishlist remove por
item e tem.

### `SPEC_DEVIATION` da T13 (`wishlist_mark_ui_test.rb:3`)

**Julgo justificado, não escopo abandonado.** Quatro razões:

1. **A causa é ambiental e já registrada no `CLAUDE.md`** ("Não há navegador no
   container, logo não há system test"). É dívida do projeto, não recuo desta
   task, e o mesmo padrão já valia nas T8 e T11 desta feature e nas T12/T14 do
   `catalogo`.
2. **Declara o que não cobre**, nominalmente: o clique real e o comportamento
   visual em 360px. Não se esconde atrás de "coberto por teste de integração".
3. **O que dá para provar sem navegador foi provado**: que existe um controle
   por impressão, que aponta para a rota certa com a variante certa, que tem
   nome acessível distinguível e que o anônimo não o vê.
4. **A decisão de escopo que ele acompanha também tem teste pelos dois lados** —
   o controle de desejo fica **só** no detalhe (Req. 2.5, a grade em 360px já
   carrega o controle de posse): um teste exige o controle de posse na grade,
   outro exige a **ausência** do de desejo, autenticado e anônimo. Uma decisão
   de escopo sem teste do lado negativo seria reversível em silêncio.

---

## Success Criteria da `spec.md` — verificação final

| Critério | Evidência | Result |
| -------- | --------- | ------ |
| `bin/rails test` passa inteiro, sem alteração de asserção dos testes de catálogo | 395 runs, 0 failures (medido por mim). O lote acrescentou 26 linhas a `catalog_grid_test.rb` (dois testes **novos** de `owned`), sem tocar asserção existente | ✅ |
| Existe teste que prova que um usuário não lê nem altera a coleção de outro | `collection_authorization_test.rb` (B1) + `wishlist_items_test.rb:387`, `:404`, `:424`, `:440`, `:449` (B2) | ✅ |
| Existe teste que prova que `UNIQUE` e `CHECK` são do banco | Coleção: B1. Wishlist: `wishlist_item_test.rb:50`, `:82`, `:92`, `:104`, `:120` | ✅ |
| A ingestão roda duas vezes com coleção **e wishlist** povoadas e nenhuma quantidade muda | `guarantees_test.rb:84`, `:106`, `:122`, `:139` — seis testes novos ao lado dos da coleção, que ficaram intactos | ✅ |
| `/catalog` responde 200 sem sessão, **inclusive com `owned` na URL** | `catalog_grid_test.rb:325` (os quatro valores) e `:337` (`user_id` na URL) | ✅ |
| `bin/rubocop` limpo | 81 files, no offenses (medido por mim) | ✅ |

---

## Lacunas de cobertura

Nenhuma bloqueante.

1. **L3 — a aplicação do Turbo Stream ao DOM segue sem cobertura** (herdada da
   L1 do B1, agora também para o quarto alvo `catalog_owned_total`). O que há é
   asserção sobre o **payload** do Stream (`collection_total_test.rb:213`, `:226`,
   `:241`): que o `turbo-stream[action=update][target=catalog_owned_total]` vem
   com o número recalculado e que o alvo existe no DOM da grade. O que **não** há
   é prova de que o navegador aplica o patch. Fecha junto com chromedriver no
   `Dockerfile.dev`.
2. **L4 — o `refute_match(/Seq Scan on collection_items/)` da T10 não
   discrimina ausência dos índices não-únicos**, pelo piso do `UNIQUE`. Está
   documentado no cabeçalho do teste e **compensado** por asserção separada de
   existência (`catalog_owned_plan_test.rb:160`). Registro como lacuna conhecida
   e coberta por outro eixo, não como defeito.
3. **L5 — o layout em 360px não tem cobertura automatizada** nem na grade
   (herdado do `catalogo`) nem no controle de desejo do detalhe. É decisão de
   layout justificada no partial e na folha de estilo; mesma dívida de navegador
   da L3.

Dívidas do B1 que continuam abertas e fora do escopo deste lote: login sem
limite de tentativas (L2) e o cookie de sessão sem `secure` explícito.

---

## Defeitos de código encontrados

**Nenhum.** Não corrigi nada, e não havia o que corrigir no escopo do lote.

Quatro pontos que examinei com desconfiança e que se sustentaram:

- **`Current.user.id` sem guarda contra `nil` no `WishlistItemsController`.** O
  controller não declara `allow_unauthenticated_access`, e `require_authentication`
  roda antes de qualquer action. Há teste do efeito nas três actions
  (`wishlist_items_test.rb:465`, `:471`, `:479`).
- **`params[:target_quantity]` atribuído sem `strong_parameters`.** Não é
  vulnerabilidade de mass assignment: o valor vai para **um** atributo nomeado
  em código (`wishlist_items_controller.rb:47`), não para `update(params[...])`.
  O `user` nunca vem do request. Alvo não numérico e alvo ausente têm teste
  (`:103`, `:118`).
- **`redirect_back` a partir do `Referer`** em `#redirect_back_to_origin`
  (`:84`): `allow_other_host: false` **explícito**, pelo mesmo padrão do
  `CollectionItemsController` já verificado no B1.
- **`WishlistItem#owned_quantity` (`wishlist_item.rb:83`) com fallback que
  dispara consulta** fora do `with_fulfillment`. É um fallback correto e
  explícito (não silencioso: devolve o valor certo, só mais caro), e o caminho da
  view sempre passa pelo scope — provado pelo teste de constância de consultas
  (`wishlist_items_test.rb:501`).

---

## Veredito final

✅ **PASS** para o lote B2 (T9–T13).

**Critérios verificados: 22. PASS: 22. FAIL: 0.** (T9: 6, T10: 3, T11: 4,
T12: 4, T13: 5.) Mais os 6 Success Criteria da `spec.md`, todos ✅.

Condições, todas não bloqueantes: **L3**, **L4** e **L5** acima.

**Cinco mutações minhas, independentes das do autor**, todas com restauração
conferida por `diff`: `LEFT`→`INNER` no join de atendimento (6 mortes),
`sum`→`count` no total (9 mortes), `find`→`find_by`+403 no `destroy` (3 mortes,
exatamente os três testes de 404), forma não indexável no predicado de posse
(3 mortes nos testes de plano), e a conferência da árvore limpa ao fim. Em
nenhuma delas a cobertura se mostrou aparente: os testes morreram pelos motivos
certos e com as mensagens certas.

---

## Nota de fechamento da feature `colecao` (B1 + B2)

Com os dois lotes verificados, **a feature `colecao` está completa e verificada**:
13 tasks, **62 critérios "Done when" verificados, 62 PASS, 0 FAIL** (40 no B1,
22 no B2), 395 testes, rubocop limpo.

Três observações que valem para quem retomar o projeto:

1. **A armadilha do `allow_unauthenticated_access` apareceu cinco vezes nesta
   feature** (T8, T9, T11 e duas na T13) e é o defeito mais caro do repositório,
   por ser **silencioso**: responde 200 e devolve vazio. As chamadas redundantes
   de `authenticated?` no `CatalogController` (`:22`, `:66`, `:92`, `:123`) são
   deliberadas e **não devem ser removidas** por parecerem duplicadas — o sensor
   da T11 e o da T13 mediram que removê-las em conjunto reintroduz o defeito.
   Já está no `CLAUDE.md`; reforço aqui porque quatro chamadas aparentemente
   redundantes no mesmo arquivo são um convite a "limpar".
2. **Os dois `SPEC_DEVIATION` da feature estão em estados diferentes**: o da T7
   está **resolvido** pela T13 (verificado acima, por mutação); o da T13
   (ausência de navegador) continua **aberto e justificado**, e fecha junto com
   chromedriver no `Dockerfile.dev` — é a mesma dívida que sustenta L3 e L5.
3. **O padrão "medir antes de criar" da T10 e da T13 vale a pena preservar.**
   Duas tasks tinham licença explícita para criar índice e nenhuma criou, cada
   uma com número medido e com o cenário de reabertura nomeado no código. É o
   oposto de escopo abandonado: é escopo **resolvido com resultado negativo**, e
   está documentado onde a próxima medição vai procurar.
