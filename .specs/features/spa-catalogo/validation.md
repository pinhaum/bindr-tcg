# Validação — spa-catalogo (iteração 3)

**Veredito**: FAIL
**Data**: 2026-10-11
**Spec**: `.specs/features/spa-catalogo/spec.md` (SCAT-01..45, 10 edge cases, 4 Success Criteria)
**Diff range**: `751e553..HEAD` (HEAD = `cde8011`; 33 commits, T1–T31). Desta iteração: `bc4e15d..HEAD` (`6792463` T29; `cde8011` T31 + asserções da T30)
**Verifier**: sub-agente independente (autor ≠ verificador; não escreveu código da feature nem os relatórios anteriores)
**Iteração**: 3 (última antes de escalar ao dono)

## Validation: spa-catalogo - FAIL ❌

G8–G11 da iteração 2 estão **fechadas**: N09, N18 e N13 morrem; E04 virou **equivalente provado** (a correção da T31 pôs `margin-inline-start: auto` em `.links`, que torna o `justify-content` de `.status` irrelevante para a posição dos links; E04 junto com a remoção dessa margem morre em 4 testes). Os 10 mutantes novos reais morrem. Implementação sem defeito conhecido; nada sob `app/` mudou desde `751e553`.

O FAIL vem do **gate e2e, que não é determinístico**: em 3 execuções completas da suíte, 2 falharam no mesmo ponto, `frontend/e2e/sessao.spec.ts:119` (SPA-46, altura de `main` com e sem a mensagem "Sessão encerrada."), nos combos 1280×800 (claro na 1ª, escuro na 2ª). O teste é desta feature (`settledBox` entrou em `06b8a2b`, T27, para fechar a G5 da iteração 1). Diagnóstico abaixo (G12): corrida no próprio teste, não defeito de produto.

**Spec-anchored check**: 45/45 ACs com resultado exato ancorado em `arquivo:linha`; 0 lacunas de AC; 1 ressalva de precisão do spec herdada (`aria-live` × `role="status"`).
**Gate**: Vitest 38 arquivos / 551 passed; build + `build/200.html` ok; **e2e 102 passed / 1 failed, 102/1, 103/0 em três execuções completas** (G12); Rails 1912 runs / 0 failures; rubocop 247 / 0; `docker build -f Dockerfile .` exit 0.
**Sensor**: 17 mutações (4 da iteração 2 reexecutadas, 1 de CSS da iteração 1, 12 novas); 14 mortas, 3 sobreviventes, todas **equivalentes provadas** (E04, X07; e E04 confirmado por E04+X06). 0 sobreviventes reais.
**Estado da árvore real**: ver "Isolamento" no fim. Escritas desta sessão: este arquivo, `.specs/LESSONS.md` e `.specs/lessons.json` (L-069).

---

## Histórico

**Iteração 1 (2026-10-10, FAIL)**: gate verde (Vitest 548, e2e 58, Rails 1912, rubocop 247); 34/34 mutantes comportamentais mortos; 5 de CSS sobreviveram (C01, C02, C03, C05, C06). Lacunas G1 (Major: dimensões e posições sem asserção), G2 (paridade num só combo), G3 (três chips sem e2e), G4 (grade intacta sem teste de página), G5 (altura de `main` no SPA-46), G6 (docs do `tasks.md`), G7 (ícone de imagem quebrada, cosmético). Fase 5 (T26–T28).

**Iteração 2 (2026-10-11, FAIL)**: gate verde (Vitest 549, e2e 101, Rails 1912 com 1 flake não identificado em 3 execuções, rubocop 247); G1–G6 fechadas; 43 mutações, 36 mortas, 3 equivalentes (E01–E03), **4 sobreviventes reais** N09, N18, N13, E04 → G8–G11. Lições L-065, L-066, L-067. Fase 6 (T29–T31).

