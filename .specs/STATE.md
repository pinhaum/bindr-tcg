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
- **Phase / Task**: Fase 0 concluída (tasks 0.1, 0.2, 0.3). Próxima: task 1.1 em `.context/tasks.md`.
- **Completed**: 0.1, 0.2, 0.3
- **In-progress** (file:line): nenhum
- **Next step**: Task 1.1 — inicializar o projeto Rails 8 com PostgreSQL, `docker-compose` e um teste trivial verde.
- **Blockers**: none
- **Uncommitted files**: none
- **Branch**: main
