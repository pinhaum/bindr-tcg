# Especificação — Troca do front: SPA na raiz e saída do Hotwire

Recorte da feature `spa-troca` sobre `.context/requirements.md` Req. 23
(STRO-NN, mesma numeração dos critérios). Em divergência, `.context/` vence
(AD-005). É a feature final da AD-023. Depende da `api-fundacao` (Req. 16) e da
`spa-fundacao` (Req. 17), encerradas e verificadas, e das cinco fatias de tela
especificadas nesta rodada e ainda não implementadas: `spa-catalogo` (Req. 18),
`spa-carta` (Req. 19), `spa-pasta` (Req. 20), `spa-decks` (Req. 21) e
`spa-portabilidade` (Req. 22). Não cria tela nem endpoint de `/api`. Escrita em
2026-10-10 sem o dono presente; as escolhas dele estão marcadas `Confirmed? não`
abaixo. As duas de contrato público, P14 (rotas de arquivo) e P15 (status dos
redirecionamentos), foram decididas pelo dono em 2026-10-11 (AD-031); segue
aberto o `⚠️ VERIFICAR` do `propshaft` em P16.

## Problem Statement

Durante a transição o Bindr tem duas camadas de apresentação: o Hotwire na raiz
e a SPA em `/app`, com cada tela existindo em dobro e cada mudança de regra
pedindo dois testes de tela (trade-off da AD-023). Quando as cinco fatias
atingirem paridade, o Hotwire passa a ser só custo: controllers, views, helpers,
importmap, 81 KB de CSS e cerca de 85 arquivos de teste de HTML que nenhum
usuário precisa. Esta feature move a SPA para a raiz, mantém vivas as URLs já
compartilhadas (Req. 4.7, 13.40) por redirecionamento, decide o destino dos dois
downloads que ainda moram em rotas HTML, remove o Hotwire e reorganiza a suíte
sem perder nenhuma garantia de autorização, concorrência ou dado.

## Goals

- [ ] Toda URL Hotwire da checklist de paridade e toda URL `/app/...` abre a tela equivalente da SPA na raiz, com a mesma query, em request test e em Playwright.
- [ ] Nenhum controller, view, helper, CSS ou JavaScript do Hotwire resta no repositório, e o `Gemfile` não traz `importmap-rails`, `turbo-rails` nem `stimulus-rails`.
- [ ] Cada garantia de isolamento, corrida, ida e volta do CSV e confirmação única do import que hoje só um teste HTML prova tem teste equivalente sobre API, model ou query antes do arquivo sair, registrado num inventário.
- [ ] `bin/rails test`, `bin/rubocop`, `bin/brakeman`, os gates quick e e2e do front e `docker build -f Dockerfile .` passam ao fim.

## Out of Scope

