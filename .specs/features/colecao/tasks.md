# Plano de execução — Coleção (Fase 4)

Espelha `.context/tasks.md` §4. A fonte de verdade da ordem é `.context/tasks.md`;
este documento acrescenta dependências, gate e teste explícitos por task (AD-005).
**Ao concluir uma task, marcar o checkbox nos dois planos e commitar junto com o
código.**

## Execution Protocol

- Uma task por vez, em ordem. Não abrir a próxima com a anterior incompleta.
- Toda task termina com código que roda e teste que passa. "Estrutura criada" não
  é task concluída.
- Se um requisito se mostrar errado durante a execução, parar e corrigir
  `.context/requirements.md` antes de continuar.
- Um commit atômico por task, Conventional Commits, sem linha de atribuição.
- Divergência deliberada entre spec e código é marcada com `SPEC_DEVIATION` no
  próprio arquivo, como em `app/models/card_set.rb`.

## Test Coverage Matrix

| Camada | Tipo de teste | Onde |
|---|---|---|
| Schema e constraints do banco | unit | `test/models/` — SQL direto, `assert_raises(ActiveRecord::RecordNotUnique / InvalidForeignKey / StatementInvalid)`, no padrão de `catalog_schema_test.rb` |
| Models e regras de domínio | unit | `test/models/` |
| Query object | unit | `test/queries/` |
| Fluxo HTTP, autorização e HTML renderizado | integration | `test/integration/` — `get`/`post`, `assert_select` |
| Preservação da coleção pela ingestão | unit | `test/services/ingestion/guarantees_test.rb` (arquivo existente) |
| Infraestrutura sem comportamento próprio (Gemfile, importmap) | none | verificada pela task seguinte que a consome |

O projeto **não usa fixtures YAML**: cada teste cria seus registros no `setup`
(`fixtures :all` em `test_helper.rb` é resíduo do esqueleto). A suíte roda em
paralelo (`parallelize(workers: :number_of_processors)`).

## Gate Check Commands

| Gate | Comando |
|---|---|
| quick | `docker compose exec app bin/rails test test/models test/queries` |
| full | `docker compose exec app bin/rails test && docker compose exec app bin/rubocop` |
| build | `docker compose build` |

Gem nova exige `docker compose run --rm --no-deps app bundle install` — o volume
nomeado `bundle` sombreia as gems da imagem, então rebuild não basta.

## Execution Plan

### Phase 1: Identidade e sessão

```
T1 → T2 → T3 → T4
```

### Phase 2: Posse

Abre com a dependência que atravessa a fronteira de fase: T5 precisa da sessão
que T4 entrega.

```
T4 → T5 → T6 → T7 → T8
```

### Phase 3: Filtro, total e wishlist

```
T8 → T9 → T10 → T11 → T12 → T13
```

## Task Breakdown

### T1: Instalar bcrypt e dar senha ao `User` ✅

**What**: Adicionar `gem "bcrypt", "~> 3.1.7"` ao Gemfile, instalá-la no volume e declarar `has_secure_password` no `User` existente, preservando `has_many :collection_items, dependent: :restrict_with_exception`.
**Where**: `app/models/user.rb`
**Depends on**: None
**Reuses**: tabela `users` e coluna `password_digest` da migração `20260919120200`
**Requirement**: COL-02

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `gem "bcrypt", "~> 3.1.7"` no Gemfile e presente no `Gemfile.lock`
- [x] `User` responde a `authenticate` e a `password=`
- [x] `has_many :collection_items, dependent: :restrict_with_exception` continua no model
- [x] Teste prova que `User.create!(password: "x")` grava `password_digest` e que nenhuma coluna guarda a senha em claro
- [x] Teste prova que `User.authenticate_by(email:, password:)` devolve o usuário com a senha certa e `nil` com a errada
- [x] Teste prova que o e-mail é único sem distinção de caixa, pelo índice `index_users_on_lower_email` do banco

**Tests**: unit
**Gate**: full

---

