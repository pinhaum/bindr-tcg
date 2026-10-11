# Especificação — Catálogo na SPA

Recorte da feature `spa-catalogo` sobre `.context/requirements.md` Req. 18
(SCAT-NN, mesma numeração dos critérios). Em divergência, `.context/` vence
(AD-005). Depende da `api-fundacao` (Req. 16) e da `spa-fundacao` (Req. 17),
ambas encerradas e verificadas: contrato da API, cliente HTTP, sessão, casco,
temas e mensagens são delas e aqui só são consumidos. Escrita em 2026-10-10
sem o dono presente; as escolhas dele estão marcadas `Confirmed? não` abaixo.

## Problem Statement

A SPA já entra, cria conta e sai, mas a primeira tela do produto, a grade do
catálogo, ainda é Hotwire: a entrada "Catálogo" do casco recarrega a página
inteira em `/catalog` (SPA-26). Enquanto a grade não migrar, nenhuma fatia
seguinte (carta, pasta, decks) tem de onde partir dentro da SPA, e a troca
(AD-023) não avança. Esta feature leva a grade, a busca, os filtros, a
paginação e a URL compartilhável para `/app`, com paridade com a tela Hotwire,
e cria os componentes que a grade é a primeira a usar: tile com placeholder,
chip de filtro e skeleton.

## Goals

- [ ] `/app?<query>` mostra as mesmas cartas, na mesma ordem e com a mesma contagem que `/catalog?<query>` para qualquer query do design §4.2, verificado por Playwright contra a API real.
- [ ] Buscar, aplicar e remover filtro, limpar e paginar funcionam só pela SPA, sem recarregar a página, a 360px e a 1280px, nos dois temas, sem scroll horizontal.
- [ ] Com sessão, o selo de posse e o filtro de posse refletem a coleção do usuário; sem sessão, nenhum dos dois aparece.
- [ ] Nenhum endpoint novo nem mudança de contrato na API: a suíte Rails continua verde sem edição.

## Out of Scope

