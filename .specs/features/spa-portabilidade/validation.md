# Import e export da coleção na SPA (`spa-portabilidade`) — Validação

**Veredito**: PASS (com 5 gaps Minor/Info, sem Blocker nem Major)
**Data**: 2026-10-11
**Spec**: `.specs/features/spa-portabilidade/spec.md` (SPOR-01..46 e Edge Cases)
**Diff range**: `d5f13c6..fd8841b` (HEAD), T1–T15 mais as correções `b02dcc1` (teto de tamanho e de linhas antes de ler) e `4d338c2` (foco e anúncio da pendência). 34 arquivos fora de `.specs/` e `.context/`; `git status --porcelain` da árvore real vazio antes e depois do sensor.
**Verifier**: sub-agente independente (autor ≠ verificador; não escreveu código, teste nem spec desta feature)
**Iteração**: 1

## Validation: spa-portabilidade - PASS ✅

Resumo: 46/46 ACs rastreados a `arquivo:linha` + asserção; 44 com cobertura plena e 2 (SPOR-18, SPOR-19) com a frase final sem asserção (G1, Minor). Gates verdes no HEAD: Rails 2026 runs, 0 falhas; rubocop limpo; front check + lint + Vitest 927/927; e2e dos dois specs 12/12. Sensor: 17/17 mutantes mortos.

---

## Task Completion

| Task | Status | Notes |
| ---- | ------ | ----- |
| T1–T15 | ✅ Done | Todos os checkboxes de `tasks.md` marcados. |
| FIX1 `b02dcc1` | ✅ Done | Teto de 8 MB e de linhas imposto antes de ler: `app/services/collection_csv/upload.rb:35-42`; provado por `test/services/collection_csv/upload_test.rb:60-107` (mutantes R1 e R2 mortos). |
| FIX2 `4d338c2` | ✅ Done | Foco e anúncio da pendência: `frontend/src/routes/pasta/importar/page.test.ts:135-142`, `frontend/src/routes/pasta/importar/[token]/page.test.ts:190-208`. |

---

## Spec-Anchored Acceptance Criteria

Convenção: `arquivo:linha` – asserção. Abreviações: `PT` = `frontend/src/routes/pasta/importar/page.test.ts`; `TT` = `frontend/src/routes/pasta/importar/[token]/page.test.ts`; `GT` = `frontend/src/lib/imports/groups.test.ts`; `RT` = `frontend/src/lib/components/ImportRowItem.test.ts`; `ST` = `frontend/src/lib/components/ImportSummary.test.ts`; `E2E` = `frontend/e2e/importar.spec.ts`; `CR`/`SH`/`CF`/`CC` = `test/integration/api/collection_imports_{create,show,confirm,concurrency}_test.rb`; `UP` = `test/services/collection_csv/upload_test.rb`. Linhas do HEAD `fd8841b`.