| Feature | Reason |
|---|---|
| Tela nova ou mudança de comportamento de tela | A régua é a paridade (AD-023); cada tela pertence à sua fatia. O estado "Página não encontrada" (STRO-10) é o substituto do `404` do Rails, não tela de produto. |
| Endpoint novo em `/api` | Todas as telas da checklist já têm seus endpoints nas fatias; os downloads ficam fora de `/api` pelo P14 (AD-031). |
| Implementar as fatias que faltam ou emendar seus specs | Cada fatia é dona do seu spec. A emenda do SCAT-03 (`spa-catalogo`) é pré-condição desta feature (STRO-02), feita no spec da `spa-catalogo`, não aqui. |
| Botão "Copiar lista" do deck, download do texto pela SPA | Melhoria além da paridade, já fora da `spa-decks`. |
| Status `404` HTTP para caminho desconhecido sob a raiz | O fallback do adapter-static responde `200` para todo caminho; dar `404` exigiria o Rails conhecer as rotas da SPA. A tela mostra "Página não encontrada" (STRO-10). |
| Restilizar as páginas de erro de `public/` (`404.html`, `500.html`, `406-unsupported-browser.html`) | São do Rails, não do Hotwire, e continuam servindo erros fora da SPA. |
| Limite de tentativas no login, `secure` explícito no cookie | Dívidas de autenticação do `CLAUDE.md`, independentes da troca. |
| Preferência de tema no servidor | AD-025 mantém a escolha por dispositivo. |
| Service worker, manifest PWA | Os arquivos de `app/views/pwa/` não têm rota hoje; saem com as views (STRO-25) e não são substituídos. |
| Remover o `ApplicationController` ou renomear concerns por estética | Só sai o que fica sem uso (STRO-25, STRO-26); a forma de reorganizar é do design. |
| Mudança de cookie, de chave de sessão ou de CSRF | A sessão continua a mesma (STRO-24); a SPA já usa o CSRF por sessão do Req. 16. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| **P14** — destino de `GET /collection/export` e `GET /decks/<id>.txt` | Manter nas URLs atuais, como rotas do Rails fora de `/api`, com sessão e `302` para `/entrar?return_to=` sem ela (STRO-16..19, 22). Alternativa: movê-las para `/api`, emendando o Req. 16.14 para admitir `text/csv` e `text/plain` | Download não é tela; o Req. 16.14 ("todo endpoint de `/api` responde JSON") e a varredura do `end_to_end_test.rb` continuam simples; a URL `/decks/<id>.txt` já foi usada no simulador (T21 da `decks`) e as fatias `spa-pasta`, `spa-decks` e `spa-portabilidade` já linkam para as duas. Mover para `/api` mudaria contrato público e invariante do Req. 16 | Sim — dono, 2026-10-11 (AD-031) |
| **P15** — status dos redirecionamentos | `301` (STRO-11, STRO-12). Alternativa: `302` | A AD-023 torna a troca definitiva e o Req. 4.7 pede URL estável; `301` atualiza favoritos e buscadores. O custo é de reversão: o navegador guarda o `301`, e um rollback para a imagem com Hotwire deixaria favoritos apontando para rotas que ela não tem. O dono aceitou esse custo | Sim — dono, 2026-10-11 (AD-031) |
| **⚠️ VERIFICAR P16** — Rails 8.0 sem `propshaft` | Retirar a gem junto com `config/initializers/assets.rb` e as referências a `config.assets` (STRO-27) | Depois da troca não resta arquivo em `app/assets/` para servir; o build da SPA vem do estágio Node. Não confirmei que o Rails 8.0.5 sobe sem a gem nem que nenhum ambiente (`production.rb`, `Dockerfile` com `assets:precompile`) depende dela; o design confirma antes da task | Não — ⚠️ VERIFICAR |
| Pré-condição de paridade | A troca só começa com as cinco fatias encerradas e verificadas (`validation.md` PASS) e o SCAT-03 emendado (STRO-01, STRO-02) | É a regra da AD-023 ("ele sai quando a SPA atingir paridade"); remover antes deixaria o usuário sem uma tela | Não — escolha do agente, segue a AD-023 |
| Remoção em bloco | O Hotwire sai de uma vez, numa feature, e não tela a tela junto de cada fatia | As fatias decidiram manter o HTML intacto (Req. 16.17, 17.4, 19.49, 20.46, 21.61, 22.45); a remoção depende de rotas, concerns e suíte compartilhados | Não — escolha do agente |
| Raiz em vez de `/app` | `paths.base` vazio; rotas da SPA iguais às de hoje sem o prefixo (STRO-09) | A AD-023 manda a SPA sair de `/app` na troca; as rotas pt-BR (`/cartas`, `/pasta`, `/baralhos`, `/entrar`) não colidem com os caminhos ingleses que o Rails mantém | Não — escolha do agente, segue a AD-023 |
| Lista fechada de caminhos do Rails | `/api/*`, `/card_images/*`, `/up`, `/_app/*`, arquivos de `public/`, as duas rotas de arquivo e os redirecionamentos (STRO-08) | Com a SPA na raiz, o proxy do Vite e o fallback do Rails precisam da mesma fronteira; uma lista explícita impede que uma rota nova engula a SPA ou o contrário | Não — escolha do agente |
| Entrada da SPA fora do servidor de estáticos | `/200.html` responde como qualquer caminho da SPA, com `no-cache` (STRO-07) | Fecha a dívida do *Handoff* da `spa-fundacao` (`/app/200.html` com cache de um ano pelo `ActionDispatch::Static`); a troca é o momento em que o arquivo muda de lugar | Não — escolha do agente |
| Destino de `/app/200.html` | Redireciona para `/200.html` pela regra geral de `/app` (STRO-12), que responde a entrada com `no-cache` (STRO-07) | Uma regra só para `/app`; nenhum link aponta para o arquivo | Não — escolha do agente |
| Caminho desconhecido na raiz | Estado "Página não encontrada" dentro do casco, com link para `/`, e HTTP `200` (STRO-10) | Hoje `/qualquer` dá o `404.html` do Rails; com o fallback, sem esse estado o usuário veria a página de erro padrão do SvelteKit. Não existe `+error` na SPA hoje | Não — escolha do agente |
| Redirecionamento sem banco | O destino sai do caminho; id, `card_number` ou `token` inexistente vira o `404` da tela da SPA (STRO-13) | O redirecionamento é público e barato, e não vaza se um deck existe (DCK-36): a tela da SPA consulta com a sessão | Não — escolha do agente |
| `/` não redireciona | A raiz já é a SPA; só `/catalog` redireciona para `/` | `/` era o catálogo Hotwire (`root "catalog#index"`) e passa a ser o catálogo da SPA com a mesma query (SCAT-05) | Não — escolha do agente |
| Métodos além de `GET` | `404` sem efeito para `POST`, `PATCH`, `DELETE` em rota HTML removida (STRO-15) | Uma aba antiga com formulário Hotwire aberto não pode cair na página de entrada nem num `500`; nada é gravado | Não — escolha do agente |
| `return_to` antigo | `/app/...` é lido sem o prefixo (STRO-21) | O `401` da SPA gerou links `/app/entrar?return_to=%2Fapp%2F...` durante a transição; o redirecionamento leva a `/entrar` com o mesmo `return_to`, e sem a regra o login cairia numa rota inexistente | Não — escolha do agente |
| Download sem sessão | `302` para `/entrar?return_to=<caminho>` e, depois do login, navegação de página inteira para o download (STRO-19, STRO-22) | Paridade com o HTML, que guarda o destino e volta a ele depois do login; o `goto` do cliente não alcança rota do Rails | Não — escolha do agente, paridade |
| Deck em edição | Continua em `session[:editing_deck_id]`, agora só pela API (STRO-23) | A chave mora na sessão do Rails, não no Hotwire; a `spa-decks` já lê e grava pela API, e login/logout pela API já rodam `reset_session` | Não — escolha do agente; confirma o herdado da `spa-decks` |
| Inventário de testes | Tabela arquivo removido → destino (removido, reescrito em X) no `design.md`, conferida pelo Verifier (STRO-31) | São cerca de 60 arquivos em `test/integration/` fora de `api/`, 28 em `test/design/` e 2 em `test/helpers/`; alguns provam regra que sobrevive (`collection_authorization_test`, `deck_entries_concurrency_test`, `collection_csv_roundtrip_test`, `collection_import_commit_test`, `progress_authorization_test`) | Não — escolha do agente |
| e2e de paridade | Os testes que comparam `/app/...` com a página Hotwire passam a comparar a SPA com a resposta da API ou com o banco (STRO-34) | Sem o Hotwire não há lado HTML; a comparação com a fonte dos números mantém a prova | Não — escolha do agente |
| Notas de emenda nos critérios superados | Uma linha em itálico em cada critério superado, como a emenda do Req. 12.2 (STRO-36) | Padrão de emenda já usado no `.context/requirements.md`; o Req. 23 lista os superados para a task não precisar redescobrir | Não — escolha do agente |
| Imagens | `/card_images/<variant_code>` continua igual: rota, `Cache-Control` de um ano, `404` e `502` (STRO-28) | A API devolve `card_image_path` no payload (`_variant.json.jbuilder`); o controller hoje herda do `ApplicationController` do HTML, e o design escolhe a nova base sem mudar a resposta | Não — escolha do agente |