### T2: Criar a tabela e o model `Session` ✅

**What**: Migração `create_table :sessions` (`user_id`, `ip_address`, `user_agent`) com FK para `users`, e o model `Session`.
**Where**: `db/migrate/` (migração nova)
**Depends on**: T1
**Reuses**: template `session.rb` de `railties-8.0.5.1`
**Requirement**: COL-01

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Migração criada e `db/structure.sql` regenerado por `db:migrate`
- [x] `Session belongs_to :user`; `User has_many :sessions, dependent: :destroy`
- [x] Teste prova que apagar um usuário apaga suas sessões e **não** apaga seus `collection_items` (a FK é `restrict`)
- [x] `db/structure.sql` não perdeu o índice trigram nem `immutable_unaccent`

**Tests**: unit
**Gate**: full

---

### T3: Concern `Authentication` com `Current` ✅

**What**: Portar à mão o concern `Authentication` e a classe `Current` dos templates do gerador, incluir o concern em `ApplicationController` e liberar o catálogo com `allow_unauthenticated_access`.
**Where**: `app/controllers/concerns/authentication.rb`
**Depends on**: T2
**Reuses**: templates `authentication.rb` e `current.rb` de `railties-8.0.5.1`
**Requirement**: COL-03, COL-04

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `require_authentication` é `before_action` default em `ApplicationController`
- [x] `CatalogController` declara `allow_unauthenticated_access` e `/catalog`, `/cards/:id` e a busca respondem 200 sem sessão
- [x] Sessão resolvida por cookie assinado, nunca por id vindo do request
- [x] Teste de integração prova que os testes de catálogo existentes continuam passando sem sessão
- [x] Teste prova que uma action protegida redireciona anônimo para a tela de autenticação e retorna à origem após autenticar

**Decisões da execução:**

- **`new_session_path` sem controller.** `request_authentication` redireciona
  para `new_session_path`, helper que só existiria na T4. Um helper ausente é
  `NameError` em tempo de requisição, não redirect — o "Done when" não fecharia.
  Resolvido declarando **só a rota** (`resource :session, only: %i[new create
  destroy]`) nesta task; o `SessionsController` que a atende continua sendo a
  T4, que não precisa mexer em `config/routes.rb`. Nenhum teste da T3 segue o
  redirect, apenas asserta o destino.
- **A action protegida do teste é uma sonda, não código de produção.** Quando a
  T3 roda não existe nenhuma action protegida no app: `SessionsController` é T4
  e `CollectionItemsController` é T6. Criar um controller de produção só para
  ter o que testar anteciparia escopo e viraria código morto no commit
  seguinte. `test/integration/authentication_test.rb` define um controller
  anônimo, protegido por omissão, com rota desenhada no `setup` e revertida no
  `teardown` — padrão do Rails para testar concern de controller. A sonda de
  autenticação chama `start_new_session_for`, de modo que o cookie é assinado
  pelo middleware real e o teste não reproduz o salt interno do Action
  Dispatch.

**Tests**: integration
**Gate**: full

---

### T4: `SessionsController` e cadastro ✅

**What**: Telas e actions de criar conta, autenticar e encerrar sessão, com mensagens de erro em português.
**Where**: `app/controllers/sessions_controller.rb`
**Depends on**: T3
**Reuses**: template `sessions_controller.rb` de `railties-8.0.5.1`, adaptado de `email_address` para `email`
**Requirement**: COL-01, COL-05

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Rotas `resource :session` e cadastro de usuário; layout com link de entrar/sair
- [x] `User.authenticate_by(email:, password:)` — sem `email_address`
- [x] Credencial errada reapresenta o formulário com mensagem em português que não revela se o e-mail existe
- [x] `rate_limit` do template só entra se acompanhado de cache store real; em teste o store é `:null_store` e em produção está comentado — decidir explicitamente e registrar a decisão em comentário
- [x] Teste de integração cobre criar conta, sair, autenticar e acessar página protegida

**Decisões da execução:**

