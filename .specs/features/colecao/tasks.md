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

### T7: Isolamento entre usuários ✅

**What**: Provar que toda leitura e escrita de coleção parte do usuário da sessão e que um id de outro usuário devolve 404.
**Where**: `test/integration/collection_authorization_test.rb`
**Depends on**: T6
**Requirement**: COL-05

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Dois usuários com a mesma variante veem apenas a própria quantidade
- [x] Requisição com id de item de outro usuário devolve 404, não 403 — não revela existência — **`SPEC_DEVIATION`: não existe rota por id de item; o critério é satisfeito por construção e migra para a T13** (ver decisão abaixo)
- [x] Parâmetro `user_id` no request é ignorado; o usuário da sessão prevalece
- [x] Nenhuma action do controller lê `params[:user_id]`

**Decisões da execução:**

- **Não acrescentar rota por id de item — decisão do orquestrador, não da
  execução.** O segundo critério pressupõe uma URL que aceite id de
  `collection_item`, e a T6 não criou nenhuma: as rotas são
  `POST /collection_items/:card_variant_id/increment|decrement`, chaveadas pela
  variante porque o botão nasce na grade do catálogo, onde o registro ainda não
  existe. A T6 deixou a escolha aberta ("acrescentar rota por id ou reformular o
  critério") e o orquestrador decidiu pela segunda, por três razões: (1) o
  requisito de origem, `.context/requirements.md` Req. 6.5, diz literalmente
  *"Um usuário NUNCA DEVE conseguir ler ou alterar a coleção de outro usuário"*
  e **não** menciona 404 nem id — o "404 por id" é uma operacionalização que a
  `spec.md` escolheu assumindo um desenho REST por id de item, que a T6 não
  adotou por razão de produto; (2) criar rota por id só para ter o que testar
  produziria superfície de ataque que o produto não usa, e código morto; (3) o
  critério se cumpre integralmente na **T13 (wishlist)**, que tem remoção por
  item e portanto id na URL de verdade — lá o teste de 404 é real, não encenado.
  O `SPEC_DEVIATION` está no cabeçalho de
  `test/integration/collection_authorization_test.rb`.
- **A ausência é provada por teste, não afirmada em comentário.**
  `"nenhuma rota de collection_items aceita id de item"` percorre
  `Rails.application.routes.routes`, filtra o controller e asserta que os
  segmentos obrigatórios de **toda** rota dele são exatamente
  `["card_variant_id"]`. Acrescentar `get "collection_items/:id"` quebra a suíte
  com a mensagem que aponta para o `SPEC_DEVIATION` — quem quiser a rota
  enfrenta a decisão em vez de contorná-la em silêncio. Verificado no sensor: a
  rota por id foi acrescentada de fato e o teste morreu.
- **O critério "`user_id` é ignorado" ganhou a metade que faltava: o
  decremento.** A T6 já provava o incremento. O decremento é o caso perigoso —
  um `user_id` aceito ali **subtrai** da coleção alheia, e o teste
  correspondente é o que mais dói no sensor (a quantidade do outro usuário cai
  de 5 para 4). Cobertos os três vetores: corpo do POST, query string e o caso
  em que o request informa o usuário *correto* (que passaria mesmo com a leitura
  do parâmetro — existe para fixar a semântica, e o teste ao lado é o que mata a
  mutação).
- **O critério "nenhuma action lê `params[:user_id]`" é estrutural, e por isso
  tem um teste estrutural.** Os testes de comportamento só pegam a leitura que
  exercitam; um `params[:user_id]` numa action nova passaria por eles. O teste
  lê o fonte do controller, descarta as linhas de comentário (o arquivo
  *menciona* `params[:user_id]` na justificativa, e sem o filtro o teste seria
  falso-positivo) e asserta a ausência do acesso — inclusive de
  `params.permit/require/fetch/expect`, que é a forma indireta de deixá-lo
  entrar.
- **Nenhuma migração e nenhuma mudança de produção, como previsto.** A task é de
  prova: o isolamento já era do desenho da T5 (`for_user` exige o objeto `User`)
  e da T6 (`WHERE user_id = $1` em ambos os statements). **Nenhum defeito de
  autorização foi encontrado** — as três mutações do sensor confirmaram que o
  que existe é o que segura, não um acaso.
- **Sensor de discriminação, três mutações, por cópia e `cp`/`diff` — nunca
  `git stash`.** (1) `Current.user.id` → `params[:user_id] || Current.user.id`
  nas duas actions: **4 testes morrem**, incluindo o decremento cruzado real
  (5 → 4). (2) `WHERE user_id = $1` removido do decremento: **2 testes morrem**,
  entre eles o de dois usuários com quantidades independentes (9 → 8).
  (3) `get "collection_items/:id"` acrescentado às rotas: **1 teste morre**, o
  de ausência de rota por id. Depois da revisão, mais três mutações sobre o
  teste estrutural reescrito em AST: `params.dig(:user_id)`,
  `params.to_unsafe_h[:user_id]` e `params.permit(:user_id)[:user_id]` — **as
  três matam 4 testes cada**, e as três passariam pela versão de regex.
  Restauração conferida com `diff` em todas.
- **Revisão do `ecc:pr-test-analyzer`: zero achado CRITICAL; um HIGH e três
  MEDIUM, três aceitos e dois recusados.**
  - **HIGH aceito, e era procedente.** A primeira versão do teste do critério 4
    era **regex sobre o texto do fonte**, e o revisor listou escapes reais:
    `params.dig(:user_id)`, `params.to_unsafe_h[:user_id]` e indireção por
    variável passariam sem ser detectados — justamente as formas que alguém
    escreveria *sem saber* que existe um teste a respeito. Um teste de
    isolamento que não pega a forma idiomática do desvio não vale nada.
    Reescrito para análise de **AST** (`Ripper.sexp`): a asserção é que o
    conjunto de chaves lidas de `params` no controller é exatamente
    `[:card_variant_id]`. **Verificado por sensor**, as quatro formas agora
    morrem: `[:user_id]`, `.dig`, `.to_unsafe_h[...]` e `.permit(...)`.
  - **MEDIUM aceito: a asserção era superampla.** A versão de regex proibia
    qualquer `params.permit/require/fetch/expect` no controller, o que quebraria
    a T8 por motivo não relacionado a autorização se ela precisasse de outro
    parâmetro legítimo. A versão de AST não proíbe método nenhum — ela pergunta
    *quais chaves* saem de `params`, então um `permit(:card_variant_id)` legítimo
    passa e um `permit(:user_id)` não.
  - **MEDIUM aceito: rota sob namespace escapava do teste de rotas.** O filtro
    era `defaults[:controller] == "collection_items"`, que não pegaria
    `api/collection_items` — a rota nova escaparia em silêncio e o teste
    continuaria verde. Agora o casamento é por sufixo do caminho do controller.
  - **MEDIUM aceito: faltava a resposta do decremento.** O teste de decremento
    cruzado conferia só o estado do banco; um defeito que escrevesse na linha
    certa mas **relatasse** a quantidade da linha do outro usuário seria
    vazamento sem alteração, e nenhuma asserção o pegaria. O teste do incremento
    já tinha esse par; o do decremento passou a ter.
  - **LOW recusado: a duplicação com `collection_items_test.rb` é deliberada.**
    O teste de `user_id` no incremento existe nos dois arquivos. O revisor
    aponta, corretamente, que remover um não reduziria a cobertura. Fica: o
    arquivo de autorização precisa ser legível como o conjunto completo do
    Req. 6.5 — quem abrir procurando "o que prova o isolamento" não deve ter de
    montar a resposta a partir de dois arquivos. Custo: um teste redundante.
  - **LOW recusado, com a observação incorporada ao código:** o teste "a sessão
    prevalece mesmo com `user_id` correto" não mata a mutação sozinho, e o
    revisor confirmou que o comentário do próprio teste já dizia isso. Ele fica
    porque fixa a semântica (a posse creditada é a da sessão), e o comentário já
    aponta qual teste ao lado é o que mata.
  - **Nota do revisor sobre `card_variant_id` não-numérico**: fora do escopo do
    Req. 6.5, e a query usa bind params tipados. Não vira teste aqui; registrado
    para quem mexer na T8.

**Tests**: integration
**Gate**: full

---

### T8: Posse na grade e no detalhe, sem recarregar ✅

**What**: Instalar o importmap e adicionar os controles de posse por variante na grade e no detalhe, atualizando sem recarga total via Turbo.
**Where**: `app/views/catalog/_card_tile.html.erb`
**Depends on**: T7
**Reuses**: o loop de variantes da view de detalhe e a folha de estilo do catálogo
**Requirement**: COL-10, COL-18

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] `bin/rails importmap:install` executado (hoje não existem `app/javascript` nem `config/importmap.rb`)
- [x] Controles presentes na grade e no detalhe, sempre por variante
- [x] Atualização por Turbo Stream, sem recarregar a página inteira
- [x] Sem JavaScript, incremento e decremento continuam funcionando por submissão normal
- [x] Alvos de toque com no mínimo 24px, conforme a dívida de a11y registrada em `STATE.md`
- [x] Teste de integração sobre o HTML renderizado; sem navegador no container, registrar `SPEC_DEVIATION` como nas tasks T12 e T14 da feature `catalogo`

