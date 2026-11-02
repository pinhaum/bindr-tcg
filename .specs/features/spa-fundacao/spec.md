# Especificação — Fundação da SPA SvelteKit

Recorte da feature `spa-fundacao` sobre `.context/requirements.md` Req. 17. Em
divergência, `.context/` vence (AD-005). Depende da `api-fundacao` (Req. 16,
API-01..17), encerrada e verificada em 2026-10-10 (`d1e90b5`): o contrato de
sessão, CSRF e erro é dela e aqui só é consumido.

## Problem Statement

O dono vai trocar o front Hotwire por uma SPA SvelteKit na mesma origem do Rails
(AD-023), e hoje não existe `frontend/`, nem cliente HTTP, nem tema claro, nem
teste de navegador. Cada fatia de tela (catálogo, carta, pasta, decks,
portabilidade) precisa da mesma base: entrega da SPA em dev e em produção, um
cliente que fala o contrato da `api-fundacao` (CSRF renovado, `401` → login,
erro único), o estado de sessão, o casco de navegação do Req. 13, os temas claro
e escuro com tokens únicos e a infraestrutura de teste. Esta feature entrega
essa base e as telas de entrar e criar conta, que já a exercitam por inteiro.

## Goals

- [ ] `docker compose up` sobe Rails e SPA, e `/app` abre a SPA em dev (proxy do Vite) e no build de produção servido pelo Rails, com recarga direta em qualquer rota `/app/*`.
- [ ] Um teste Playwright percorre criar conta → sair → entrar → sair só pela SPA, contra a API real, a 360px e a 1280px.
- [ ] Os dois temas passam no cálculo de contraste do Req. 12.3 para todo par de tokens, e a primeira pintura já sai no tema escolhido.
- [ ] Vitest cobre o cliente HTTP (CSRF, `401`, erro, falha de rede) com `fetch` falso, sem rede.

## Out of Scope