**Nota sobre execução concorrente**: durante esta sessão, outro agente gravou neste mesmo arquivo um relatório "iteração 3, PASS" (08:51:03) e marcou `spec.md` como Verified e o Status de `tasks.md` como "it.3 PASS" (08:51:47). Esse relatório registrou "e2e 103 passed" numa única execução. Os sensores dele e os meus concordam (N09, N18, N13 mortos; E04 e `.links` sem `flex-end` equivalentes). A divergência é só o gate e2e, que reproduzi falhando 2 vezes em 3. Cópia do relatório concorrente preservada fora do repositório, em `/tmp/claude-1000/-home-pho-lab-bindr-tcg-svelt-front/b655fbd9-b67d-48f4-b9f3-3dc3f5433ca4/scratchpad/validation-concorrente-PASS.md`. Não toquei em `spec.md` nem em `tasks.md`; com este FAIL, o supervisor precisa reverter aquelas marcações.

---

## Conclusão das tasks

T1–T31 `[x]` em `.specs/features/spa-catalogo/tasks.md` (31 cabeçalhos `### T`; "Done when" da fase 6 marcados). Commits da fase 6: `6792463` (T29) e `cde8011` (T31), Conventional Commits sem corpo nem atribuição.

**Desvio de processo (T30)**: o commit previsto `test(spa-catalogo): medir a amostra de cor e o link à direita no layout` não existe; as asserções da T30 (`catalogo-layout.spec.ts:140-160`, `:274-297`) entraram em `cde8011` junto com a correção da T31. Não muda comportamento; fica registrado.

---

## Fechamento das lacunas da iteração 2 (G8–G11)

| # | Veredito | `arquivo:linha` da asserção nova | Prova de que discrimina |
|---|---|---|---|
| G8 (SCAT-12, limite 2) | **fechada** | `frontend/src/lib/components/CardTile.test.ts:118-125`: `.rarity toHaveTextContent('2 impressões')` (`:123`), `not.toContain('SR')` (`:124`); variante única segue com `'SR'` (`:107`) | N09 (`CardTile.svelte:14`, `> 1` → `> 2`) **morto** (1 falha: "duas variantes…") |
| G9 (SCAT-38, 39) | **fechada** | `frontend/src/routes/page.test.ts:361-376`: erro inicial, "Tentar novamente" com resposta pendente, `advanceTimersByTimeAsync(200)`, `skeletons(container) toHaveLength(10)` (`:373`), `aria-busy 'true'` (`:374`), `queryByText(message)` ausente (`:375`) | N18 (`+page.svelte:142`, `skeleton` → `skeleton && !error`) **morto** (1 falha: o teste novo) |
| G10 (SCAT-20, 21) | **fechada** | `frontend/e2e/catalogo-layout.spec.ts:140-160`: amostra do chip ativo e do inativo, `backgroundColor not.toBe(accent)` (`:157`), borda `'1px'` (`:158`), `borderTopColor toBe(borderStrong)` resolvido do token (`:141`, `:159`); 4 combos | N13 (amostra com `background-color: var(--accent)`) **morto** (4 falhas); X08 (borda da amostra em `--border`) **morto** (4 falhas) |
| G11 (SCAT-30, à direita abaixo de 64rem) | **fechada** | 360px deslogado, links quebrados: `catalogo-layout.spec.ts:256-266` (links abaixo da frase `:259-261`; borda direita a ≤ 1px da borda da linha `:262-266`). 768 e 1023px, mesma linha: `:274-297` (à direita da frase `:287`, primeira linha `:291`, encostados `:292-295`) | E04 sozinho sobrevive, **equivalente** (margem automática de `.links`); E04+X06 **morto** (4 falhas: `:208` a 360 claro/escuro, `:278` a 768 e 1023); X06 sozinho **morto** (2 falhas a 360) |

**T31 (código de produção)**: `frontend/src/lib/components/CatalogStatus.svelte:58-59` acrescenta `justify-content: flex-end` e `margin-inline-start: auto` a `.links`. Efeito medido: a 360px, deslogado e com filtro, os links (que quebram para a 2ª linha) passam a encostar na borda direita (X06 prova que a asserção falha sem a margem). `justify-content: flex-end` é inerte nas larguras suportadas: sonda na cópia a 320 e 360px mostra os dois links na mesma linha interna, com geometria idêntica com e sem a regra (X07, equivalente). Regressão: o e2e de layout inteiro (20 testes, 4 combos + 768/1023) e a suíte e2e completa passaram com a mudança; C05 (barra em coluna a partir de 64rem) segue morto, então SCAT-32 continua discriminado.