| Feature | Reason |
|---|---|
| Detalhe da carta, controle de posse, deck em edição | Fatia `spa-carta`; até lá o tile leva ao detalhe Hotwire (SCAT-03). |
| Controle de ordenação na tela | O HTML não tem: ordenação só pela URL (`sort`, `dir`), e a SPA a preserva (SCAT-27). Um controle cumpre melhor o Req. 2.4, mas vai além da paridade; fica para decisão do dono. |
| Controles de faixa (custo, power, counter), attribute e trait | Req. 4.9: só pela URL até decisão própria; a SPA os preserva e mostra como chip (SCAT-27, SCAT-28). |
| Busca enquanto digita (sem "Buscar") e sugestões | Além da paridade (Req. 13.18 pede o botão); fica para depois da troca. |
| Rolagem infinita ou "carregar mais" | O HTML usa paginação clássica (Req. 2.2); trocar o modelo é decisão de produto. |
| Hexadecimais das seis cores do jogo no chip de cor | Pendência P8 aberta; o chip usa tratamento neutro (SCAT-21). |
| Morph tile → detalhe, `animate:flip` na grade | Nascem na `spa-carta` (tabela da `spa-fundacao`); aqui a grade troca sem animação de posição. |
| Pré-carregamento da próxima página ou do detalhe | Otimização sem requisito; o p95 do Req. 11.1 é da API. |
| Redirecionar `/catalog` para `/app`, remover a grade Hotwire | Feature final `spa-troca` (AD-023). |
| Links de outras telas Hotwire para o catálogo (pasta → catálogo filtrado, "Voltar ao catálogo" do detalhe) | Continuam em `/catalog` até a fatia de cada tela migrar. |
| Endpoint novo ou campo novo na API | Os dois endpoints do Req. 16 bastam (SCAT-45); a fatia vertical não tem lado Rails. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| Lado API da fatia vertical | Nenhum endpoint novo: `GET /api/catalog` (API-18..21, 26, 31) e `GET /api/catalog/filters` (API-22) entregam cartas, variantes com raridade e imagem, `owned_quantity` por variante, `meta` com página e `active_filters`, e as opções de filtro já ordenadas | Lido em `app/views/api/catalog/*.jbuilder` e `app/views/api/cards/_*.jbuilder`: todo dado que a grade Hotwire usa já sai no JSON | Sim — verificado no código, 2026-10-10 |
| Rota do catálogo | `/app` (a raiz da SPA), substituindo a página de início da `spa-fundacao` | A raiz do Rails já é o catálogo (`root "catalog#index"`), e a `spa-fundacao` registrou que o início "vira o catálogo na `spa-catalogo`" | Não — escolha do agente, já anunciada na `spa-fundacao` |
| Formato da URL | A query de `/app` é a mesma do design §4.2, com colchetes nas listas (`colors[]=Red&colors[]=Green`), repassada crua à API (SCAT-04, SCAT-05) | Mantém uma URL `/catalog?…` trocável por `/app?…`; sem colchetes o Rack guarda só o último valor repetido e o `OU` da categoria se perde | Não — escolha do agente |
| Origem dos links | Chips, remoção, paginação, "Limpar filtros", busca e "Aplicar" montam a URL a partir de `meta.active_filters` da última resposta, como o `CatalogHelper` faz | Parâmetro inválido descartado pela API não pode ressuscitar num link (comentário do `CatalogHelper`) | Não — escolha do agente, paridade |
| Busca preserva filtros | Enviar a busca mantém os filtros e a ordenação ativos e descarta `page` (SCAT-16) | O formulário Hotwire só envia `q` e por isso **zera** os filtros; o Req. 3.6 pede busca combinável com todos os filtros, e perder os chips ao buscar o contraria. Divergência deliberada da tela HTML | Não — escolha do agente |
| Set com mais de um valor | O seletor mostra "N sets selecionados" quando há mais de um set ativo, e "Aplicar" com essa opção não mexe no filtro (SCAT-24) | No HTML o seletor mostra "Todos os sets" nesse caso e preserva os sets por campos ocultos, o que exibe um estado falso; a nova opção diz a verdade e mantém o efeito | Não — escolha do agente |
| Set aplicado por botão | Seletor + "Aplicar", sem aplicar ao mudar a seleção | Paridade com o HTML (NAV-14) e WCAG 3.2.2: no teclado, setas num `<select>` disparam `change` a cada opção | Não — escolha do agente, paridade |
| Rótulo do chip de posse ativo | "Posse: Tenho" e "Posse: Não tenho" | No HTML o chip sai "Owned: owned" (`humanize` da chave, que falta em `FILTER_LABELS`), o que é defeito, não comportamento | Não — escolha do agente |
| Contagem na linha de status | Inteiro sem separador de milhar ("2815 cartas"), singular "1 carta" e "1 filtro ativo" | Paridade com o `pluralize` do HTML | Não — escolha do agente |
| Selo do tile | Soma de `owned_quantity` das variantes devolvidas da carta | Mesmo cálculo do `owned_quantity_for_card` do HTML; a API já devolve só as variantes presentes (API-21) | Não — escolha do agente, paridade |
| Imagem do tile | A da primeira variante de `variants[]` (a API já ordena por `variant_code`), `alt=""` (o nome está no tile), `loading="lazy"` | Paridade com `_card_tile.html.erb` | Não — escolha do agente, paridade |
| Skeleton | Só depois de 200 ms de espera, dez tiles, região com `aria-busy="true"` e texto acessível "Carregando cartas…"; antes disso a tela mantém o conteúdo anterior | Resposta rápida não pisca a grade; dez tiles são duas fileiras a 1280px. Sem animação com `prefers-reduced-motion` (SPA-42) | Não — escolha do agente |
| Resposta fora de ordem | Só a resposta da URL atual é exibida; as demais são descartadas (SCAT-08) | Clicar dois chips seguidos pode devolver a primeira resposta por último | Não — escolha do agente |
| Erro de carga | Inline, no lugar da grade (catálogo) ou no painel (opções), com a `message` da API como veio e "Tentar novamente"; não vira toast | Toast some ou se acumula; o erro de carga é estado da tela, não evento (SPA-11 entrega a mensagem pronta) | Não — escolha do agente |
| Foco em navegação dentro do catálogo | Mudança só de query não leva o foco a `main#conteudo`: chip do painel, "Aplicar" e "Buscar" mantêm o foco; remover chip ativo leva ao vizinho; trocar de página leva à linha de status; a contagem é anunciada em `aria-live="polite"` | Mover o foco a cada chip obrigaria a voltar ao painel por Tab a cada filtro; o `afterNavigate` da `spa-fundacao` segue valendo entre rotas diferentes | Não — escolha do agente |
| Painel recolhido abaixo de 64rem | Continua aberto depois de aplicar um filtro, enquanto o usuário está no catálogo | No HTML o painel fecha a cada recarga; na SPA o componente persiste e fechar o painel a cada toque seria regressão provocada | Não — escolha do agente |
| Convite ao anônimo | "Entrar para registrar posse" leva a `/app/entrar?return_to=<URL atual com query>` | O HTML leva a `/session/new` sem retorno; a SPA já valida `return_to` (SPA-23) | Não — escolha do agente |
| Catálogo vazio sem filtro nenhum | Exibe "Nenhuma carta corresponde aos filtros aplicados." sem "Limpar filtros" | Só acontece com banco sem import; oferecer "Limpar filtros" sem filtro é ação vazia | Não — escolha do agente |
| Página além da última | Exibe o estado vazio do SCAT-37 com a linha de status mostrando o total real | Paridade: a API devolve `data` vazio com `total_count` maior que zero e a tela HTML faz o mesmo | Não — escolha do agente, paridade |
| Teste e2e da `spa-fundacao` que confere o e-mail no início | Passa a conferir a navegação com sessão, porque o início vira o catálogo | Consequência da rota; ajuste de teste, não de comportamento da fundação | Não — escolha do agente |
| "sem JavaScript" do Req. 13.11 | Na SPA, o equivalente é o chip ser link com `href` real (abre em nova aba, funciona com o botão do meio) | A SPA depende de JS por definição; o valor do critério era o controle ser navegação comum | Não — escolha do agente |