- **`rate_limit` ficou de fora, e a ausência é a decisão.** O template traz
  `rate_limit to: 10, within: 3.minutes`, que depende de cache store
  compartilhado. Este projeto não tem: em teste o store é `:null_store`
  (`config/environments/test.rb:23`) e não conta nada — um teste do limite
  passaria sem exercitar coisa alguma; em produção `config.cache_store` está
  comentado (`config/environments/production.rb:50`) e o default é
  `:file_store` em `tmp/cache/`, por container e perdido no recreate. Com mais
  de um container, cada um contaria seu próprio limite. Incluir a linha daria
  aparência de proteção contra força bruta sem a proteção, e sem teste que
  denunciasse a diferença. Entra junto com um cache store real, que é mudança
  de infraestrutura. Justificativa no comentário do controller.
- **`RegistrationsController` não vem do gerador.** O gerador do Rails entrega
  entrar, sair e reset de senha; o cadastro é requisito daqui (Req. 6.1) e foi
  escrito do zero, com rota `resource :registration, only: %i[new create]`.
- **Achado da revisão de segurança, corrigido na task:** sem `rate_limit` **e**
  sem piso de senha, nada estreitava o espaço de força bruta — omitir os dois
  transformaria a decisão sobre o `rate_limit` em lacuna. `validates :password,
  length: { minimum: 8 }, allow_nil: true` no `User` é a metade que não depende
  de infraestrutura. O teste de senha vazia que já existia não provava piso
  nenhum (passaria com um caractere); há agora um teste de senha curta.
- **Defeito encontrado e corrigido na própria task:** cadastro com e-mail
  duplicado estourava `ActiveRecord::RecordNotUnique` — 500 em vez de formulário
  com erro. Só existia o índice do banco, sem validação no model.
  `validates :email, uniqueness: { case_sensitive: false }` foi acrescentado ao
  `User`. O índice continua sendo a garantia real (a validação tem corrida), e o
  teste da T1 que prova isso foi ajustado para contornar a validação com
  `save(validate: false)` em vez de ser afrouxado — mais um teste cobre a
  validação na camada de cima.

**Tests**: integration
**Gate**: full

---

### T5: Model `CollectionItem` sobre o usuário da sessão ✅

**What**: Completar `CollectionItem` com as regras de domínio e o escopo por usuário, sem aceitar `user_id` de request.
**Where**: `app/models/collection_item.rb`
**Depends on**: T4
**Reuses**: tabela `collection_items` da migração `20260919120200`
**Requirement**: COL-06, COL-09, COL-13

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Teste prova, por SQL direto, que `UNIQUE (user_id, card_variant_id)` é do banco (`ActiveRecord::RecordNotUnique`)
- [x] Teste prova, por SQL direto, que `CHECK (quantity >= 0)` é do banco
- [x] Teste prova que a FK recusa apagar uma variante possuída (`ActiveRecord::InvalidForeignKey`)
- [x] Quantidade zero é representável e tratada como não possuída

**Decisões da execução:**

- **Nenhuma migração, e isso é o resultado esperado.** As três garantias já
  nasceram na migração `20260919120200` (Fase 2), que criou `collection_items`
  para que a T8 do `catalogo` pudesse provar a invariante do Req. 1.7. A task
  consome o schema e o prova; não o recria. Se tivesse sido preciso migrar, o
  sinal seria de que a Fase 2 entregou menos do que `spec.md` §47 afirma.
- **`for_user` exige o objeto `User` e levanta `ArgumentError` para um id.** O
  Req. 6.5 é absoluto, e a forma barata de garantir "nunca um id vindo do
  request" é tornar a escrita errada impossível de compilar por acidente:
  `CollectionItem.for_user(params[:user_id])` explode em vez de devolver a
  coleção de outra pessoa. `nil` é o único valor não-`User` aceito, porque é o
  `Current.user` do anônimo do catálogo público — devolve relação vazia, não
  erro (Req. 7.6, critério 3). A alternativa (`where(user_id: ...)` aceitando
  qualquer coisa) deixaria a violação de autorização passar pela revisão sem
  ruído.