| Feature | Reason |
|---|---|
| Telas de catálogo, carta, pasta, decks e portabilidade | Uma fatia cada (`spa-catalogo` … `spa-portabilidade`), decisão do dono em 2026-10-10. |
| Estado de quantidades com atualização otimista e de deck em edição | Decisão do dono em 2026-10-10: nascem na `spa-carta` e na `spa-decks`, testados contra a API real da fatia, não contra dado falso. |
| Componentes que esta feature não usa: tile com placeholder, chip de filtro, stepper `−`/`+`, skeleton, número interpolado, `animate:flip`, morph grade→detalhe | Mesma decisão aplicada aos componentes: cada um nasce na primeira fatia que o consome (tile, chip e skeleton na `spa-catalogo`; stepper e morph na `spa-carta`; número interpolado na `spa-pasta`). Esta feature entrega só os tokens de movimento e o corte por `prefers-reduced-motion` que todos herdam. |
| Hexadecimais das seis cores do jogo | Pendência P8 aberta (Req. 12): exigem fonte primária, não estimativa. Entram com o chip de cor na `spa-catalogo` ou depois; até lá, tratamento neutro. |
| Remoção do Hotwire, troca de `/app` para a raiz | Feature final `spa-troca`, ao atingir paridade (AD-023). |
| Limite de tentativas de login | Dívida aberta da API (`sessions_controller.rb`); a SPA não a resolve no cliente. |
| Recuperação de senha, troca de e-mail, exclusão de conta | Não existem no Req. 6 nem no HTML atual. |
| Preferência de tema guardada no servidor | Não há tabela de preferências; a escolha é por dispositivo. |
| Tradução das mensagens de erro no cliente | A API já entrega `message` em pt-BR (API-11); o front exibe, não traduz. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| Stack | SvelteKit 3 + Svelte 5 (runes), TypeScript, adapter-static com fallback `200.html` (a doc recomenda evitar `index.html`), `ssr = false`, em `frontend/` | Decisão do dono, AD-023 | Sim — dono, 2026-10-10 |
| Base da SPA | `paths.base = "/app"` durante a transição | AD-023: o Hotwire continua na raiz até a `spa-troca` | Sim — dono, 2026-10-10 |
| Rotas desta feature | `/app` (início), `/app/entrar`, `/app/criar-conta` | Nomes em pt-BR iguais aos rótulos da navegação; as rotas HTML (`/session/new`) continuam inalteradas | Não — escolha do agente |
| Navegação para telas ainda não migradas | As entradas "Catálogo", "Minha pasta" e "Baralhos" apontam para as páginas Hotwire (`/catalog`, `/progress`, `/decks`) até a fatia correspondente existir; cada fatia troca o destino da sua entrada | Req. 13.8 proíbe entrada para o que não existe; a sessão é o mesmo cookie, então o usuário segue autenticado ao cruzar | Não — escolha do agente |
| Início (`/app`) | Página com o título "Bindr" e o e-mail do usuário quando há sessão; vira o catálogo na `spa-catalogo` | Precisa existir uma rota-alvo para o pós-login antes do catálogo migrar | Não — escolha do agente |
| Seletor de tema | Três opções, "Sistema", "Claro" e "Escuro", padrão "Sistema"; no topo da coluna lateral em viewport larga e num cabeçalho com a marca em viewport estreita (a barra inferior mantém só as entradas do Req. 13.1) | Três estados permitem voltar ao padrão do sistema; a barra inferior já divide a largura em partes iguais (Req. 13.9) e um quinto item a apertaria | Não — escolha do agente |
| Persistência do tema | `localStorage`, chave `bindr-theme`, valores `system`/`light`/`dark`; valor ausente ou desconhecido vale `system` | Não há preferência no servidor; leitura síncrona permite aplicar antes da pintura | Não — escolha do agente |
| Destino pós-login e pós-cadastro | O `return_to` da URL quando é caminho relativo começando por `/app/`; qualquer outro valor é descartado e vale `/app` | Evita redirect aberto; o `return_to` vem da própria SPA (SPA-09) | Não — escolha do agente |
| CSRF desatualizado | Em `422 invalid_csrf_token`, o cliente busca `GET /api/session`, troca o token e compara o usuário devolvido com o da tela: reenvia **uma** vez só com o mesmo usuário (SPA-10) | Login ou logout em outra aba roda `reset_session` e invalida o token desta; a API não executa a action no `422` (API-08), então o reenvio não duplica efeito. O Rails confere o CSRF antes da sessão (`verify_authenticity_token` precede `require_authentication` no `Api::BaseController`), então sessão encerrada em outra aba chega como `422`, não como `401` | Sim — dono, 2026-10-10 (comparação do usuário) |
| Tempo limite de requisição | 15 s, com a mesma mensagem de falha de rede | Mesa de loja com rede ruim: sem limite o botão fica pendente indefinidamente | Não — escolha do agente |
| Mensagens | Sucesso em região `aria-live="polite"` que some em 5 s; erro em `role="alert"`, permanece até ser fechado | Erro não pode sumir antes de ser lido (WCAG 2.2.1) | Não — escolha do agente |
| Validação no cliente | Só `required` e `type="email"` nativos; regras de senha e unicidade são da API (API-07) | Duplicar a regra de 8 caracteres no cliente cria dois donos para a mesma regra | Não — escolha do agente |
| Paleta clara | Mesmas duas matizes do Req. 12.4 (azul-petróleo e âmbar) e `danger`, com valores novos; o design define os hex | Req. 12.4 vale para os dois temas; a paleta é trabalho de design, não de spec | Não — escolha do agente |
| Tema escuro | Os valores do design §11.3 são o ponto de partida e só mudam se um par reprovar o Req. 12.3 | Handoff do dono: o escuro é revisado, não descartado | Sim — dono, 2026-10-10 |
| Req. 12.2 ("um único tema, escuro") | Emendado por esta feature (AD-025): dois temas, padrão `prefers-color-scheme` | Decisão do dono, 2026-10-10 | Sim — dono, 2026-10-10 |
| Testes | Vitest + `@testing-library/svelte` para cliente e componentes; Playwright num serviço do compose com a imagem `mcr.microsoft.com/playwright`, contra a API real | Decisão do dono; sem navegador no container `app` (dívida do CLAUDE.md), o serviço próprio a resolve | Sim — dono, 2026-10-10 |
| Entrega em produção | Build em `public/app/`, assets servidos pelo `ActionDispatch::Static`; rota `app(/*path)` devolve `200.html` com `no-cache` | Escolha do dono no design: pouco código e os assets não passam pelo Ruby | Sim — dono, 2026-10-10 |
| Gerenciador de pacotes | npm, com `package-lock.json` versionado | Não há lockfile JS no repo; npm é o padrão da maioria dos projetos do dono | Não — escolha do agente |