### P1: Envio do arquivo (SPOR-01..08)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 01 | título "Importar coleção — Bindr", h1 e texto exatos | `PT:37-43` – `document.title` `toBe('Importar coleção — Bindr')`, `getByRole('heading',{level:1,name:'Importar coleção'})`, `getByText('Envie o arquivo CSV exportado…')` | ✅ |
| 02 | "Importar coleção" da pasta → `/app/pasta/importar` sem recarga | `frontend/src/routes/pasta/page.test.ts:246-247` – `toHaveAttribute('href','/app/pasta/importar')`, `not.toHaveAttribute('data-sveltekit-reload')` | ✅ |
| 03 | anônimo → `/app/entrar?return_to=…` sem chamar a API, nas duas rotas | `PT:56-62` – `status 307`, `location '/app/entrar?return_to=%2Fapp%2Fpasta%2Fimportar'`, `post` `not.toHaveBeenCalled`; `TT:60-68` – idem com `%2Fapp%2Fpasta%2Fimportar%2Fabc` e `get` não chamado | ✅ |
| 04 | campo "Arquivo CSV" obrigatório, `accept="text/csv,.csv"`, botão "Pré-visualizar importação" | `PT:44-49` – `toBeRequired`, `accept 'text/csv,.csv'`, `name 'file'`, botão presente | ✅ |
| 05 | `POST /api/collection/imports` multipart campo `file`, botão desabilitado, duplo clique ignorado | `PT:75-81` – `post` 1×, path `'/api/collection/imports'`, `body` `toBeInstanceOf(FormData)`, `get('file')` `toBe(file)`, `toBeDisabled()` | ✅ |
| 06 | `201` → `/app/pasta/importar/<token>` sem recarga | `PT:91` – `nav.goto` `toHaveBeenCalledWith('/app/pasta/importar/a%2Fb')` | ✅ |
| 07 | `422`: alerta focado com `message` + `fields.file` na ordem, `aria-describedby`, `aria-invalid`, permanece na rota | `PT:101-111` – regex `…não foi alterada\.\s*Primeira frase\.\s*Segunda frase\.`, `toHaveFocus`, `aria-invalid 'true'`, `aria-describedby` contém o alerta, `goto` não chamado; `E2E:526-534` contra a API real com `;` (frase do separador, foco, URL fica) | ✅ |
| 08 | outro erro: `message` como veio; `401` sem erro local | `PT:121-122` – `alert.textContent toContain(error.message)`, sem `aria-invalid`; `PT:131-132` – `401` sem `alert`. `session_changed` retorna em silêncio (`frontend/src/routes/pasta/importar/[token]/+page.svelte:68`), regra do cliente | ✅ |

### P1: Pré-visualização (SPOR-09..20)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 09 | `GET /api/collection/imports/<token>`, título e h1 | `TT:75-77` – `get` `toHaveBeenCalledWith('/api/collection/imports/abc')`, `document.title 'Pré-visualização da importação — Bindr'`, h1 "Confira o que vai mudar" | ✅ |
| 10 | > 200 ms: `aria-busy="true"` e "Carregando pré-visualização…" | `TT:120-125` – após 250 ms o texto existe e `closest('section')` `aria-busy 'true'`. **Info**: o texto é `.visually-hidden` (`[token]/+page.svelte:97`), como na `spa-pasta`; o spec diz "exibir" (G4) | ✅ |
| 11 | `404`: `message` + "Enviar um arquivo", sem "Tentar novamente"; outro erro: com "Tentar novamente" que repete | `TT:132-137` – link `href '/app/pasta/importar'`, botão ausente; `TT:145-148` – `500` mostra o botão, `get` 2× | ✅ |
| 12 | "Arquivo: <f> — N linha(s) analisada(s)." e aviso "Nada foi gravado…" | `TT:74,78` – `/Arquivo: colecao.csv — 2 linhas analisadas\./`, `/Nada foi gravado na sua coleção ainda/`; `GT:95-99` – `analyzedLines(0/1/2)` `'0 linhas analisadas'`/`'1 linha analisada'`. O "em destaque" não é asserido (CSS) | ✅ |
| 13 | cinco grupos em ordem fixa, "<título> (<n>)", frase de apoio, vazio omitido | `GT:41-68` – ordem, títulos, rótulos e as cinco frases de apoio (`toEqual`); `TT:87-88` – `['Remove da coleção (2)','Passa a constar (1)','Já está assim (1)']`; `GT:78-83` vazio omitido | ✅ |
| 14 | rótulo escrito, número, código em `code`, nome, "—" no ausente, "Linha N do arquivo", ordem da resposta | `RT:24-48` – cinco rótulos, `getByText('tcgplayer:1').tagName` `'CODE'`, `'Linha 7 do arquivo'`, `getAllByText('—')` 2; `GT:71-76` – ordem dentro do grupo `[5,7]`, `[2,6]` | ✅ |
| 15 | recusada: `message`; `creates`: "Você não tem esta variante…"; demais: "De quantidade atual X para nova quantidade Y.", valores em elementos próprios | `RT:50-55` – `'De quantidade atual 2 para nova quantidade 5.'`, `getByText('2').tagName 'STRONG'`; `RT:57-65`; `RT:67-78` | ✅ |
| 16 | distinção por rótulo, cabeçalho e forma/peso, não só cor | `RT:88-92` – lê o `.svelte` e exige `overflow-wrap: anywhere` e `border-inline-start-style` (regex sobre o código-fonte, fraca; o e2e de 360px cobre o layout). Rótulo e cabeçalho: `GT:48-61` | ✅ |
| 17 | `<script>` no nome/arquivo/mensagem aparece escrito, não executa | `RT:80-86` – `getByText('<script>alert(1)</script>')`, `querySelector('script')` `toBeNull`; `TT:108-114` idem na página | ✅ |
| 18 | `removes` → "Atenção: N cartas…" antes do botão, seguido de "Veja quais em “Remove da coleção”, no topo desta página." | `TT:89-91` – `getByText('Atenção: 2 cartas que você possui hoje saem da sua coleção se você confirmar.')`; `GT:101-108` – singular e plural; `TT:100` – ausente sem `removes`. **A segunda frase (`[token]/+page.svelte:132`) e a posição "antes do botão" não têm asserção (G1)** | ⚠️ Parcial (Minor) |
| 19 | botão "Confirmar e gravar na minha coleção", texto "Se algo estiver errado…", link "envie outro arquivo" sem recarga | `TT:101-105` – botão presente e link `href '/app/pasta/importar'`. **O texto "Se algo estiver errado, envie outro arquivo. Sair desta página sem confirmar deixa sua coleção exatamente como está." (`[token]/+page.svelte:142`) não é asserido (G1)** | ⚠️ Parcial (Minor) |
| 20 | `collection_items` inalterada ao abrir, recarregar e sair | `E2E:397,401,409-411` – `exportCsv(context)` `toBe(before)` depois de enviar/abrir, de recarregar e de sair sem confirmar (API real); `CR:81` – `assert_no_changes` em `collection_items` no envio | ✅ |