- **Zero é linha existente, não ausência de linha.** `owned` filtra
  `quantity > 0` e `unowned` filtra `quantity = 0`, em vez de testar existência
  do registro. Usar ausência como sentinela quebraria o filtro do Req. 7.6 para
  quem teve a carta e zerou: "nunca teve" e "não tem mais" deixariam de ser
  distinguíveis, e a T9 herdaria o defeito.
- **O teste da FK não asserta nada depois do `raise`.** A violação aborta a
  transação do teste; qualquer consulta seguinte falha com
  `PG::InFailedSqlTransaction` e não diz nada sobre o schema. A primeira versão
  do teste trazia um `assert CardVariant.exists?` depois do `assert_raises` e
  errava por isso. O nome da constraint na mensagem é o que identifica quem
  recusou.
- **O `CHECK` é provado duas vezes, por `INSERT` e por `UPDATE` direto.** Só o
  `INSERT` não distinguiria a constraint da validação do model: o caso que
  importa é o `UPDATE ... SET quantity = quantity - 1`, que é exatamente a forma
  que o decremento da T6 tenderia a tomar e que passa por fora de toda
  validação do Active Record.
- **O trabalho não commitado que existia no arquivo foi aproveitado quase
  inteiro.** Era uma tentativa anterior desta mesma T5, sem teste: scopes
  `owned`, `unowned`, `for_user` e o método `owned?`. A avaliação confirmou que
  estavam alinhados a COL-06/COL-08/COL-09 e ao Req. 6.5. Única correção: o
  comentário de `for_user` citava `CollectionItem.for(...)`, nome de método que
  não existe. Nada foi descartado; o que faltava era o teste, que é o que esta
  task acrescenta.
- **Revisão do `ecc:database-reviewer`: zero achado CRITICAL ou HIGH.** As duas
  correções LOW aceitas entraram: o teste de dois usuários passou a assertar a
  **coexistência** das duas linhas (`assert insert_item(...)` sozinho passaria
  mesmo se o segundo INSERT sobrescrevesse o primeiro), e `owned` trocou
  `arel_table[:quantity].gt(0)` por `where(quantity: 1..)`, simétrico ao
  `unowned` e sem Arel explícito. Dois MEDIUM foram **recusados por escopo**:
  trocar `quantity` de `integer` para `bigint` editaria uma migração já
  commitada da Fase 2 — que não altera a coluna do banco existente e forçaria
  churn em `structure.sql` — e cópias de uma carta física não chegam perto de
  2³¹; e a redundância do índice simples `user_id` com o prefixo do composto
  `(user_id, card_variant_id)` é trabalho de índice, que é a **T10**, como o
  próprio revisor apontou.

**Tests**: unit
**Gate**: quick

---

### T6: Incremento e decremento por variante ✅

**What**: Controller de coleção com incremento e decremento em uma ação, derivando o usuário de `Current.user` e nunca do request.
**Where**: `app/controllers/collection_items_controller.rb`
**Depends on**: T5
**Requirement**: COL-07, COL-08, COL-18

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Uma requisição por operação, sem formulário intermediário
- [x] Decremento abaixo de zero é rejeitado e mantém a quantidade anterior
- [x] Decremento de variante sem registro não cria registro negativo
- [x] Anônimo é redirecionado e a alteração não é aplicada
- [x] Teste de integração cobre incremento, decremento, piso em zero e anônimo

**Decisões da execução:**

