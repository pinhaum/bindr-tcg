# Plano de execução — Imagens servidas pela aplicação (§3.6)

Espelha `.context/tasks.md` §3.6. A fonte de verdade da ordem é
`.context/tasks.md`; este documento acrescenta dependências, gate e teste
explícitos por task (AD-005). **Ao concluir uma task, marcar o checkbox nos dois
planos e commitar junto com o código.** A §3.6 cobre T1–T3 e só fecha na T3.

A feature é governada por **AD-012** e o contrato normativo é `design.md` §7.
Não se reabre: cache em disco sob demanda, sem Postgres, sem Active Storage,
sem gem nova.

## Execution Protocol

- Uma task por vez, em ordem. Não abrir a próxima com a anterior incompleta.
- Toda task termina com código que roda e teste que passa.
- Testes derivam dos critérios de aceitação da spec, nunca espelham a
  implementação. Nunca enfraquecer, pular ou apagar teste para passar no gate.
- Se um requisito se mostrar errado, parar e avisar o dono do produto (AD-005).
- Um commit atômico por task, em português brasileiro, Conventional Commits, sem
  linha de atribuição.
- **Nenhum teste toca a rede.** Minitest 6 não traz `minitest/mock`: a costura é
  injeção explícita (argumento do serviço e um default de classe trocável pelo
  teste, restaurado em `teardown`), no padrão de `Ingestion::Fetch`.
- **Nenhum teste grava em `storage/card_images/` real**: o diretório é injetável
  e o teste usa `Dir.mktmpdir`. A suíte roda em paralelo por processos.
- **Nenhuma mudança de CSS.** `catalog.css` é da `interface`. Se parecer
  necessário, parar e perguntar.
- Nada de `git stash` nem worktree.

## Test Coverage Matrix

| Camada | Tipo de teste | Onde |
|---|---|---|
| Serviço de cache (URL, host, extensão, escrita atômica, falha) | unit | `test/services/card_image_cache_test.rb` |
| Rota, controller, status, cabeçalhos, acesso público | integration | `test/integration/card_images_test.rb` |
| `<img>` da grade e do detalhe apontando para a rota | integration | `test/integration/catalog_grid_test.rb`, `test/integration/card_detail_test.rb` |

## Gate Check Commands

| Gate | Comando |
|---|---|
| quick | `docker compose exec app bin/rails test test/services test/integration/card_images_test.rb` |
| full | `docker compose exec app bin/rails test && docker compose exec app bin/rubocop` |
| build | `docker compose build` |

Além do full, a T3 roda `docker compose exec app bin/brakeman`.

## Execution Plan

### Phase 1: Serviço de cache

O conhecimento de rede, host e disco mora num único objeto, provado por unidade
antes de existir rota.

```
T1
```

### Phase 2: Endpoint

```
T1 → T2
```

### Phase 3: Views

```
T2 → T3
```

## Task Breakdown

### T1: `CardImageCache` — fetch restrito ao host, escrita atômica, falha não cacheada ✅

**What**: Serviço que recebe uma `CardVariant` e devolve o caminho do arquivo em disco (baixando e gravando na primeira vez) ou falha tipada, sem nunca ler URL de fora do registro.
**Where**: `app/services/card_image_cache.rb`
**Depends on**: None
**Reuses**: padrão de `Ingestion::Fetch` (`app/services/ingestion/fetch.rb`): cliente `Net::HTTP` injetável com `get(url)` → `[status, corpo]`, rescue da mesma lista de exceções de rede, `binwrite` em temporário + `File.rename`
**Requirement**: IMG-05, IMG-06, IMG-08, IMG-10, IMG-12, IMG-13

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Host permitido é constante (`asia-en.onepiece-cardgame.com`), esquema `https`, porta 443; URL malformada, outro host, outro esquema ou outra porta falham **sem** chamar o cliente HTTP — teste com dublê que registra chamadas prova zero chamadas
- [x] Extensão vem do caminho de `image_url` e só `.png`, `.jpg`, `.jpeg`, `.webp` são aceitas; outra extensão falha sem chamar o cliente
- [x] Cliente próprio com timeouts curtos (ordem de segundos), sem seguir redirect; status ≠ 200 (inclusive 301/302) e corpo vazio são falha
- [x] Erro de rede e timeout (`Net::OpenTimeout`, `Net::ReadTimeout` e a mesma lista de `Ingestion::Fetch`) viram falha tipada, nunca exceção crua
- [x] Sucesso grava `<dir>/<variant_code>.<ext>` via temporário único no mesmo diretório + `rename`; teste prova que os bytes gravados são os do dublê
- [x] Arquivo já em disco é devolvido sem chamar o cliente
- [x] Falha não deixa arquivo final nem temporário no diretório; a chamada seguinte chama o cliente de novo
- [x] Variante sem `image_url` falha sem chamar o cliente
- [x] Diretório injetável; default `Rails.root.join("storage", "card_images")`; testes usam `Dir.mktmpdir`

