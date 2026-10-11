# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Estado atual: Fases 1, 2 (decks) e 3 (preços) encerradas; API JSON (`api-fundacao`) implementada

**Todo o `.context/tasks.md` da Fase 1 está fechado** (§0 a §8). As features em
`.specs/features/` estão todas encerradas e verificadas (Verifier autor ≠
verificador, `validation.md` PASS): `catalogo`, `colecao`, `progresso`,
`portabilidade`, `imagens`, `interface`, `navegacao`, `conformidade`,
`fechamento` e `fonte-apitcg`. A última trocou a fonte do catálogo para a apitcg
(AD-019) e fechou em 2026-10-01 com a emenda do SRC-31 (estabilidade do
`tcgplayer.id` medida em 20h27m: 7.252 comuns, 0 mudados; D-14).

A **Fase 2 (`decks`, Req. 14, DCK-01..44)** está implementada: montar deck de
1 Leader + 50 pelo detalhe da carta, status derivado pelas regras de montagem
(Comprehensive Rules v1.2.1, com cartas sem limite de cópias e aviso para Leader
de regra própria), o que falta na pasta por deck e no agregado, e lista em texto
do OPTCG Simulator (importar e exportar). A feature está
**encerrada e verificada** (`validation.md` PASS; T21 fechada em 2026-10-05 com
o dono confirmando que o simulador aceita a lista exportada com LF). A **Fase 3 (`precos`, Req. 15, PRC-01..16)** está
**encerrada e verificada** (`validation.md` PASS na iteração 2, 2026-10-05): o
preço `market` do TCGplayer que a apitcg já entrega é gravado em `card_variants`
(valor, moeda ISO 4217 e data do import, AD-022), aparece no detalhe da carta e
vira o valor estimado da pasta, com subtotal por set, na mesma consulta dos
indicadores (AD-021 intacta). Só USD e só o preço atual, por decisão do dono. Pendências do dono abertas: sets não lançados no topo do catálogo sem
arte (403 do CDN) e arte "SAMPLE" presa no cache de imagens (ver *Handoff*). A
aprovação da T12 da `conformidade` foi dada em 2026-10-01. A D-03 (SRC-19) foi fechada mantendo a regra (registro no spec da
`fonte-apitcg`) e o flake D-10 foi corrigido (registro no *Handoff*). `STATE.md` (*Handoff*) tem o
retrato mais recente. A feature `api-fundacao` (Req. 16, API-01..32) acrescentou a
API JSON sob `/api` (sessão, cadastro, catálogo e detalhe da carta), com teste de
ponta a ponta; a §11 do `.context/tasks.md` está fechada.

A **`spa-fundacao`** (Req. 17, SPA-01..46) está **encerrada e verificada** (T1–T26, front em
`frontend/`: SvelteKit + Svelte 5, entrega em `/app`, cliente HTTP da API, sessão,
temas, casco e mensagens; `validation.md` PASS na iteração 2); `STATE.md` (*Handoff*) tem o retrato.

A **`spa-catalogo`** (Req. 18, SCAT-01..45) está **implementada (T1–T25) e aguarda o
Verifier**: `/app` deixou de ser o início da fundação e é o catálogo (busca, chips de
filtro, painel de filtros, grade, paginação, estados vazio/skeleton/erro), lendo só
`GET /api/catalog` e `GET /api/catalog/filters` (SCAT-45: nenhum arquivo sob `app/`
mudou desde `751e553`). O detalhe da carta era Hotwire na época (hoje é SPA: ver `spa-carta`).
Módulos novos em `frontend/src/lib/`: `catalog/url.ts` (links a partir de
`active_filters`), `catalog/catalog.svelte.ts` (carregador com token),
`catalog/filter-options.svelte.ts` (opções de filtro, uma vez por carga do app) e
`shell.svelte.ts` (slot `shell.aside` e `wide`). Componentes em `src/lib/components/`:
`CardTile`, `CardTileSkeleton`, `FilterChip`, `CatalogSearch`, `CatalogStatus`,
`ActiveFilters`, `CatalogPagination` e `FilterPanel`; a página é `src/routes/+page.svelte`.
Design em `.specs/features/spa-catalogo/design.md`.

A **`spa-carta`** (Req. 19, SCAR-01..49) está **implementada (T1–T22) e aguarda o
Verifier**: o detalhe da carta saiu do Hotwire e é a rota `/app/cartas/[card_number]`
(cabeçalho com arte e campos por tipo, linhas de variante com troca local do destaque,
posse otimista com `−`/`+` em fila por variante, desejo por variante e morph da arte entre
grade e detalhe). O tile do catálogo leva a ela (SCAR-03). Rails ganhou três rotas de
mutação em `Api::CardVariantsController` e `CollectionItem.increment_for!`/`decrement_for!`
(o SQL atômico de posse passou do `CollectionItemsController` para o model, sem mudar
respostas, mensagens nem rotas HTML; SCAR-49: nenhum teste Rails existente foi editado).
Design em `.specs/features/spa-carta/design.md`.

A **`spa-portabilidade`** (Req. 22, SPOR-01..46) está **implementada (T1–T14) e aguarda o
Verifier**: o import da coleção saiu do HTML e é SPA em `/app/pasta/importar` (envio do CSV) e
`/app/pasta/importar/[token]` (pré-visualização em cinco grupos, confirmação e resumo); o
export segue pelo link da pasta, para `GET /collection/export` do Rails, e a ida e volta é
provada no e2e. Rails ganhou três rotas em `Api::CollectionImportsController` e o serviço
`CollectionCsv::Upload`; o controller, as views e os serviços HTML do import ficam intocados
(SPOR-45: `git diff --name-status d5f13c6..HEAD -- test/` só com `A`). Design em
`.specs/features/spa-portabilidade/design.md`.

