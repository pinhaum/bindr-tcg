# Especificação — Decks (Fase 2)

Recorte da feature `decks` sobre `.context/requirements.md` Req. 14. Em
divergência, `.context/` vence (AD-005).

## Problem Statement

O Bindr responde "quais cartas eu tenho?", mas não responde "consigo montar este
deck com o que tenho?". O jogador monta a lista em outro app, que não conhece a
pasta, e confere à mão carta por carta o que falta comprar ou trocar. Esta
feature entrega a montagem de decks pelas regras do jogo e o cruzamento de cada
deck com a coleção. O deck referencia `cards` e a coleção referencia
`card_variants` (`design.md` §10); é essa ponte que esta feature constrói.

## Goals

- [ ] O usuário monta um deck de 1 Leader + 50 cartas pelo detalhe da carta, sem formulário por carta.
- [ ] Cada deck mostra se cumpre as regras de montagem e, quando não cumpre, os motivos.
- [ ] Cada deck mostra, por carta, quantas cópias faltam na pasta para montá-lo.
- [ ] Uma lista no formato do OPTCG Simulator entra e sai do Bindr sem perda: importar o texto exportado reproduz o mesmo deck.
- [ ] A pasta mostra o que falta para montar qualquer um dos decks do usuário.

## Out of Scope

| Feature | Reason |
|---|---|
| Lista de banidas e pares banidos | Decisão do dono em 2026-10-01. A lista oficial muda com frequência (a de 12/10/2026 baniu a OP14-020) e a apitcg não a traz; mantê-la à mão produziria um "válido" falso no dia em que ficasse desatualizada. A página do deck declara que banimento não é verificado (DCK-17). |
| Deck de DON!! | As 10 DON!! são fixas e ficam fora do catálogo (P7). Não há escolha a fazer nem nada a validar. |
| Deck escolher variante (arte) | Para jogar, qualquer impressão da carta serve. O deck referencia `cards`; a escolha de arte é coisa da coleção. |
| Decks públicos, compartilhamento por link, perfis | `product.md` §4: rede social e perfis públicos são non-goals. O export em texto cobre o caso de levar a lista para fora. |
| Simulador de partida, mão inicial, estatística de curva | `product.md` §4: simulador e regra de jogo além da montagem são non-goals. |
| Preço do deck ou do que falta | Fase 3. |
| Outros formatos de lista (Limitless, Egman etc.) | O dono pediu o formato do OPTCG Simulator. Outro formato entra como requisito novo. |
| Mandar o que falta para a wishlist em um clique | Ideia adjacente, não pedida. |

## Assumptions & Open Questions

