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

### L-030 - Ao testar página de detalhe por objeto ActiveRecord com rota por slug/código (não id), usar o helper com o campo do slug explícito (card_path(record.card_number)), nunca card_path(record) — o path_helper usa to_param/id por padrão e gera 404 silencioso que faz assert_empty passar vacuamente.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `test/integration, rotas com find_by! por campo não-id` · harmful: 0
- features: navegacao
- evidence: M08 / navegacao_principal_test.rb:289,299 (test/integration, rotas com find_by! por campo não-id)
- last seen: 2026-09-27T23:07:57Z

### L-031 - Test each side of a count threshold, including the smallest value past it, not only the extremes
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `views` · harmful: 0
- features: conformidade
- evidence: M4 app/views/catalog/_card_tile.html.erb:54 (views)
- last seen: 2026-09-29T01:52:39Z

### L-032 - Assert the value the spec defines, not the value the current implementation happens to use
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `design` · harmful: 0
- features: conformidade
- evidence: CNF-12 test/design/catalog_grid_canvas_test.rb:43 (design)
- last seen: 2026-09-29T01:52:39Z

### L-033 - When a criterion names where an element lives, assert its container, not only that it exists
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `views` · harmful: 0
- features: conformidade
- evidence: CNF-23 test/integration/card_detail_layout_test.rb:66 (views)
- last seen: 2026-09-29T01:52:39Z

### L-034 - Give every visual criterion a measurable outcome instead of an adjective such as compact or same size
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `spec` · harmful: 0
- features: conformidade
- evidence: CNF-17 spec.md 'forma compacta' (spec)
- last seen: 2026-09-29T01:52:39Z

### L-035 - Assert the resolved min-height of every control the spec sizes, including the empty-state variant, not only the sibling control
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `css` · harmful: 0
- features: conformidade
- evidence: catalog.css:362-366 mutante h (validation.md) (css)
- last seen: 2026-09-29T02:43:20Z

### L-036 - When a spec amendment adds a measured criterion, change the code and add its test in the same task, not only the spec text
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `spec` · harmful: 0
- features: conformidade
- evidence: CNF-41 (validation.md G1) (spec)
- last seen: 2026-09-29T02:43:20Z

### L-037 - Assert positioning clauses such as top and right of an overlay, not only its colors and radius
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `css` · harmful: 0
- features: conformidade
- evidence: CNF-02 posição do selo (validation.md G2) (css)
- last seen: 2026-09-29T02:43:20Z

### L-038 - Give every layout adjective in a spec a measurable value or mark it as an owner decision before tasks start
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `spec` · harmful: 0
- features: conformidade
- evidence: CNF-17 forma compacta (validation.md) (spec)
- last seen: 2026-09-29T02:43:20Z

### L-039 - Run every documented shell command and observe its effect; checking that the files it names exist does not prove it works.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: FEC-03 README.md:65 (docs)
- last seen: 2026-09-29T03:07:21Z

### L-040 - Tick a Done-when item only after grepping the deliverable for each literal thing the item lists.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: FEC-03 tasks.md:104 (docs)
- last seen: 2026-09-29T03:07:21Z

### L-041 - Check every requirement number cited in a document against the requirements file it points to.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: FEC-11 design.md:602 (docs)
- last seen: 2026-09-29T03:07:21Z

### L-042 - When a document keeps a pending-items table, mark the items already decided as resolved.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: FEC-11 requirements.md:511-519 (docs)
- last seen: 2026-09-29T03:07:21Z

### L-043 - Pair each existence check with its inverse so that deleting a required item is also detected.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: mutant e2 README.md:76-77 (docs)
- last seen: 2026-09-29T03:07:21Z

### L-044 - Back numbers quoted in a handoff with a check that compares them with the measured gate output.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: mutant f STATE.md:151 (docs)
- last seen: 2026-09-29T03:07:21Z

### L-045 - Write validator commands in a spec with the argument form the script really takes.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: FEC-20 tasks.md:250 (docs)
- last seen: 2026-09-29T03:07:21Z