- **A rota opera por `card_variant_id`, não por id de `collection_item`, e
  isso decide o que a T7 pode testar.** O botão "+1" nasce na grade do
  catálogo, onde na imensa maioria das vezes ainda não existe registro de
  coleção: exigir um id de item forçaria uma leitura prévia só para descobrir
  que não há o que ler, ou semear linhas zeradas para o catálogo inteiro. O
  registro é encontrado-ou-criado pelo par (`Current.user`, variante), que é a
  chave natural já protegida pelo `UNIQUE (user_id, card_variant_id)`.
  **Consequência: não existe nenhuma rota por id de item.** A T7 exige provar
  "id de item de outro usuário devolve 404", e hoje não há URL onde esse id
  caiba — é decisão do orquestrador na T7 se acrescenta rota por id (mostrar
  ou remover um item) ou se reformula o critério. O terreno está pronto para a
  primeira opção: `CollectionItem.for_user(Current.user)` é o único caminho de
  leitura, e uma busca por id dentro dele cai em `RecordNotFound` → 404 por
  construção, sem checagem de dono espalhada.
- **A corrida foi resolvida no banco, em um statement por operação.** O
  incremento é
  `INSERT ... ON CONFLICT (user_id, card_variant_id) DO UPDATE SET quantity =
  collection_items.quantity + 1`; o decremento é
  `UPDATE ... SET quantity = quantity - 1 WHERE ... AND quantity > 0`. A
  alternativa ingênua (`item.update!(quantity: item.quantity + 1)`) lê em Ruby
  e escreve depois: duas abas incrementando de 1 leem 1 as duas, escrevem 2 as
  duas, e uma operação do usuário evapora — o *lost update* que o
  `ecc:database-reviewer` apontou na T5 como problema **desta** camada.
  `SELECT ... FOR UPDATE` também resolveria, mas custa uma ida a mais ao banco
  e uma transação explícita para proteger um contador de inteiro, enquanto o
  `ON CONFLICT` usa o mesmo lock de linha que o `UPDATE` já toma. O
  `ON CONFLICT` ainda cobre a corrida de **criação** — duas abas incrementando
  uma variante ainda não possuída viram atualização em vez de
  `RecordNotUnique`, como os Edge Cases da spec exigem.
- **O piso de zero mora no `WHERE`, e um `WHERE` cobre os dois casos de
  rejeição.** `AND quantity > 0` faz o banco decidir, na mesma linha que vai
  travar, se ainda há o que decrementar; checar antes em Ruby reabriria a
  janela. Zero linha afetada é simultaneamente "já está em zero" e "não existe
  registro", e como `UPDATE` não cria linha, decrementar o que não existe não
  tem como produzir registro negativo — não há o que inserir. O
  `CHECK (quantity >= 0)` do schema continua sendo a garantia real (a T5 o
  prova por `UPDATE` direto); o `WHERE` é o que transforma a violação em
  mensagem em português em vez de 500. O sensor de discriminação confirmou:
  removido o `AND quantity > 0`, dois testes morrem com `PG::CheckViolation`.
- **Nenhuma migração, como previsto.** A tabela, o `UNIQUE`, o `CHECK` e as
  duas FKs `restrict` são da migração `20260919120200`; esta task só os
  consome.
- **Nada de view e nada de Turbo — é T8.** A resposta é `redirect_back
  fallback_location: catalog_path`, que devolve o usuário à grade ou ao
  detalhe de onde ele veio. Esse redirect não é provisório: depois da T8 ele
  continua sendo o caminho sem JavaScript, que os Edge Cases da spec exigem
  continuar funcionando.