**Open questions:** none - all resolved or logged above. Nenhuma `DECISÃO PENDENTE`: nada aqui mexe em dado, segurança ou contrato público; todas as escolhas são de tela e reversíveis.

---

## User Stories

### P1: Catálogo em `/app` com URL compartilhável ⭐ MVP

**User Story**: Como colecionador, quero abrir o catálogo na SPA pela mesma URL que eu compartilho, para que um link mande quem recebe para o mesmo resultado.

**Why P1**: Sem a rota e a consulta não há tela; a URL como fonte de verdade é o que o Req. 4.7 exige.

**Acceptance Criteria**:

1. WHEN o usuário abrir `/app` THEN the system SHALL exibir o catálogo com o título de página "Catálogo — Bindr" e o cabeçalho de nível 1 "Catálogo", no lugar da página de início da `spa-fundacao`.
2. The system SHALL apontar a entrada "Catálogo" da navegação para `/app`, com navegação sem recarga, e marcá-la com `aria-current="page"` em `/app` com qualquer query (Req. 17.25, 17.27).
3. WHEN o usuário acionar um tile THEN the system SHALL navegar com página inteira para `/cards/<card_number>` (detalhe Hotwire), com o `card_number` codificado para URL.
4. WHEN `/app` abrir ou sua query mudar THEN the system SHALL chamar `GET /api/catalog` pelo cliente da `spa-fundacao` com a query da URL repassada sem alteração.
5. The system SHALL usar na URL os nomes e o formato de parâmetro do design §4.2 (`q`, `colors[]`, `card_types[]`, `sets[]`, `rarities[]`, `attributes[]`, `traits[]`, `cost_min` … `counter_max`, `owned`, `sort`, `dir`, `page`, `per_page`), de forma que `/app?<query>` mostre as mesmas cartas, na mesma ordem, que `/catalog?<query>`.
6. The system SHALL montar todo link e toda navegação da tela a partir de `meta.active_filters` da última resposta, nunca da query crua, de modo que um parâmetro descartado pela API não apareça em link nenhum.
7. WHEN a URL mudar por voltar ou avançar do navegador THEN the system SHALL exibir o resultado, o termo do campo de busca e o estado dos controles da URL nova.
8. IF chegar a resposta de `GET /api/catalog` de uma URL que já não é a atual THEN the system SHALL descartá-la sem alterar a tela.
9. WHEN o estado de sessão mudar (entrar, sair, `401`) com o catálogo aberto THEN the system SHALL repetir `GET /api/catalog` para a URL atual.
45. The system SHALL consumir só `GET /api/catalog` e `GET /api/catalog/filters` com o contrato do Req. 16, sem criar nem mudar endpoint.

**Independent Test**: Vitest da rota com cliente falso (query repassada, resposta antiga descartada, refetch na troca de sessão); Playwright: abrir `/app?colors[]=Red&colors[]=Green&sort=name` e comparar nomes e contagem com `/catalog` na mesma query.

---

### P1: Grade e tile ⭐ MVP

**User Story**: Como colecionador, quero reconhecer as cartas pela arte, com nome e código legíveis mesmo quando a imagem falha, e ver de relance quantas cópias tenho.

**Why P1**: É o conteúdo da tela (Req. 2.1); o tile é o componente que as fatias de lista seguintes vão reusar.

**Acceptance Criteria**:

10. The system SHALL exibir as cartas de `data` numa grade em que cada tile mostra a imagem da primeira variante de `variants[]`, o nome e o `card_number` no estilo monoespaçado `code` (Req. 2.1, 12.7).
11. The system SHALL renderizar em cada tile, atrás da imagem, um placeholder com nome e `card_number`, que fica visível quando `image_url` é `null` ou a imagem falha ao carregar, sem mudar a largura nem a altura do tile (Req. 2.3).
12. WHEN a carta tiver uma variante THEN the system SHALL exibir a raridade dela ao lado do código; WHEN tiver mais de uma THEN the system SHALL exibir "N impressões" no lugar (Req. 13.24).
13. WHILE houver sessão e a soma de `owned_quantity` das variantes da carta for maior que zero the system SHALL exibir sobre o canto superior direito da arte um selo com essa soma, com `role="img"` e nome acessível "1 cópia" ou "N cópias", sem nenhum controle de posse no tile (Req. 13.22).
14. The system SHALL exibir a grade com cinco colunas em viewport de 1280px e sem scroll horizontal em 360px (Req. 2.5, 13.25).

**Independent Test**: Vitest do tile: placeholder presente com e sem `image_url`, evento `error` da imagem não muda o tamanho, legenda por número de variantes, selo só com sessão e soma > 0; Playwright: cinco colunas a 1280px e `scrollWidth <= clientWidth` a 360px.

---

### P1: Busca ⭐ MVP

**User Story**: Como colecionador, quero buscar por nome ou código sem perder os filtros que já escolhi, para estreitar o resultado em vez de recomeçar.

**Why P1**: Req. 3 é o caminho principal para achar uma carta conhecida.

**Acceptance Criteria**:

15. The system SHALL exibir o campo de busca com o rótulo "Buscar por nome ou card_number", o placeholder "OP01-024" e o botão "Buscar", ambos com alvo de no mínimo 44px (Req. 13.18, 13.27).
16. WHEN o usuário enviar a busca THEN the system SHALL navegar para `/app` com o termo sem espaços nas pontas em `q` (sem `q` quando vazio), mantendo os demais filtros ativos e a ordenação e sem `page`.
17. The system SHALL exibir no campo o valor de `active_filters.q` da resposta atual, ou vazio sem busca ativa.

**Independent Test**: Vitest: enviar "zoro" com `colors[]=Red` ativo gera `?q=zoro&colors[]=Red` sem `page`; Playwright: busca por `OP01-024` põe a carta exata em primeiro (Req. 3.4, já garantido pela API).

---

### P1: Filtros ⭐ MVP

**User Story**: Como colecionador, quero aplicar e remover filtros de cor, tipo, raridade, set e posse com um toque, para responder "quais Characters vermelhos eu ainda não tenho?".

**Why P1**: Req. 4.9 exige os controles na grade; o chip é o segundo componente que nasce aqui.

**Acceptance Criteria**:

18. The system SHALL exibir chips de cor, tipo e raridade com os valores de `GET /api/catalog/filters`, na ordem devolvida, exibindo o tipo com inicial maiúscula e enviando o valor cru na URL (Req. 4.9, 13.29).
19. The system SHALL renderizar cada chip como link para a URL com o valor alternado (acrescentado se inativo, removido se ativo), preservando os demais filtros ativos e a ordenação e sem `page` (Req. 4.3, 4.4).
20. WHILE um chip estiver ativo the system SHALL exibir um sinal de remoção visível, anel sólido de 2px em `accent` e rótulo escrito, com nome acessível "Remover filtro <categoria>: <valor>", e o chip de cor SHALL não ser preenchido com `accent` (Req. 12.6, 12.11, 13.11).
21. WHILE a pendência P8 estiver aberta the system SHALL exibir os chips de cor com tratamento neutro (`border-strong` mais rótulo), sem hexadecimal de cor do jogo.
22. The system SHALL dar alvo de no mínimo 44px de altura a todo chip, ao seletor de set e ao botão "Aplicar".
23. WHEN o usuário acionar "Aplicar" com um set escolhido no seletor "Set" (opções "Todos os sets" e os sets de `filters.sets` pelo nome) THEN the system SHALL navegar com `sets[]` igual só a esse set; com "Todos os sets", sem `sets[]`; nos dois casos mantendo os demais filtros e a ordenação e sem `page`.
24. WHILE houver mais de um set ativo the system SHALL exibir selecionada no seletor a opção "N sets selecionados", e "Aplicar" com ela SHALL manter os sets ativos sem mudança.
25. WHILE houver sessão the system SHALL exibir os chips de posse "Todas", "Tenho" e "Não tenho": "Tenho" e "Não tenho" alternam `owned=owned` e `owned=missing`, e "Todas" remove `owned`; sem filtro de posse, "Todas" SHALL ter `aria-current="true"` e nenhum sinal de remoção.
26. WHILE não houver sessão the system SHALL omitir os controles de posse, e um `owned` na URL SHALL não virar chip (a API o descarta, API-20).
27. The system SHALL aplicar pela URL, sem controle na tela, as faixas de custo, power e counter, `attributes[]`, `traits[]`, `sort` e `dir`, e preservá-los em todo link gerado pela tela (Req. 4.9).