**Open questions:** none - all resolved or logged above. P14 e P15 decididos pelo dono em 2026-10-11 (AD-031); o P16 é verificado no design.

---

## User Stories

### P1: Paridade comprovada antes da remoção ⭐ MVP

**User Story**: Como dono, quero que o Hotwire só saia quando cada tela dele tiver equivalente verificado na SPA, para que nenhum usuário perca uma função na troca.

**Why P1**: É a regra da AD-023; sem ela a troca vira regressão.

**Checklist de paridade** (Req. 23):

| Tela Hotwire | URL Hotwire | Destino na SPA | Cobertura |
|---|---|---|---|
| Catálogo | `/`, `/catalog` | `/` | Req. 18 (`spa-catalogo`), SCAT-03 emendado |
| Detalhe da carta | `/cards/<card_number>` | `/cartas/<card_number>` | Req. 19 (`spa-carta`) |
| Deck em edição no detalhe | `/cards/<card_number>` | `/cartas/<card_number>` | Req. 21 (`spa-decks`) |
| Entrar, criar conta, sair | `/session/new`, `/registration/new` | `/entrar`, `/criar-conta`, casco | Req. 17 (`spa-fundacao`, encerrada) |
| Minha pasta | `/progress` | `/pasta` | Req. 20 (`spa-pasta`) |
| Faltando para os decks | `/progress` | `/pasta` | Req. 21 (`spa-decks`) |
| Lista de desejos | `/wishlist` | `/pasta/desejos` | Req. 20 (`spa-pasta`) |
| Import da coleção | `/collection/import`, `/collection/import/<token>` | `/pasta/importar`, `/pasta/importar/<token>` | Req. 22 (`spa-portabilidade`) |
| Export da coleção | `/collection/export` | rota de arquivo (P14) | Req. 22.33 |
| Decks | `/decks`, `/decks/new`, `/decks/<id>`, `/decks/<id>/edit`, `/decks/<id>/delete`, `/decks/import` | `/baralhos`, `/baralhos/novo`, `/baralhos/<id>`, `/baralhos/<id>/renomear`, `/baralhos/<id>/excluir`, `/baralhos/importar` | Req. 21 (`spa-decks`) |
| Exportar lista do deck | `/decks/<id>.txt` | rota de arquivo (P14) | Req. 21.29 |
| Navegação, layout, mensagens | todas | casco e mensagens | Req. 17 (`spa-fundacao`) |