### P1: Confirmação e resumo (SPOR-21..32)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 21 | `POST …/confirm` sem corpo, botão desabilitado, duplo acionamento ignorado | `TT:165-168` – `post` 1× com `('/api/collection/imports/abc/confirm', undefined, {timeoutMs: 60000})` | ✅ |
| 22 | `200` troca pelo resumo na mesma URL, título "Importação concluída — Bindr", h1 focado | `TT:164,169-170` – h1 "Importação concluída" `toHaveFocus`, `document.title`; `E2E:462-467` – `toHaveTitle('Importação concluída — Bindr')` na API real | ✅ |
| 23 | "Arquivo: <f> — sua coleção foi atualizada." e três contagens em ordem, com frase de apoio, com zero | `ST:29-42` – `toEqual(['Importadas','Atualizadas','Recusadas'])`, cada `.value` `'0'`, as três frases de apoio; `E2E:470-474` – `["1","2","1"]` igual ao HTML | ✅ |
| 24 | `removed` > 0: frase singular/plural | `ST:49-53` – `'1 dessas atualizações removeu a carta…'`; `GT:110-117` – plural | ✅ |
| 25 | `unchanged` > 0: frase singular/plural | `ST:56-63` – ausente com 0, `'4 linhas do arquivo já estavam assim…'`; `GT:119-126` | ✅ |
| 26 | recusas: frase + `card_number`, `variant_code`, `card_name`, "Linha N", `message` | `ST:81-90` – frase "Confira estas linhas…", e o `li` contém `OP01-001`, `tcgplayer:1`, `Zoro`, `Quantidade inválida.`; `GT:128-135` plural | ✅ |
| 27 | falhas separadas das recusas, "Linha N do arquivo — <card_number> <variant_code>" | `ST:91-92` – `getByText(/^Atenção: 1 linha não pôde ser gravada/)`, `'Linha 9 do arquivo — OP01-002 tcgplayer:2'`; `GT:137-144` | ✅ |
| 28 | sem recusa nem falha: nenhum "rejeitada", "falha", "erro" | `ST:95-100` – `container.textContent` `not.toMatch(/rejeitada|falha|erro/i)` | ✅ |
| 29 | links "Ver minha coleção" → `/app/pasta` e "importar outro arquivo" → `/app/pasta/importar`, sem recarga | `ST:104-109` – `href` e `not.toHaveAttribute('data-sveltekit-reload')` | ✅ |
| 30 | `409 import_closed`: mantém a pré-visualização, `message` em `role="alert"` | `TT:182-187` – alerta com a `message`, h1 "Confira o que vai mudar" ainda na tela, botão habilitado, alerta focado; `E2E:490-503` – na API real, recarregar depois do resumo e confirmar dá a frase "já foi confirmada ou expirou" e a coleção não muda | ✅ |
| 31 | falha sem resposta: frase do P13 + link "Ver minha coleção", sem reenviar | `TT:224-231` – a frase exata, link `href '/app/pasta'`, botão de confirmar ausente, `post` `toHaveBeenCalledTimes(1)` | ✅ |
| 32 | 60 s no envio e na confirmação, 15 s nas demais | `frontend/src/lib/imports/api.test.ts:21-23` (constante); `PT:80` – `options toEqual({ timeoutMs: 60000 })`; `TT:166-168`; `frontend/src/lib/api/client.test.ts:826-841` – relógio falso: `get` cai em `network_error` aos 15 s, `post` com 60 s só aos 60 s | ✅ |