**Independent Test**: Vitest do chip e do painel com `active_filters` e opções falsos: `href` de cada chip, nome acessível do ativo, "Todas" atual sem filtro, opção "N sets selecionados"; Playwright: Red + Green dá o mesmo total que `/catalog?colors[]=Red&colors[]=Green`.

---

### P1: Filtros ativos e linha de status ⭐ MVP

**User Story**: Como colecionador, quero ver quantas cartas sobraram e quais filtros estão valendo, e tirar um deles sem refazer os outros.

**Why P1**: Req. 4.6 e 4.8; sem os chips ativos os filtros só da URL (faixa, trait) ficariam invisíveis.

**Acceptance Criteria**:

28. The system SHALL listar em "Filtros ativos" um chip por valor de `active_filters`, com o rótulo "<categoria>: <valor>" (Busca, Cor, Tipo, Set, Raridade, Attribute, Trait, Custo mín., Custo máx., Power mín., Power máx., Counter mín., Counter máx., e Posse com "Tenho" ou "Não tenho"), cada um com link que remove só aquele valor e descarta `page`, sem chip para `sort`, `dir`, `page` e `per_page` (Req. 4.6).
29. The system SHALL exibir a linha de status como uma frase: "N cartas" (singular "1 carta") com `meta.total_count`, acrescida de " · M filtros ativos" (singular "1 filtro ativo") quando M, o número de chips do SCAT-28, for maior que zero (Req. 4.8, 13.26).
30. WHILE houver filtro ativo e a página tiver cartas the system SHALL exibir na linha de status, à direita, o link "Limpar filtros", que remove todos os filtros e mantém `sort` e `dir` (Req. 13.12).
31. WHILE não houver sessão the system SHALL exibir uma única vez, na linha de status, o link "Entrar para registrar posse" para `/app/entrar?return_to=<caminho e query atuais>` (Req. 13.23).
32. WHILE a viewport tiver 64rem ou mais the system SHALL exibir a linha de status na mesma linha do campo de busca (Req. 13.26).

**Independent Test**: Vitest da linha de status e da lista de ativos com `meta` falso: frase no singular e no plural, contagem de chips, `href` de remoção que mantém o resto, convite só sem sessão.

---

### P1: Disposição dos filtros ⭐ MVP

**User Story**: Como colecionador no celular, quero os filtros recolhidos até eu pedir, sem perder de vista os que estão valendo; no computador, quero os filtros sempre ao lado da grade.

**Why P1**: Req. 13.5, 13.10, 13.16 e 13.17; é o que deixa a primeira tela do celular com cartas.

**Acceptance Criteria**:

33. WHILE a viewport tiver 64rem ou mais the system SHALL exibir os controles de filtro na coluna lateral do casco, abaixo da navegação, numa superfície contínua com espaçamento fixo entre os grupos e sempre visíveis (Req. 13.10, 13.16).
34. WHILE a viewport tiver menos de 64rem the system SHALL exibir os controles acima da grade, recolhidos por padrão num controle expansível "Filtros" que diz "M filtros ativos" quando M > 0, com a lista de filtros ativos do SCAT-28 visível com o controle recolhido (Req. 13.5, 13.17).
35. WHILE o usuário navegar dentro de `/app` mudando só a query the system SHALL manter aberto o painel de filtros que estava aberto.

**Independent Test**: Playwright a 360px (painel fechado na carga, chip ativo visível, painel segue aberto depois de um chip) e a 1280px (filtros na coluna lateral abaixo da navegação).

---

### P1: Paginação ⭐ MVP

**User Story**: Como colecionador, quero avançar e voltar páginas sem perder os filtros.

**Why P1**: Req. 2.2; o catálogo tem mais de 2800 cartas.

**Acceptance Criteria**:

36. WHILE `meta.total_pages` for maior que 1 the system SHALL exibir uma navegação com nome acessível "Paginação do catálogo" contendo o link "Anterior" quando `page > 1`, o texto "Página X de Y" e o link "Próxima" quando `page < total_pages`, cada link com os filtros ativos e a página de destino (Req. 2.2, 4.7).