**Acceptance Criteria**:

1. The system SHALL só ter a troca iniciada quando cada linha da checklist de paridade estiver coberta por uma feature encerrada e verificada, com `validation.md` PASS e `validate_state.py <feature>` saindo 0.
2. The system SHALL ter, antes da troca, o SCAT-03 do spec da `spa-catalogo` emendado para levar o tile a `/app/cartas/<card_number>` sem recarga, como o Req. 19.3 e o SCAR-03 já determinam.
3. The system SHALL não ter na SPA nenhum `href`, `goto` ou destino de navegação para rota HTML removida; os únicos destinos fora da SPA SHALL ser as rotas de arquivo (STRO-17, STRO-18) e as imagens.

**Independent Test**: `validate_state.py` das cinco fatias saindo 0; leitura do SCAT-03; varredura do `frontend/src` e do build por destinos da lista de rotas removidas (Vitest ou script do gate).

---

### P1: SPA servida na raiz ⭐ MVP

**User Story**: Como colecionador, quero abrir o Bindr no endereço raiz e ter cada tela no caminho curto, para não depender de um prefixo de transição.

**Why P1**: É o objetivo da troca (AD-023); sem a raiz, as URLs antigas não têm para onde ir.

**Acceptance Criteria**:

4. WHEN `docker compose up` terminar THEN the system SHALL servir a SPA em `http://localhost:<porta do Vite>/` e encaminhar ao Rails, pelo proxy do Vite, só os caminhos do STRO-08, sem comando adicional (Req. 11.6).
5. WHEN o Rails de produção receber `GET` de caminho fora do STRO-08 THEN the system SHALL responder `200` com a página de entrada da SPA, `Content-Type` `text/html` e `Cache-Control: no-cache`.
6. The system SHALL servir os arquivos do build sob `/_app/` pelo servidor de estáticos com o cache de longa duração que ele aplica, e responder `404` a arquivo inexistente sob `/_app/`.
7. WHEN chegar `GET /200.html` THEN the system SHALL responder como no STRO-05 (`no-cache`), nunca com `max-age` de longa duração.
8. The system SHALL tratar como caminhos do Rails só esta lista fechada: `/api/*`, `/card_images/*`, `/up`, `/_app/*`, os arquivos de `public/`, as rotas de arquivo do STRO-17 e do STRO-18 e os redirecionamentos do STRO-11 e do STRO-12.
9. The system SHALL expor as rotas da SPA na raiz, sem `/app`: `/`, `/entrar`, `/criar-conta`, `/cartas/<card_number>`, `/pasta`, `/pasta/desejos`, `/pasta/importar`, `/pasta/importar/<token>`, `/baralhos`, `/baralhos/novo`, `/baralhos/importar`, `/baralhos/<id>`, `/baralhos/<id>/renomear` e `/baralhos/<id>/excluir`, com o comportamento que os Req. 17 a 22 dão às mesmas rotas sob `/app`.
10. IF a SPA receber um caminho que não é rota dela THEN the system SHALL exibir dentro do casco o cabeçalho de nível 1 "Página não encontrada", o título de página "Página não encontrada — Bindr" e o link "Ir para o catálogo" para `/`.

**Independent Test**: request tests Rails com `200.html` de fixture para `/`, `/pasta/desejos`, `/200.html` (`no-cache`) e `/_app/inexistente.js` (`404`); `curl` em `/` e `/api/session` pela porta do Vite; Vitest do estado de não encontrado; Playwright navegando pelas rotas na raiz.

---

### P1: URLs antigas continuam abrindo a mesma tela ⭐ MVP

**User Story**: Como colecionador que guardou ou compartilhou links do Bindr, quero que `/catalog?...`, `/cards/OP01-001?variant=...` e `/app/pasta` continuem abrindo a mesma tela, para não perder favoritos nem links enviados.

**Why P1**: O Req. 4.7 e o Req. 13.40 prometem URL compartilhável; a troca não pode quebrá-la.

**Acceptance Criteria**:

11. WHEN chegar `GET` numa URL Hotwire da checklist, salvo `/`, THEN the system SHALL redirecionar para o destino da mesma linha na SPA, com `301` (P15, AD-031) e a query string preservada sem alteração.
12. WHEN chegar `GET /app` ou `GET /app/<caminho>` THEN the system SHALL redirecionar para `/` ou `/<caminho>`, com `301` (P15, AD-031) e a query preservada.
13. The system SHALL derivar o destino do redirecionamento só do caminho, sem exigir sessão e sem consultar o banco.
14. The system SHALL repassar o segmento dinâmico (`card_number`, `id`, `token`) ao destino com a mesma codificação percentual da URL pedida.
15. IF chegar requisição de método diferente de `GET` e `HEAD` a uma rota HTML removida THEN the system SHALL responder `404` sem gravar nada, nunca a página de entrada nem `500`.

**Independent Test**: request test por linha da checklist e para `/app`, `/app/pasta?order=code` e `/app/cartas/P-029`: status, `Location` com a query e o segmento codificados; contagem de consultas zero no redirecionamento; `POST /collection_items/1/increment` e `DELETE /wishlist/1` com `404` e `collection_items`/`wishlist_items` intactos.

---

### P1: Downloads da coleção e do deck ⭐ MVP

**User Story**: Como colecionador, quero continuar baixando a minha coleção em CSV e a lista do deck em texto pelos mesmos links, para levar o dado embora e jogar no simulador.

**Why P1**: São as duas funções Hotwire que não viram tela (Req. 10.1, 14.31) e que as fatias deixaram para a troca decidir.

**Acceptance Criteria**:

16. The system SHALL manter as rotas de arquivo fora de `/api`, e todo endpoint sob `/api` SHALL continuar respondendo `application/json` (Req. 16.14, P14).
17. WHEN chegar `GET /collection/export` com sessão THEN the system SHALL devolver o CSV do Req. 10.1 com o mesmo conteúdo, tipo, `Content-Disposition` e nome de arquivo que devolve antes da troca.
18. WHEN chegar `GET /decks/<id>.txt` com sessão THEN the system SHALL devolver a lista do Req. 14.31 com o mesmo conteúdo e tipo que devolve antes da troca, e `404` para deck de outra conta ou inexistente (DCK-36).
19. IF uma rota de arquivo for pedida sem sessão THEN the system SHALL redirecionar com `302` para `/entrar?return_to=<caminho com query, codificado>`.

**Independent Test**: request tests com o corpo de antes da troca como referência (gravado do teste atual `collection_exports_test.rb` e `deck_export_test.rb`), deck alheio `404`, anônimo `302` com `Location` exato; varredura do `end_to_end_test.rb` continua só JSON.

---

### P1: Sessão, retorno e deck em edição atravessam a troca ⭐ MVP

**User Story**: Como colecionador já logado, quero continuar logado depois da troca e voltar à tela em que estava depois de entrar, para não perceber a mudança de front.

**Why P1**: Login e retorno tocam o prefixo `/app` (SPA-23); errar aqui é perder o usuário no primeiro acesso.

**Acceptance Criteria**:

20. WHEN o login ou o cadastro for aceito THEN the system SHALL seguir para o `return_to` decodificado se ele começar por `/` e não tiver `//`, `\`, caractere de controle nem segmento `.` ou `..`, e para `/` nos demais casos, no lugar da regra `/app/` do SPA-23.
21. IF o `return_to` for `/app` ou começar por `/app/` THEN the system SHALL removê-lo do prefixo `/app` antes de aplicar o STRO-20.
22. IF o destino pós-login for uma rota de arquivo THEN the system SHALL navegar com página inteira, e destino sob `/api/`, `/_app/` ou `/card_images/` SHALL virar `/`.
23. The system SHALL manter o deck em edição em `session[:editing_deck_id]`, lido e gravado só pela API, revalidado contra `Current.user.decks` a cada leitura e limpo no login e no logout.
24. WHEN um usuário com sessão aberta antes da troca abrir a SPA depois dela THEN the system SHALL reconhecê-lo pelo mesmo cookie, sem novo login.

**Independent Test**: Vitest do `safeReturnTo` com `/pasta`, `/app/pasta`, `/app`, `//x`, `/\x`, `/a/../b`, `/collection/export` e `/api/session`; request test que abre sessão, aplica a troca de rotas e lê `GET /api/session` com o mesmo cookie; request test de seleção de deck seguido de login de outra conta (`editing_deck` nulo).

---

### P1: Hotwire fora do código ⭐ MVP

**User Story**: Como dono, quero o código e as dependências do Hotwire removidos, para manter uma camada de apresentação só.

**Why P1**: É o ganho da troca; deixar o HTML morto no repositório mantém o custo da AD-023.

**Acceptance Criteria**:

25. The system SHALL não conter os controllers HTML (`CatalogController`, `CollectionItemsController`, `WishlistItemsController`, `ProgressController`, `CollectionImportsController`, `DecksController`, `DeckEntriesController`, `DeckImportsController`, `SessionsController`, `RegistrationsController`), as views fora de `app/views/api/`, os helpers de view, `app/javascript/`, `config/importmap.rb`, `bin/importmap`, `app/assets/stylesheets/` nem as rotas HTML, salvo o que as rotas de arquivo usam.
26. The system SHALL manter de cada concern e objeto só o que a API e as rotas de arquivo usam, sem redirecionamento para `new_session_path` nem leitura de `return_to_after_authenticating`.
27. The system SHALL não trazer no `Gemfile` as gems `importmap-rails`, `turbo-rails`, `stimulus-rails` e `propshaft`, com a remoção do `propshaft` condicionada ao ⚠️ VERIFICAR P16.
28. The system SHALL manter sem mudança de comportamento os endpoints de `/api` (Req. 16 e fatias), `/card_images/<variant_code>` (resposta, `Cache-Control`, `404`, `502`), `/up`, a ingestão e as tarefas `ingestion:*`.
29. The system SHALL fazer a troca sem migração e sem alterar linha de `cards`, `card_variants`, `collection_items`, `wishlist_items`, `decks`, `deck_entries`, `users` ou `sessions`.

**Independent Test**: `git ls-files` sem os caminhos do STRO-25; `bundle list` sem as quatro gems; `db/structure.sql` sem diff; suíte de API, imagens e ingestão passando sem edição.

---

### P1: Suíte reorganizada sem perder garantia ⭐ MVP

**User Story**: Como dono, quero que os testes de HTML saiam sem levar junto as provas de isolamento, concorrência e dado que eles carregam, para que a suíte continue protegendo o que é insubstituível.

**Why P1**: Vários testes de integração HTML são a única prova de regra crítica (Req. 6.5, corrida de posse e de deck, confirmação única do import); apagá-los às cegas abre buraco silencioso.

**Acceptance Criteria**:

30. The system SHALL remover cada teste cujo objeto é só markup, CSS, Turbo ou helper de view do HTML junto com o código que ele testa.
31. The system SHALL ter, antes de remover um teste HTML que prove garantia que continua valendo (isolamento entre usuários do Req. 6.5, corrida de posse e de deck, ida e volta do CSV, confirmação única do import, números da pasta e do que falta), um teste equivalente sobre a API, o model ou o query object, com o destino de cada arquivo removido registrado num inventário.
32. The system SHALL manter passando sem edição os testes de model, query, service, lib, API e imagem, e o teste de entrega da SPA SHALL mudar só para a raiz.
33. The system SHALL ter teste para cada redirecionamento do STRO-11 e do STRO-12 (status e `Location` com query) e para o `404` do STRO-15.
34. The system SHALL rodar o e2e contra a raiz, e todo teste que hoje compara a SPA com página Hotwire SHALL comparar com a resposta da API ou com o banco.
35. WHEN a troca terminar THEN the system SHALL passar `bin/rails test`, `bin/rubocop`, `bin/brakeman`, os gates quick e e2e do front e `docker build -f Dockerfile .`.

**Independent Test**: inventário do `design.md` com uma linha por arquivo removido; o Verifier escolhe ao acaso garantias do inventário e confere o teste de destino; mutação nas regras de isolamento e de corrida morta pela suíte depois da remoção.

---

### P2: Documentos coerentes com a troca

**User Story**: Como quem pega o projeto depois, quero que requisitos e `CLAUDE.md` descrevam o sistema como ele é, para não seguir instrução de um front que não existe.

**Why P2**: Não muda comportamento, mas um `CLAUDE.md` que manda "não trocar o placeholder por JS porque existe importmap" vira instrução errada para toda sessão seguinte.

**Acceptance Criteria**:

36. The system SHALL ter, em cada critério superado listado no Req. 23 (Req. 16.17, 17.4, 17.26, 19.49, 20.46, 21.61, 22.45, a frase do 12.2 e a cláusula "sem JavaScript" dos 9.7, 13.11, 13.30 e 13.40), uma nota de emenda apontando para o Req. 23.
37. The system SHALL ter o `CLAUDE.md` sem descrever o Hotwire como vigente e com as rotas e os comandos do front na raiz.

**Independent Test**: leitura dos critérios superados e do `CLAUDE.md`; `grep` por `/app/` e por "Hotwire" no `CLAUDE.md` só em contexto histórico.

---

## Edge Cases