**Tests**: unit
**Gate**: quick

### T2: Rota pública `GET /card_images/:variant_code` e `CardImagesController` ✅

**What**: Rota e controller público que valida o formato de `variant_code`, resolve a variante no banco, delega ao `CardImageCache` e serve o arquivo com cache HTTP longo, ou responde erro sem corpo.
**Where**: `config/routes.rb`, `app/controllers/card_images_controller.rb`
**Depends on**: T1
**Reuses**: `allow_unauthenticated_access` como em `CatalogController`; `send_file`/`expires_in` do Rails
**Requirement**: IMG-04, IMG-05, IMG-07, IMG-08, IMG-09, IMG-11, IMG-12, IMG-13

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] Rota `get "card_images/:variant_code"` com helper `card_image_path`, sem formato (`format: false`), comentada no estilo do `routes.rb`
- [x] `variant_code` validado contra `\A[A-Za-z0-9]+(-[A-Za-z0-9]+)*(_[a-z0-9]+)?\z` no controller **antes** de qualquer consulta; teste com `..`, `%2F`, `OP01-001.png` e similares prova 404 sem chamada ao cliente e sem arquivo criado
- [x] Anônimo recebe 200 (não redirect) para variante com imagem
- [x] 200 traz os bytes do dublê, `Content-Type` pela extensão (`image/png`), `Cache-Control` com `public` e `max-age=31536000`, disposição inline
- [x] Segunda requisição da mesma variante não chama o cliente
- [x] Variante inexistente e variante sem `image_url` → 404 corpo vazio, sem chamada ao cliente
- [x] Falha da fonte (status ≠ 200, timeout, host recusado) → 502 corpo vazio; nada gravado
- [x] Nenhum parâmetro do request além de `variant_code` é lido; teste com `?url=https://evil.test/x.png` prova que o cliente recebe a URL do banco
- [x] Controller não lê `Current.user` (não há dado de usuário aqui)

**Tests**: integration
**Gate**: quick

### T3: Grade e detalhe apontam o `<img>` para a rota ✅

**What**: `_card_tile.html.erb` e `catalog/show.html.erb` passam a usar `card_image_path(variant.variant_code)` no `<img>`, mantendo o placeholder e o `loading="lazy"`; comentário de cabeçalho do tile deixa de explicar o hotlink.
**Where**: `app/views/catalog/_card_tile.html.erb`, `app/views/catalog/show.html.erb`, `test/integration/catalog_grid_test.rb`, `test/integration/card_detail_test.rb`
**Depends on**: T2
**Reuses**: condição `variant.image_url.present?` já existente nas duas views
**Requirement**: IMG-01, IMG-02, IMG-03

**Tools**:

- MCP: NONE
- Skill: `superpowers:test-driven-development`

**Done when**:

- [x] O `<img>` da grade e o de cada variante do detalhe têm `src` igual a `card_image_path(variant_code)`; teste asserta que nenhum `src` contém o valor de `image_url`
- [x] Variante sem `image_url` continua sem `<img>`; os testes de placeholder existentes continuam passando sem asserção enfraquecida (Req. 2.3)
- [x] `loading="lazy"` continua no `<img>` da grade
- [x] O detalhe deixa de usar `image_url_large` (Out of Scope; coluna vazia), sem outra mudança de layout
- [x] Cabeçalho de `_card_tile.html.erb` descreve AD-012 (imagem servida pela aplicação; placeholder atrás cobre falha 404/502) em vez do hotlink da AD-004; comentários de teste que citam hotlink/AD-004 atualizados para AD-012
- [x] Se `catalog/show.html.erb:112` se deslocar, a citação em `.specs/features/interface/tasks.md` (T11) é atualizada no mesmo commit — linha 112 mantém-se a mesma, sem deslocamento
- [x] Nenhum arquivo CSS alterado
- [x] Checkbox marcado aqui e em `.context/tasks.md` §3.6
- [x] Gate full e `bin/brakeman` limpos

**Tests**: integration
**Gate**: full
