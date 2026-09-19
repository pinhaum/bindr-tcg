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

- **Feature**: catalogo (`.specs/features/catalogo/`)
- **Phase / Task**: **Fase 2 concluída (T3–T9 / lote B1)**. Próxima: **T10** = task **3.1** — query object do catálogo. Início do lote **B2** (Fase 3, T10–T14).
- **Completed**: 0.1, 0.2, 0.3, 1.1 (T1), 1.2 (T2), **2.1 (T3), 2.2 (T4), 2.3 (T5), 2.4 (T6), 2.5 (T7), 2.6 (T8), 2.7 (T9)**
- **In-progress** (file:line): nenhum
- **Next step**: B2 (T10–T14). O Verifier do lote B1 ainda **não rodou** — é o passo imediato antes de abrir a Fase 3.
- **Blockers**: none
- **Uncommitted files**: none
- **Branch**: main

### Contexto que não está nos documentos

- **Docker em WSL:** `~/.docker/config.json` tem `"credsStore": "desktop.exe"`, que não existe no PATH. Qualquer `docker compose` que precise puxar imagem falha com `docker-credential-desktop.exe: executable file not found`. Contorno documentado no README: `DOCKER_CONFIG` apontando para um config `{}` vazio. **Não editar o config global do usuário.**
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

### Pendência aberta para o orquestrador

- **CI (`.github/workflows/ci.yml`) não foi alterado, por instrução.** Mas a T4 mudou o caminho do `db:prepare`: com `schema_format = :sql`, `bin/rails db:prepare` carrega `db/structure.sql` via `psql`, que precisa estar no runner **e** ser compatível com o Postgres 17 do serviço. O `ubuntu-latest` traz cliente PostgreSQL, mas a versão não está fixada. **Conferir antes de confiar no verde do CI.**