---

## Spec-Anchored Acceptance Criteria

Caminhos relativos a `frontend/`. `PT` = `src/routes/page.test.ts` (linhas ≥ 361 subiram +17 desde a iteração 2); `INT` = `e2e/catalogo-interacao.spec.ts`; `PAR` = `e2e/catalogo.spec.ts`; `LAY` = `e2e/catalogo-layout.spec.ts` (linhas > 137 subiram +22; depois do teste da linha de status, +62). Arquivos sem diff na fase 6 mantêm as linhas da iteração 2, conferidas por amostragem.

| AC | Resultado definido no spec | `arquivo:linha` + asserção | |
|---|---|---|---|
| SCAT-01 | título "Catálogo — Bindr", `h1` "Catálogo" | `PT:139` `expect(document.title).toBe('Catálogo — Bindr')`; `:140` heading nível 1 | ✅ |
| SCAT-02 | "Catálogo" → `/app` sem recarga, `aria-current="page"` com qualquer query | `src/lib/navigation/nav-entries.test.ts:23-31`; `src/lib/components/MainNav.test.ts:59-70` | ✅ |
| SCAT-03 | tile → `/cards/<card_number>` codificado, página inteira | `src/lib/components/CardTile.test.ts:50-52`; `:57` `'/cards/OP01-0%231%3Fx'` | ✅ |
| SCAT-04 | `GET /api/catalog` com a query crua | `PT:158` `toHaveBeenCalledWith('/api/catalog' + search)`; `src/lib/catalog/catalog.svelte.test.ts:39-40` | ✅ |
| SCAT-05 | formato §4.2; mesmas cartas e ordem que `/catalog` | `src/lib/catalog/url.test.ts:25-29`; `PAR:123-124` `expect(spa.tiles).toEqual(hotwire.tiles)` em 7 queries × 4 combos | ✅ |
| SCAT-06 | links só de `meta.active_filters` | `PT:209-219` `goto('/app?q=luffy&colors%5B%5D=Red', …)` com URL `/app`; `url.test.ts:197-212` | ✅ |
| SCAT-07 | voltar/avançar restauram resultado, termo e controles | `INT:363-412` | ✅ |
| SCAT-08 | resposta de URL antiga descartada | `catalog.svelte.test.ts:60-76` `expect(loader.state.result).toEqual(page(2))` | ✅ |
| SCAT-09 | troca de sessão repete a consulta | `PT:182`, `:196` `toHaveBeenLastCalledWith('/api/catalog')`; `INT:461-580` | ✅ |
| SCAT-10 | imagem da 1ª variante, nome, `card_number` em `code` | `CardTile.test.ts:71-75`; `LAY:201-205` fonte `--font-mono` computada | ✅ |
| SCAT-11 | placeholder visível com `null`/falha, sem mudar o tile | `CardTile.test.ts:78-102`; `LAY:163-199` (502 forçado, `naturalWidth === 0` `:176`, arte transparente, mesma caixa, 5/7) | ✅ |
| SCAT-12 | raridade com 1 variante; "N impressões" com mais de uma | `CardTile.test.ts:107` `'SR'`; **`:123` `'2 impressões'`**; `:132` `'3 impressões'`; N09 morto | ✅ |
| SCAT-13 | selo no canto superior direito, `role="img"` "1 cópia"/"N cópias", só com sessão e soma > 0 | `CardTile.test.ts:136-160`; `LAY:304-341` (posição, tolerância `--space-2`+1); `INT:461+` | ✅ |
| SCAT-14 | 5 colunas a 1280px; sem scroll horizontal a 360px | `PAR:254` `toBe(combo.width >= 1024 ? 5 : 2)`; `PAR:65-69` `scrollWidth <= clientWidth` | ✅ |
| SCAT-15 | rótulo, placeholder "OP01-024", "Buscar", alvos ≥ 44px | `src/lib/components/CatalogSearch.test.ts:11-15`; `LAY:78` `toBeGreaterThanOrEqual(44)` aplicado a botão e campo; `LAY:99` placeholder | ✅ |
| SCAT-16 | busca com `q` aparado, mantém filtros/ordem, sem `page` | `PT:209-219`; `url.test.ts:118-126` | ✅ |
| SCAT-17 | campo mostra `active_filters.q` ou vazio | `CatalogSearch.test.ts:35-39`; `PT:170` | ✅ |
| SCAT-18 | chips na ordem da API; tipo com inicial maiúscula, valor cru | `src/lib/components/FilterPanel.test.ts:59-62` | ✅ |
| SCAT-19 | chip = link com valor alternado, sem `page` | `FilterPanel.test.ts:78-82`; `url.test.ts:38-60` | ✅ |
| SCAT-20 | ativo: anel 2px `accent`, ×, nome "Remover filtro <cat>: <valor>"; cor não preenchida com `accent` | `src/lib/components/FilterChip.test.ts:24-28`; `LAY:130` `['2px'×4]`, `:132` `[accent, accent]`, `:133` fundo ≠ accent; **`LAY:157` amostra ≠ accent** (N13 morto) | ✅ |
| SCAT-21 | cor neutra (`border-strong` + rótulo), sem hex do jogo | **`LAY:158-159` borda da amostra `1px` em `borderStrong`** (X08 morto); `src/lib/styles/guard.test.ts:61-64` | ✅ |
| SCAT-22 | alvo ≥ 44px em chip, select e "Aplicar" | `LAY:73-80,86-97` | ✅ |
| SCAT-23 | "Aplicar" com um set / "Todos os sets" | `FilterPanel.test.ts:92-116` | ✅ |
| SCAT-24 | "N sets selecionados" mantém os sets | `FilterPanel.test.ts:121-126` | ✅ |
| SCAT-25 | posse com sessão, "Todas" `aria-current="true"` sem × | `FilterPanel.test.ts:146-155`; `url.test.ts:62-70` | ✅ |
| SCAT-26 | sem sessão, sem posse; `owned` não vira chip | `FilterPanel.test.ts:167-171`; `INT:421-460` | ✅ |
| SCAT-27 | faixas, attribute, trait, sort, dir pela URL e preservados | `url.test.ts:168-174`; `PAR:191-216` | ✅ |
| SCAT-28 | um chip por valor, rótulos exatos, remove só aquele | `url.test.ts:179-226`; `src/lib/components/ActiveFilters.test.ts:16-24` | ✅ |
| SCAT-29 | "N cartas"/"1 carta" + " · M filtros ativos" | `src/lib/components/CatalogStatus.test.ts:17-23`; X05 (`chipCount >= 0`) morto em 8 testes | ✅ |
| SCAT-30 | "Limpar filtros" com filtro **e** cartas, mantém `sort`/`dir`, à direita | `PT:240-247` `'/app?sort=name&dir=desc'`; `CatalogStatus.test.ts:42-46`; à direita: `LAY:208-249` (≥ 1024), **`LAY:256-266` (360, quebrado)**, **`LAY:278-297` (768, 1023)**; "e a página tiver cartas": X01 (sem `&& hasCards`) morto em 2 testes | ✅ |
| SCAT-31 | convite único → `/app/entrar?return_to=<caminho e query>` | `PT:388-399` `'/app/entrar?return_to=' + encodeURIComponent(...)`; X02 (sem `page.url.search`) morto em 2 testes | ✅ |
| SCAT-32 | status na linha da busca a partir de 64rem | `LAY:212-249` (`tolerance`); C05 morto | ✅ |
| SCAT-33 | filtros na coluna lateral abaixo da navegação, espaçamento fixo | `src/lib/components/AppShell.test.ts:58-69`; `PT:486-497`; `INT:333-362` | ✅ |
| SCAT-34 | recolhido abaixo de 64rem, "Filtros · M filtros ativos" | `PT:499-521` (`:517` `'Filtros · 2 filtros ativos'`); `INT:255-298` | ✅ |
| SCAT-35 | painel aberto segue aberto | `PT:548-588`; `INT:255-332` | ✅ |
| SCAT-36 | "Paginação do catálogo", "Anterior"/"Próxima", "Página X de Y" | `src/lib/components/CatalogPagination.test.ts:25-46` | ✅ |
| SCAT-37 | vazio com termo em `strong` ou texto padrão; "Limpar filtros" com filtro | `PT:223-247` (`:227` `strong` "zoro") | ✅ |
| SCAT-38 | após 200 ms, 10 esqueletos, `aria-busy="true"`, "Carregando cartas…"; antes, conteúdo anterior | `PT:270-292` (199/200 ms, `:287` 10); `PT:293-314`; **`PT:361-376` (esqueleto sobre erro)**; N18 morto | ✅ |
| SCAT-39 | erro: `message` + "Tentar novamente" repete a URL atual | `PT:315-360`; `PT:378-387`; `:375` erro velho some no retry; X03/X04 mortos | ✅ |
| SCAT-40 | falha das opções: grade, status e ativos intactos | `FilterPanel.test.ts:182-195`; `PT:534-546` (ressalva herdada: `:540` `toHaveTextContent('1')` é substring) | ✅ |
| SCAT-41 | só query muda: foco não vai a `main` | `src/routes/layout.svelte.test.ts:152-162`; `INT:107-192` | ✅ |
| SCAT-42 | remover chip: seguinte/anterior/status | `PT:644-697`; `INT:193-231` | ✅ |
| SCAT-43 | "Anterior"/"Próxima" focam o status | `PT:699-718`; `INT:232-254` | ✅ |
| SCAT-44 | frase anunciada em região `aria-live="polite"` | `PT:433-485` (`getByRole('status')`, regrava frase igual `:458-474`) | ✅ (⚠️ precisão: spec diz `aria-live="polite"`, a página usa `role="status"`, que o implica) |
| SCAT-45 | só os dois endpoints do Req. 16 | `git diff --stat 751e553..HEAD -- app/` vazio; Rails 1912 / 0 sem edição | ✅ |

