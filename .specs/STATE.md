# STATE

## Decisions

### AD-001
- **Decision**: O catálogo é carregado de `hugoprudente/optcgjson` (`output/*.json`), fixado em revisão imutável, e não da apitcg.com nem da dotgg.gg.
- **Reason**: É a única das três fontes que preserva a distinção entre carta e impressão física. Ela fornece `id` estável por variante (`OP01-001_p1`), o que elimina a necessidade de derivar `variant_code` por hash — a parte que o design apontava como a mais frágil do projeto.
- **Trade-off**: Abre mão de preços (que apitcg tem e optcgjson não) e depende de um scraper de mantenedor único, sem licença declarada. Mitigado pelo estágio Fetch salvar o payload bruto em disco: o catálogo é reconstruível sem rede, e trocar de fonte significa reescrever só o Normalize.
- **Scope**: Todo o subsistema de ingestão; modelo de `cards` e `card_variants`; Fase 3 (preços) precisará de outra fonte.
- **Date**: 2026-09-19
- **Status**: active

### AD-002
- **Decision**: Stack Rails 8 + Hotwire + PostgreSQL.
- **Reason**: PostgreSQL é requisito de design, não preferência — `pg_trgm`, `unaccent` e GIN sobre arrays sustentam os Req. 3 e 4 inteiros. Hotwire cobre o incremento/decremento sem recarregar página (Req. 7.2) sem introduzir uma SPA.
- **Trade-off**: Descartado Next.js + Prisma, apesar de haver cinco apps Next no workspace; Prisma tem atrito com arrays Postgres + GIN e com `pg_trgm`, o que jogaria boa parte das consultas para SQL cru.
- **Scope**: Todo o projeto.
- **Date**: 2026-09-19
- **Status**: active

### AD-003
- **Decision**: "Set completo" usa `baseSetSize` (variantes base) como denominador; parallels contam em métrica separada, nunca somados ao percentual.
- **Reason**: Sob a leitura "todas as impressões", sets dominados por parallels travam perto de zero permanentemente — em `LimitedProductCard`, 171 de 192 registros são parallels. O percentual deixaria de responder a pergunta que o Req. 9 existe para responder.
- **Trade-off**: Quem persegue completar todas as impressões não vê isso no número principal; fica na métrica secundária.
- **Scope**: Req. 9 (progresso por set).
- **Date**: 2026-09-19
- **Status**: active

### AD-004
- **Decision**: Imagens por hotlink de `imageUrl` (onepiece-cardgame.com), sem cache local na Fase 1.
- **Reason**: Coerente com `product.md` §5.1, que prefere referenciar a redistribuir arte. Custo zero de storage e invalidação, nenhum dos quais é requisito hoje.
- **Trade-off**: Se a Bandai bloquear hotlink, a grade fica sem arte. O placeholder do Req. 2.2 deixa de ser detalhe de robustez e passa a ser a mitigação desta decisão. Nenhum dado de usuário depende de imagem.
- **Scope**: Grade do catálogo e detalhe da carta.
- **Date**: 2026-09-19
- **Status**: active

### AD-005
- **Decision**: Os documentos de especificação continuam em `.context/` (`product.md`, `requirements.md`, `design.md`, `tasks.md`); `.specs/` guarda o recorte por feature, o log de decisões e os artefatos de verificação.
- **Reason**: `.context/` é a fonte de verdade histórica do projeto e tem convenções próprias (`⚠️ VERIFICAR`, `DECISÃO PENDENTE`, P1–P7) referenciadas pelo `CLAUDE.md`. Reescrevê-lo criaria duas fontes de verdade para os mesmos requisitos.
- **Trade-off**: Exige manter a rastreabilidade entre os dois diretórios — os IDs `CAT-NN` em `.specs/` apontam para os requisitos numerados de `.context/requirements.md`.
- **Scope**: Método de trabalho de todas as features.
- **Date**: 2026-09-19
- **Status**: active

## Handoff

> **Começando uma sessão nova?** Leia **`.specs/HANDOFF-colecao.md`** primeiro:
> estado, decisões, armadilhas de ambiente e método para a feature `colecao`.
> O `HANDOFF-fase-4.md` continua válido como histórico do fim do `catalogo`.

- **Feature**: colecao (`.specs/features/colecao/`) — `catalogo` encerrada
- **Phase / Task**: **Feature `catalogo` ENCERRADA.** 14 de 14 tasks fechadas,
  os dois lotes verificados (B1 e B2, ambos PASS, autor ≠ verificador). Os
  achados dos Verifiers e da revisão de a11y foram corrigidos e commitados.
