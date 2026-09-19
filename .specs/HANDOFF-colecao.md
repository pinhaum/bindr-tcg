# Handoff — feature `colecao` (Fase 4)

Documento de entrada para uma sessão nova. Leia este arquivo inteiro antes de
escrever qualquer linha de código. Ele condensa estado, decisões já tomadas e
armadilhas de ambiente; o que ele não cobre está em `.specs/STATE.md`.

O `HANDOFF-fase-4.md`, ao lado deste, descreve o **fim** da feature `catalogo` e
continua válido como histórico. Este descreve o **início** da `colecao`.

## Onde o projeto está

A feature `catalogo` está **encerrada e verificada** (14 tasks, dois lotes, ambos
PASS em `.specs/features/catalogo/validation.md`). Catálogo, busca, filtros,
grade e detalhe funcionam e são públicos.

A feature `colecao` tem **spec e plano escritos e validados, e nenhuma task
executada**:

- `.specs/features/colecao/spec.md` — 18 requisitos (COL-01..COL-18), Req. 6–8 e 5.3
- `.specs/features/colecao/tasks.md` — 13 tasks (T1..T13) em três fases

Ambos passam nos validadores com zero erro e zero warning.

## A primeira coisa a não fazer

**Não rode `bin/rails generate authentication`.** A decisão está registrada na
spec, com a leitura do fonte da gem (`railties-8.0.5.1`). O gerador causa quatro
conflitos:

1. `generate "migration CreateUsers ... --force"` cria um **segundo**
   `create_table :users` — a tabela já existe (migração `20260919120200`) e o
   `db:migrate` quebra.
2. Ele usa `email_address`; a tabela tem `email` e o índice
   `index_users_on_lower_email`.
3. `template "app/models/user.rb"` **sobrescreve** o model e apaga
   `has_many :collection_items, dependent: :restrict_with_exception` — a linha
   que impede a ingestão de destruir dado irrecuperável (Req. 1.7). Some em
   silêncio, sem erro.
4. `uncomment_lines "Gemfile"` + `bundle install` não atravessa o volume nomeado
   `bundle`, que sombreia as gems da imagem.

**O que fazer no lugar:** portar à mão `Session`, `Current`, o concern
`Authentication` e o `SessionsController` a partir dos templates em
`/usr/local/bundle/gems/railties-8.0.5.1/lib/rails/generators/rails/authentication/templates/`,
mantendo a coluna `email` e preservando o `User` atual.

Isso é barato porque `ActiveRecord.authenticate_by` particiona os argumentos por
`has_attribute?` (`activerecord-8.0.5.1/lib/active_record/secure_password.rb:41`):
`email:` funciona sem nenhuma adaptação — a doc da própria gem usa `email:`.

## Por onde começar

Execute **T1** de `.specs/features/colecao/tasks.md`, e só ela. Uma task por vez,
em ordem, cada uma terminando com teste que passa e um commit atômico.

Ordem das fases:

```
Fase 1 (T1–T4)  identidade e sessão
Fase 2 (T5–T8)  posse
Fase 3 (T9–T13) filtro, total e wishlist
```

## Método de trabalho

- Uma task por vez. Não abra a próxima com a anterior incompleta.
- "Estrutura criada" não é task concluída — precisa de código que roda e teste
  que passa.
- Ao concluir, marque o checkbox **nos dois planos** (`.context/tasks.md` §4 e
  `.specs/features/colecao/tasks.md`) e commite junto com o código.
- Se um requisito se mostrar errado, **pare e corrija `.context/requirements.md`**
  antes de continuar. Não improvise no código.
- Conventional Commits, em português, **sem linha de atribuição** de nenhum tipo.
- Divergência deliberada entre spec e código leva um comentário `SPEC_DEVIATION`
  no próprio arquivo, como em `app/models/card_set.rb`.

### Delegação

O padrão pedido pelo usuário e usado para escrever esta spec: **coletas mecânicas
vão para subagentes Haiku, com prompt fechado e leitura apenas** — ler arquivo,
listar símbolo, extrair formato, conferir consistência entre dois documentos.
Decisão de design, resolução de colisão e escrita de spec ficam com o
orquestrador. O plano de delegação por fase está no fim de `tasks.md`.

Prompt de subagente que funcionou bem aqui: escopo fechado, "LEITURA APENAS, não
edite, não rode docker", lista numerada do que coletar, e "sem análise nem
recomendação — só os fatos; se não existir, diga que não existe".

Revisão pelos agentes agnósticos de linguagem — **não existe `ruby-reviewer` nem
`rails-reviewer`** entre os instalados: `ecc:security-reviewer` no concern e no
controller de sessão, `ecc:database-reviewer` nas constraints e no plano de
execução, `ecc:a11y-architect` nos controles de posse, `ecc:pr-test-analyzer`
nos testes de isolamento.

## Comandos

```bash
cp .env.example .env
docker compose up                                   # db + app em :3000
docker compose exec app bin/rails test
docker compose exec app bin/rubocop
docker compose run --rm --no-deps app bundle install # OBRIGATÓRIO para gem nova
```