| Assumption/decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| Uso principal do deck | Montar pelas regras **e** cruzar com a pasta | Decisão do dono em 2026-10-01. O canvas "Bindr — telas" já desenha "Baralhos" na navegação e "Faltando para os baralhos" na pasta | Sim |
| Regras de montagem | 1 Leader; deck principal com exatamente 50 cartas; no máximo 4 cópias por `card_number`; cada carta do deck principal só com cores que o Leader tem | Confirmado no Play Guide oficial (`en.onepiece-cardgame.com/play-guide/`): "1 Leader Card, a 50-card deck, and 10 DON!! cards", "Your deck must match the color of your Leader Card", "up to 4 copies of any one card number". Resolve o `⚠️ VERIFICAR` de `design.md` §10 | Sim |
| Carta multicolorida no deck principal | Legal só se **todas** as cores dela estiverem entre as do Leader | Confirmado nas Comprehensive Rules v1.2.1 (28/08/2026), T1 em 2026-10-02: 2-3-5 ("treated as a card of every color it possesses") com 5-1-2-2 ("Only cards of a color included on the Leader card"). O Rule Manual diz o mesmo (p. 8 e p. 16) | Sim |
| Carta cujo texto permite mais de 4 cópias | **Existe**: a carta com "Under the rules of this game, you may have any number of this card in your deck" fica isenta do limite de 4, detectada pelo texto do catálogo (DCK-43) | T1 em 2026-10-02: 5-1-2-4 das Comprehensive Rules ("Effects related to deck construction rules … replace the deck construction rules above"). No snapshot de 2026-10-01: OP01-075 Pacifista, OP08-072 Biscuit Warrior, OP16-042 Prisoner of Impel Down. O default anterior ("não existe") marcaria `inválido` um deck legal | Sim — dono, 2026-10-02 |
| Leader com regra de montagem própria | Não verificada; a página do deck mostra o aviso e o texto da regra, e o status não muda (DCK-44) | T1 em 2026-10-02, mesma regra 5-1-2-4: OP12-001 Silvers Rayleigh (sem carta de custo 5+), OP13-079 Imu (sem Event de custo 2+), P-117 Nami (só tipo "East Blue"). Interpretar cada restrição exigiria código por Leader; o dono escolheu `válido` com aviso em vez de um quarto status | Sim — dono, 2026-10-02 |
| Banimentos | Não verificados; a página do deck declara isso | Decisão do dono em 2026-10-01 (ver Out of Scope) | Sim |
| Deck fora das regras | Salvo a cada alteração, com status derivado e motivos visíveis | Decisão do dono em 2026-10-01: montar um deck leva mais de uma sessão. O status é calculado na leitura, nunca persistido, pela mesma razão da wishlist "atendida": uma flag gravada fica obsoleta na alteração seguinte | Sim |
| Quantas cópias o usuário "tem" de uma carta | A soma de `collection_items.quantity` de **todas** as variantes da carta, presentes ou não na fonte | Para jogar, qualquer impressão serve. Variante ausente da fonte continua sendo uma carta física na pasta (Req. 1.7) | Sim — aprovado pelo dono em 2026-10-01 |
| "Faltando para os baralhos" com a mesma carta em vários decks | Vale o **maior** uso entre os decks, menos o possuído | Decisão do dono em 2026-10-01: um deck é desmontado para montar outro | Sim |
| Formato da lista em texto | Uma linha por carta, `<N>x<card_number>` (ex.: `4xOP17-094`), com o Leader incluído como `1x<card_number>` | Exemplo fornecido pelo dono em 2026-10-01, compatível com o OPTCG Simulator: 15 linhas, soma 51, primeira linha `1xOP17-079` (Leader Monkey.D.Luffy no banco de dev) | Sim |
| Separador de linha na importação | Aceitar CR, LF e CRLF, misturados ou não | O exemplo do dono veio separado por CR; um `<textarea>` envia CRLF; colar de um site costuma dar LF | Sim |
| Separador de linha na exportação | LF, Leader na primeira linha | ⚠️ VERIFICAR que o OPTCG Simulator aceita LF; o exemplo do dono usava CR | Não |
| Importação sobre deck existente | Importar sempre cria um deck novo | Substituir um deck existente por colagem destruiria o deck sem volta; criar um novo não destrói nada | Sim — aprovado pelo dono em 2026-10-01 |
| Importação com linha ruim | Tudo ou nada: nenhuma linha é aplicada e a mensagem lista os números das linhas problemáticas | Pular linha em silêncio entrega um deck diferente do colado, e o usuário só descobre na mesa | Sim — aprovado pelo dono em 2026-10-01 |
| Carta do deck ausente da fonte | Continua no deck, contando para as regras, marcada como "fora da fonte" | A ingestão nunca apaga (Req. 1.7); sumir com a carta do deck mudaria a lista sem o usuário pedir | Sim — aprovado pelo dono em 2026-10-01 |
| Limites de entrada | Nome de 1 a 60 caracteres; quantidade por carta de 1 a 50; texto importado até 200 linhas e 10.000 caracteres | 50 é o tamanho do deck principal, e uma lista real tem menos de 51 linhas. Os limites só barram entrada absurda | Sim — aprovado pelo dono em 2026-10-01 |
| Escolha do deck que recebe as cartas pelo detalhe | Um "deck em edição" escolhido pelo usuário; o mecanismo (sessão, URL) fica para o design | É decisão técnica; o requisito é só que o controle saiba para qual deck vai | Não — design |

**Open questions:** none — os padrões assumidos foram aprovados pelo dono em 2026-10-01 e 2026-10-02. Resta uma linha ⚠️ VERIFICAR (separador da exportação), resolvida pelo teste manual do dono na T21.

## User Stories

### P1: Montar um deck pelo detalhe da carta ⭐ MVP

**User Story**: Como jogador, quero montar um deck escolhendo um Leader e as cartas pelo detalhe da carta, para ter minha lista no mesmo lugar que minha pasta.

**Why P1**: Sem deck não há o que validar nem o que cruzar com a coleção.