**Independent Test**: Vitest com `meta` falso nas páginas 1, meio e última; Playwright: "Próxima" com filtro ativo mantém o filtro e muda os nomes da grade.

---

### P1: Carga, vazio e erro ⭐ MVP

**User Story**: Como colecionador em mesa de loja com rede ruim, quero saber se a grade está carregando, vazia ou com erro, e tentar de novo sem recarregar.

**Why P1**: Sem estes estados a tela fica em branco ou presa; o skeleton é o terceiro componente da fatia.

**Acceptance Criteria**:

37. WHEN a resposta trouxer `data` vazio THEN the system SHALL exibir "Nenhuma carta encontrada para <termo>." com o termo em destaque quando houver `q`, ou "Nenhuma carta corresponde aos filtros aplicados." quando não houver, com o link "Limpar filtros" sempre que houver filtro ativo (Req. 3.5).
38. WHILE a resposta da URL atual estiver pendente há mais de 200 ms the system SHALL exibir na grade dez tiles esqueleto, com `aria-busy="true"` na região de resultados e o texto acessível "Carregando cartas…"; antes dos 200 ms SHALL manter o conteúdo anterior.
39. IF `GET /api/catalog` falhar com qualquer erro do cliente (`network_error`, `unexpected_response` ou erro da API) THEN the system SHALL exibir no lugar da grade a `message` do erro como veio e o botão "Tentar novamente", que repete a consulta da URL atual, mantendo busca e filtros utilizáveis.
40. IF `GET /api/catalog/filters` falhar THEN the system SHALL exibir no painel de filtros a `message` do erro e o botão "Tentar novamente", que repete só essa chamada, mantendo a grade, a linha de status e a lista de filtros ativos.

**Independent Test**: Vitest com cliente falso e timer falso: skeleton só depois de 200 ms, erro de rede com "Tentar novamente" que refaz a chamada, falha das opções sem afetar a grade; estado vazio com e sem `q`.

---

### P1: Foco e anúncio ⭐ MVP

**User Story**: Como colecionador que usa teclado ou leitor de tela, quero aplicar vários filtros seguidos sem perder meu lugar, e ouvir quantas cartas sobraram.

**Why P1**: A SPA troca a recarga do HTML por navegação no cliente; sem regra de foco, cada chip jogaria o foco para o conteúdo principal (o `afterNavigate` da fundação).

**Acceptance Criteria**:

41. WHEN a navegação mudar só a query de `/app` THEN the system SHALL não mover o foco para `main#conteudo`, e o chip do painel, o botão "Aplicar" ou o botão "Buscar" acionado SHALL continuar com o foco.
42. WHEN o usuário remover um chip da lista de filtros ativos THEN the system SHALL mover o foco para o chip seguinte da lista, ou para o anterior se não houver seguinte, ou para a linha de status se a lista ficar vazia.
43. WHEN o usuário acionar "Anterior" ou "Próxima" THEN the system SHALL mover o foco para a linha de status.
44. WHEN chegar a resposta de `GET /api/catalog` THEN the system SHALL anunciar a frase da linha de status numa região `aria-live="polite"`.

**Independent Test**: Playwright com teclado: Tab até "Red", Enter, foco segue em "Red" e o painel continua aberto; remover o único chip ativo leva o foco à linha de status; "Próxima" leva o foco à linha de status.

---

## Edge Cases