### P1: Ida e volta com o export (SPOR-33, 34)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 33 | "Baixar minha coleção (CSV)" segue link de página inteira para `/collection/export`, sem endpoint em `/api` | `frontend/src/routes/pasta/page.test.ts:246-247` – `href '/collection/export'` e `data-sveltekit-reload`; `frontend/e2e/importar-ida-e-volta.spec.ts:92` – o teste usa o link da pasta; o diff de `config/routes.rb` traz só as três rotas de import | ✅ |
| 34 | CSV baixado e reenviado: só "Já está assim"; depois de confirmar a coleção é idêntica | `E2E:425-437` – `preview.groups.map(title)` `toEqual(["Já está assim (N)"…])` e coleção igual; `frontend/e2e/importar-ida-e-volta.spec.ts:33` (usuário com três sets e variante zerada, CSV do link da pasta, confirmação, `exportCsv` igual ao de antes) | ✅ |

### P1: Cliente HTTP com arquivo (SPOR-35)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 35 | `FormData` sem `Content-Type` próprio, com `X-CSRF-Token`, renova e reenvia uma vez; outro e-mail não reenvia; `fetch` só em `client.ts` | `frontend/src/lib/api/client.test.ts:760` (corpo, header sem `Content-Type`, com CSRF), `:781-798` (reenvio do mesmo `FormData`, `fetch` 3×, timeouts `[60000,15000,60000]`), `:800-824` (outro e-mail: `session_changed`, sem reenvio); `npm run lint` verde (regra do ESLint da `spa-fundacao`) | ✅ |