A **`spa-pasta`** (Req. 20, SPAS-01..46) está **encerrada e verificada** (T1–T17, `validation.md` PASS): `/app/pasta` (indicadores com número interpolado, progresso por set, chips de
ordem, ações) e `/app/pasta/desejos` (lista e remoção não otimista, com foco) são SPA e
leem só `GET /api/progress` e `GET /api/wishlist`, além de `DELETE …/wishlist`.
`app/views/progress`, `app/views/wishlist_items` e os controllers HTML ficam intocados
(SPAS-46). A entrada "Minha pasta" da navegação aponta para `/app/pasta`. Design em
`.specs/features/spa-pasta/design.md`.

O que existe hoje:

- **Models**: `Card`, `CardVariant`, `CardSet`, `ImportRun`, `CollectionItem`,
  `WishlistItem`, `CollectionImport`, `Deck`, `DeckEntry`, `User`, `Session`,
  `Current`, e as peças puras `Deck::Legality` (status, motivos e avisos) e
  `Deck::ListText` (`parse`/`format` do OPTCG Simulator).
- **Controllers**: `CatalogController` e `CardImagesController` (públicos),
  `CollectionItemsController`, `WishlistItemsController`, `ProgressController`,
  `CollectionImportsController`, `CollectionExportsController`,
  `DecksController`, `DeckEntriesController`, `DeckImportsController`,
  `SessionsController`, `RegistrationsController`, e os concerns
  `Authentication` e `EditingDeck`.
- **Query objects**: `CatalogQuery` (busca e filtros), `SetProgressQuery` e
  `DeckShortfallQuery` (o que falta na pasta, por deck ou agregado pelo maior
  uso; uma consulta, que a pasta paga mesmo sem decks, AD-021).
- **Ingestão**: `app/services/ingestion/` — `Run`, `Upsert`, `Remap`,
  `SourceConfig` e `apitcg/` (Fetch, Normalize, CompareSnapshots).
- **Dez migrações**, de `20260919120000` a `20261005130000` (preço da variante). `schema_format`
  é `:sql`: migração nova exige `db:migrate` para regenerar `db/structure.sql`.
- **1995 testes Rails**, rubocop e brakeman limpos (o único aviso do brakeman é o fim de suporte do Rails 8.0.5.1, de calendário).
- **Importmap só com Turbo** e **Stimulus deliberadamente não pinado** (não há
  controller Stimulus no projeto; ver `config/importmap.rb`). O placeholder de
  imagem do catálogo continua resolvido em CSS — não trocar por JS só porque
  existe pipeline.

### API JSON (`/api`, `api-fundacao`)

Controllers em `app/controllers/api/`, todos filhos de `Api::BaseController`
(irmão de `ApplicationController`, não filho: herdar traria o `allow_browser` do
HTML). Rotas no `scope "api"` de `config/routes.rb` (`format: false` +
`defaults: { format: :json }`):

| Rota | Controller | Acesso |
|---|---|---|
| `GET/POST/DELETE /api/session` | `SessionsController` | `GET` público; login público; logout exige sessão |
| `POST /api/registration` | `RegistrationsController` | público |
| `GET /api/catalog`, `GET /api/catalog/filters` | `CatalogController` | público (posse só com sessão) |
| `GET /api/cards/:card_number` | `CardsController` | público (posse só com sessão) |
| `POST /api/cards/:card_number/variants/:variant_code/increment` | `CardVariantsController` | exige sessão e CSRF |
| `POST /api/cards/:card_number/variants/:variant_code/decrement` | `CardVariantsController` | exige sessão e CSRF; em zero é `200` com `owned_quantity: 0` |
| `PUT /api/cards/:card_number/variants/:variant_code/wishlist` | `CardVariantsController` | exige sessão e CSRF; alvo inteiro ≥ 1 e ≤ 2147483647, senão `422 validation_failed` com mensagem pt-BR |
| `GET /api/progress` | `ProgressController` | exige sessão; `{ data: { order, summary, sets } }`; `order` inválido cai em `recent`; `base_size` e `completion_percent` nulos quando o set não tem base; número de consultas constante |
| `GET /api/wishlist` | `WishlistController` | exige sessão; itens por ordem de criação e id, com `owned_quantity` e `fulfilled` |
| `DELETE /api/cards/:card_number/variants/:variant_code/wishlist` | `CardVariantsController` | exige sessão e CSRF; `200` com `{ variant_code, wishlist_target: null }`, idempotente; `404` para carta ou variante inexistente |
| `POST /api/collection/imports` | `CollectionImportsController` | exige sessão e CSRF; multipart com `file`; `201` com a pré-visualização `{ token, filename, rows[] }`; recusa do arquivo é `422 validation_failed` com `fields.file`; não escreve em `collection_items` |
| `GET /api/collection/imports/:token` | `CollectionImportsController` | exige sessão; pré-visualização do staging do próprio usuário (`quantity_before` `null` sem registro); token alheio, inexistente ou vencido é `404` |
| `POST /api/collection/imports/:token/confirm` | `CollectionImportsController` | exige sessão e CSRF; `200` com `{ filename, created, updated, removed, unchanged, rejected[], failures[] }` (`updated` inclui `removed`); já confirmada ou vencida é `409 import_closed` |
| `* /api/*path` | `NotFoundController` | catch-all |