- **Completed**: `catalogo` inteira (14 tasks). `colecao`: T1, T2, T3, **T4**.
  `colecao` Fase 1 (T1–T4) encerrada; `.context/tasks.md` §4.1 fechado.
  Detalhe do `catalogo`: 0.1, 0.2, 0.3, 1.1 (T1), 1.2 (T2), 2.1–2.7 (T3–T9),
  3.1 (T10), 3.2 (T11), 3.3 (T12), 3.4 (T13), 3.5 (T14). Verifier B1 + B2 PASS
  em `.specs/features/catalogo/validation.md` (B1 linhas 1–414, B2 a partir da
  419).
- **In-progress** (file:line): nenhum
- **Next step**: **Executar T5** de `.specs/features/colecao/tasks.md` (model
  `CollectionItem` sobre o usuário da sessão). **Fase 1 (T1–T4) encerrada** — a
  identidade e a sessão estão de pé, e `.context/tasks.md` §4.1 fechou junto com
  a T4. A decisão central segue de pé: **não rodar
  `bin/rails generate authentication`**.
- **`rate_limit` é dívida aberta, não esquecimento.** A T4 decidiu **não**
  incluir a linha do template: sem cache store compartilhado ela não limita
  nada (teste é `:null_store`; produção cai em `:file_store` por container) e
  daria aparência de proteção contra força bruta. O login está **sem limite de
  tentativas** hoje. Reabrir junto com Redis ou `solid_cache` — é mudança de
  infraestrutura, com teste que exercite o limite de verdade. Justificativa
  completa no comentário de `app/controllers/sessions_controller.rb`. A
  revisão de segurança apontou que omitir o limite **e** o piso de senha
  deixaria o espaço de força bruta no menor denominador; o piso
  (`minimum: 8`) entrou na T4 por isso, e é a metade que não depende de
  infraestrutura.
- **A T5 herda o padrão de sonda de teste.** `CollectionItemsController` é a T6,
  então tanto `authentication_test.rb` quanto `sessions_test.rb` definem um
  controller-sonda anônimo com rota desenhada no `setup`. Quando a T6 chegar,
  **não remover as sondas**: elas cobrem o concern em si — o default herdado por
  uma action que não declara nada — e continuam sendo o único teste disso.
- **A sonda de teste da T3 não é código de produção.** Quando a T3 rodou não
  havia nenhuma action protegida no app, então
  `test/integration/authentication_test.rb` define um controller anônimo com
  rota desenhada no `setup`. Quando a T6 entregar o
  `CollectionItemsController`, a sonda continua válida como teste do concern em
  si — não removê-la achando que virou redundante: ela é o único teste que
  cobre o default herdado por uma action que **não declara nada**.
- **Achado da T1, já resolvido na própria T1**: `authenticate_by` resolve o
  usuário com `find_by(email:)`, que é **sensível à caixa**. O índice
  `index_users_on_lower_email` impede que duas grafias coexistam, mas não faz a
  busca casar — quem se cadastrasse como `sanji@` não entraria digitando
  `SANJI@`. Resolvido com `normalizes :email` no `User`, que normaliza tanto a
  escrita quanto o argumento nomeado das consultas
  (`activerecord-8.0.5.1/lib/active_record/normalization.rb:33`). A **T4** não
  precisa mais tratar caixa de e-mail.
- **Dívida registrada na revisão de segurança da T3** (`ecc:security-reviewer`,
  sem achado bloqueante): o cookie de sessão não declara `secure: true` no hash
  de opções de `start_new_session_for`. Em produção o middleware o marca, porque
  `config.force_ssl = true` — a garantia é **indireta**: um staging que não
  herde `production.rb`, ou o dia em que `force_ssl` for desligado, tira o
  `secure` sem que nenhum teste acuse. Fixar exige `secure: Rails.env.production?`
  (desenvolvimento e teste rodam em HTTP), que é decisão de política de cookie e
  não cabia na task que porta o concern. Ambos os pontos estão comentados em
  `app/controllers/concerns/authentication.rb`.
- **Blockers**: none
- **Uncommitted files**: none
- **Branch**: main

### Dívida conhecida ao fim da feature `catalogo`

Nada aqui bloqueia a Fase 4; são pontos que a próxima sessão herda com os olhos abertos.