### P1: API do import (SPOR-36..45)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 36 | `201`, staging do usuário da sessão, nome saneado, sem tocar `collection_items` | `CR:81-98` – `assert_no_changes` em `collection_items`, `assert_difference` 1 em `CollectionImport.for_user`, `assert_response :created`, `filename "minha_coleção.csv"`; `UP:41-58`, `UP:145-160` | ✅ |
| 37 | `422 validation_failed`, `message` geral, `fields.file`, sem staging (sem arquivo, > 12 MB, parser recusa) | `CR:104-146` – `assert_no_difference CollectionImport.count` em vazio/`;`/Latin-1/sem arquivo/JSON/string/13 MB, `assert_refused` confere `code`, `GENERAL` e a frase; `UP:60-143`. A frase de UTF-8 e a de 10.000 linhas são comparadas com a saída do `Parser` (`UP:140`), não com o texto literal | ✅ |
| 38 | `{token, filename, rows}` com `line` (+2), `classification`, `quantity_before` `null` (nunca `0`), `quantity_after` `null` na recusada, `message`; também vencido | `CR:94-101` – `classification` `%w[removes creates updates rejected unchanged]`, `line [2,3,4,5,6]`, `quantity_before [3,nil,1,nil,2]`, `quantity_after [0,2,5,nil,2]`; `SH:55-75` – `get` igual ao `201`, e `travel 3.hours` continua `200` | ✅ |
| 39 | token alheio, inexistente e malformado: o mesmo `404`, sem gravar | `SH:77-92` – três `404` com corpos iguais (`assert_equal corpo`); `CF:208-222` – confirmação idem, `status "pendente"` e `snapshot` inalterado | ✅ |
| 40 | `200` `{filename, created, updated, removed, unchanged, rejected, failures}`, `updated` inclui `removed`, mesmo `Commit` do HTML, corpo ignorado | `CF:86-96` – `created 1`, `updated 1`, `removed 1`, `unchanged 1`, `rejected` com `line 5`/`card_number`/`variant_code`/`card_name`, `failures []`; `CF:101-123` – coleção igual à do HTML para o mesmo staging; `CF:126-139` – `file` e `linhas` no corpo ignorados; `CF:159-178` – `failures` com `line 2` | ✅ |
| 41 | confirmada ou vencida: `409 import_closed` com a frase, sem gravar | `CF:181-206` – `assert_response :conflict`, `code "import_closed"`, `message MENSAGEM_409`, `assert_no_changes snapshot` (repetida e `expires_at` vencido) | ✅ |
| 42 | duas confirmações simultâneas: grava uma vez, `409` à outra | `CC:104-112` – `[200, 409]`, `quantity [3]`, `status "confirmado"` (duas threads com lock forçado) | ✅ |
| 43 | sessão (`401`), CSRF (`422`), só registros do usuário, `user_id` ignorado | `CR:148-176` (`401`, `422 invalid_csrf_token`, `user_id` no corpo e na query ignorado); `SH:94-105` (`401`, `?user_id=` ignorado); `CF:224-239` (`422` e `401`). Confirmação com `user_id` não tem teste próprio (G3); o escopo é por `Current.user` em `app/controllers/api/collection_imports_controller.rb:46` | ✅ (ver G3) |
| 44 | consultas não crescem com as linhas, no envio e na leitura | `CR:178-190` e `SH:107-118` – `assert_equal consultas_pequeno, consultas_grande` (2 × 200 linhas) | ✅ |
| 45 | controllers e views HTML intocados, suíte existente sem edição | `git diff --name-status d5f13c6..HEAD -- test/ app/controllers/collection_imports_controller.rb app/views/collection_imports app/services/collection_csv` → só seis linhas `A`, nenhuma `M`/`D`; Rails 2026 runs, 0 falhas | ✅ |

### P2: 360px e os dois temas (SPOR-46)

| AC | Resultado definido no spec | Evidência | Result |
|---|---|---|---|
| 46 | três telas a 360px (e 1280px) nos dois temas sem scroll horizontal, nome/código longos, botões ≥ 44px | `E2E:544-584` – quatro combinações; `E2E:269` `scrollWidth` `toBe(clientWidth)` em envio, pré-visualização e resumo; `getByText(LONG_NAME)`/`LONG_CODE` visíveis; `E2E:278-285` `height`/`width` `toBeGreaterThanOrEqual(44)` | ✅ |

**Status**: 44 ✅ pleno, 2 ⚠️ parcial (SPOR-18, SPOR-19: frase sem asserção, G1). Nenhum ❌.

---

## Edge Cases