**Status**: ✅ 45/45 ACs ancorados; 1 ressalva de precisão do spec (herdada).

### Success Criteria

| Critério | Evidência | |
|---|---|---|
| 1. Paridade a 360/1280 nos dois temas, sem scroll horizontal | `PAR:72-73,123-124`, `PAR:65-69,224-243`; verdes nas 3 execuções | ✅ |
| 2. Selo e "Tenho" batem com a coleção; "Sair" os remove sem recarregar | `INT:461-580`; verde nas 3 execuções | ✅ |
| 3. Três chips pelo teclado, foco no painel, anúncio a cada resposta | `INT:133-168` | ✅ |
| 4. Suíte Rails sem edição e nada sob `app/` | `git diff --stat 751e553..HEAD -- app/` vazio; 1912 / 0 | ✅ |

Com o FAIL, os checkboxes do `spec.md` não deveriam estar marcados nem o Status "Verified" (ver nota de execução concorrente).

---

## Edge Cases

- [x] Parâmetro desconhecido/inválido: `PT:158` (`?zzz=1` cru); `url.test.ts:197-212`
- [x] `colors=Red` sem colchetes repassado cru: `PT:158`
- [x] `page` > `total_pages`: `PT:250-258`
- [x] Catálogo vazio sem filtro: `PT:232-238`
- [x] Variante única sem raridade: `CardTile.test.ts:110-115`
- [x] Imagem 403/404 mantém o placeholder: `LAY:163-187`
- [x] Sair em `/app?owned=owned`: `INT:461-580`
- [x] Dois chips antes da resposta: `catalog.svelte.test.ts:60-76`
- [x] Cruzar 64rem sem refazer a consulta: `PT:591-618`
- [x] `card_number` com caractere reservado: `CardTile.test.ts:57`