- **CI verde no primeiro run real** (`35475280590`, 2026-09-19), remoto em `github.com/pinhaum/bindr-tcg`. O run expôs que o pin da major não pegava o `pg_dump` (era 16.15 com `psql` 17.11, porque o runner traz um client 16 e o `update-alternatives` só reassume o `psql`); corrigido pondo `/usr/lib/postgresql/17/bin` na frente do PATH, com step que falha o job se a major regredir. Confirmado 17.11 nos dois binários no run `35475533719`.
- **T12/T14 não têm cobertura de navegador.** Viraram teste de integração porque não há chromedriver no container (`SPEC_DEVIATION` registrado em cada uma). O 360px do Req. 2.5 foi verificado à mão em Chromium; uma regressão de layout passaria no CI. Decidir se vale chromedriver no `Dockerfile.dev`.
- **Importmap não instalado.** Não há pipeline de JS: `stimulus-rails` está no Gemfile mas nunca foi executado, e o placeholder de imagem foi resolvido por CSS. **O Req. 7.2 (incremento sem recarregar) vai exigir o importmap** — é a primeira coisa a resolver na task 4.3.
- **Três melhorias de a11y não bloqueantes**, da revisão do `ecc:a11y-architect`: `lang="en"` no conteúdo em inglês (nome, `effect_text`, `trigger_text`), `min-height/min-width: 24px` explícitos nos alvos de toque (SC 2.5.8) e reforço do indicador de foco (SC 2.4.11).
- **Flakiness observada uma vez:** `guarantees_test.rb` falhou uma vez em ~20 execuções por contenção entre os 4 workers paralelos (`last_seen_at` do presente menor que o do ausente). Se voltar, congelar o relógio — `Upsert` já aceita `clock:` — e **não** afrouxar a asserção.

### Contexto que não está nos documentos

- **Docker em WSL:** `~/.docker/config.json` tem `"credsStore": "desktop.exe"`, que não existe no PATH. Qualquer `docker compose` que precise puxar imagem falha com `docker-credential-desktop.exe: executable file not found`. Contorno documentado no README: `DOCKER_CONFIG` apontando para um config `{}` vazio. **Não editar o config global do usuário.**
- **`tmp/pids/server.pid` órfão impede o app de subir.** Se o container morre sem limpar o pid, `docker compose up app` reinicia e sai com `A server is already running (pid: 1)`. O serviço fica fora do ar sem erro óbvio. Correção: `rm -f tmp/pids/server.pid` e subir de novo. Aconteceu ao rodar smoke test na verificação do B2.
- **A rota do catálogo é `/catalog`, não `/cards`.** `/cards/:id` é a página de detalhe da carta. `root` aponta para `catalog#index`.
- **`RAILS_ENV` posicional NÃO é lido pelo `bin/rails`.** `bin/rails db:drop db:create RAILS_ENV=test` atinge o banco de **desenvolvimento** e apaga o catálogo da T9 — aconteceu na verificação do B1. Use `env RAILS_ENV=test bin/rails ...` (variável antes do comando) ou `bin/rails db:test:prepare`. Recuperação, sem rede: `REUSE_PAYLOAD=1 bin/rails ingestion:import`, a partir do payload fixado em `storage/ingestion/`.
- **O volume nomeado `bundle` sombreia as gems da imagem.** Mudar o `Gemfile` e reconstruir a imagem **não basta**: é preciso `docker compose run --rm --no-deps app bundle install` para a gem entrar no volume, senão o container sobe com `Bundler::GemNotFound`.
- **App renomeado à mão:** o projeto foi gerado fora do repo e nasceu como `railsgen`; o módulo é `Bindr` em `config/application.rb`. Se algo referenciar `railsgen`, é resíduo.
- **`--skip-solid` foi deliberado**, justificado em `.context/design.md` §2.
- **O gerador de autenticação NÃO foi executado.** A T8 criou `users` e `collection_items` mínimos (migração `20260919120200`) porque a invariante do Req. 1.7 não é demonstrável sem coleção. O fluxo de sessão/login continua sendo Fase 4 e deve usar o gerador, que criará `Session` e provavelmente vai querer ajustar `users`.
- `config/database.yml` lê tudo do ambiente; `POSTGRES_TEST_DB` é variável própria.
- Ao concluir qualquer task, marcar o checkbox **nos dois** planos e commitar junto com o código.
- `python3 spec/verify_fixture.py` roda offline e continua passando (12 verificações).
- Não adicionar linhas de atribuição em mensagens de commit.

### Decisões técnicas da Fase 2 que valem para a Fase 3