- WHEN chegar `GET /catalog?colors[]=Red&colors[]=Green&sort=name` THEN the system SHALL redirecionar para `/?colors[]=Red&colors[]=Green&sort=name` com a query byte a byte, e a SPA SHALL mostrar o mesmo resultado (SCAT-05).
- WHEN chegar `GET /cards/OP01-001?variant=tcgplayer%3A123` THEN the system SHALL redirecionar para `/cartas/OP01-001?variant=tcgplayer%3A123`.
- WHEN chegar `GET /cards/P.029` (código com ponto) THEN the system SHALL redirecionar para `/cartas/P.029`, sem tratar `.029` como formato.
- WHEN chegar `GET /decks/<id>` sem extensão THEN the system SHALL redirecionar para `/baralhos/<id>`, e `GET /decks/<id>.txt` SHALL seguir o STRO-18, sem redirecionar.
- WHEN chegar `GET /decks/<id>` de deck alheio THEN the system SHALL redirecionar sem consultar, e a tela da SPA SHALL mostrar o `404` da API, sem revelar que o deck existe (DCK-36).
- WHEN chegar `GET /collection/import/<token>` de token vencido ou alheio THEN the system SHALL redirecionar para `/pasta/importar/<token>`, e a SPA SHALL seguir o Req. 22 (leitura do vencido, `404` do alheio).
- WHEN chegar `GET /app/entrar?return_to=%2Fapp%2Fpasta` THEN the system SHALL redirecionar para `/entrar?return_to=%2Fapp%2Fpasta`, e o login SHALL levar a `/pasta` (STRO-21).
- WHEN chegar `GET /app/_app/immutable/x.js` (chunk de build anterior) THEN the system SHALL responder `404`, nunca redirecionar para `/_app/` nem devolver a página de entrada.
- WHEN chegar `GET /app/200.html` THEN the system SHALL redirecionar para `/200.html`, que SHALL responder a entrada com `no-cache` (STRO-07).
- WHEN chegar `GET /session/new` ou `GET /registration/new` com sessão THEN the system SHALL redirecionar para `/entrar` ou `/criar-conta`, e a SPA SHALL levar a `/` (SPA-24).
- IF uma aba aberta antes da troca enviar um formulário Hotwire (`POST /collection_items/<id>/increment`, `DELETE /session`) THEN the system SHALL responder `404` sem gravar, e recarregar a aba SHALL levar à SPA pelo STRO-11.
- IF o proxy do Vite na raiz usar `changeOrigin` THEN o CSRF quebraria; the system SHALL manter o proxy sem `changeOrigin`, com `server.allowedHosts` e `config.hosts` como hoje.
- WHEN o usuário anônimo abrir `/decks/5.txt` THEN the system SHALL redirecionar para `/entrar?return_to=%2Fdecks%2F5.txt` e, depois do login com a conta dona, SHALL baixar a lista por navegação de página inteira (STRO-22).
- WHEN um caminho novo de primeiro nível for proposto para o Rails fora de `/api` THEN the system SHALL exigir emenda do STRO-08 antes, para não engolir rota da SPA.
- IF `/` receber parâmetro desconhecido THEN the system SHALL ignorá-lo como o catálogo ignora (Req. 4, SCAT-05), sem redirecionar.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| STRO-01 | P1: Paridade — fatias encerradas e verificadas (Req. 23.1) | - | Pending |
| STRO-02 | P1: Paridade — SCAT-03 emendado (Req. 23.2) | - | Pending |
| STRO-03 | P1: Paridade — nenhum destino para rota removida (Req. 23.3) | - | Pending |
| STRO-04 | P1: Raiz — dev pelo Vite (Req. 23.4) | - | Pending |
| STRO-05 | P1: Raiz — fallback de produção (Req. 23.5) | - | Pending |
| STRO-06 | P1: Raiz — arquivos do build em `/_app/` (Req. 23.6) | - | Pending |
| STRO-07 | P1: Raiz — `/200.html` sem cache longo (Req. 23.7) | - | Pending |
| STRO-08 | P1: Raiz — lista fechada de caminhos do Rails (Req. 23.8) | - | Pending |
| STRO-09 | P1: Raiz — rotas da SPA sem `/app` (Req. 23.9) | - | Pending |
| STRO-10 | P1: Raiz — página não encontrada (Req. 23.10) | - | Pending |
| STRO-11 | P1: URLs antigas — redirecionamento Hotwire (Req. 23.11, P15) | - | Pending |
| STRO-12 | P1: URLs antigas — redirecionamento de `/app` (Req. 23.12, P15) | - | Pending |
| STRO-13 | P1: URLs antigas — sem sessão nem banco (Req. 23.13) | - | Pending |
| STRO-14 | P1: URLs antigas — codificação do segmento (Req. 23.14) | - | Pending |
| STRO-15 | P1: URLs antigas — `404` para outros métodos (Req. 23.15) | - | Pending |
| STRO-16 | P1: Downloads — fora de `/api` (Req. 23.16, P14) | - | Pending |
| STRO-17 | P1: Downloads — CSV da coleção (Req. 23.17, P14) | - | Pending |
| STRO-18 | P1: Downloads — lista do deck (Req. 23.18, P14) | - | Pending |
| STRO-19 | P1: Downloads — anônimo para `/entrar` (Req. 23.19, P14) | - | Pending |
| STRO-20 | P1: Sessão — destino pós-login na raiz (Req. 23.20) | - | Pending |
| STRO-21 | P1: Sessão — `return_to` com `/app` (Req. 23.21) | - | Pending |
| STRO-22 | P1: Sessão — retorno a rota de arquivo (Req. 23.22) | - | Pending |
| STRO-23 | P1: Sessão — deck em edição (Req. 23.23) | - | Pending |
| STRO-24 | P1: Sessão — sessões abertas continuam (Req. 23.24) | - | Pending |
| STRO-25 | P1: Remoção — código HTML (Req. 23.25) | - | Pending |
| STRO-26 | P1: Remoção — concerns enxutos (Req. 23.26) | - | Pending |
| STRO-27 | P1: Remoção — gems (Req. 23.27, P16) | - | Pending |
| STRO-28 | P1: Remoção — API, imagens, `/up` e ingestão intactos (Req. 23.28) | - | Pending |
| STRO-29 | P1: Remoção — sem migração nem dado alterado (Req. 23.29) | - | Pending |
| STRO-30 | P1: Suíte — testes só de HTML saem (Req. 23.30) | - | Pending |
| STRO-31 | P1: Suíte — garantias com equivalente e inventário (Req. 23.31) | - | Pending |
| STRO-32 | P1: Suíte — testes de domínio sem edição (Req. 23.32) | - | Pending |
| STRO-33 | P1: Suíte — testes dos redirecionamentos (Req. 23.33) | - | Pending |
| STRO-34 | P1: Suíte — e2e na raiz e sem Hotwire (Req. 23.34) | - | Pending |
| STRO-35 | P1: Suíte — gates finais (Req. 23.35) | - | Pending |
| STRO-36 | P2: Documentos — notas de emenda (Req. 23.36) | - | Pending |
| STRO-37 | P2: Documentos — `CLAUDE.md` (Req. 23.37) | - | Pending |