**Acceptance Criteria**:
1. WHEN o usuário autenticado criar um deck com um nome THEN the system SHALL criar o deck vazio, sem Leader, pertencente a esse usuário, e abrir a página dele.
2. The system SHALL guardar o deck como um Leader opcional mais entradas `(carta, quantidade)` que referenciam `cards`, nunca `card_variants`, com no máximo uma entrada por carta por deck garantida no banco.
3. WHILE o usuário tiver um deck em edição, the system SHALL exibir no detalhe de cada carta não-Leader um controle de incremento e decremento da quantidade dela nesse deck, com a quantidade atual visível.
4. WHILE o usuário tiver um deck em edição, the system SHALL exibir no detalhe de uma carta Leader a ação "Usar como Leader", que torna essa carta o Leader do deck e substitui o anterior.
5. WHEN o usuário acionar incremento ou decremento de uma carta no deck THEN the system SHALL aplicar a alteração em uma única ação e atualizar a quantidade exibida sem recarregar a página inteira.
6. WHEN o decremento levar a quantidade de uma carta a zero THEN the system SHALL remover a entrada do deck.
7. WHEN o usuário abrir a página de um deck THEN the system SHALL exibir o Leader, as cartas do deck principal agrupadas em Character, Event e Stage, ordenadas por custo e depois por `card_number`, com a quantidade de cada uma e o total "N / 50".
8. WHEN o usuário abrir a lista de decks THEN the system SHALL exibir cada deck do usuário com nome, Leader, total "N / 50" e status.
9. WHEN o usuário excluir um deck THEN the system SHALL pedir confirmação antes e, confirmada, remover o deck sem alterar coleção nem wishlist.
10. WHEN o usuário renomear um deck THEN the system SHALL gravar o nome novo mantendo Leader e entradas.

**Independent Test**: Criar um deck, abrir o detalhe de um Leader preto e usá-lo, incrementar quatro cartas pretas pelo detalhe, abrir a página do deck e ver o Leader, as quatro entradas agrupadas por tipo e "N / 50".

### P1: Validar o deck pelas regras ⭐ MVP

**User Story**: Como jogador, quero ver se meu deck cumpre as regras de montagem e o que está errado quando não cumpre, para não chegar à mesa com uma lista ilegal.

**Why P1**: Um deck salvo sem validação é só uma lista; as regras são o que o separa de uma wishlist.

**Acceptance Criteria**:
1. The system SHALL calcular o status do deck a cada leitura, sem persisti-lo, como exatamente um de `válido`, `incompleto` ou `inválido`.
2. The system SHALL classificar o deck como `válido` quando ele tiver um Leader, o deck principal somar exatamente 50 cartas, nenhuma carta não isenta pelo critério 10 passar de 4 cópias e toda carta do deck principal tiver só cores presentes no Leader.
3. The system SHALL classificar o deck como `inválido` quando o deck principal passar de 50 cartas, alguma carta não isenta pelo critério 10 passar de 4 cópias ou, havendo Leader, alguma carta tiver uma cor que o Leader não tem.
4. The system SHALL classificar como `incompleto` o deck que não for `válido` nem `inválido`, isto é, sem Leader ou com menos de 50 cartas e nenhuma violação do critério 3.
5. WHEN o status não for `válido` THEN the system SHALL listar na página do deck cada motivo em português, nomeando as cartas envolvidas (ex.: "OP01-016 tem 5 cópias; o máximo é 4", "Faltam 3 cartas para 50", "OP02-001 é vermelha e o Leader é preto").
6. The system SHALL contar a carta multicolorida como tendo todas as suas cores ao mesmo tempo (Comprehensive Rules 2-3-5).
7. The system SHALL aceitar e salvar entradas que violam as regras, deixando a violação no status, sem nunca recusar a alteração por causa de uma regra do jogo.
8. The system SHALL exibir na página do deck o aviso "A lista de banidas não é verificada".
9. The system SHALL marcar na página do deck a carta ausente da fonte como "fora da fonte", e ela continua contando para as regras.
10. The system SHALL isentar do limite de 4 cópias a carta cujo texto de efeito contém "Under the rules of this game, you may have any number of this card in your deck", derivando a isenção do texto do catálogo e mantendo o limite de 50 do DCK-39.
11. WHEN o texto de efeito do Leader contiver "Under the rules of this game" seguido de "cannot include" ou "can only include" THEN the system SHALL exibir na página do deck o aviso "Este Leader tem regra de montagem própria, não verificada" junto com o texto dessa regra, sem verificá-la e sem mudar o status.