Sucesso é `{ "data": ... }` (a lista traz `meta`); erro é sempre
`{ "error": { "code", "message", "fields" } }` com mensagem em pt-BR. Códigos:
`unauthenticated` 401, `invalid_credentials` 401, `invalid_csrf_token` 422,
`validation_failed` 422, `bad_request` 400, `invalid_json` 400, `not_found` 404, `import_closed` 409,
`not_acceptable` 406, `unsupported_browser` 406, `internal_error` 500 (genérico,
a exceção só vai para o log). Nenhuma resposta sob `/api` é HTML ou redirect;
`end_to_end_test.rb` varre isso. As peças reaproveitadas pelo HTML e pela API:
`CatalogQuery`, `CardDetail`, `VariantHoldings`, `Card.preload_present_variants`.

Armadilhas:

- **`before_action :resume_session` no base é obrigatório.** Sem ele, `Current.user`
  é `nil` nos endpoints públicos e a posse some com 200 (mesma armadilha do
  `allow_unauthenticated_access`).
- **`ParseError` tem handler próprio** (`invalid_json` 400): o Rails levanta
  `ActionDispatch::Http::Parameters::ParseError` ao ler o corpo JSON malformado,
  antes da action, e cairia no `StandardError` como 500.
- **CSRF vai por sessão, não por cookie de formulário.** Todo `GET /api/session`,
  login, cadastro e logout devolve `csrf_token`; login, cadastro e logout trocam a
  sessão e portanto o token, e o anterior passa a ser recusado. O cliente usa o
  token devolvido no passo anterior, no header `X-CSRF-Token`.
- **O catch-all `match "*path"` tem de ser a última rota** do escopo; rota nova da
  API entra acima dele. `catalog/filters` vem antes de qualquer rota com `:id`.
- **Teste de CSRF liga `ActionController::Base.allow_forgery_protection`** no
  `setup` e restaura no `teardown`: o ambiente de teste o desliga, e sem isso
  nenhum teste prova o `422`.

### Front SPA (`frontend/`, `spa-fundacao`)

SPA em **SvelteKit 3.0.1 + Svelte 5.57.2 + TypeScript**, `adapter-static` com
fallback `200.html` e `paths.base = /app`, em `frontend/`. Consome só a API JSON
acima. Testes: Vitest 5 (jsdom, `@testing-library/svelte`) e `@playwright/test`
1.64.0. O ESLint proíbe `fetch` fora de `src/lib/api/client.ts` (SPA-06).

- **Dev**: serviço `frontend` do compose (`node:24.21.0-slim`, `npm ci && npm run dev`,
  porta 5173, volume nomeado `frontend_node_modules`). O proxy do Vite manda tudo fora
  de `/app` (regex `^/(?!app(/|$))`) para `http://app:3000`.
- **Produção**: o estágio `frontend-build` do `Dockerfile` roda `npm ci`, `npm run
  build`, `test -f build/200.html` e copia para `/rails/public/app` (a imagem final não
  tem Node; `/public/app` está no `.gitignore`). `SpaController < ActionController::Base`
  (sem `Authentication` nem `allow_browser`) serve `config.x.spa_entry_path`
  (`public/app/200.html`) como `text/html` com `Cache-Control: no-cache`. A rota
  `get "app(/*path)"` é a **última** de `config/routes.rb` e exclui `/app/_app/`
  (chunk ausente dá 404, nunca o HTML).
- **Cliente** (`src/lib/api/client.ts`): JSON, `credentials: same-origin`,
  `X-CSRF-Token` só em mutação e trocado por qualquer `data.csrf_token` string, tempo
  limite de 15 s, `path` só iniciando por `/` (não `//`). Erros tipados `ApiError`
  (`network_error` e `unexpected_response` com status 0; `session_changed` 422). `401
  unauthenticated` chama `onUnauthenticated` (exceto `DELETE /api/session`). `422
  invalid_csrf_token` em mutação renova por `GET /api/session` e reenvia **uma** vez,
  só se o e-mail for o mesmo (`user` nulo → `unauthenticated`; outro e-mail →
  `onSessionChanged` + `session_changed`).