**Coverage:** 37 total, 0 mapped to tasks, 37 unmapped ⚠️ (`design.md` e `tasks.md` ainda não escritos).

### Implicit-requirement dimensions

| Dimensão | Cobertura |
|---|---|
| Input validation & bounds | STRO-14 (segmento codificado), STRO-20, STRO-21, STRO-22 (`return_to`), STRO-08 (fronteira de caminhos) |
| Failure / partial-failure states | STRO-10 (caminho desconhecido), STRO-15 (método removido), STRO-06 (chunk ausente) |
| Idempotency / retry / duplicate handling | STRO-11, STRO-12: redirecionamento sem estado; N/A para escrita, porque a troca não cria mutação |
| Auth boundaries & rate limits | STRO-13 (redirecionamento público), STRO-18, STRO-19 (download com sessão, deck alheio `404`), STRO-31 (isolamento preservado); limite de tentativas fora (dívida do `CLAUDE.md`) |
| Concurrency / ordering | STRO-31: as provas de corrida de posse, de deck e de confirmação do import sobrevivem à remoção |
| Data lifecycle / expiry | STRO-29: nenhum dado muda; STRO-05 e STRO-07 (cache da entrada) |
| Observability | N/A porque a troca não acrescenta fluxo novo; o log de erro da API (Req. 16.16) não muda |
| External-dependency failure | N/A porque a troca não toca a apitcg nem o CDN; `/card_images` mantém o `502` (STRO-28) |
| State-transition integrity | STRO-23, STRO-24: sessão e deck em edição atravessam a troca sem mudar de estado |

---

## Success Criteria

- [ ] Para cada linha da checklist, abrir a URL Hotwire com uma query real leva à tela da SPA na raiz com o mesmo resultado, em request test e em Playwright.
- [ ] `/app`, `/app/pasta?order=code` e `/app/entrar?return_to=%2Fapp%2Fpasta` levam à raiz, e o login do último termina em `/pasta`.
- [ ] `GET /collection/export` e `GET /decks/<id>.txt` devolvem os mesmos bytes e cabeçalhos de antes da troca para a mesma conta.
- [ ] `git ls-files` não lista controller, view, helper, CSS nem JavaScript do Hotwire, e o `Gemfile` não traz as gems do STRO-27.
- [ ] O inventário de testes tem uma linha por arquivo removido, e cada garantia de isolamento, corrida, CSV e confirmação tem teste de destino que mata a mutação correspondente.
- [ ] `bin/rails test`, `bin/rubocop`, `bin/brakeman`, os gates quick e e2e do front e `docker build -f Dockerfile .` passam, e `db/structure.sql` não muda.
