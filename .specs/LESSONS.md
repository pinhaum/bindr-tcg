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

### L-015 - Teste textual de CSS deve ler a declaração na regra do próprio seletor, nunca procurar o valor na folha inteira, porque outra regra com o mesmo valor mascara a remoção.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `css/text-tests` · harmful: 0
- features: navegacao
- evidence: M14 filter_layout_test.rb:92-110 (css/text-tests)
- last seen: 2026-09-27T19:39:23Z

### L-016 - O teste deve exercitar o método que a tela chama, com um registro que a guarda exclui, e não um método irmão sem uso em produção.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `models/aggregates` · harmful: 0
- features: navegacao
- evidence: M06 collection_item.rb:89 / minha_pasta_test.rb:117 (models/aggregates)
- last seen: 2026-09-27T19:39:23Z

### L-017 - Atributo numérico renderizado deve ser afirmado pelo valor esperado do fixture, não só pela presença do atributo.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `views/assertions` · harmful: 0
- features: navegacao
- evidence: M12 minha_pasta_test.rb:340-351 (views/assertions)
- last seen: 2026-09-27T19:39:23Z

### L-018 - Cláusula de não renderização precisa de um fixture em que a condição falha e de uma asserção count: 0 no elemento.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `views/assertions` · harmful: 0
- features: navegacao
- evidence: M13 progress/index.html.erb:163 (views/assertions)
- last seen: 2026-09-27T19:39:23Z

### L-019 - Asserção de marcador visível deve mirar o texto do marcador, não um seletor genérico que outro elemento decorativo também satisfaz.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `views/a11y` · harmful: 0
- features: navegacao
- evidence: M41 catalog_filter_controls_test.rb:156 (views/a11y)
- last seen: 2026-09-27T19:39:23Z

### L-020 - Rótulo escondido visualmente precisa de asserção de presença no HTML, além da regra CSS que o esconde.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `views/a11y` · harmful: 0
- features: navegacao
- evidence: M45 show.html.erb:142 (views/a11y)
- last seen: 2026-09-27T19:39:23Z

### L-021 - Ao reescrever testes por mudança de forma de um controle, manter as asserções dos controles cuja forma não mudou.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `test/rewrite` · harmful: 0
- features: navegacao
- evidence: M43 / P-5 reescrita da Fase 7 (test/rewrite)
- last seen: 2026-09-27T19:39:23Z

### L-022 - Critério de marcação só na página X precisa de teste de ausência na página vizinha que compartilha prefixo de rota.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `views/navigation` · harmful: 0
- features: navegacao
- evidence: M08 application.html.erb:31 (views/navigation)
- last seen: 2026-09-27T19:39:23Z

### L-023 - Alinhamento entre dois blocos se testa comparando os recuos dos dois, não o recuo de um só.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `css/text-tests` · harmful: 0
- features: navegacao
- evidence: M42 catalog_search_styling_test.rb:45-49 (css/text-tests)
- last seen: 2026-09-27T19:39:23Z

### L-024 - Contagem total com paginação precisa de fixture maior que uma página para distinguir total de itens da página.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `pagination` · harmful: 0
- features: navegacao
- evidence: M39 index.html.erb:87 (pagination)
- last seen: 2026-09-27T19:39:23Z

### L-025 - Quando o plano estreita um critério da spec, emendar a spec no mesmo commit ou cobrir o texto integral do critério.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `spec/plan` · harmful: 0
- features: navegacao
- evidence: NAV-04 application.html.erb:36-37 / tasks.md T5 (spec/plan)
- last seen: 2026-09-27T19:39:23Z

### L-026 - Links com o mesmo rótulo e função devem usar o mesmo helper de URL, senão a variante alternativa perde parte do estado.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `views/catalog` · harmful: 0
- features: navegacao
- evidence: NAV-36 index.html.erb:313 (views/catalog)
- last seen: 2026-09-27T19:39:23Z

### L-027 - Success Criterion que afirma arquivos sem edição deve ser conferido com git diff --diff-filter=M sobre o range antes de ser marcado.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `spec/success-criteria` · harmful: 0
- features: navegacao
- evidence: spec.md:342-343 / 6394755 (spec/success-criteria)
- last seen: 2026-09-27T19:39:38Z

### L-028 - Em filtro exclusivo com valor padrão, a spec deve dizer se o padrão conta como filtro ativo.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `spec/filters` · harmful: 0
- features: navegacao
- evidence: NAV-34 index.html.erb:283-294 (spec/filters)
- last seen: 2026-09-27T19:39:38Z

### L-029 - Critério que amarra dois números da tela deve nomear o denominador de cada um quando o modelo tem mais de uma métrica de total.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `spec/progress` · harmful: 0
- features: navegacao
- evidence: NAV-38 progress/index.html.erb:163-167 (spec/progress)
- last seen: 2026-09-27T19:39:39Z

## Quarantined (failed when applied - ignore)

A confirmed lesson that recurred alongside failure. Kept for the maintainer to review.

_none_