- IF a query tiver parâmetro desconhecido ou inválido (`colors[]=Roxo`, `cost_min=abc`, `page=-1`) THEN the system SHALL exibir o resultado que a API devolver (`200`, API-19) e nenhum link gerado SHALL carregar o parâmetro descartado (SCAT-06).
- IF a URL vier com `colors=Red` sem colchetes THEN the system SHALL repassá-la crua (SCAT-04) e exibir o que a API devolver, sem corrigir a URL.
- WHEN `page` for maior que `total_pages` THEN the system SHALL exibir o estado vazio do SCAT-37 com a linha de status mostrando `total_count` e a paginação do SCAT-36 com "Anterior".
- WHEN o catálogo estiver vazio sem filtro nenhum (banco sem import) THEN the system SHALL exibir "Nenhuma carta corresponde aos filtros aplicados." sem "Limpar filtros".
- WHEN a variante única não tiver raridade (`rarity` `null`) THEN the system SHALL omitir a raridade do tile, sem texto vazio nem "null".
- IF a imagem responder `403` ou `404` (sets não lançados, pendência do *Handoff*) THEN the system SHALL manter o placeholder do SCAT-11 visível.
- WHEN o usuário sair pelo casco estando em `/app?owned=owned` THEN the system SHALL repetir a consulta (SCAT-09) e deixar de exibir chip, selo e controles de posse (SCAT-13, SCAT-26).
- WHEN o usuário acionar dois chips em menos tempo do que a primeira resposta leva THEN the system SHALL exibir só o resultado da segunda URL (SCAT-08).
- WHEN a viewport cruzar 64rem com a página aberta THEN the system SHALL mover os controles entre o painel recolhível e a coluna lateral sem refazer a consulta.
- IF o `card_number` tiver caractere reservado de URL THEN the system SHALL codificá-lo no link do tile (SCAT-03), já que a rota `cards/:id` aceita qualquer caractere menos `/`.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| SCAT-01 | P1: Catálogo em `/app` — rota (Req. 18.1) | Tasks (T20, T22) | Pending |
| SCAT-02 | P1: Catálogo em `/app` — entrada da navegação (Req. 18.2) | Tasks (T3) | Pending |
| SCAT-03 | P1: Catálogo em `/app` — tile leva ao detalhe Hotwire (Req. 18.3) | Tasks (T12) | Pending |
| SCAT-04 | P1: Catálogo em `/app` — query repassada (Req. 18.4) | Tasks (T1, T8, T20) | Pending |
| SCAT-05 | P1: Catálogo em `/app` — formato da URL (Req. 18.5) | Tasks (T4, T23) | Pending |
| SCAT-06 | P1: Catálogo em `/app` — links dos filtros normalizados (Req. 18.6) | Tasks (T4) | Pending |
| SCAT-07 | P1: Catálogo em `/app` — voltar e avançar (Req. 18.7) | Tasks (T20, T24) | Pending |
| SCAT-08 | P1: Catálogo em `/app` — resposta antiga descartada (Req. 18.8) | Tasks (T8) | Pending |
| SCAT-09 | P1: Catálogo em `/app` — troca de sessão (Req. 18.9) | Tasks (T20, T24) | Pending |
| SCAT-10 | P1: Grade — tile (Req. 18.10) | Tasks (T12) | Pending |
| SCAT-11 | P1: Grade — placeholder (Req. 18.11) | Tasks (T12) | Pending |
| SCAT-12 | P1: Grade — raridade ou impressões (Req. 18.12) | Tasks (T12) | Pending |
| SCAT-13 | P1: Grade — selo de posse (Req. 18.13) | Tasks (T12, T24) | Pending |
| SCAT-14 | P1: Grade — colunas e 360px (Req. 18.14) | Tasks (T20, T23) | Pending |
| SCAT-15 | P1: Busca — campo (Req. 18.15) | Tasks (T15) | Pending |
| SCAT-16 | P1: Busca — envio preserva filtros (Req. 18.16) | Tasks (T4, T15, T23) | Pending |
| SCAT-17 | P1: Busca — termo ativo no campo (Req. 18.17) | Tasks (T15, T20) | Pending |
| SCAT-18 | P1: Filtros — chips de cor, tipo e raridade (Req. 18.18) | Tasks (T9, T19) | Pending |
| SCAT-19 | P1: Filtros — chip como link alternado (Req. 18.19) | Tasks (T4, T14) | Pending |
| SCAT-20 | P1: Filtros — chip ativo (Req. 18.20) | Tasks (T5, T14) | Pending |
| SCAT-21 | P1: Filtros — cor neutra até a P8 (Req. 18.21) | Tasks (T14, T19) | Pending |
| SCAT-22 | P1: Filtros — alvo de 44px (Req. 18.22) | Tasks (T14, T19) | Pending |
| SCAT-23 | P1: Filtros — seletor de set (Req. 18.23) | Tasks (T4, T19) | Pending |
| SCAT-24 | P1: Filtros — vários sets (Req. 18.24) | Tasks (T4, T19) | Pending |
| SCAT-25 | P1: Filtros — posse com sessão (Req. 18.25) | Tasks (T4, T14, T19, T24) | Pending |
| SCAT-26 | P1: Filtros — posse sem sessão (Req. 18.26) | Tasks (T19, T24) | Pending |
| SCAT-27 | P1: Filtros — filtros só da URL (Req. 18.27) | Tasks (T4, T23) | Pending |
| SCAT-28 | P1: Ativos e status — lista de filtros ativos (Req. 18.28) | Tasks (T5, T17) | Pending |
| SCAT-29 | P1: Ativos e status — frase de contagem (Req. 18.29) | Tasks (T5, T16, T20) | Pending |
| SCAT-30 | P1: Ativos e status — limpar filtros (Req. 18.30) | Tasks (T4, T16, T20) | Pending |
| SCAT-31 | P1: Ativos e status — convite ao anônimo (Req. 18.31) | Tasks (T2, T16, T20, T24) | Pending |
| SCAT-32 | P1: Ativos e status — status ao lado da busca (Req. 18.32) | Tasks (T20) | Pending |
| SCAT-33 | P1: Disposição — coluna lateral (Req. 18.33) | Tasks (T10, T21, T24) | Pending |
| SCAT-34 | P1: Disposição — painel recolhido (Req. 18.34) | Tasks (T21, T24) | Pending |
| SCAT-35 | P1: Disposição — painel persiste (Req. 18.35) | Tasks (T21, T24) | Pending |
| SCAT-36 | P1: Paginação (Req. 18.36) | Tasks (T4, T18, T23) | Pending |
| SCAT-37 | P1: Estados — vazio (Req. 18.37) | Tasks (T20) | Pending |
| SCAT-38 | P1: Estados — skeleton (Req. 18.38) | Tasks (T8, T13, T20) | Pending |
| SCAT-39 | P1: Estados — erro do catálogo (Req. 18.39) | Tasks (T8, T20) | Pending |
| SCAT-40 | P1: Estados — erro das opções (Req. 18.40) | Tasks (T9, T19) | Pending |
| SCAT-41 | P1: Foco — query não move o foco (Req. 18.41) | Tasks (T7, T11, T21, T24) | Pending |
| SCAT-42 | P1: Foco — remoção de chip ativo (Req. 18.42) | Tasks (T17, T21, T24) | Pending |
| SCAT-43 | P1: Foco — paginação (Req. 18.43) | Tasks (T18, T21, T24) | Pending |
| SCAT-44 | P1: Foco — contagem anunciada (Req. 18.44) | Tasks (T6, T20, T24) | Pending |
| SCAT-45 | P1: Catálogo em `/app` — sem endpoint novo (Req. 18.45) | Tasks (T1, T25) | Pending |