**Open questions:** none - all resolved or logged above.

---

## User Stories

### P1: SPA servida na mesma origem ⭐ MVP

**User Story**: Como dono do Bindr, quero que a SPA suba junto do Rails e seja servida na mesma origem em dev e em produção, para que o cookie de sessão e o CSRF funcionem sem CORS.

**Why P1**: Sem entrega nenhuma tela da SPA existe, e a mesma origem é a premissa da AD-023.

**Acceptance Criteria**:

1. WHEN `docker compose up` terminar THEN the system SHALL servir a SPA em `http://localhost:<porta do Vite>/app` e encaminhar ao Rails, pelo proxy do Vite, todo caminho fora de `/app` (API, imagens e páginas Hotwire), sem comando adicional (Req. 11.6).
2. WHEN o Rails de produção receber `GET /app` ou `GET /app/<qualquer caminho>` sem arquivo correspondente no build THEN the system SHALL responder `200` com a página de entrada da SPA (`200.html`, fallback do adapter-static) e `Cache-Control: no-cache`.
3. WHEN o Rails de produção receber `GET` de um arquivo existente do build sob `/app/` THEN the system SHALL servir o arquivo pelo servidor de arquivos estáticos do Rails, com o `Cache-Control` de longa duração que ele já aplica (`max-age` de 1 ano).
4. The system SHALL manter inalteradas as rotas fora de `/app`: a suíte Rails existente passa sem edição.
5. WHEN `docker build -f Dockerfile .` rodar THEN the system SHALL gerar o build da SPA num estágio Node do `Dockerfile` de produção e copiá-lo para a imagem final, sem Node na imagem final.

**Independent Test**: Request test no Rails sobre `/app/qualquer/coisa` com um `200.html` de fixture; `docker compose up` seguido de `curl` em `/app` e em `/api/session` pela porta do Vite.

---

### P1: Cliente HTTP do contrato da API ⭐ MVP

**User Story**: Como fatia de tela da SPA, quero um cliente HTTP único que cuide de CSRF, sessão expirada, erro e falha de rede, para que nenhuma tela reimplemente essas regras.

**Why P1**: Toda fatia seguinte faz chamadas pela mesma porta; uma regra de CSRF ou de `401` duplicada por tela é o erro mais caro de corrigir depois.

**Acceptance Criteria**:

6. The system SHALL fazer toda chamada à API por um único módulo cliente, com `credentials: "same-origin"`, e nenhuma tela SHALL chamar `fetch` diretamente.
7. The system SHALL enviar o header `X-CSRF-Token` com o token vigente em toda requisição `POST`, `PATCH`, `PUT` e `DELETE`.
8. WHEN uma resposta de `GET /api/session`, `POST /api/session`, `DELETE /api/session` ou `POST /api/registration` trouxer `data.csrf_token` THEN the system SHALL substituir o token vigente por ele antes da próxima requisição.
9. IF uma resposta vier `401` com `error.code` `"unauthenticated"` THEN the system SHALL marcar a sessão como anônima e navegar para `/app/entrar?return_to=<caminho atual com query>`, exceto na resposta de `DELETE /api/session`, tratada pelo SPA-22.
10. IF uma mutação vier `422` com `error.code` `"invalid_csrf_token"` THEN the system SHALL buscar `GET /api/session`, trocar o token e comparar o usuário devolvido com o da sessão em memória: com o mesmo usuário (ou anônimo nos dois), SHALL reenviar a mesma mutação uma única vez; com `user` nulo onde havia usuário, SHALL agir como no SPA-09 sem reenviar, exceto quando a mutação for `DELETE /api/session`, que SHALL ser tratada como saída concluída pelo SPA-22; com outro usuário, SHALL atualizar o estado de sessão, navegar para `/app` e entregar à tela um erro com `code` `"session_changed"` e a mensagem "A sessão mudou em outra aba. Confira a conta e tente de novo.", sem reenviar. IF o reenvio também vier `422 invalid_csrf_token` THEN the system SHALL entregar o erro à tela sem novo reenvio.
11. WHEN uma resposta de erro chegar com o corpo `{ error: { code, message, fields } }` THEN the system SHALL entregar à tela um erro tipado com `status`, `code`, `message` e `fields` exatamente como vieram, sem reescrever `message`.
12. IF a requisição falhar sem resposta (rede, DNS) ou passar de 15 s THEN the system SHALL entregar à tela um erro com `code` `"network_error"` e a mensagem "Sem conexão com o servidor. Tente novamente.".
13. IF a resposta não for JSON no formato do envelope (`data` ou `error`) THEN the system SHALL entregar à tela um erro com `code` `"unexpected_response"` e a mensagem "Erro inesperado. Tente novamente.".