---

## Gate de build

`DOCKER_CONFIG` temporário (`{}`); tudo em série; `frontend` parado antes do `npm ci` e religado depois (e de novo ao fim do sensor).

| Etapa | Comando | Resultado |
|---|---|---|
| 1 | `docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run && npm run build"` + `test -f build/200.html` | exit 0; `svelte-check found 0 errors and 0 warnings`; lint limpo; **Vitest 38 arquivos, 551 passed**; `BUILD_200_OK` |
| 2 | `docker compose up -d app frontend && docker compose --profile e2e run --rm e2e` (catálogo importado: 2873 cartas) | **exec. 1: 102 passed, 1 failed** (`sessao.spec.ts:84` 1280×800 claro, `:119`); **exec. 2: 102 passed, 1 failed** (mesmo teste, 1280×800 escuro, `:119`, `height` 847 esperado × 1749,84 recebido); exec. 3: 103 passed |
| 2b | `npx playwright test e2e/sessao.spec.ts --repeat-each=4` | 20 passed (isolado não reproduz) |
| 3 | `docker compose exec -T app bin/rails test` | **1912 runs, 7800 assertions, 0 failures, 0 errors, 0 skips** |
| 4 | `docker compose exec -T app bin/rubocop` | 247 arquivos, 0 ofensas |
| 5 | `docker build -f Dockerfile .` | exit 0 |
| 6 | `git diff --stat 751e553..HEAD -- app/` | vazio (SCAT-45) |