- [x] Mesma variante em duas linhas: classificação é do `Resolver` (feature `portabilidade`); a SPA exibe a `message` da recusada (`RT:67-78`). Sem teste de ponta a ponta nesta feature.
- [x] Só o cabeçalho: `TT:94-105` – "0 linhas analisadas.", nenhum h2, botão presente. O resumo com zeros existe em `ST:26-43`, mas o fluxo todo não tem teste (G5).
- [x] BOM, ordem de colunas, `;`: regra do `Parser` (Req. 10); `;` recusado com frase em `fields.file`: `CR:108-117`, `E2E:526`. BOM e ordem não são retestados aqui.
- [x] Não UTF-8: `CR:109,117` e `UP:129,140` – `422` com `fields.file` presente (não `500`); a frase é a do `Parser`.
- [x] Mais de 10.000 linhas: `UP:85-107` e `UP:125-143` – recusa sem staging, sem chamar o `Parser` no caso de linhas curtas.
- [x] Sessão expirada entre pré-visualização e confirmação e outra conta em outra aba: o cliente trata `401` (`spa-fundacao`) e `[token]/+page.svelte:68` retorna sem alerta; não há teste de página nem e2e que exerça o `return_to` do token (G2). O `404` com outra conta: `SH:77-92`.
- [x] Recarregar depois do resumo: `E2E:489-503`.
- [x] Coleção mudou entre pré-visualização e confirmação: `CF:142-157`.
- [x] `colecao.csv` como nome saneado: `UP:152-153`.
- [x] Token com caractere reservado: `frontend/src/lib/imports/api.test.ts:11-19`; malformado dá `404`: `SH:89-91`.
- [x] 10.000 linhas na pré-visualização: `E2E:590-640` – `toHaveCount(MAX_ROWS)` e tempos medidos (360px: 3,3 s envio→botão, 2,3 s abrir; 1280px: 9,1 s e 3,2 s).
- [x] Corpo não multipart: `CR:128-133` – `422` com a frase de arquivo ausente.

---

## Discrimination Sensor

Cópia `rsync` do repo para `/tmp/claude-1000/v/copy` (fora do repo); front rodado por `docker run node:24.21.0-slim` com a cópia montada, Rails por `docker run` da imagem do `app` com a cópia em `/rails`. Linha-base da cópia sem mutação: Vitest `src/lib/imports` + `src/routes/pasta/importar` 35/35; Rails `upload_test` + `show_test` 13 runs, 0 falhas. Cada arquivo mutado foi restaurado do repo real; `git status --porcelain` da árvore real igual ao baseline (vazio) ao fim.

| Mutação | Arquivo:linha | Descrição | Killed? |
| ------- | ------------- | --------- | ------- |
| F1 | `frontend/src/lib/imports/groups.ts:24` | rotulagem: `label: 'Cria'` → `'Altera'` | ✅ (`RT` + `GT`, 2 falhas) |
| F2 | `frontend/src/lib/imports/groups.ts:15` | ordem dos grupos: `removes` deixa de casar | ✅ (`GT`) |
| F3 | `frontend/src/lib/components/ImportRowItem.svelte:19` | SPOR-17: `{row.card_name}` → `{@html …}` | ✅ (`RT:80-86`, `TT:108-114`) |
| F4 | `frontend/src/lib/api/client.ts:85` | CSRF: sem `X-CSRF-Token` em `FormData` | ✅ (`client.test.ts`, 2 falhas) |
| F5 | `frontend/src/lib/api/client.ts:84` | `Content-Type` próprio no `FormData` | ✅ (`client.test.ts`, 2 falhas) |
| F6 | `frontend/src/lib/imports/api.ts:3` | tempo limite 60 s → 15 s | ✅ (`api.test.ts:21`, `PT`, `TT`) |
| F7 | `frontend/src/routes/pasta/importar/[token]/+page.svelte:57` | sem trava de duplo clique na confirmação | ✅ (`TT:151`) |
| F8 | `frontend/src/routes/pasta/importar/[token]/+page.svelte:69` | `409` tratado como resultado desconhecido | ✅ (`TT:173`) |
| F9 | `frontend/src/lib/imports/groups.ts:63` | aviso de remoção: singular errado | ✅ (`GT:101`) |
| R1 | `app/services/collection_csv/upload.rb:35` | teto de `Content-Length` (12 MB) removido | ✅ (17 runs: 1 falha, 1 erro) |
| R2 | `app/services/collection_csv/upload.rb:42` | teto de linhas por contagem de quebras removido | ✅ (9 runs: 1 falha) |
| R3 | `app/controllers/api/collection_imports_controller.rb:46` | `409 import_closed` → `422` | ✅ (10 runs: 3 falhas) |
| R4 | `app/controllers/api/collection_imports_controller.rb:21` | escopo por usuário do token removido (`find_by(token:)`) | ✅ (4 runs: 2 falhas) |
| R5 | `app/views/api/collection_imports/confirm.json.jbuilder:4` | `updated` sem somar `removed` | ✅ (9 runs: 2 falhas) |
| R6 | `app/views/api/collection_imports/_preview.json.jbuilder:4` | `line` sem o `+2` | ✅ (12 runs: 1 falha) |
| R7 | `app/views/api/collection_imports/_preview.json.jbuilder:9` | `quantity_before` `0` no lugar de `null` | ✅ (12 runs: 1 falha) |
| R8 | `app/controllers/api/collection_imports_controller.rb:12` | `cria: "creates"` → `"updates"` | ✅ (12 runs: 1 falha) |