**Coverage:** 45 total, 45 mapped to tasks, 0 unmapped

## Implicit-Requirement Dimensions

| Dimension | Resolution |
|---|---|
| Input validation & bounds | SCAT-04, SCAT-06: a validação de parâmetro é da API (API-19); a tela repassa a query crua e só gera links a partir do normalizado. SCAT-16 tira os espaços das pontas do termo |
| Failure / partial-failure states | SCAT-39 (catálogo), SCAT-40 (opções de filtro, falha parcial que não derruba a grade), SCAT-11 (imagem) |
| Idempotency / retry / duplicate handling | SCAT-39, SCAT-40: "Tentar novamente" repete um `GET`, seguro por natureza; não há mutação nesta fatia |
| Auth boundaries & rate limits | SCAT-13, SCAT-25, SCAT-26: posse só com sessão, e a coleção lida sai da sessão no servidor (API-20, API-32). Rate limit N/A because a fatia só faz `GET` público |
| Concurrency / ordering | SCAT-08: resposta fora de ordem descartada; SCAT-09: troca de sessão refaz a consulta |
| Data lifecycle / expiry | N/A because a fatia não grava dado; o estado vive na URL e na resposta corrente |
| Observability | N/A because a SPA não tem coleta de erro remota (mesma decisão da `spa-fundacao`); as consultas ficam no log do Rails |
| External-dependency failure | SCAT-11 e o caso de borda do `403`: a imagem vem do CDN via rota do app (AD-019) e o placeholder a cobre; a API é tratada pelo SCAT-39 |
| State-transition integrity | SCAT-38 → resultado, vazio (SCAT-37) ou erro (SCAT-39): a grade só mostra a resposta da URL atual; SCAT-35 mantém o painel entre transições |

## Success Criteria

- [ ] Playwright contra a API real compara `/app?<query>` com `/catalog?<query>` (mesmos `card_number`, mesma ordem, mesma contagem) para busca, cor múltipla, set, faixa e ordenação, a 360px e a 1280px, nos dois temas, sem scroll horizontal.
- [ ] Com sessão, o selo do tile e o filtro "Tenho" batem com a coleção do usuário; depois de "Sair", somem sem recarregar a página.
- [ ] Aplicar três chips seguidos pelo teclado não tira o foco do painel, e a contagem é anunciada a cada resposta.
- [ ] A suíte Rails passa sem edição e nenhum arquivo sob `app/` muda nesta feature.