- **`schema_format = :sql`** (`db/structure.sql`, `db/schema.rb` removido). O índice trigram do nome depende da função `immutable_unaccent`, e o formato Ruby não representa funções — um banco criado a partir de `schema.rb` falhava ao recriar o índice. Migração nova exige `db:migrate` para regenerar `structure.sql`.
- **`unaccent` é STABLE**, nas duas assinaturas (medido no PostgreSQL 17.11). Não entra em índice de expressão nem em coluna gerada. Usar sempre o wrapper `immutable_unaccent(text)`, que a migração `20260919120100` cria. A busca por nome da **T11** depende disso.
- **`json` pinada em `~> 2.7`.** A 3.x removeu o argumento `quirks_mode` que o ActiveSupport 8.0.5.1 ainda passa; com ela **toda** escrita em coluna `jsonb` levanta `ArgumentError`. Soltar o pin só quando o Rails parar de passar esse argumento.
- **Nomes que divergem de `design.md` §3.2**, ambos por colisão com o Ruby/Rails e marcados com `SPEC_DEVIATION` no código: a coluna `attributes` virou **`attributes_list`** (`attributes` é método do Active Record) e o model `Set` virou **`CardSet`** (a tabela continua `sets`; `Set` é classe da stdlib).
- **Teste de plano de execução precisa de seletividade realista.** O teste da T4 semeia 20k cartas com cor e custo raros: com filtro pouco seletivo o planejador escolhe Seq Scan *com razão*, e o teste não distinguiria índice ausente de índice ignorado por custo. A T13 (latência) herda esse cuidado.
- **`Dockerfile.dev` instala `postgresql-client-17` do PGDG**, porque o `pg_dump` 15 do bookworm recusa dumpar um servidor 17 e quebraria `db:schema:dump`.

### Decisões técnicas da Fase 3 que valem para as próximas

- **O limiar do trigram exige transação explícita.** `set_config(..., true)` é
  `SET LOCAL`: vale até o fim da transação corrente. Fora de uma, cada
  statement é a sua própria e o limiar já reverteu quando a consulta roda — a
  busca por typo devolve **zero** em produção enquanto a suíte passa, porque o
  Rails envolve todo teste numa transação. `CatalogQuery#call` abre transação
  quando há termo de busca. O teste que pega isso é o único da suíte com
  `use_transactional_tests = false`; não remover.
- **`word_similarity` (`<%`), não `similarity` (`%`), limiar 0.5.** O par
  default do `pg_trgm` não atende o Req. 3.3: a similaridade da string inteira
  é diluída por partes do nome que o termo não tem. Medido em `design.md`
  §4.1.3.
- **Ramificações de busca se unem por `UNION`, não por `OR`.** Uma ramificação
  inindexável num `OR` derruba o plano indexado do predicado inteiro. Em
  `design.md` §4.1.2.
- **Match exato compara a coluna crua** (`card_number = ?`) com o termo já em
  maiúsculas pelo Ruby. `upper(card_number) = upper(?)` descarta o índice
  único — defeito só de latência, que nenhum teste funcional pega. Há teste de
  plano de execução para ele.
- **O placeholder de imagem não usa JavaScript.** O projeto não tem pipeline
  de JS: `app/javascript` e `config/importmap.rb` não existem, e
  `stimulus-rails` está no Gemfile sem nunca ter sido instalado. O placeholder
  é resolvido por camada de CSS (sempre renderizado, embaixo da imagem). Se a
  Fase 4 precisar de Hotwire para o incremento sem recarregar (Req. 7.2), o
  importmap precisa ser instalado então — não está feito.
- **Não há navegador no container**, logo não há system test. T12 e T14 estão
  marcadas `Tests: e2e` no plano e foram entregues como teste de integração
  sobre HTML renderizado, com `SPEC_DEVIATION` registrado em cada uma. Os
  360px e o lazy loading foram verificados à mão em Chromium do Playwright, no
  host. Fechar essa lacuna é mudança de `Dockerfile.dev`.
- **Migração nova na Fase 3:** `20260919120300_add_card_number_trigram_index`.
  É **aditiva** — só cria índice GIN trigram em `cards.card_number`, não toca
  tabela, coluna nem constraint do schema verificado na Fase 2.
- **Benchmark de latência é rake, não teste:**
  `bin/rails catalog:benchmark` (`lib/tasks/benchmark.rake`).

### Pendência aberta para o orquestrador

- **CI (`.github/workflows/ci.yml`) não foi alterado, por instrução.** Mas a T4 mudou o caminho do `db:prepare`: com `schema_format = :sql`, `bin/rails db:prepare` carrega `db/structure.sql` via `psql`, que precisa estar no runner **e** ser compatível com o Postgres 17 do serviço. O `ubuntu-latest` traz cliente PostgreSQL, mas a versão não está fixada. **Conferir antes de confiar no verde do CI.**