**Sensor depth**: P0-full manual (≥ 5 mutações; dado insubstituível da coleção), cobrindo teto de linhas e bytes, `409`, escopo por usuário do token, rotulagem e ordem dos grupos, escape do texto do arquivo e CSRF do `FormData`.
**Result**: 17/17 killed — PASS ✅. Não mutado: o escopo por usuário no `confirm` (`Commit.new(Current.user, …)`), provado só por `CF:208-222`.

---

## Code Quality

| Principle | Status |
| --------- | ------ |
| Minimum code | ✅ — `Upload` é um objeto só; `ImportRowItem`, `ImportSummary` e `groups.ts` têm uso real |
| Surgical changes | ✅ — nenhum controller, view ou serviço HTML alterado (SPOR-45); fora de testes, só `CLAUDE.md` e um link em `frontend/src/routes/pasta/+page.svelte` de arquivos existentes |
| No scope creep | ✅ |
| Matches patterns | ✅ — `createLoader`, `FormError`, `Button`, jbuilder parcial como no resto da `/api` |
| Spec-anchored outcome check (asserted values match spec) | ✅ 44/46; SPOR-18 e 19 parciais (G1) |
| Per-layer Coverage Expectation met (domain 1:1 ACs; routes happy+edge+error) | ✅ — três rotas com sucesso, recusa, `401`, `422` CSRF, `404`, `409` |
| Every test maps to a spec requirement — no unclaimed tests | ✅ |
| Documented guidelines followed | `CLAUDE.md` do projeto (gates Rails e front) — seguidos |
| Duplicação conhecida | `CollectionCsv::Upload` repete a regra do controller HTML; `UP:162-166` fixa as constantes e `UP:145-160` o saneamento; sai na `spa-troca` (registrado em `CLAUDE.md`) |

---

## Gate Check

- **Gate command**: `docker compose exec -T app bin/rails test`; `bin/rubocop`; `docker compose run --rm --no-deps frontend sh -c "npm ci && npm run check && npm run lint && npm test -- --run"`; `docker compose --profile e2e run --rm e2e npx playwright test e2e/importar.spec.ts e2e/importar-ida-e-volta.spec.ts` (em série, `docker compose stop frontend` antes do `npm ci`).
- **Result**: Rails 2026 runs, 8463 assertions, 0 falhas, 0 erros, 0 skips; rubocop 274 arquivos, nenhuma ofensa; `check` e `lint` sem erro; Vitest 65 arquivos, 927 testes, 0 falhas; e2e 12 passaram, 0 falharam.
- **Test count before feature** (`CLAUDE.md` em `d5f13c6`): Vitest 859, Rails 1995, e2e 193.
- **Test count after**: Vitest 927 (+68), Rails 2026 (+31). Os e2e da feature são 12 (a suíte inteira de 193 não foi rerodada; só os dois specs pedidos).
- **Skipped tests**: nenhum.
- **Failures**: nenhuma. Os avisos `STATS_DIRECTORIES` do Rails são ruído do rake.
- **Integridade de testes**: nenhum teste existente foi apagado nem enfraquecido; a única edição de teste existente é `frontend/src/routes/pasta/page.test.ts` (`/collection/import` → `/app/pasta/importar`, a mudança que o SPOR-02 manda) e a suíte Rails só tem arquivos `A`.