Gates: **quick** = `bin/rails test test/models test/queries`;
**full** = `bin/rails test && bin/rubocop`; **build** = `docker compose build`.

Validadores (devem continuar com zero erro):

```bash
SKILL=~/.claude/skills/tlc-spec-driven
python3 $SKILL/scripts/validate_spec.py  .specs/features/colecao/spec.md
python3 $SKILL/scripts/validate_tasks.py .specs/features/colecao/tasks.md
python3 spec/verify_fixture.py            # offline, 12 verificações
```

## Armadilhas de ambiente — todas já custaram tempo

- **Gem nova exige `docker compose run --rm --no-deps app bundle install`.**
  Mudar o Gemfile e reconstruir a imagem **não basta**: o volume nomeado `bundle`
  sombreia as gems da imagem e o container sobe com `Bundler::GemNotFound`.
  Isso atinge a T1 diretamente.
- **`RAILS_ENV` posicional não é lido pelo `bin/rails`.**
  `bin/rails db:drop RAILS_ENV=test` apaga o banco de **desenvolvimento** e leva
  o catálogo junto. Use `env RAILS_ENV=test bin/rails ...` ou
  `bin/rails db:test:prepare`. Recuperação sem rede:
  `REUSE_PAYLOAD=1 bin/rails ingestion:import`.
- **`tmp/pids/server.pid` órfão impede o app de subir**, com
  `A server is already running (pid: 1)` e sem erro óbvio.
  `rm -f tmp/pids/server.pid`.
- **Docker em WSL:** `~/.docker/config.json` tem `"credsStore": "desktop.exe"`,
  que não existe no PATH. Contorno no README via `DOCKER_CONFIG`.
  **Não editar o config global do usuário.**
- **`schema_format = :sql`.** Migração nova exige `db:migrate` para regenerar
  `db/structure.sql`. O índice trigram depende da função `immutable_unaccent`,
  que o formato Ruby não representa.
- **`json` pinada em `~> 2.7`.** A 3.x quebra toda escrita em coluna `jsonb`.
- **Sem navegador no container**, logo não há system test. Teste de UI vira teste
  de integração sobre HTML renderizado, com `SPEC_DEVIATION` registrado — foi o
  que se fez nas T12/T14 do `catalogo`. Afeta a T8.
- **Sensor de mutação vai em worktree ou cópia — nunca `git stash`.** Há trabalho
  não commitado com frequência neste repo.

## Dois pontos que a T4 e a T8 vão encostar

- **`rate_limit` precisa de cache store real.** O template do
  `SessionsController` traz `rate_limit to: 10, within: 3.minutes`. Em teste o
  store é `:null_store` (não conta nada, e um teste do limite passaria vazio); em
  produção `config.cache_store` está **comentado**, então cai no default
  `:file_store` em `tmp/cache/`, que é por container e não sobrevive a recreate.
  Decida explicitamente e registre em comentário — não copie o template sem olhar.
- **O importmap não está instalado.** Não existem `app/javascript` nem
  `config/importmap.rb`; `stimulus-rails` está no Gemfile mas nunca foi
  executado, e o placeholder de imagem do catálogo foi resolvido por CSS.
  O Req. 7.5 (atualizar sem recarregar) depende de instalar o importmap na T8.

## Dívida herdada do `catalogo`

Nada aqui bloqueia a Fase 4.

- T12/T14 sem cobertura de navegador (ver acima).
- Três melhorias de a11y não bloqueantes: `lang="en"` no conteúdo em inglês,
  `min-height/min-width: 24px` nos alvos de toque (SC 2.5.8) e reforço do
  indicador de foco (SC 2.4.11). A T8 deve já nascer com os 24px.
- `guarantees_test.rb` falhou uma vez em ~20 execuções por contenção entre os
  workers paralelos. Se voltar, congele o relógio (`Upsert` aceita `clock:`) —
  **não** afrouxe a asserção.

## Contexto que não está nos documentos

- A rota do catálogo é `/catalog`; `/cards/:id` é o detalhe; `root` aponta para
  `catalog#index`.
- O app nasceu como `railsgen` e foi renomeado à mão; o módulo é `Bindr`. Resíduo
  com esse nome é lixo, não referência válida.
- Dois nomes divergem de `design.md` §3.2 por colisão com Ruby/Rails, ambos
  marcados com `SPEC_DEVIATION`: a coluna `attributes` virou `attributes_list` e
  o model `Set` virou `CardSet` (a tabela continua `sets`).
- O projeto **não usa fixtures YAML**: cada teste cria seus registros no `setup`.
  `fixtures :all` em `test_helper.rb` é resíduo do esqueleto.
- Testes de constraint vão ao banco por SQL direto, para provar que a garantia é
  do schema e não do Active Record. Veja `test/models/catalog_schema_test.rb`.
- `config/master.key` existe, então cookie assinado funciona em desenvolvimento e
  teste sem configuração extra.
