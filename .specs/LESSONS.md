# LESSONS - auto-maintained by scripts/lessons.py

> Machine-owned. Do NOT hand-edit. Changes are overwritten on the next `lessons.py` write.
> Canonical state lives in `.specs/lessons.json`. Edit lessons only via the script.
> promote_threshold=2 distinct features · window_days=45 · quarantine_threshold=2

## Confirmed (load these at Specify/Design)

Corroborated across multiple features. Safe to apply as guidance.

_none_

## Candidates (under observation - do NOT load as guidance yet)

Seen once or not yet corroborated. Tracked, not trusted.

### L-001 - Conversor string→número: testar o caminho da string NÃO-numérica, não só nil e vazio; a guarda de nil responde antes e mascara o mutante que devolve 0 no lugar de nil.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `ingestion/normalize` · harmful: 0
- features: catalogo
- evidence: app/services/ingestion/normalize.rb:189 (mutante M10) (ingestion/normalize)
- last seen: 2026-09-19T21:52:58Z

### L-002 - Quando o spec proíbe um sentinela (0 para ausência), declarar a proibição para todos os campos numéricos, não só o exemplo citado — senão os demais campos ficam sem critério de aceite.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `spec/edge-cases` · harmful: 0
- features: catalogo
- evidence: .specs/features/catalogo/spec.md (Edge Cases) — proibição de sentinela citada só para counter (spec/edge-cases)
- last seen: 2026-09-19T21:53:12Z

### L-003 - Quando uma guarda combina duas condições (aplicável ao tipo E tem valor), a fixture precisa satisfazer uma e violar a outra; dar nil ao campo inaplicável colapsa as duas e deixa metade da guarda sem teste.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `test/fixtures` · harmful: 0
- features: catalogo
- evidence: app/models/card.rb:118 (M13) (test/fixtures)
- last seen: 2026-09-19T22:54:58Z

### L-004 - Limiar de similaridade precisa de teste nos dois sentidos: só assert_includes trava o limite superior, e afrouxar o limiar inunda o resultado sem derrubar nada — acrescentar refute_includes de um resultado irrelevante.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `search/threshold` · harmful: 0
- features: catalogo
- evidence: app/queries/catalog_query.rb:60 (M10) (search/threshold)
- last seen: 2026-09-19T22:54:58Z

### L-005 - Quando um resultado é prependido fora da paginação, testar página >= 2 explicitamente: testar só a página 1 deixa o ramo de offset sem cobertura e esconde violação do tamanho de página.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `pagination` · harmful: 0
- features: catalogo
- evidence: .specs/features/catalogo/validation.md D1 (app/queries/catalog_query.rb:158) (pagination)
- last seen: 2026-09-19T22:54:58Z

### L-006 - Escrita atômica: teste só verifica ausência de .part final, não previne arquivo pela metade em concorrência. Mutante 2 (gravar direto em final_path) sobreviveu.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · harmful: 0
- features: imagens
- evidence: test/services/card_image_cache_test.rb:242-256
- last seen: 2026-09-22T23:15:52Z

### L-007 - Cleanup em exceção: remover ensure File.delete(temporary) não foi detectado. Nenhum teste força exception durante persist() para verificar remoção de .part.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · harmful: 0
- features: imagens
- evidence: test/services/card_image_cache_test.rb:173-185
- last seen: 2026-09-22T23:15:56Z

### L-008 - Status HTTP: trocar status == 200 por status.between?(200, 299) não foi detectado. Testes aceitam qualquer 2xx e redirect; spec exige exatamente 200.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · harmful: 0
- features: imagens
- evidence: test/services/card_image_cache_test.rb:298-310
- last seen: 2026-09-22T23:16:01Z

### L-009 - Teste textual que compara regras CSS de modificador deve comparar o estilo efetivo com a cascata do bloco base, não a lista de declarações do modificador, senão uma declaração que repete o valor herdado conta como diferença visual.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `css/text-tests` · harmful: 0
- features: interface
- evidence: validation.md M2b; test/design/flash_test.rb:29 (css/text-tests)
- last seen: 2026-09-23T01:20:41Z

### L-010 - Ao inventariar ocorrências de um dado na interface, incluir as strings compostas no controller e exibidas por flash, não só as views, porque o flash também é texto renderizado.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `views/flash` · harmful: 0
- features: interface
- evidence: validation.md INT-08; app/controllers/wishlist_items_controller.rb:50 (views/flash)
- last seen: 2026-09-23T01:20:41Z

### L-011 - Número de itens citado na spec deve sair de uma medição registrada, ou a spec deve descrever o critério sem o número, porque uma contagem estimada diverge da medida e desalinha spec e plano.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `spec/counts` · harmful: 0
- features: interface
- evidence: validation.md ponto (c); spec.md Problem Statement (spec/counts)
- last seen: 2026-09-23T01:20:41Z

### L-012 - Quando uma pendência aberta suspende parte de um requisito, o texto do requisito deve dizer que a cláusula só vale depois da pendência, senão o requisito contradiz o design que aplica o tratamento provisório.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `spec/pending-decisions` · harmful: 0
- features: interface
- evidence: validation.md ressalva 3; .context/requirements.md Req. 12.11 (spec/pending-decisions)
- last seen: 2026-09-23T01:20:41Z

### L-013 - Todo token que o teste assere com valor exato precisa ter esse valor escrito no documento normativo, senão o teste trava um número que a spec não define.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `design-tokens` · harmful: 0
- features: interface
- evidence: validation.md ressalva 2; test/design/tokens_test.rb:50 (design-tokens)
- last seen: 2026-09-23T01:20:41Z

### L-014 - O estilo efetivo usado para comparar regras CSS deve incluir as propriedades herdadas do ancestral, senão uma declaração ausente conta como diferente de um valor explícito igual ao herdado.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `css/text-tests` · harmful: 0
- features: interface
- evidence: validation.md rodada 2 M2d; test/design/flash_test.rb:37-41; app/assets/stylesheets/catalog.css:76 (css/text-tests)
- last seen: 2026-09-23T01:32:26Z

## Quarantined (failed when applied - ignore)

A confirmed lesson that recurred alongside failure. Kept for the maintainer to review.

_none_