- **Revisão do `ecc:security-reviewer`: zero achado CRITICAL ou HIGH.** O
  controller não tem `allow_unauthenticated_access`, então herda o default de
  `ApplicationController` e o anônimo é barrado **antes** de a action rodar —
  o teste prova isso pela ausência de registro, não só pelo 302. O SQL cru usa
  bind params (`exec_query` com `QueryAttribute`), sem interpolação; `params`
  só contribui com o id da variante, que é catálogo público. O CSRF do Rails
  está ativo (nada desativa `protect_from_forgery` em lugar nenhum) e o
  `UNIQUE` + o `WHERE user_id = $1` tornam a escrita cruzada estruturalmente
  impossível.
  - **O MEDIUM foi aceito, com a razão corrigida.** O revisor apontou
    `redirect_back` sem `allow_other_host: false` como open redirect teórico
    pelo `Referer`. **Medido: não era exploitável** —
    `config.load_defaults 8.0` liga `raise_on_open_redirects`, que é de onde
    sai o default do parâmetro, e um `Referer` de outro host já caía no
    `fallback_location` com 302, sem exceção. A correção entrou mesmo assim,
    por um motivo diferente do alegado: a garantia era **indireta**, vinda de
    uma config global que ninguém relaciona com a linha do redirect — o mesmo
    defeito que já está registrado como dívida no `secure` do cookie de
    sessão. Agora é explícita e tem teste de regressão próprio.
  - **O LOW foi recusado.** Guardar `Current.user` contra `nil` dentro da
    action duplicaria o trabalho do `before_action :require_authentication` e
    trocaria uma falha barulhenta por uma silenciosa: se alguém puser
    `allow_unauthenticated_access` aqui por engano, um `NoMethodError` é
    exatamente o que se quer ver, e não um incremento que não acontece. O
    próprio revisor classificou como "não é risco de segurança per se" e não
    pediu mudança de código.

**Tests**: integration
**Gate**: full

---

### T7: Isolamento entre usuários

**What**: Provar que toda leitura e escrita de coleção parte do usuário da sessão e que um id de outro usuário devolve 404.
**Where**: `test/integration/collection_authorization_test.rb`
**Depends on**: T6
**Requirement**: COL-05

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Dois usuários com a mesma variante veem apenas a própria quantidade
- [ ] Requisição com id de item de outro usuário devolve 404, não 403 — não revela existência
- [ ] Parâmetro `user_id` no request é ignorado; o usuário da sessão prevalece
- [ ] Nenhuma action do controller lê `params[:user_id]`

**Tests**: integration
**Gate**: full

---

### T8: Posse na grade e no detalhe, sem recarregar

**What**: Instalar o importmap e adicionar os controles de posse por variante na grade e no detalhe, atualizando sem recarga total via Turbo.
**Where**: `app/views/catalog/_card_tile.html.erb`
**Depends on**: T7
**Reuses**: o loop de variantes da view de detalhe e a folha de estilo do catálogo
**Requirement**: COL-10, COL-18

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `bin/rails importmap:install` executado (hoje não existem `app/javascript` nem `config/importmap.rb`)
- [ ] Controles presentes na grade e no detalhe, sempre por variante
- [ ] Atualização por Turbo Stream, sem recarregar a página inteira
- [ ] Sem JavaScript, incremento e decremento continuam funcionando por submissão normal
- [ ] Alvos de toque com no mínimo 24px, conforme a dívida de a11y registrada em `STATE.md`
- [ ] Teste de integração sobre o HTML renderizado; sem navegador no container, registrar `SPEC_DEVIATION` como nas tasks T12 e T14 da feature `catalogo`

**Tests**: integration
**Gate**: full

---

### T9: Parâmetro `owned` no `CatalogQuery`

**What**: Aceitar `owned` com valores `all`, `owned` e `missing`, com o usuário injetado pelo chamador e nunca lido da URL.
**Where**: `app/queries/catalog_query.rb`
**Depends on**: T8
**Reuses**: o query object existente, que já ignora parâmetro inválido em vez de levantar erro
**Requirement**: COL-11

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Contrato de `design.md` §4.2 respeitado: `all | owned | missing`
- [ ] Valor fora do contrato é ignorado, sem erro
- [ ] Sem usuário, o filtro é ignorado e o catálogo sai completo
- [ ] Semântica preservada: OU dentro da categoria, E entre categorias
- [ ] Variante com quantidade zero conta como não possuída
- [ ] Teste prova que a URL do catálogo com `owned` responde 200 para anônimo

**Tests**: unit
**Gate**: quick

---

### T10: Filtro de posse sem full table scan