**Decisões da execução:**

- **Na grade o controle direto só existe quando a carta tem uma variante só, e
  a decisão saiu de uma medição.** O "Done when" pede controle na grade
  "sempre por variante", mas a grade renderiza **cartas**. Medido no catálogo
  real (2815 cartas): **1129 (40,1%) têm mais de uma variante** e 1686 (59,9%)
  têm exatamente uma. Isso elimina as duas saídas ingênuas. Um controle único
  por tile **agregaria a posse na carta em 40% dos casos**, violação direta do
  Req. 5.3 de `.context/requirements.md` (*"o registro DEVE ser feito por
  variante, nunca agregado na carta"*). Empilhar N controles por tile destrói a
  grade em 360px sem scroll horizontal (Req. 2.5), requisito vigente e já
  verificado no `catalogo`. O desenho entregue: com **uma** variante o controle
  é inequívoco e aparece no tile; com **mais de uma**, o tile mostra "N
  impressões" e leva ao detalhe, onde a escolha da variante é explícita. Um
  controle que agregasse seria mais cômodo e estaria errado. No **detalhe**
  não há ambiguidade nenhuma: o controle vai em cada variante, dentro do loop
  `@variants` que já existia.
- **Um partial só, usado nos dois lugares.** `collection_items/_ownership`
  serve grade e detalhe. Duplicar o markup faria cada correção de a11y precisar
  ser lembrada duas vezes — e foram cinco correções nesta task.
- **`turbo_stream.update`, não `replace`, e a diferença é de acessibilidade.**
  `update` troca os **filhos** e preserva o elemento; `replace` troca o próprio
  nó. Como a região `aria-live` mora no elemento alvo, `replace` a recriaria a
  cada operação — e uma região viva recém-inserida no DOM **não anuncia**. Com
  `replace`, a quantidade mudaria em silêncio para quem usa leitor de tela. O
  sensor confirmou: trocado para `replace`, dois testes morrem.
- **O `format.html` da T6 continua sendo o caminho de produção, não resíduo.**
  `respond_to` põe `format.html` **primeiro**: quem não pede Stream recebe o
  `redirect_back`. É o que os Edge Cases da spec exigem (*"IF o JavaScript não
  estiver disponível, THEN incremento e decremento continuam funcionando por
  submissão normal"*), e `button_to` gera formulário POST de verdade com token
  CSRF — nada no controle depende de JS para funcionar. O sensor confirmou:
  removido o `format.html`, cinco testes morrem, três deles da própria T6.
- **Os dois statements atômicos da T6 não foram tocados.** O `ON CONFLICT` do
  incremento e o `UPDATE ... WHERE quantity > 0` do decremento estão idênticos.
  O que a task mudou foi **a renderização da resposta**, não a escrita nem a
  origem do usuário — o aviso registrado na T7 em `STATE.md` era exatamente
  sobre isso.
- **Defeito encontrado e corrigido na própria task, e ele era silencioso.**
  `CatalogController` declara `allow_unauthenticated_access`, que remove o
  `before_action :require_authentication` — e era **ele** que resolvia a sessão
  a partir do cookie assinado. Sem isso, `Current.session` ainda era `nil` na
  action e **todo usuário autenticado via quantidade zero**, porque a sessão só
  seria resolvida mais tarde, quando a view chamasse `authenticated?` para
  decidir se mostra os botões. A página respondia 200, os controles apareciam e
  a posse sumia. Corrigido com uma chamada a `authenticated?` antes de ler
  `Current.user` (`resume_session` é idempotente, então a view não repete a
  consulta). O defeito foi encontrado **pelo teste**, não por leitura.
- **N+1 resolvido no controller, não no tile.** O tile precisa saber quantas
  variantes a carta tem e quanto o usuário possui; perguntar por tile seriam
  duas consultas por carta, 48 numa página de 24. `CatalogController#index`
  resolve as variantes com `ActiveRecord::Associations::Preloader` (e não
  `includes`: o `CatalogQuery` monta a página em Ruby e entrega um **Array**,
  não uma relação) e as quantidades com um `pluck` de conjunto. Há teste que
  conta consultas com limite folgado de propósito — o que ele protege é a
  **ausência de crescimento linear**, não um número exato, que quebraria em
  toda mudança inócua. O sensor confirmou: removido o `Preloader`, o teste
  acusa 27 consultas contra o limite de 20.
- **Stimulus não foi pinado.** A gem está no Gemfile desde o esqueleto, mas
  esta task não tem um único controller Stimulus: o Turbo Stream é declarativo
  e chega pronto do servidor. Pinar o que não se usa carregaria JS em toda
  página para nada. Turbo é pinado para `turbo.js`, servido pelo Propshaft a
  partir da própria gem — sem download e sem `vendor/javascript` a versionar.
- **Plural explícito em vez de `pluralize`.** O inflector do Rails é inglês e
  não sabe acentuação portuguesa: `"cópia".pluralize(2)` devolve `"cópia"`, e a
  frase **anunciada pelo leitor de tela** sairia "2 cópia". Um `Inflector` em
  português resolveria para o app inteiro, mas é mudança de configuração
  global; fica como dívida.
- **Revisão do `ecc:a11y-architect`: zero CRITICAL, um HIGH e dois MEDIUM
  aceitos, um LOW recusado.**
  - **HIGH aceito, e o cenário era concreto:** o botão de decremento usava
    `disabled` de verdade. Com uma cópia, o usuário foca o "−1" e aperta Enter;
    o Turbo re-renderiza o botão já em zero, um `disabled` sai da árvore de
    foco, o navegador joga o foco para o `<body>` e quem navega por teclado
    recomeça a tabulação do topo da página (SC 2.4.3). Trocado por
    `aria-disabled`, que comunica o mesmo estado e mantém o botão focável. É
    seguro justamente porque o piso de zero **não** depende do botão: o
    `WHERE quantity > 0` recusa o clique e responde a mensagem em português.
    A folha passou a estilizar `[aria-disabled="true"]`. Sensor: revertido para
    `disabled`, o teste morre.
  - **MEDIUM aceito:** a região `aria-live` anunciava só o `variant_code`, sem
    o nome da carta — menos informativo que o `aria-label` do botão que
    originou a ação. Numa grade, "3 cópias" sozinho não identifica nada. O nome
    entrou na região.
  - **MEDIUM aceito:** havia uma região de flash única com `role="alert"`, que
    implica `aria-live="assertive"` e **interrompe** a fala corrente. Isso é o
    que se quer para uma recusa e é demais para o retorno de rotina de um "+1":
    quem registra uma caixa de boosters aperta o botão dezenas de vezes, e cada
    incremento cortaria a leitura em andamento. Separado em `role="status"`
    (polite) para o `notice` e `role="alert"` (assertive) para o `alert`, cada
    um com `id` próprio e atualizado pelo Stream. O `role` mora no contêiner que
    **permanece**, pela mesma razão do `update` vs `replace`.
  - **LOW recusado, por não ser acionável:** contraste do `outline` de foco,
    que usa `currentcolor`. O próprio revisor marcou como "não confirmado" e
    disse depender de paleta que não existe — o projeto **não declara nenhuma
    cor**, então `currentcolor` é a cor de texto do navegador sobre o fundo do
    navegador. Não há o que corrigir sem antes haver uma paleta; registrado
    como dívida para quando houver.
- **`SPEC_DEVIATION` registrado no cabeçalho de
  `test/integration/collection_ownership_ui_test.rb`**, no padrão das T12/T14
  do `catalogo`: não há navegador no container, então "atualiza sem recarregar"
  é provado sobre o `text/vnd.turbo-stream.html` renderizado — que a resposta é
  um `<turbo-stream action="update">` mirando só o contêiner daquela variante,
  que o alvo é o mesmo `id` que a página renderiza, e que a mesma rota sem
  `Accept` de Stream responde `redirect_back`. O que **não** fica coberto é a
  aplicação do Stream ao DOM por um navegador real.
- **Sensor de discriminação, seis mutações, por cópia e `cp`/`diff` — nunca
  `git stash`.** (1) tile renderizando controle para carta de várias variantes
  (`variants.one?` → `variants.any?`): **3 testes morrem**. (2) `format.html`
  removido do `respond_to`: **5 testes morrem**, três deles da T6. (3)
  `turbo_stream.update` → `replace`: **2 morrem**. (4) `Preloader` removido:
  **1 morre**, acusando 27 consultas. (5) chamada a `authenticated?` removida
  do `CatalogController`: **1 morre** — é a mutação que reproduz o defeito
  silencioso encontrado na task. (6) `aria-disabled` → `disabled`: **1 morre**.
  Restauração conferida com `diff` em todas as seis.
- **Nenhuma migração, como previsto.** A task é de view, controller e
  configuração de asset; nada toca schema.

**Tests**: integration
**Gate**: full

---

### T9: Parâmetro `owned` no `CatalogQuery` ✅

**What**: Aceitar `owned` com valores `all`, `owned` e `missing`, com o usuário injetado pelo chamador e nunca lido da URL.
**Where**: `app/queries/catalog_query.rb`
**Depends on**: T8
**Reuses**: o query object existente, que já ignora parâmetro inválido em vez de levantar erro
**Requirement**: COL-11

**Tools**:

- MCP: NONE
- Skill: NONE

**Done when**:

- [x] Contrato de `design.md` §4.2 respeitado: `all | owned | missing`
- [x] Valor fora do contrato é ignorado, sem erro
- [x] Sem usuário, o filtro é ignorado e o catálogo sai completo
- [x] Semântica preservada: OU dentro da categoria, E entre categorias
- [x] Variante com quantidade zero conta como não possuída
- [x] Teste prova que a URL do catálogo com `owned` responde 200 para anônimo

**Decisões da execução:**

- **A semântica com várias variantes é a decisão central da task, e ela é de
  partição.** `owned` = a carta tem **ao menos uma** variante possuída;
  `missing` = a carta **não tem nenhuma**. As duas são complementares:
  `owned ∪ missing == all` e `owned ∩ missing == ∅`, e há teste que asserta
  exatamente isso. A alternativa ("`missing` = falta alguma variante") faria as
  duas se **sobrepor** em 40,1% do catálogo — a fração de cartas com mais de uma
  variante que a T8 mediu (1129 de 2815) —, e a carta com a base possuída e o
  parallel faltando apareceria nos dois filtros ao mesmo tempo. "O que eu tenho"
  e "o que me falta" deixariam de ser respostas a perguntas opostas, que é o que
  o Req. 7.6 pede. Completude **por impressão** é outro requisito, o Req. 9
  (progresso por set), que tem métrica própria e denominador decidido em AD-003;
  resolvê-la aqui atropelaria aquela decisão. O teste que discrimina as duas
  leituras é o da carta com uma de três variantes possuídas.
- **O mesmo problema de `sets` e `rarities`, logo a mesma forma.** Posse é por
  variante e o query object devolve **cartas**: `collection_items` referencia
  `card_variants`, e não há coluna de posse em `cards`. O predicado atravessa
  `card_variants` em subconsulta, como `VARIANT_FILTERS`/`#variant_card_ids` já
  faziam. Nenhum caminho novo foi inventado.
- **`NOT EXISTS`, não `NOT IN`, e a razão é de robustez futura.**
  `id NOT IN (subconsulta)` devolve **zero linhas** se um único valor do
  conjunto for NULL, porque `x <> NULL` é NULL e não falso — falha silenciosa,
  sem erro e sem teste que acuse. Hoje `card_variants.card_id` e
  `collection_items.card_variant_id` são ambos `NOT NULL` e o `NOT IN`
  funcionaria; o `NOT EXISTS` é o que mantém a consulta correta no dia em que
  isso mudar. O `ecc:database-reviewer` confirmou: não há bug de NULL, e a
  negação incide sobre o `EXISTS` inteiro, nunca sobre o `IN` interno.
- **Zero é linha existente, e o recorte sai dos scopes do model.** O predicado
  parte de `CollectionItem.for_user(@user).owned` (`quantity >= 1`), não da
  existência do registro. Quem zerou uma quantidade mantém a linha e tem que
  voltar a aparecer em `missing`; usar existência como critério deixaria essa
  pessoa fora dos dois filtros. Há teste provando que quantidade zero e ausência
  de registro dão o **mesmo** resultado no filtro.
- **O usuário é injetado como segundo argumento e é impossível vir da URL.**
  `CatalogQuery.new(params, Current.user)`. Não existe caminho de `@params` para
  `@user` dentro do objeto — o que torna `?owned=owned&user_id=7` ruído, provado
  por quatro testes (dois no query object, dois na integração, um deles anônimo).
  A barreira de tipo continua sendo `CollectionItem.for_user`, que levanta
  `ArgumentError` para qualquer coisa que não seja `User` ou `nil`.
- **Posicional, não nomeado, e a descoberta custou uma rodada da suíte.** A
  primeira versão usava `user:` nomeado. Em Ruby, isso faz
  `CatalogQuery.new(colors: [ "Green" ])` — a forma que **todos** os 54
  chamadores existentes usam — ser interpretada como lista de keywords, e a
  suíte estourou com `ArgumentError: unknown keyword: :colors` em 54 testes.
  Posicional com default `nil`, a forma antiga continua válida e nenhum chamador
  precisou ser tocado.
- **`all` é o default e não vira chip.** Não há o que remover num chip "todas":
  `all` é a ausência de recorte, não um filtro ativo. Só `owned` e `missing`
  entram em `active_filters`. Pelo mesmo critério já vigente no arquivo, valor
  fora do contrato e filtro descartado por falta de usuário também não viram
  chip — o chip só representa filtro que está de fato valendo.
- **O `authenticated?` do `CatalogController` valia para a T9 também, e essa
  era a armadilha silenciosa.** `allow_unauthenticated_access` remove o
  `before_action :require_authentication`, que era quem resolvia a sessão: sem a
  chamada, `Current.user` seria `nil` na action e o filtro sairia **ignorado**
  para quem está autenticado, com a página respondendo 200 e o catálogo inteiro
  na tela. É o mesmo defeito que a T8 encontrou em `#owned_quantities`. A
  chamada foi movida para o topo da action, antes de montar o query object.
- **O filtro não passa por `@owned_quantities`, por instrução da T8 e por
  correção.** Aquele hash cobre só as variantes da página corrente e é camada de
  view; filtrar em Ruby sobre a página já paginada filtraria **depois** de
  paginar e devolveria página incompleta. Filtro é consulta.
- **Nenhuma migração e nenhum índice, como previsto.** Índice é a T10, que
  existe para medir o plano desta consulta.
- **Revisão do `ecc:database-reviewer`: zero CRITICAL; um HIGH aceito, um
  índice registrado para a T10, o resto confirmado correto.**
  - **HIGH aceito, e a falha seria silenciosa:** a subconsulta correlacionava
    por `scope.arel_table[:id]`, isto é, pela tabela do escopo recebido. Funciona
    hoje porque `filtered_scope` sempre parte de `cards`, mas o dia em que ele
    passar por um alias ou uma subconsulta a correlação aponta para a coluna
    errada **sem erro de sintaxe** — consulta que devolve o conjunto errado em
    silêncio. Trocado por `Card.arel_table[:id]`: a raiz é fixa no código porque
    é fixa de fato.
  - **Índice registrado para a T10, não criado aqui:** o
    `UNIQUE (user_id, card_variant_id)` existente localiza o usuário mas **não**
    filtra `quantity`, então a checagem de `quantity >= 1` volta à heap. O
    candidato é um índice **parcial**
    `collection_items (user_id, card_variant_id) WHERE quantity >= 1`, que
    permitiria Index Only Scan. O próprio revisor pediu medição antes: a tabela
    pode ser pequena o bastante para o planejador preferir Seq Scan com razão —
    que é exatamente o cuidado de seletividade realista que o "Done when" da T10
    já exige.
  - **Confirmado correto, sem ação:** o `IN` interno é seguro (a coluna é
    `NOT NULL` e a negação incide sobre o `EXISTS`, não sobre ele); a precedência
    de `NOT` não vaza para o predicado irmão, então `E` entre categorias
    continua valendo no SQL gerado; `index_card_variants_on_card_id` já cobre o
    lado correlacionado.
  - **Recusado por não mudar nada:** reescrever o `IN` interno como `JOIN`. O
    próprio revisor mediu que o planejador achata os dois na mesma forma de
    semi-join, então a troca seria churn sem ganho — e o registro dessa conclusão
    poupa a T10 de tentar.
  - **LOW recusado:** `LIMIT 1`/`DISTINCT` na subconsulta interna. O revisor
    classificou como irrelevante para correção e provavelmente para performance,
    porque o semi-join já para na primeira correspondência.
- **Sensor de discriminação, cinco mutações, por cópia e `cp`/`diff` — nunca
  `git stash`.** (1) `missing` devolvendo o mesmo que `owned` (`exists.not` →
  `exists`): **9 testes morrem**. (2) filtro valendo sem usuário
  (`return nil if @user.nil?` removido): **5 morrem**, entre eles o de integração
  do anônimo. (3) quantidade zero contando como posse (scope `owned` removido,
  virando existência de registro): **10 morrem**. (4) usuário lido de
  `params[:user_id]` — a falha de autorização que a task existe para impedir:
  **3 morrem**, incluindo o teste anônimo de integração. (5) valor inválido
  caindo em `"owned"` em vez de ser ignorado: **3 morrem**. Restauração conferida
  com `diff` em todas as cinco.

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