- **Test count**: antes da feature Vitest 312 / e2e 26; it.1 548 / 58; it.2 549 / 101; **agora 551 / 103** (+2 Vitest da T29; +2 e2e a 768 e 1023px da T30). Nenhuma contagem diminuiu; nenhum skip.
- **Integridade (fase 6)**: só acréscimos em testes; nenhuma asserção enfraquecida (`git diff bc4e15d..HEAD`).

### G12: diagnóstico da falha do e2e (`sessao.spec.ts:112-119`)

- **O que o teste faz**: `settledBox` (`:112-115`) espera `section[aria-busy="false"]` visível e **depois**, em outra chamada, lê `boundingBox()` de `main#conteudo`; mede com a mensagem (`:117`), espera a mensagem sumir (`:118`) e compara (`:119`).
- **O que acontece depois de "Sair"** (provado): o log do Rails mostra, em toda jornada, `DELETE /api/session` seguido de **duas** `GET /api/catalog` (ex.: 12:02:33 e 12:02:34 na exec. 2; o mesmo par nas jornadas que passaram), uma pela troca de `session.user` e outra pela navegação de `signOut` a `/app` (`+page.svelte:55-59` relê `page.url`). Uma sonda por quadro (`requestAnimationFrame`) na cópia, 8 jornadas a 1280px, registrou sempre a sequência `aria-busy=false, 25 tiles, main 1750px` → `aria-busy=true, 10 esqueletos, main 847px` (~3 s depois do clique, porque o Puma de dev está ocupado com os proxies de imagem que respondem 502) → `aria-busy=false, 25 tiles, 1750px`.
- **Causa (inferida, consistente com as duas falhas)**: 847px é exatamente a altura de `main` com o esqueleto. A checagem `aria-busy="false"` e a leitura da caixa não são atômicas: se a segunda carga atravessa os 200 ms entre as duas chamadas, o teste mede o esqueleto e grava 847 como "com mensagem"; depois mede a grade (1749,84) e falha. O produto se comporta como o SCAT-38 pede (esqueleto após 200 ms). Uma sonda com atraso fixo de 2,5 s na API não reproduziu a falha, o que confirma que é janela de tempo, não estado errado.
- **Por que importa**: o teste é desta feature (T27, fechamento da G5) e torna o gate e2e não determinístico (2 de 3 execuções completas vermelhas). O PASS concorrente se apoiou numa execução verde.
- **Observação (não é lacuna)**: a dupla `GET /api/catalog` ao sair é redundante (a segunda descarta a primeira pelo token do SCAT-08). Não viola o spec; é a causa prática de a janela existir.

---

## Discrimination Sensor

Scratch: `git worktree add --detach <scratchpad>/wt HEAD` (fora do repositório; sem `git stash`), `npm ci` próprio em `node:24.21.0-slim`. Uma mutação por vez: substituição exata com contagem 1 (aborta se o trecho não for único), backup `.orig`, testes, restauração por cópia e conferência do `git status` do worktree. Vitest na cópia (baseline 38 arquivos verdes). Mutantes de CSS: `frontend` real parado; Vite **da cópia** na rede `bindr-tcg-svelt-front_default` com o alias `frontend` (proxy sem `changeOrigin` para `http://app:3000`), recriado a cada mutante; Playwright `v1.64.0-noble` com os specs da cópia contra `http://frontend:5173/app/` (baseline `catalogo-layout.spec.ts`: 20 passed). No fim: container removido, worktree removido (`git worktree remove --force` + `prune`), `frontend` religado.