**Independent Test**: Montar decks de fixture com 49, 50 e 51 cartas, com 5 cópias de uma carta, com uma carta de cor fora do Leader e sem Leader; conferir status e motivos de cada um.

### P1: Ver o que falta na pasta para um deck ⭐ MVP

**User Story**: Como jogador, quero ver em cada deck quantas cópias de cada carta eu ainda não tenho, para saber o que comprar ou trocar.

**Why P1**: É o motivo de montar o deck no Bindr, e não em outro app (decisão do dono em 2026-10-01).

**Acceptance Criteria**:
1. The system SHALL considerar como possuídas de uma carta a soma das quantidades de todas as variantes dela na coleção do usuário, presentes ou não na fonte.
2. WHEN o usuário abrir a página de um deck THEN the system SHALL exibir, para o Leader e para cada carta do deck principal, a quantidade pedida, a possuída e a que falta, sendo a que falta `max(0, pedida − possuída)`.
3. WHEN o usuário abrir a página de um deck THEN the system SHALL exibir o total de cópias que faltam somando todas as cartas do deck, ou "Você tem todas as cartas deste deck" quando o total for zero.
4. WHEN a coleção do usuário mudar THEN the system SHALL refletir a mudança no que falta na próxima leitura da página do deck, sem nenhuma sincronização gravada.

**Independent Test**: Com 2 cópias da variante base e 1 da parallel de uma carta, e um deck que pede 4 dela, a página mostra "pedida 4, possuída 3, falta 1".

### P2: Importar e exportar a lista em texto

**User Story**: Como jogador, quero colar uma lista no formato do OPTCG Simulator e exportar meu deck no mesmo formato, para trazer listas prontas e levar as minhas para o simulador.

**Why P2**: Montar carta por carta funciona sozinho (P1); a importação poupa o trabalho de copiar uma lista que já existe.

**Acceptance Criteria**:
1. WHEN o usuário colar uma lista e confirmar a importação THEN the system SHALL criar um deck novo, nunca alterar um existente, com o nome informado ou, sem nome, o nome do Leader importado.
2. The system SHALL ler uma linha por carta no formato `<N>x<card_number>`, aceitando CR, LF e CRLF como fim de linha, ignorando linhas em branco e espaços nas bordas e ao redor do `x`, e comparando `card_number` sem distinção de caixa.
3. WHEN uma linha importada apontar para uma carta Leader THEN the system SHALL usá-la como Leader do deck.
4. WHEN o mesmo `card_number` aparecer em mais de uma linha THEN the system SHALL somar as quantidades numa única entrada.
5. IF alguma linha não seguir o formato, apontar para um `card_number` inexistente no catálogo, tiver quantidade fora de 1 a 50, ou a lista tiver mais de um Leader, um Leader com quantidade diferente de 1, linhas repetidas de uma carta cuja soma passe de 50 (limite do DCK-39) ou nenhuma carta THEN the system SHALL recusar a importação inteira, sem criar deck, e exibir em português cada linha recusada com seu número e motivo.
6. IF o texto colado passar de 200 linhas ou 10.000 caracteres THEN the system SHALL recusar a importação sem processar o texto e informar o limite.
7. WHEN a lista importada for aceita mas violar uma regra de montagem THEN the system SHALL criar o deck e mostrá-lo com o status `inválido` ou `incompleto` (P1: Validar).
8. WHEN o usuário exportar um deck THEN the system SHALL produzir o texto com o Leader como `1x<card_number>` na primeira linha, seguido de uma linha `<N>x<card_number>` por carta do deck principal, na ordem da página do deck, separadas por LF.
9. The system SHALL garantir que importar o texto exportado de um deck produz um deck com o mesmo Leader e as mesmas entradas.

**Independent Test**: Importar o exemplo do dono (15 linhas, separadas por CR, Leader OP17-079), conferir 1 Leader + 50 cartas; exportar e reimportar e comparar os dois decks.

### P2: Ver na pasta o que falta para os decks

**User Story**: Como jogador com vários decks, quero ver na pasta tudo o que me falta para montar qualquer um deles, para fazer uma única lista de compra ou troca.