### L-046 - Run a grep before writing in a spec that it shows something; never assert grep results unrun.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: FEC-08 spec.md:54 (docs)
- last seen: 2026-09-29T03:07:21Z

### L-047 - Copy on-screen strings for a manual test script from the rendered template output, never from code comments that describe the screen.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: .specs/features/fechamento/roteiro-7-1.md:98,107 (docs)
- last seen: 2026-09-29T03:42:34Z

### L-048 - After correcting a wrong figure in a document, grep the whole document for the old value before ticking the fix.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: .specs/features/fechamento/roteiro-7-1.md:115 (docs)
- last seen: 2026-09-29T03:42:34Z

### L-049 - Cite lines of a document that sibling tasks are editing by heading or literal text, not by line number.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: .specs/features/fechamento/spec.md:66-67 (docs)
- last seen: 2026-09-29T03:42:34Z

### L-050 - When items move from open to resolved in a tracking section, rewrite the section heading and lead-in sentence that described the old state.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: .context/requirements.md:522-526 (docs)
- last seen: 2026-09-29T03:42:34Z

### L-051 - Recompute with grep every line number quoted in a log document at commit time, or cite the section title instead.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: FEC-13 verificar-resolvidos.md:21 (docs)
- last seen: 2026-09-29T04:01:35Z

### L-052 - Name in the Done-when the command that recomputes each figure copied from a live source, such as a database count.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: mutant h roteiro-7-1.md:98 (docs)
- last seen: 2026-09-29T04:01:35Z

### L-053 - Make each worked numeric example in a manual-test script obey the formulas the screen uses.
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `docs` · harmful: 0
- features: fechamento
- evidence: roteiro-7-1.md:98,107 (docs)
- last seen: 2026-09-29T04:01:35Z

### L-054 - Give each distinct discard reason its own end-to-end test asserting run status and failed counter, not only the normalizer output
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `ingestion` · harmful: 0
- features: fonte-apitcg
- evidence: SRC-36 (ingestion)
- last seen: 2026-10-01T03:59:24Z

### L-055 - Test every output channel of a secret (stdout, stderr, inspect, logs) with the secret set, not only with it unset
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `security` · harmful: 0
- features: fonte-apitcg
- evidence: SRC-05 (security)
- last seen: 2026-10-01T03:59:24Z

### L-056 - Assert that configured timeouts reach the real HTTP client call, not only that the config value exists
- signal: `ac_gap` · recurrence: 1 feature(s) · scope: `http-client` · harmful: 0
- features: fonte-apitcg
- evidence: SRC-04 (http-client)
- last seen: 2026-10-01T03:59:24Z

### L-057 - State in the criterion which entity and edge semantics a derived term such as present or owned refers to (set of the card vs of the variant, zero quantity, wishlist vs collection)
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `spec` · harmful: 0
- features: fonte-apitcg
- evidence: SRC-15 (spec)
- last seen: 2026-10-01T03:59:24Z

### L-058 - Pin the tool version or document the outdated-version flag in the gate command so an upstream release cannot turn the gate red without a code change
- signal: `gate_fail` · recurrence: 1 feature(s) · scope: `ci` · harmful: 0
- features: fonte-apitcg
- evidence: tasks.md:47 (ci)
- last seen: 2026-10-01T03:59:24Z

### L-059 - State in the criterion at which pipeline stage and at what moment a rule applies (dedup stage, when a revision is recorded)
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `spec` · harmful: 0
- features: fonte-apitcg
- evidence: SRC-33 (spec.md:194), SRC-06 (spec.md:97) (spec)
- last seen: 2026-10-01T04:14:32Z

### L-060 - Fix literal reason texts, log entry shape and rule precedence in the criterion when a test has to assert them
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `spec` · harmful: 0
- features: fonte-apitcg
- evidence: SRC-11 (spec.md:102), SRC-13 (spec.md:104) (spec)
- last seen: 2026-10-01T04:14:32Z

## Quarantined (failed when applied - ignore)

A confirmed lesson that recurred alongside failure. Kept for the maintainer to review.

_none_