---

## Gaps (ranqueados)

| # | Severidade | Gap | Fix sugerido |
|---|---|---|---|
| G1 | Minor | SPOR-18 e SPOR-19: as frases "Veja quais em “Remove da coleção”, no topo desta página." (`frontend/src/routes/pasta/importar/[token]/+page.svelte:132`) e "Se algo estiver errado, envie outro arquivo. Sair desta página sem confirmar deixa sua coleção exatamente como está." (`:142`) existem, mas nenhum teste as assere; também falta provar que o aviso de remoção vem antes do botão | Duas asserções em `TT` (`toHaveTextContent`) e `compareDocumentPosition` entre o aviso e o botão |
| G2 | Minor | Edge Cases de sessão: sem teste de página nem e2e de `401` na confirmação com `return_to=/app/pasta/importar/<token>` e de troca de conta; a página só retorna em `unauthenticated`/`session_changed` (`:68`) | Teste de página com `ApiError(401)`/`session_changed` no `post`: `post` 1×, sem alerta, sem resumo; e2e opcional |
| G3 | Minor | SPOR-43: `user_id` no corpo ou na query da confirmação não tem teste (envio e leitura têm: `CR:168-176`, `SH:94-105`) | Um caso em `CF` com `?user_id=<outro>` e corpo com `user_id`, afirmando que a coleção do outro não muda |
| G4 | Info | SPOR-10: "Carregando pré-visualização…" é `visually-hidden` (`[token]/+page.svelte:97`); o spec diz "exibir". Mesmo padrão da `spa-pasta` | Alinhar a redação do spec ("anunciar") ou mostrar o texto |
| G5 | Minor | Edge "só o cabeçalho → confirmar dá um resumo com três zeros": nenhum teste faz o fluxo inteiro (só a pré-visualização `TT:94-105` e o resumo com zeros `ST:26-43`, separados) | Teste de página: `preview([])`, confirmar com resumo zerado, h1 "Importação concluída" |

Observações sem gap: SPOR-16 é provado por regex sobre o código-fonte do componente (`RT:88-92`); o e2e de 360px cobre o layout, mas a distinção "além da cor" não é medida visualmente. A pendência P13 (resposta da confirmação perdida) continua aberta para o dono e a implementação segue o default recomendado (SPOR-31).

---

## Requirement Traceability Update

| Requirement | Previous Status | New Status |
| ----------- | --------------- | ---------- |
| SPOR-01..17, 20..46 | Implemented | ✅ Verified |
| SPOR-18, SPOR-19 | Implemented | ✅ Verified com ressalva Minor (G1: frase sem asserção) |

---

## Summary

**Overall**: ✅ Ready (PASS) — nenhum Blocker nem Major; cinco gaps Minor/Info para fix tasks opcionais.

**Spec-anchored check**: 44/46 ACs com asserção que bate com o resultado do spec; 2 parciais (SPOR-18, 19); SPOR-10 "exibir" × `visually-hidden` registrado em G4.
**Sensor**: 17/17 mutantes mortos.
**Gate**: Rails 2026 passam, rubocop limpo, Vitest 927 passam, e2e 12 passam.

**What works**: envio, pré-visualização, confirmação e resumo na SPA com paridade com o HTML provada contra a API real; a barreira "nada grava antes de confirmar" (`E2E:389-414`); `409` e corrida de confirmação; escopo por usuário e CSRF nos três endpoints; ida e volta do CSV; 360px e 1280px nos dois temas; pré-visualização de 10.000 linhas medida.

**Issues found**: G1–G5 acima, todos de cobertura de teste, nenhum de comportamento.

**Next steps**: o orquestrador decide se abre fix tasks para G1–G3 e G5 (testes pequenos, sem mudar código de produção) ou aceita como dívida; G4 é ajuste de redação do spec. Pendência do dono: P13.