**Why P2**: Cada deck já mostra o que falta (P1); o agregado só poupa abrir deck por deck.

**Acceptance Criteria**:
1. The system SHALL calcular o que falta de cada carta como `max(0, maior quantidade pedida entre os decks do usuário − possuída)`, contando o Leader como 1.
2. WHEN o usuário abrir a pasta e tiver ao menos uma carta faltando THEN the system SHALL exibir o bloco "Faltando para os baralhos" com cada carta que falta, a quantidade que falta e os decks que a usam, com link para cada um.
3. WHEN o usuário não tiver decks, ou nada faltar THEN the system SHALL omitir o bloco, sem estado vazio.

**Independent Test**: Dois decks pedem 4× e 2× da mesma carta e o usuário tem 1: a pasta mostra "faltam 3" e os dois decks.

## Edge Cases

- IF um usuário tentar ler, alterar, exportar ou excluir um deck de outro usuário THEN the system SHALL responder 404, sem revelar que o deck existe.
- IF um usuário não autenticado tentar acessar qualquer rota de deck THEN the system SHALL redirecionar para a autenticação sem aplicar nenhuma alteração.
- WHEN dois incrementos da mesma carta no mesmo deck chegarem ao mesmo tempo THEN the system SHALL aplicar os dois, sem perder nenhum.
- IF um incremento levar a quantidade de uma carta acima de 50 THEN the system SHALL recusar a operação e manter a quantidade anterior.
- IF o nome do deck estiver vazio ou passar de 60 caracteres THEN the system SHALL recusar a gravação com mensagem em português.
- WHEN a ingestão rodar com decks existentes THEN the system SHALL manter todo Leader e toda entrada de deck intactos, sem delete em cascata a partir de `cards`.
- IF o deck em edição for excluído THEN the system SHALL deixar de exibir os controles de deck no detalhe até outro deck ser escolhido.
- WHEN o deck não tiver Leader THEN the system SHALL omitir a regra de cor do status e dos motivos.

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| DCK-01 | Montar: criar deck vazio (Req. 14.1) | - | Pending |
| DCK-02 | Montar: modelo Leader + entradas sobre `cards` (Req. 14.2) | - | Pending |
| DCK-03 | Montar: controle no detalhe de carta não-Leader (Req. 14.3) | - | Pending |
| DCK-04 | Montar: "Usar como Leader" (Req. 14.4) | - | Pending |
| DCK-05 | Montar: incremento/decremento sem recarregar (Req. 14.5) | - | Pending |
| DCK-06 | Montar: zero remove a entrada (Req. 14.6) | - | Pending |
| DCK-07 | Montar: página do deck agrupada e "N / 50" (Req. 14.7) | - | Pending |
| DCK-08 | Montar: lista de decks (Req. 14.8) | - | Pending |
| DCK-09 | Montar: excluir com confirmação, sem tocar a coleção (Req. 14.9) | - | Pending |
| DCK-10 | Montar: renomear (Req. 14.10) | - | Pending |
| DCK-11 | Validar: status derivado, nunca persistido (Req. 14.11) | - | Pending |
| DCK-12 | Validar: regra de `válido` (Req. 14.12) | - | Pending |
| DCK-13 | Validar: regra de `inválido` (Req. 14.13) | - | Pending |
| DCK-14 | Validar: regra de `incompleto` (Req. 14.14) | - | Pending |
| DCK-15 | Validar: motivos em português (Req. 14.15) | - | Pending |
| DCK-16 | Validar: multicolorida conta todas as cores (Req. 14.16) | - | Pending |
| DCK-17 | Validar: aviso de banidas (Req. 14.17) | - | Pending |
| DCK-18 | Validar: regra do jogo nunca recusa gravação (Req. 14.18) | - | Pending |
| DCK-19 | Validar: carta fora da fonte marcada (Req. 14.19) | - | Pending |
| DCK-20 | Faltando: possuída = soma das variantes (Req. 14.20) | - | Pending |
| DCK-21 | Faltando: pedida/possuída/falta por carta (Req. 14.21) | - | Pending |
| DCK-22 | Faltando: total do deck (Req. 14.22) | - | Pending |
| DCK-23 | Faltando: derivado da coleção atual (Req. 14.23) | - | Pending |
| DCK-24 | Importar: sempre cria deck novo (Req. 14.24) | - | Pending |
| DCK-25 | Importar: formato e fins de linha (Req. 14.25) | - | Pending |
| DCK-26 | Importar: linha Leader vira Leader (Req. 14.26) | - | Pending |
| DCK-27 | Importar: linhas repetidas somam (Req. 14.27) | - | Pending |
| DCK-28 | Importar: tudo ou nada com linhas listadas (Req. 14.28) | - | Pending |
| DCK-29 | Importar: limite de tamanho (Req. 14.29) | - | Pending |
| DCK-30 | Importar: deck fora das regras é criado (Req. 14.30) | - | Pending |
| DCK-31 | Exportar: formato e ordem (Req. 14.31) | - | Pending |
| DCK-32 | Exportar → importar reproduz o deck (Req. 14.32) | - | Pending |
| DCK-33 | Pasta: falta = maior uso − possuída (Req. 14.33) | - | Pending |
| DCK-34 | Pasta: bloco "Faltando para os baralhos" (Req. 14.34) | - | Pending |
| DCK-35 | Pasta: bloco omitido sem falta (Req. 14.35) | - | Pending |
| DCK-36 | Isolamento: deck de outro usuário é 404 (Req. 14.36) | - | Pending |
| DCK-37 | Isolamento: rota de deck exige sessão (Req. 14.37) | - | Pending |
| DCK-38 | Concorrência: incrementos simultâneos (Req. 14.38) | - | Pending |
| DCK-39 | Limites: quantidade até 50 e nome até 60 (Req. 14.39) | - | Pending |
| DCK-40 | Ingestão preserva decks, sem cascata (Req. 14.40) | - | Pending |
| DCK-41 | Deck em edição excluído (Req. 14.41) | - | Pending |
| DCK-42 | Sem Leader, sem regra de cor (Req. 14.42) | - | Pending |
| DCK-43 | Validar: isenção do limite de 4 pelo texto da carta (Req. 14.43) | - | Pending |
| DCK-44 | Validar: aviso de regra própria do Leader (Req. 14.44) | - | Pending |