- **Estado e telas**: `session.svelte.ts`, `theme.svelte.ts` (script inline em
  `app.html` antes do paint; `localStorage` `bindr-theme`), `toasts.svelte.ts` +
  `Toaster` (duas regiões sempre montadas; o sucesso some em 5000 ms sem pausa, exceção
  à WCAG 2.2.1 registrada), `motion.ts`, `safeReturnTo` (rejeita `//`, `\`, controle e
  segmentos `.`/`..`). Rotas `/app`, `/app/entrar`, `/app/criar-conta`. `AppShell`: barra
  inferior abaixo de `64rem`, coluna lateral a partir dele, mesmo DOM. `<title>` por
  rota; `afterNavigate` move o foco para `main#conteudo` (não na carga inicial). Tokens
  dos dois temas verificados por contraste em `tokens.test.ts` (porta de
  `test/design/contrast_test.rb`). Desde a `spa-catalogo`, `/app` é o catálogo e a
  entrada "Catálogo" da navegação aponta para ele (ver "Estado atual").

Gates do front (em série com o gate Rails; o flake D-10 do relógio do host mistura).
Contagens atuais: Vitest 859 testes, e2e 193, Rails 1995 (rubocop limpo).

```bash
# quick
docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run"
# e2e (Playwright contra a API real; não sobe no `docker compose up`)
docker compose up -d app frontend && docker compose --profile e2e run --rm e2e
```

O e2e agora **exige o catálogo importado no banco de dev** (a paridade `/app` × `/catalog`
e o selo de posse leem cartas reais): `docker compose exec app bin/rails ingestion:import
SNAPSHOT=storage/ingestion/apitcg-<UTC>.json`, offline, a partir de um snapshot em disco.
As imagens `/card_images/*` respondem 502 porque o CDN responde 403 (AD-019); os e2e
ignoram essas respostas.

Armadilhas:

- **Kit 3 difere do que a doc antiga mostra.** A config do Kit (`adapter`, `paths`)
  fica em `vite.config.ts` (não há `svelte.config.js`); **não existe `$lib`** (imports
  relativos); `base` saiu de `$app/paths` (vem de `resolve('/')` sem a barra final; nos
  testes, `vi.mock('$app/paths')`); arquivo de teste sob `src/routes` não pode começar
  com `+` (`page.test.ts`, `layout.test.ts`); rodar `npx svelte-kit sync` antes de
  `tsc`/`check`.
- **O proxy não pode ter `changeOrigin`.** O `Host` chega ao Rails como
  `localhost:5173` e a checagem de origem do CSRF compara `Origin` com
  `request.base_url`; com `changeOrigin` o CSRF falharia. Também exigem
  `server.allowedHosts` (`localhost`, `frontend`) e `config.hosts << "frontend"` em
  `development.rb`. Os internos do Vite (`/app/@vite/client`, HMR) ficam sob `/app`,
  então a regex basta.
- **`npm ci` com o `frontend` de pé troca o volume `node_modules` sob o Vite:** parar
  o serviço antes ou reiniciá-lo depois.
- **`credsStore` do host quebra o pull de imagem nova:** `export
  DOCKER_CONFIG=$(mktemp -d)` com `{}` em `config.json`. A imagem do `e2e` tem de ter a
  mesma versão do `@playwright/test`.
- **`200.html` e cache:** `/app/_app/immutable/*` sai com `max-age` de 1 ano (certo, tem
  hash); `/app` e `/app/x` saem `no-cache`. `/app/200.html` pedido direto também sai
  com 1 ano, pelo `ActionDispatch::Static` (nada linka para ele; dívida baixa). A rota
  `app(/*path)` tem de continuar **última**.
- **Primeiro quadro em dev:** o CSS chega por injeção do Vite depois do primeiro quadro;
  o e2e prova `data-theme` certo desde o primeiro quadro e a cor após o carregamento. O
  build é conferido por `build/200.html` trazer o script de tema antes da stylesheet.
- **O e2e escreve contas** `e2e-<timestamp>@exemplo.test` no banco de dev, sem limpeza.
- **Abertas para o dono:** `Button` pendente com `disabled` + `aria-busy` (perde o foco
  e não é anunciado; `aria-disabled` exigiria emendar o SPA-21); dica de formato da
  senha só no erro; chave desconhecida de `fields` vira `chave: mensagem`; e-mail como
  identidade da sessão; login sem limite de tentativas (dívida da API).

Armadilhas do catálogo (`spa-catalogo`):

- **Foco e rolagem na mesma rota:** o Kit 3.0.1 não tem `keepFocus` nem `noScroll`. Use
  `goto(url, { reset: false })` e `data-sveltekit-reset="false"` nos links (chips,
  paginação). O `afterNavigate` do layout e o `viewTransitionOnNavigate` retornam cedo
  quando só a query muda (mesmo `pathname`).
- **Um único painel de filtros, dois lugares:** o slot `shell.aside` (snippet) e `wide`
  (`MediaQuery` de `64rem`) decidem onde ele monta. A partir de `64rem` vai para a coluna
  lateral do `AppShell`, abaixo disso para um `<details>` acima da grade. Nunca há duas
  instâncias (sem id duplicado). O `open` do `<details>` é `$state` da página.
- **Os hrefs nascem de `meta.active_filters` da última resposta** (SCAT-06), não da URL.
  Logo, um segundo clique antes de a resposta chegar usa href obsoleto; e, se a
  **primeira** carga falha, busca e chips ficam vazios até o "Tentar novamente"
  (limitação aceita).
- **Foco e anúncio:** `CatalogStatus` expõe `focus()` e exporta `statusSentence`. A
  região `role="status"` (com a classe `.visually-hidden`) é esvaziada e regravada depois
  de `tick()`, senão uma frase igual à anterior não é anunciada. `pendingFocus` (chip ou
  status) não expira: dívida conhecida.
- **`--z-nav` (10)** em `tokens.css`: a barra inferior fixa (abaixo de `64rem`) tem de
  ficar acima do tile da grade. O `Toaster` segue com `100` literal.
- **`signOut` vai a `/app` e descarta a query:** sair em `/app?owned=owned` não preserva
  o resto dos filtros; a consulta é refeita por causa da troca de sessão (SCAT-09).

Módulos do detalhe da carta (`spa-carta`): `lib/format.ts`; `lib/cards/url.ts`,
`featured.ts`, `card-detail.svelte.ts` (carregador com token), `ownership-queue.svelte.ts`
(fila de posse por variante), `morph.svelte.ts`; componentes `CardArt`, `CardHeader`,
`CardFields`, `OwnershipStepper`, `WishlistForm`, `VariantRow`; rota
`src/routes/cartas/[card_number]/+page.svelte`. `OwnershipResult` está em `api/types.ts` e,
em versão parcial, em `ownership-queue.svelte.ts`.

Módulos da pasta (`spa-pasta`): `lib/api/loader.svelte.ts` (`createLoader<T>(fetch,
slowMs = 200)`), `lib/navigation/require-session.ts`, `easeStandard`/`cubicBezier` em
`motion.ts`; componentes `AnimatedNumber`, `PastaSummary`, `SetProgressRow`,
`WishlistItem`; rotas `src/routes/pasta/+page.svelte` e
`src/routes/pasta/desejos/+page.svelte`.

Armadilhas da pasta (`spa-pasta`):

- **`api.get` já devolve o `data` desempacotado:** não leia `result.data`. O mock do teste
  de página deve devolver o dado sem envelope; um teste unitário com envelope escondeu
  isso e só o e2e pegou.
- **`AnimatedNumber` interpola o valor monetário em CENTAVOS** e reserva a largura com uma
  cópia invisível do texto final (`inline-grid`). O `Tween` nasce no valor final quando
  `duration()` é 0. Teste com animação em curso precisa avançar os timers falsos no fim,
  senão envenena o loop de rAF.
- **`disabled` num botão focado manda o foco ao `body`:** a página de desejos devolve o
  foco ao botão na falha.
- **A remoção de desejo usa `variantApiPath(card, variant, 'wishlist')`**, a mesma rota do
  `PUT`.
- **A reserva de espaço da ação fixa abaixo de `64rem`** fica no contêiner que termina a
  página.
- **"Um quarto da coluna" (SPAS-11)** é medido como a trilha de `repeat(4, 1fr)`
  descontados os vãos.
- **A ação "Adicionar cartas" mora em `shell.aside` com `wide`** (AD-028).
- **Dívida:** migrar `catalog.svelte.ts` e `card-detail.svelte.ts` para `createLoader`
  (hoje só a pasta e a lista de desejos o usam).

Módulos do import (`spa-portabilidade`): `lib/imports/api.ts` (caminhos e chamadas),
`lib/imports/groups.ts` (cinco grupos da pré-visualização), tipos em `api/types.ts`;
componentes `ImportRowItem` e `ImportSummary`; rotas `src/routes/pasta/importar/+page.svelte`
e `src/routes/pasta/importar/[token]/+page.svelte`. O cliente HTTP (`api/client.ts`) agora
aceita `FormData` (sem `Content-Type` próprio, com CSRF e o mesmo reenvio único) e
`timeoutMs` por chamada: 60 s no envio e na confirmação, 15 s nas demais (SPOR-32).

Armadilhas do import (`spa-portabilidade`):

- **Confirmação com resposta perdida (P13, aberta):** rede ou tempo limite na confirmação
  não reenvia; a SPA mostra "Não foi possível saber se a importação foi gravada…" com link
  para a pasta (SPOR-31). O resumo não é persistido, como no HTML; uma segunda tentativa
  recebe `409 import_closed`. Persistir o `Commit::Result` exige migração e é do dono.
- **`409 import_closed` junta dois casos** (já confirmada e vencida), com a frase do HTML;
  a pré-visualização continua na tela com alerta (SPOR-30).
- **O teto do upload é imposto antes de ler o arquivo** (`CollectionCsv::Upload`, fix
  `b02dcc1`): `content_length` acima do limite de 8 MB recusa sem chamar `read`.
- **`line` da pré-visualização já vem somado (+2) do servidor**; a SPA não refaz a conta.
- **Texto do arquivo entra como texto** (`card_name`, `message`): nada de `{@html}` (SPOR-17).
- **Foco e anúncio no envio e na pendência** (fix `4d338c2`): o foco volta ao controle e a
  pendência é anunciada em região viva; `disabled` num botão focado manda o foco ao `body`.
- **Duplicação temporária:** `CollectionCsv::Upload` repete a validação e o saneamento do
  nome do `CollectionImportsController` HTML; a duplicação sai na `spa-troca`, quando o
  HTML do import for removido. Não unificar antes, para não editar o HTML (SPOR-45).
- **Medições:** `Commit` de 10.000 linhas levou 7,91 s no container (T4, abaixo do teto de
  30 s); a pré-visualização de 10.000 linhas leva ≈3,0 s no envio e 1,9 s para abrir a
  360px (T13), sem virtualização.
- **O e2e escreve contas** `e2e-<timestamp>@exemplo.test` e coleção no banco de dev, como os demais.

Armadilhas do detalhe (`spa-carta`):

- **`card_type` da API é minúsculo** (`leader`, `character`, `event`, `stage`): indexar os
  campos por tipo em `CardFields` com a caixa errada some com a seção sem erro.
- **O `OwnershipStepper` cria a própria fila.** Não há `Map` na página: o `{#key}` por
  `card_number` + e-mail da sessão recria os steppers, e a fila descarta o que não foi
  enviado ao desmontar. O valor exibido sobe por `bind:displayed` para o selo.
- **O morph exige o destino renderizado quando a View Transition captura o novo estado.**
  `awaitArrival`/`signalArrival` em `morph.svelte.ts` (teto de 500 ms) e `armArrival` em
  `viewTransitionOnNavigate`; sem isso a transição roda sem a arte de destino.
- **A marca do morph** (`view-transition-name`) é posta pelo tile e pela página do detalhe
  (`markCard`), só no elemento visível; nome duplicado anula a transição.
- **`WishlistForm` usa `novalidate`**: a regra do alvo é da API (422), não do navegador.
- **Dívidas fora do escopo:** o `CardImagesController` busca a variante só por
  `variant_code` (`card_images_controller.rb:23`); o `WishlistItemsController` HTML tem a
  mesma corrida de criação que a API trata (500 no HTML); flake e2e de `sessao.spec.ts`
  ("a mensagem não desloca o conteúdo", SPA-46) quando a altura do catálogo muda por carga
  assíncrona.

**O default do app é exigir sessão.** `ApplicationController` inclui
`Authentication`, então toda action nasce protegida e o acesso público é exceção
declarada com `allow_unauthenticated_access` — hoje `CatalogController`,
`CardImagesController`, `RegistrationsController` e `new`/`create` do
`SessionsController`. Os demais controllers não declaram nada e por isso exigem
sessão.
Uma action nova que não declare nada já está protegida.

**O deck em edição mora na sessão do Rails** (`session[:editing_deck_id]`,
concern `EditingDeck`) e é revalidado contra `Current.user.decks` a cada
leitura — um id herdado de outra conta vira `nil`. Num controller público
(`CatalogController`), `editing_deck` chama `authenticated?` antes. O
`DeckEntriesController` usa o mesmo SQL atômico da coleção, com o teto de 50 no
`WHERE` do `DO UPDATE` e o decremento sob `FOR UPDATE`; o teste de corrida força
a sobreposição por lock e é o único com `use_transactional_tests = false`.

Dívidas abertas que valem saber antes de mexer em autenticação:

- **Login sem limite de tentativas.** O `rate_limit` do template do Rails foi
  deliberadamente omitido na T4: sem cache store compartilhado ele não limita
  nada (teste é `:null_store`; produção cai em `:file_store` por container).
  Justificativa completa em `app/controllers/sessions_controller.rb`. Reabrir
  junto com Redis ou `solid_cache`.
- **O cookie de sessão não declara `secure` explicitamente** — em produção vem
  de `config.force_ssl`. A garantia é indireta; comentada no concern.
- **Não há navegador no container**, logo não há system test. Teste de UI vira
  teste de integração sobre HTML renderizado, com `SPEC_DEVIATION` registrado.
- **`allow_unauthenticated_access` não resolve a sessão.** Ele remove o
  `before_action :require_authentication`, que era quem chamava
  `resume_session`: num controller público, `Current.user` é `nil` na action
  até alguém chamar `authenticated?`. Ler dado do usuário ali sem isso é
  defeito **silencioso** — responde 200 e devolve vazio. A T8 tropeçou nisso;
  `CatalogController#owned_quantities` chama `authenticated?` antes de ler
  `Current.user` por esse motivo.

## Comandos

Tudo roda em Docker; o Postgres não existe fora dele. A chave da apitcg é obrigatória
só para `ingestion:import` real; os testes usam um cliente HTTP falso e não a usam.

```bash
cp .env.example .env
# Depois de pôr a chave em `.env`, recrie o container (a variável passa como ENV):
docker compose up
docker compose exec app bin/rails test
docker compose exec app bin/rails test test/integration/sessions_test.rb
docker compose exec app bin/rails test test/models/user_password_test.rb -n "/senha/"
docker compose exec app bin/rubocop      # rubocop-rails-omakase
docker compose exec app bin/brakeman
docker compose exec app bin/rails db:prepare
```

Ingestão do catálogo — a chave da apitcg é lida de `APITCG_API_KEY` no `.env`:

```bash
# Busca na apitcg real (requer chave e conectividade)
docker compose exec app bin/rails ingestion:import

# Reprocessa um snapshot existente sem rede nem chave (útil offline ou para testar)
docker compose exec app bin/rails ingestion:import SNAPSHOT=storage/ingestion/apitcg-<UTC>.json

# Aponta coleção e wishlist para as variantes da fonte atual (sempre após import)
docker compose exec app bin/rails ingestion:remap

# Compara dois snapshots para medir estabilidade do tcgplayer.id (≥20h de diferença)
docker compose exec app bin/rails ingestion:compare_snapshots A=storage/ingestion/<arq-A> B=storage/ingestion/<arq-B>
```

Front SPA (`frontend/`): gates e armadilhas na seção "Front SPA" acima. Atalho:
`docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run"`
(quick) e `docker compose up -d app frontend && docker compose --profile e2e run --rm e2e` (e2e).

Gem nova exige `docker compose run --rm --no-deps app bundle install`: o volume
nomeado `bundle` sombreia as gems da imagem, então rebuild **não** basta.

Gates da última feature (`.specs/features/fonte-apitcg/tasks.md`), padrão para as próximas: **quick** =
`bin/rails test test/models test/queries`; **full** =
`bin/rails test && bin/rubocop`; **build** = `docker compose build`.

Verificação da fixture de ingestão, offline, sem Docker e sem Ruby — deve
continuar passando (19 verificações):

```bash
python3 spec/verify_fixture.py
```

Validadores do fluxo spec-driven:

```bash
SKILL=~/.claude/skills/tlc-spec-driven
python3 $SKILL/scripts/validate_spec.py  .specs/features/<feature>/spec.md
python3 $SKILL/scripts/validate_tasks.py .specs/features/<feature>/tasks.md
python3 $SKILL/scripts/validate_state.py <feature>
```

`Dockerfile.dev` é a imagem de desenvolvimento (código como volume); `Dockerfile`
é o de produção gerado pelo Rails — separados de propósito, não unificar.

## Método de trabalho: spec-driven

O fluxo é `requirements` → `design` → `tasks`, documentado em `.context/README.md`.
Regras que valem para qualquer sessão de trabalho aqui:

- **Tasks em ordem de dependência**, de `.context/tasks.md`. Não abrir uma task com
  alguma de que ela depende incompleta. Tasks independentes podem rodar em
  paralelo quando nenhuma dependência (`Depends on`) está pendente e os arquivos
  tocados (`Where`) não se sobrepõem; na dúvida, sequencial.
- **Toda task termina com código que roda e teste que passa.** "Estrutura criada"
  não conta como task concluída.
- **Se um requisito se mostrar errado durante a execução, pare e corrija
  `requirements.md`** antes de continuar. Não improvisar no código — corrigir só o
  código desalinha o spec e destrói o valor do método.
- Mudança de escopo volta ao documento de origem e se propaga para baixo.

### Dois diretórios de spec, de propósito

`.context/` é a **fonte de verdade** de requisitos, design e plano de tasks.
`.specs/` guarda o recorte por feature — dez features em `features/`, todas
encerradas —, o log de decisões (`STATE.md`, AD-001 a AD-020) e os artefatos do
Verifier. Em divergência, `.context/` vence (AD-005).
Os IDs de `.specs/` apontam para os requisitos numerados de
`.context/requirements.md` com prefixo próprio por feature (`CAT-NN` no
`catalogo`, `COL-NN` na `colecao`, `SRC-NN` na `fonte-apitcg` etc.). **Todo plano
numera `T1` em diante e as numerações não têm relação entre si** — sempre dizer de qual feature se fala.

**Ao concluir uma task, marcar o checkbox nos dois planos** (`.context/tasks.md` e
o `tasks.md` da feature em execução) e commitar junto com o código. Atenção ao
escopo de cada seção do `.context/tasks.md`: uma seção costuma cobrir várias
tasks do plano da feature e só fecha quando todas elas fecham — a §4.1 cobriu
T1–T4 e só foi marcada na T4. `STATE.md` tem a seção *Handoff* com o ponto exato
de retomada — ler antes de começar.

### Convenções nos documentos

- `SHALL` / `DEVE` — requisito obrigatório e testável.
- `⚠️ VERIFICAR` — afirmação sobre o jogo, uma API ou uma biblioteca que **não foi
  confirmada**. Precisa de validação em fonte primária antes de virar código. Não
  tratar como fato.
- `DECISÃO PENDENTE` — ponto onde o design deliberadamente não escolheu.

Os documentos estão em português brasileiro. Escrever novos documentos e commits
na mesma língua.

## Decisões já tomadas (P1–P7 resolvidas)

As sete pendências que bloqueavam código foram decididas na Fase 0 e estão em
`.specs/STATE.md`. **Nenhuma bloqueia mais nada** — não reabrir sem motivo novo:

| # | Decisão | Onde |
|---|---------|------|
| P1 | Fonte = apitcg (`GET /api/one-piece/sets` e `/products?type=card`, header `x-api-key`) | **AD-019** |
| P2 | Campos/raridades/sets reais extraídos da fixture; glossário de `product.md` §6 corrigido | task 0.2 |
| P3 | "Set completo" = `baseSetSize` (variantes base); parallels em métrica separada | AD-003 |
| P4 | Rails 8 + Hotwire + PostgreSQL | AD-002 |
| P5 | `variant_code = "tcgplayer:<id>"`, ou `"apitcg:<_id>"` sem esse id | **AD-019** |
| P6 | App serve a imagem com cache em disco; host = `tcgplayer-cdn.tcgplayer.com` | **AD-019** |
| P7 | `DON!!` fora do catálogo na Fase 1 | task 0.2 |

A troca para a apitcg (AD-019) superou a AD-001. O `variant_code` agora vem do
`tcgplayer.id` da apitcg, com reserva para `apitcg:<_id>` quando o id não existe.
A estabilidade do `tcgplayer.id` entre buscas foi verificada em 2026-10-01:
0 mudados em 20h27m entre dois snapshots (7.252 comuns), fechando o SRC-31 com
a emenda de 20h no lugar de 24h (SRC-31, D-14).

A fixture `spec/fixtures/apitcg-subset.json` é versionada de propósito — é a entrada
dos testes de ingestão sem rede (Req. 11.5). Já `storage/ingestion/` (snapshots brutos
do Fetch) é ignorada pelo git: reconstruível a partir de `ingestion:import`.

## Arquitetura (de `.context/design.md`)

Três subsistemas, e a separação entre eles é o eixo do design inteiro:

```
Fonte externa → INGESTÃO (Fetch → Normalize → Upsert) → CATÁLOGO → COLEÇÃO
                                                     (read-only)  (escrita do usuário)
```

**O catálogo é regenerável; a coleção é insubstituível.** Todas as invariantes
abaixo existem para impedir que a ingestão corrompa dados do usuário:

- A ingestão **não tem operação de delete**. Carta ausente da fonte é marcada,
  nunca removida (Req. 1.7).
- **Nenhuma foreign key da coleção usa delete em cascata** — deletar uma variante
  apagaria em cascata o registro do usuário.
- Upsert por chave natural (`card_number` para cartas, `card_id + variant_code`
  para variantes), nunca `create` cego. Cada registro em transação própria; erro em
  um registro vai para `import_runs.error_log` e o loop continua.
- O teste mais valioso do projeto (task 2.6): rodar a ingestão duas vezes com um
  `collection_item` existente e verificar que a quantidade continua intacta.

### `Card` ≠ `CardVariant` — a decisão central do modelo

- **Card** = a carta do jogo, identificada por `card_number` (`OP01-001`). É sobre
  ela que as regras e textos falam.
- **CardVariant** = uma impressão física específica (base, alternate art, parallel,
  manga, promo). Mesmo `card_number`, mesmo efeito, **objeto de coleção diferente**.

Coleção e wishlist referenciam **variantes**. Busca e filtros operam sobre
**cartas**, exibindo variantes agregadas. Colapsar as duas entidades destrói metade
do sentido do produto e é o erro mais caro de corrigir depois. Preço (Fase 3) e
deck (Fase 2) dependem dessa mesma distinção: deck referencia `cards`, coleção
referencia `card_variants`.

### Isolamento da fonte externa

Todo conhecimento sobre o formato da apitcg vive **no estágio Normalize e em nenhum
outro lugar** (`app/services/ingestion/apitcg/normalize.rb`). O estágio Fetch salva
o snapshot bruto em `storage/ingestion/apitcg-<UTC>.json` antes de normalizar —
é isso que permite reprocessar sem rede via `ingestion:import SNAPSHOT=` e transforma
o snapshot em fixture de teste (Req. 11.5). A apitcg não tem revisão imutável; o
snapshot em disco a substitui.

### Busca e filtros

Tudo em PostgreSQL, sem serviço de busca dedicado (dataset pequeno, consultas
estruturadas): `pg_trgm` + GIN para nome com tolerância a typo, `unaccent` para
acentos, `tsvector` para texto de efeito, e uma **consulta separada** para match
exato de `card_number` cujo resultado é prependido. Não tentar resolver ranking
exato dentro do full-text.

Um **único query object** traduz parâmetros de URL em consulta e serve tanto HTML
quanto JSON — é o único lugar que precisa de teste de filtro. Contrato em
`design.md` §4.2. Semântica: `OU` dentro de uma categoria, `E` entre categorias;
filtro de cor inclui multicoloridas. **Parâmetro desconhecido ou inválido é
ignorado, nunca causa erro** — uma URL compartilhada não pode dar 500 porque um
filtro foi renomeado.

### Detalhes de modelagem fáceis de errar

- `counter` **NULL ≠ 0**: "não tem counter" não é "counter de 0". Nunca usar 0 como
  sentinela.
- `colors`, `traits`, `attributes` como arrays Postgres + GIN (não tabelas de
  junção). `traits` vem de texto livre da fonte → **normalizar caixa e espaçamento
  na ingestão**, senão `"Straw Hat Crew"` e `"Straw hat crew"` viram traits
  distintos e o filtro fica furado.
- `rarity` como **texto, não enum** — o snapshot da apitcg traz `C UC R SR PR L
  SEC TR`, mas a fonte é um agregador comunitário: enum faz a ingestão explodir
  no dia em que aparecer um valor novo.
- `variant_code` precisa ser **estável entre execuções**, senão a idempotência
  quebra e o usuário perde o vínculo com a coleção. Hoje ele é `"tcgplayer:<id>"`
  do campo `markets.tcgplayer.id` da apitcg, ou `"apitcg:<_id>"` quando aquele não
  existe. A estabilidade deste id foi verificada em 2026-10-01: 0 mudados em 20h27m (SRC-31, D-14).

### Revisão por subagente

**Não existe `ruby-reviewer` nem `rails-reviewer`** entre os agentes instalados
(Python, Go, Rust, Java, PHP, TypeScript, React, Django, FastAPI — Ruby não), daí
a revisão sair sempre pelos agentes agnósticos de linguagem. Cada feature tem seu
plano na seção "Plano de delegação" do próprio `tasks.md`. Na `colecao`:
`ecc:security-reviewer` no concern e no controller de sessão (feito na Fase 1),
`ecc:database-reviewer` nas constraints e no plano de execução,
`ecc:a11y-architect` nos controles de posse, `ecc:pr-test-analyzer` nos testes de
isolamento e wishlist.

Coletas mecânicas — ler arquivo, listar símbolo, extrair formato — vão para
subagentes Haiku com prompt fechado e **leitura apenas**. Decisão de design e
resolução de colisão ficam com o orquestrador.

Se rodar sensor de mutação, isolar em worktree ou cópia — **nunca `git stash`**:
há trabalho não commitado com frequência neste repo.

### Autorização

**Toda** consulta a coleção ou wishlist parte do usuário da sessão, nunca de um ID
vindo do request. Isso satisfaz o Req. 6.5 por construção em vez de por verificação.
Catálogo é público; qualquer mutação exige sessão.

## Alvos não-funcionais que já têm task de validação

- Filtro combinado com busca: **p95 < 500ms** com catálogo completo (Req. 11.1,
  task 3.4). Se falhar, a saída é otimizar índice/consulta e depois hidratar
  filtros no cliente — **não** trocar de stack.
- Filtros do Req. 4 **sem full table scan**, verificável por plano de execução
  (Req. 11.3, task 2.2).
- Usável em viewport de **360px sem scroll horizontal** (Req. 2.5).
- Subida local em **um único comando documentado** (Req. 11.6).