| # | `arquivo:linha` | Mutação | Testes | Resultado |
|---|---|---|---|---|
| N09 | `src/lib/components/CardTile.svelte:14` | `> 1` → `> 2` | `CardTile.test`, `page.test` | ✅ morto (1: `CardTile.test.ts:118`) |
| N18 | `src/routes/+page.svelte:142` | `skeleton` → `skeleton && !error` | `page.test` | ✅ morto (1: `page.test.ts:361`) |
| N13 | `src/lib/components/FilterChip.svelte:55-59` | `.swatch` com `background-color: var(--accent)` | e2e layout | ✅ morto (4: `LAY:102` nos 4 combos) |
| E04 | `src/lib/components/CatalogStatus.svelte:47` | `.status` `justify-content: flex-start` | e2e layout | ⚪ sobreviveu, **equivalente**: `.links` tem `margin-inline-start: auto` (`:59`), que já empurra os links à direita |
| E04+X06 | `CatalogStatus.svelte:47` + `:59` | E04 e sem a margem automática | e2e layout | ✅ morto (4: `LAY:208` a 360 claro/escuro; `LAY:278` a 768 e 1023): prova a equivalência de E04 |
| X06 | `CatalogStatus.svelte:59` | `.links` sem `margin-inline-start: auto` (desfaz metade da T31) | e2e layout | ✅ morto (2: `LAY:208` a 360, "links encostados… ao quebrar") |
| X07 | `CatalogStatus.svelte:58` | `.links` sem `justify-content: flex-end` | e2e layout | ⚪ sobreviveu, **equivalente**: sonda a 320 e 360px, os dois links na mesma linha interna, geometria idêntica com e sem a regra |
| X08 | `FilterChip.svelte:58` | borda da `.swatch` em `--border` | e2e layout | ✅ morto (4: `LAY:159`) |
| C05 | `src/routes/+page.svelte:250` | barra em coluna a partir de 64rem | e2e layout | ✅ morto (2: `LAY:208` a 1280, "status e campo na mesma linha") |
| X01 | `+page.svelte:124` | "Limpar filtros" sem exigir `hasCards` | `page.test`, `CatalogStatus.test` | ✅ morto (2: `PT:223`, `PT:240`) |
| X02 | `+page.svelte:35` | `return_to` sem `page.url.search` | `page.test` | ✅ morto (2: `PT:388`, `PT:400`) |
| X03 | `src/lib/catalog/catalog.svelte.ts:57` | erro sem `settle()` (esqueleto preso) | `catalog.svelte.test`, `page.test` | ✅ morto (2) |
| X04 | `catalog.svelte.ts:47` | sucesso não zera `error` | idem | ✅ morto (4+) |
| X05 | `CatalogStatus.svelte:4` | `chipCount > 0` → `>= 0` | `CatalogStatus.test`, `page.test` | ✅ morto (8) |

Contagem: 17 aplicações (N09, N18, N13, E04, E04+X06, X06, X07, X08, C05, X01–X05, mais a reexecução de E04 sozinho e as duas sondas de geometria não contam como mutantes) → **14 mortos, 3 sobreviventes equivalentes** (E04, X07, e E04 confirmado por E04+X06). Os demais mutantes das iterações 1 e 2 não foram reexecutados: o único código de produção alterado desde a iteração 2 é `CatalogStatus.svelte:58-59`, coberto por E04, E04+X06, X06, X07 e C05.

**Sensor depth**: lightweight ampliado (funções de estado, página, componentes e CSS por e2e).
**Result**: 0 sobreviventes reais → sensor ✅. O FAIL é só do gate (G12).

---

## Code Quality