**Independent Test**: Vitest com `fetch` falso: token trocado após login; `X-CSRF-Token` presente em `POST` e ausente em `GET`; `401` dispara navegação com `return_to`; `422 invalid_csrf_token` gera exatamente um `GET /api/session` e um reenvio.

---

### P1: Sessão, entrar e criar conta ⭐ MVP

**User Story**: Como colecionador, quero entrar, criar conta e sair pela SPA, e voltar para onde eu estava depois de entrar, para usar a coleção sem passar pelas páginas antigas.

**Why P1**: É a primeira tela que exercita o cliente, a sessão e os componentes de formulário de ponta a ponta.

**Acceptance Criteria**:

14. WHEN a SPA carregar THEN the system SHALL chamar `GET /api/session` uma vez antes de renderizar a primeira rota e guardar `user` e `csrf_token` no estado de sessão.
15. IF o `GET /api/session` inicial falhar com qualquer erro (`network_error`, `unexpected_response` ou erro da API, como `406 unsupported_browser` ou `500 internal_error`) THEN the system SHALL exibir a mensagem do erro e um botão "Tentar novamente" que repete a chamada, sem renderizar a rota.
16. WHEN o usuário enviar o formulário de `/app/entrar` com e-mail e senha THEN the system SHALL chamar `POST /api/session` e, com `200`, atualizar o estado de sessão e navegar para o destino pós-login.
17. IF `POST /api/session` vier `401 invalid_credentials` THEN the system SHALL exibir `error.message` acima do formulário, manter o e-mail preenchido, limpar a senha e mover o foco para a mensagem.
18. WHEN o usuário enviar o formulário de `/app/criar-conta` com e-mail, senha e confirmação THEN the system SHALL chamar `POST /api/registration` e, com `201`, atualizar o estado de sessão e navegar para o destino pós-login.
19. IF `POST /api/registration` vier `422 validation_failed` THEN the system SHALL exibir cada mensagem de `error.fields.<atributo>` junto do campo correspondente (`email`, `password`, `password_confirmation`), associada por `aria-describedby`, marcar o campo com `aria-invalid="true"` e mover o foco para o primeiro campo inválido.
20. IF `error.fields` trouxer atributo sem campo correspondente no formulário THEN the system SHALL exibir a mensagem acima do formulário, nunca descartá-la.
21. WHILE um envio de entrar ou criar conta estiver pendente the system SHALL desabilitar o botão de envio e ignorar novo envio do mesmo formulário.
22. WHEN o usuário acionar "Sair" THEN the system SHALL chamar `DELETE /api/session` e, com `200`, marcar a sessão como anônima, navegar para `/app` e emitir a mensagem de sucesso "Sessão encerrada." (a mesma do HTML); com `401 unauthenticated`, ou com `user` nulo na renovação do SPA-10, the system SHALL produzir o mesmo resultado, sem navegar para `/app/entrar`.
23. The system SHALL calcular o destino pós-login como o `return_to` da URL, depois de decodificado, quando ele começa por `/app/` e não contém `//` nem `\`, e como `/app` em qualquer outro caso.
24. WHEN um usuário com sessão abrir `/app/entrar` ou `/app/criar-conta` THEN the system SHALL navegar para `/app` sem exibir o formulário.

**Independent Test**: Vitest dos formulários com cliente falso (erro por campo, foco, botão pendente); Playwright contra a API real: criar conta → sair → entrar com senha errada → entrar → ver o e-mail no início.

---

### P1: Casco de navegação ⭐ MVP

**User Story**: Como colecionador, quero a mesma navegação do Req. 13 na SPA, para alcançar catálogo e pasta com o polegar em qualquer tela.

**Why P1**: Toda fatia monta dentro deste casco; sem ele cada tela redesenharia a navegação.

**Acceptance Criteria**:

25. The system SHALL exibir em toda rota da SPA a navegação principal do Req. 13.1: "Catálogo", "Minha pasta", "Baralhos" e "Sair" com sessão; "Catálogo", "Entrar" e "Criar conta" sem sessão, nesta ordem.
26. WHILE uma entrada apontar para tela ainda não migrada the system SHALL usar como destino a página Hotwire equivalente (`/catalog`, `/progress`, `/decks`), com navegação de página inteira.
27. The system SHALL marcar a entrada da rota atual com `aria-current="page"` e distingui-la por fundo e peso de fonte, não só por cor (Req. 13.2, 13.9).
28. WHILE a viewport tiver menos de 64rem de largura the system SHALL fixar a navegação na borda inferior, com entradas de largura igual e alvo de no mínimo 44px, e reservar no fim do conteúdo a altura da barra (Req. 13.3, 13.9).
29. WHILE a viewport tiver 64rem ou mais the system SHALL exibir a navegação no topo de uma coluna lateral de largura fixa, logo abaixo da marca, com superfície elevada separada do conteúdo por borda (Req. 13.10, 13.15).
30. The system SHALL renderizar o casco e as telas desta feature em 360px de largura sem scroll horizontal (Req. 2.5).

**Independent Test**: Playwright a 360px e a 1280px: posição da navegação, `scrollWidth <= clientWidth`, alvo ≥ 44px por `boundingBox`, `aria-current` na rota atual.

---

### P1: Temas claro e escuro ⭐ MVP

**User Story**: Como colecionador, quero a interface no tema do meu sistema ou no que eu escolher, sem piscar na carga, para ler a tela tanto na loja iluminada quanto à noite.

**Why P1**: Os tokens dos dois temas são a base visual de todas as fatias; trocar o sistema de cor depois de cinco telas prontas é retrabalho em todas.

**Acceptance Criteria**:

31. The system SHALL declarar cor, tipografia, espaço, raio, duração e easing como custom properties num único arquivo de tokens, e nenhum componente SHALL repetir um valor literal que exista como token (Req. 12.1).
32. The system SHALL definir cada token de cor com um valor para o tema claro e um para o escuro, com os mesmos nomes semânticos do design §11.3, e nenhum componente SHALL escolher cor por tema.
33. The system SHALL atingir, nos dois temas, 4.5:1 em todo par de texto sobre superfície e 3:1 em borda de controle e anel de foco sobre as três superfícies, verificável por cálculo de luminância relativa sobre os valores dos tokens (Req. 12.3).
34. The system SHALL usar nos dois temas só as matizes azul-petróleo e âmbar, mais `danger` (Req. 12.4).
35. WHILE a preferência guardada for "Sistema" ou estiver ausente the system SHALL seguir `prefers-color-scheme` e acompanhar sua mudança sem recarregar a página.
36. WHEN o usuário escolher "Claro" ou "Escuro" no seletor THEN the system SHALL aplicar o tema imediatamente, guardar a escolha em `localStorage` e mantê-la em cargas seguintes.
37. The system SHALL aplicar o tema efetivo ao documento antes da primeira pintura, sem exibir o outro tema em nenhum quadro da carga.
38. IF `localStorage` lançar exceção ou trouxer valor desconhecido THEN the system SHALL usar "Sistema" sem erro no console.
39. The system SHALL declarar `color-scheme` coerente com o tema efetivo, para que barras de rolagem e controles nativos acompanhem.
40. The system SHALL exibir o anel de foco de 2px sólido em `accent` com 2px de deslocamento em todo elemento focável, nos dois temas (Req. 12.9).

**Independent Test**: Teste de contraste sobre o arquivo de tokens (Vitest); Playwright com `emulateMedia({ colorScheme })` e `localStorage` pré-carregado: cor de fundo do `body` no primeiro quadro e após troca no seletor.

---

### P2: Movimento com corte por preferência

**User Story**: Como colecionador sensível a movimento, quero que a interface não anime quando eu peço menos movimento, e como dono quero uma regra única de movimento que as fatias herdem.

**Why P2**: As animações reais nascem nas fatias; aqui fica a regra que elas herdam, e a SPA funciona sem ela.

**Acceptance Criteria**:

41. The system SHALL declarar durações e curvas de easing só como tokens, e as transições SHALL animar apenas `transform` e `opacity`.
42. WHILE `prefers-reduced-motion: reduce` estiver ativo the system SHALL zerar toda duração de transição e animação, inclusive as transições do Svelte.
43. WHEN a SPA navegar entre rotas e o navegador suportar `document.startViewTransition` THEN the system SHALL envolver a troca numa View Transition via `onNavigate`; WHERE o navegador não suportar, the system SHALL trocar a rota sem transição e sem erro.

**Independent Test**: Playwright com `emulateMedia({ reducedMotion: "reduce" })`: `getComputedStyle` de um elemento animado devolve duração `0s`.

---

### P2: Mensagens transitórias

**User Story**: Como colecionador, quero ver o resultado de uma ação sem perder o lugar na tela, e ouvir esse resultado no leitor de tela.

**Why P2**: Substitui o flash do Rails para as fatias seguintes; nesta feature só o "Sair" o usa.

**Acceptance Criteria**:

44. WHEN uma tela emitir mensagem de sucesso THEN the system SHALL exibi-la numa região `aria-live="polite"` e removê-la após 5 s.
45. WHEN uma tela emitir mensagem de erro THEN the system SHALL exibi-la com `role="alert"`, distinta da de sucesso por rótulo escrito além da cor (Req. 12.8), até o usuário fechá-la.
46. The system SHALL exibir a mensagem sem mover o foco nem deslocar o conteúdo da página.

**Independent Test**: Vitest do componente: sucesso some após 5 s com timer falso; erro permanece; papéis ARIA corretos.

---

## Edge Cases

- WHEN o usuário estiver autenticado em duas abas e sair numa delas THEN the system SHALL, na outra, tratar a próxima mutação pelo SPA-10 (sem reenvio, levando a `/app/entrar`; se a mutação for o "Sair", concluindo-o pelo SPA-22) e o próximo `401` pelo SPA-09, sem estado preso de usuário logado.
- WHEN outra aba trocar a conta (sair de A e entrar como B) THEN the system SHALL, nesta aba, recusar o reenvio da próxima mutação pelo SPA-10 (`session_changed`), para que a ação pensada para A nunca seja executada na conta de B (decisão do dono, 2026-10-10).
- IF `return_to` vier codificado com `%2F%2F` ou com esquema (`https:`) THEN the system SHALL descartá-lo pelo SPA-23 depois de decodificar.
- IF o `401` chegar durante o próprio `POST /api/session` THEN the system SHALL tratá-lo como `invalid_credentials` (SPA-17), não como sessão expirada, sem navegar.
- IF `DELETE /api/session` vier `401 unauthenticated` (o registro `Session` sumiu no servidor com a sessão do Rails intacta; o logout em outra aba não chega assim, chega como `422 invalid_csrf_token` e segue o SPA-10) THEN the system SHALL tratá-lo como saída concluída pelo SPA-22, sem navegar para `/app/entrar`.
- WHEN o usuário recarregar o navegador em `/app/criar-conta?return_to=/app/x` THEN the system SHALL manter o `return_to` após o cadastro.
- WHEN a viewport cruzar 64rem com a página aberta THEN the system SHALL trocar barra inferior por coluna lateral sem recarregar e sem perder o foco.
- IF o Rails de produção receber `GET` de arquivo inexistente sob `/app/_app/` (chunk de um build anterior) THEN the system SHALL responder `404`, nunca a página de entrada com `200`.
- IF o build de produção não tiver `200.html` THEN the system SHALL falhar o `docker build -f Dockerfile .`, não o primeiro request.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| SPA-01 | P1: Entrega — dev em um comando (Req. 17.1) | Tasks (T2, T20, T22) | Verified |
| SPA-02 | P1: Entrega — página de entrada `200.html` (Req. 17.2) | Tasks (T3) | Verified |
| SPA-03 | P1: Entrega — arquivos do build (Req. 17.3) | Tasks (T4) | Verified |
| SPA-04 | P1: Entrega — rotas fora de `/app` intactas (Req. 17.4) | Tasks (T3) | Verified |
| SPA-05 | P1: Entrega — estágio Node no build (Req. 17.5) | Tasks (T4, T22) | Verified |
| SPA-06 | P1: Cliente — porta única (Req. 17.6) | Tasks (T1, T6) | Verified |
| SPA-07 | P1: Cliente — `X-CSRF-Token` (Req. 17.7) | Tasks (T6) | Verified |
| SPA-08 | P1: Cliente — troca do token (Req. 17.8) | Tasks (T6) | Verified |
| SPA-09 | P1: Cliente — `401` → entrar (Req. 17.9) | Tasks (T7, T13) | Verified |
| SPA-10 | P1: Cliente — CSRF desatualizado (Req. 17.10) | Tasks (T7, T13) | Verified |
| SPA-11 | P1: Cliente — erro tipado (Req. 17.11) | Tasks (T5, T6) | Verified |
| SPA-12 | P1: Cliente — falha de rede (Req. 17.12) | Tasks (T5, T6) | Verified |
| SPA-13 | P1: Cliente — resposta inesperada (Req. 17.13) | Tasks (T5, T6) | Verified |
| SPA-14 | P1: Sessão — carga inicial (Req. 17.14) | Tasks (T13, T14, T20) | Verified |
| SPA-15 | P1: Sessão — falha na carga (Req. 17.15) | Tasks (T14) | Verified |
| SPA-16 | P1: Sessão — entrar (Req. 17.16) | Tasks (T13, T16, T20) | Verified |
| SPA-17 | P1: Sessão — credencial inválida (Req. 17.17) | Tasks (T15, T16, T20) | Verified |
| SPA-18 | P1: Sessão — criar conta (Req. 17.18) | Tasks (T13, T17, T20) | Verified |
| SPA-19 | P1: Sessão — erro por campo (Req. 17.19) | Tasks (T15, T17) | Verified |
| SPA-20 | P1: Sessão — erro sem campo (Req. 17.20) | Tasks (T17) | Verified |
| SPA-21 | P1: Sessão — envio pendente (Req. 17.21) | Tasks (T15, T16, T17) | Verified |
| SPA-22 | P1: Sessão — sair (Req. 17.22) | Tasks (T7, T13, T20) | Verified |
| SPA-23 | P1: Sessão — destino pós-login (Req. 17.23) | Tasks (T12, T16, T17, T20) | Verified |
| SPA-24 | P1: Sessão — já autenticado (Req. 17.24) | Tasks (T16, T17, T20) | Verified |
| SPA-25 | P1: Casco — entradas (Req. 17.25) | Tasks (T18) | Verified |
| SPA-26 | P1: Casco — telas não migradas (Req. 17.26) | Tasks (T18) | Verified |
| SPA-27 | P1: Casco — entrada atual (Req. 17.27) | Tasks (T18, T21) | Verified |
| SPA-28 | P1: Casco — barra inferior (Req. 17.28) | Tasks (T19, T21) | Verified |
| SPA-29 | P1: Casco — coluna lateral (Req. 17.29) | Tasks (T19, T21) | Verified |
| SPA-30 | P1: Casco — 360px (Req. 17.30) | Tasks (T19, T21) | Verified |
| SPA-31 | P1: Temas — tokens únicos (Req. 17.31) | Tasks (T8) | Verified |
| SPA-32 | P1: Temas — valor por tema (Req. 17.32) | Tasks (T8) | Verified |
| SPA-33 | P1: Temas — contraste nos dois (Req. 17.33) | Tasks (T8) | Verified |
| SPA-34 | P1: Temas — duas matizes (Req. 17.34) | Tasks (T8) | Verified |
| SPA-35 | P1: Temas — seguir o sistema (Req. 17.35) | Tasks (T9, T21) | Verified |
| SPA-36 | P1: Temas — escolha manual (Req. 17.36) | Tasks (T9, T19, T21) | Verified |
| SPA-37 | P1: Temas — sem flash (Req. 17.37) | Tasks (T9, T21) | Verified |
| SPA-38 | P1: Temas — `localStorage` indisponível (Req. 17.38) | Tasks (T9) | Verified |
| SPA-39 | P1: Temas — `color-scheme` (Req. 17.39) | Tasks (T8) | Verified |
| SPA-40 | P1: Temas — anel de foco (Req. 17.40) | Tasks (T8) | Verified |
| SPA-41 | P2: Movimento — tokens e propriedades (Req. 17.41) | Tasks (T8) | Verified |
| SPA-42 | P2: Movimento — reduced motion (Req. 17.42) | Tasks (T8, T10, T21) | Verified |
| SPA-43 | P2: Movimento — View Transitions (Req. 17.43) | Tasks (T14, T21) | Verified |
| SPA-44 | P2: Mensagens — sucesso (Req. 17.44) | Tasks (T11) | Verified |
| SPA-45 | P2: Mensagens — erro (Req. 17.45) | Tasks (T11) | Verified |
| SPA-46 | P2: Mensagens — sem mover foco (Req. 17.46) | Tasks (T11) | Verified |

**Coverage:** 46 total, 46 mapped to tasks, 0 unmapped

## Implicit-Requirement Dimensions

| Dimension | Resolution |
|---|---|
| Input validation & bounds | SPA-19, SPA-20: a validação é da API; o cliente só tem `required`/`type="email"` nativos (premissa). SPA-23 valida `return_to` |
| Failure / partial-failure states | SPA-11, SPA-12, SPA-13, SPA-15: todo erro chega tipado à tela; falha na carga inicial tem tela própria |
| Idempotency / retry / duplicate handling | SPA-10 (um reenvio só, seguro porque a API não executa a action no `422`), SPA-21 (envio duplo bloqueado) |
| Auth boundaries & rate limits | SPA-09 (`401` → entrar), SPA-23 (sem redirect aberto), SPA-24. Rate limit fora de escopo, dívida da API |
| Concurrency / ordering | SPA-08, SPA-10 e o caso de borda das duas abas: a troca de token após login/logout e a recuperação quando outra aba trocou a sessão |
| Data lifecycle / expiry | SPA-36, SPA-38: a preferência de tema vive no `localStorage` do dispositivo, sem expiração; a sessão segue a política da API |
| Observability | N/A because a SPA não tem coleta de erro remota no escopo; falhas de API já ficam no log do Rails, e o cliente não escreve no console em fluxo normal (SPA-38) |
| External-dependency failure | SPA-12, SPA-15: a única dependência externa é a própria API; rede ausente e tempo limite têm mensagem definida |
| State-transition integrity | SPA-14, SPA-16, SPA-18, SPA-22: anônimo ↔ autenticado só por resposta bem-sucedida da API, com troca de token a cada transição |

## Success Criteria

- [x] Playwright, contra a API real, percorre criar conta → sair → entrar com senha errada → entrar → sair a 360px e a 1280px, nos dois temas, sem scroll horizontal.
- [x] O teste de contraste reprova se qualquer par de tokens de qualquer tema cair abaixo do Req. 12.3.
- [x] `docker compose up` sobe a SPA sem passo manual, e a suíte Rails continua verde sem edição.