**What**: Garantir que o filtro de posse não degrade o plano de execução, com índice se necessário.
**Where**: `test/queries/catalog_owned_plan_test.rb`
**Depends on**: T9
**Reuses**: o padrão do teste de plano da feature `catalogo`, que semeia dados com seletividade realista
**Requirement**: COL-11

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] O plano do filtro combinado com busca não mostra Seq Scan na tabela de coleção
- [ ] Dados semeados com seletividade realista — com filtro pouco seletivo o planejador escolhe Seq Scan com razão, e o teste não distinguiria índice ausente de índice ignorado por custo
- [ ] Se faltar índice, a migração é aditiva e o dump do schema é regenerado

**Tests**: unit
**Gate**: quick

---

### T11: Total de cartas possuídas

**What**: Exibir o total de cópias possuídas pelo usuário da sessão.
**Where**: `app/views/catalog/index.html.erb`
**Depends on**: T10
**Requirement**: COL-12

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Total soma cópias, não variantes distintas
- [ ] Variante com quantidade zero não entra no total
- [ ] Nada é exibido para anônimo
- [ ] Teste de integração confere o número com posse conhecida

**Tests**: integration
**Gate**: full

---

### T12: Tabela e model `wishlist_items`

**What**: Migração de `wishlist_items` com as mesmas garantias de banco da coleção, e o model correspondente.
**Where**: `db/migrate/` (migração nova)
**Depends on**: T11
**Reuses**: a migração da coleção como referência de FK `restrict` e constraints
**Requirement**: COL-14, COL-17

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] `UNIQUE (user_id, card_variant_id)`, `CHECK (target_quantity >= 1)` e FK `on_delete: :restrict`, conforme `design.md` §3.2
- [ ] Nenhuma FK em cascata — a ingestão não pode apagar dado do usuário
- [ ] Testes por SQL direto provam que as três garantias são do banco
- [ ] O teste de garantias da ingestão é estendido: rodar duas vezes com wishlist povoada e nenhum alvo muda

**Tests**: unit
**Gate**: full

---

### T13: Wishlist — marcar, listar, remover e sinalizar atendido

**What**: Controller e view da wishlist do usuário da sessão, com "atendido" derivado na consulta.
**Where**: `app/controllers/wishlist_items_controller.rb`
**Depends on**: T12
**Requirement**: COL-14, COL-15, COL-16, COL-17

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [ ] Marcar variante com alvo inteiro maior que zero; listar apenas os itens do usuário da sessão; remover
- [ ] "Atendido" é derivado comparando posse com alvo, nunca persistido como flag
- [ ] Item cuja variante sumiu da fonte continua listado — a ingestão não deleta
- [ ] Anônimo é redirecionado; id de item de outro usuário devolve 404
- [ ] Teste de integração cobre alvo 2, posse 1 (não atendido), posse 2 (atendido) e remoção

**Tests**: integration
**Gate**: full

---

## Plano de delegação

Não existe `ruby-reviewer` nem `rails-reviewer` entre os agentes instalados.
O padrão herdado da feature `catalogo`: lote por fase, revisão pelos agentes
agnósticos de linguagem.

| Fase | Execução | Revisão |
|---|---|---|
| 1 (T1–T4) | lote único — T1 fixa as convenções de autenticação que T2–T4 herdam | `ecc:security-reviewer` no concern e no controller de sessão |
| 2 (T5–T8) | lote único | `ecc:database-reviewer` nas constraints; `ecc:a11y-architect` nos controles de posse |
| 3 (T9–T13) | lote único | `ecc:database-reviewer` no plano de execução de T10; `ecc:pr-test-analyzer` nos testes de isolamento e wishlist |

Verifier ao fim de cada lote, autor ≠ verificador, relatório em
`.specs/features/colecao/validation.md`.

Coletas mecânicas (ler arquivo, listar símbolo, extrair formato) vão para
subagentes Haiku com prompt fechado e leitura apenas. Decisão de design,
resolução de colisão e escrita de spec ficam com o orquestrador.

Sensor de mutação, se rodar, vai em worktree ou cópia — **nunca `git stash`**:
há trabalho não commitado com frequência neste repo.