| Princípio | Status |
|---|---|
| Minimum code / surgical | ✅ Fase 6: duas linhas de CSS em produção (`CatalogStatus.svelte:58-59`), o resto é teste |
| Matches patterns | ✅ e2e reusa `resolveToken`, `box`, `openCatalog`, `spaStatus`; tokens resolvidos no documento, sem hex/px no teste; `guard.test.ts` verde |
| Tests map to ACs, não rasos | ✅ asserções novas medem valor (cor computada, borda, posição com tolerância de 1px) |
| Determinismo dos testes da feature | ❌ `sessao.spec.ts:112-119` não é atômico (G12) |
| Atomicidade de commit por task | ⚠️ T30 sem commit próprio |
| Diretrizes | `CLAUDE.md` seção "Front SPA" (gates em série, `fetch` só no cliente) seguidas |

---

## Lacunas ranqueadas (fix task proposta)

| # | Severidade | Lacuna | AC / critério | Proposta |
|---|---|---|---|---|
| G12 | Minor (bloqueia o gate) | Gate e2e não determinístico: `frontend/e2e/sessao.spec.ts:112-119` checa `aria-busy="false"` e lê a caixa de `main` em chamadas separadas; a segunda `GET /api/catalog` disparada por "Sair" pode exibir o esqueleto entre elas; 2 de 3 execuções completas falharam com 847 × 1749,84 | Gate e2e; SPA-46 (fundação), reforçado pela T27 desta feature | Medir de forma atômica: um único `evaluate` que só devolve a caixa quando `section[aria-busy="false"]` e `ul.grid > li` existem no mesmo quadro, dentro de `expect.poll` exigindo duas leituras iguais seguidas; ou esperar as duas respostas de `/api/catalog` (`waitForResponse`) antes de medir. Verificação: 5 execuções completas da suíte e2e verdes e `--repeat-each` do teste com a API atrasada de 200 a 400 ms por rota |

Observações (não bloqueiam): `PT:540` com substring `'1'` (herdada); T30 sem commit próprio; dupla `GET /api/catalog` ao sair; G7 (cosmética) aberta.

---

## Requirement Traceability Update

| Requirement | Situação após a iteração 3 |
|---|---|
| SCAT-01..45 | ✅ comportamento verificado e discriminado (45/45 ancorados, 0 sobrevivente real) |
| Fechamento da feature | ❌ bloqueado pelo gate e2e não determinístico (G12); Status deve voltar a "Implemented" até o PASS |

---

## Isolamento

- Baseline de `git status --porcelain` capturado no início: `M .context/requirements.md`, `M .specs/LESSONS.md`, `M .specs/STATE.md`, `M .specs/lessons.json`, e os untracked `.specs/features/spa-{carta,decks,pasta,portabilidade,troca}/` e `.specs/features/spa-catalogo/validation.md`.
- Final: o mesmo, **mais** `M .specs/features/spa-catalogo/spec.md` e `M .specs/features/spa-catalogo/tasks.md`, alterados às 08:51:47 por **outro agente** (marcação "Verified"/"it.3 PASS"), não por esta sessão. Esta sessão não escreveu nesses arquivos nem em código ou testes. O worktree de mutação foi removido (`git worktree list` só mostra os dois checkouts pré-existentes).

---

## Lições

Registrada via `lessons.py add`: **L-069** (`gate_fail`, origem `frontend/e2e/sessao.spec.ts:112-119`, escopo `frontend/e2e`): checar o estado assentado e ler a medida na mesma chamada `evaluate`, porque uma recarga disparada pela ação pode começar entre duas chamadas separadas. Status `candidate` (recorrência 1).

---

## Summary

**Overall**: ❌ Not Ready (só pelo gate; comportamento verificado)

**Spec-anchored check**: 45/45 ACs, 1 ressalva de precisão herdada
**Sensor**: 17 aplicações, 14 mortas, 3 equivalentes provados, 0 sobreviventes reais
**Gate**: Vitest 551 / Rails 1912 / rubocop 247 / build verdes; e2e 1 falha em 2 de 3 execuções completas

**Next steps**: como é a iteração 3, escalar ao dono: (a) corrigir `sessao.spec.ts:112-119` (G12) e reverificar o gate com 5 execuções completas, ou (b) o dono aceitar o flake como débito explícito; e reverter as marcações "Verified" de `spec.md`/`tasks.md` feitas a partir do relatório concorrente.