**Coverage:** 44 total, 0 mapped to tasks, 44 unmapped ⚠️ (plano ainda não existe)

## Implicit-Requirement Dimensions

| Dimension | Resolution |
|---|---|
| Input validation & bounds | DCK-25, DCK-28, DCK-29, DCK-39 |
| Failure / partial-failure states | DCK-28 (importação tudo ou nada) |
| Idempotency / retry / duplicate handling | DCK-02 (uma entrada por carta no banco), DCK-27 (linhas repetidas), DCK-24 (reimportar cria outro deck, nunca duplica entradas) |
| Auth boundaries & rate limits | DCK-36, DCK-37. Rate limit N/A: deck não abre superfície nova de abuso num app de uso pessoal, e a dívida de rate limit do login não muda aqui |
| Concurrency / ordering | DCK-38 |
| Data lifecycle / expiry | DCK-09 (exclusão confirmada, sem tocar coleção), DCK-40 (ingestão), DCK-19 (carta fora da fonte) |
| Observability | N/A: não há processo assíncrono nem chamada externa nova; o erro de importação vai para o usuário (DCK-28) |
| External-dependency failure | N/A: nenhuma dependência externa nova; o catálogo é local |
| State-transition integrity | DCK-11 a DCK-14: o status é função das entradas, não um estado gravado com transições |

## Success Criteria

- [ ] O exemplo de lista do dono (OP17-079 + 50) importa num deck `válido`, e exportar e reimportar dá o mesmo deck.
- [ ] Um deck montado só pelo detalhe da carta chega a `válido` a 360px, sem scroll horizontal (Req. 2.5).
- [ ] Existe teste que prova que um usuário não lê nem altera o deck de outro.
- [ ] Existe teste que prova que `UNIQUE (deck_id, card_id)` e o limite de quantidade são do banco, não só da aplicação.
- [ ] A ingestão roda duas vezes com decks povoados e nenhum Leader ou entrada muda (extensão da task 2.6).
- [x] As regras de cor e de cópias foram confirmadas nas Comprehensive Rules antes do código que as implementa (T1, 2026-10-02).
- [ ] `bin/rails test && bin/rubocop` limpos; `bin/brakeman` sem aviso novo.
