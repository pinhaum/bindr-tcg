# Especificação — Progresso por set (Fase 5)

Recorte da feature `progresso` sobre `.context/requirements.md` Req. 9 e
`.context/tasks.md` §5.1. Em divergência, `.context/` vence (AD-005).

A feature é governada por **AD-003**: "set completo" usa as variantes base como
denominador, e parallels contam em métrica separada, nunca somados ao
percentual.

## Problem Statement

A coleção existe e é registrável por variante, mas o sistema só responde
"quantas cópias eu tenho no total" (Req. 7.7). Não responde "quanto falta para
eu fechar OP01", que é a pergunta que decide o que o colecionador vai caçar na
próxima compra. Hoje isso só se descobre navegando o catálogo set a set e
contando à mão — exatamente a planilha que `product.md` §7 existe para
substituir.

Esta feature entrega a agregação por set em cima do dado que já existe: nenhuma
tabela nova, nenhuma escrita, nenhuma alteração no modelo da coleção. O risco
desta feature não é perder dado, é **exibir um número errado** — um percentual
com o denominador errado é pior que percentual nenhum, porque o usuário toma
decisão de compra com base nele.

## Goals

- [ ] Para cada set: variantes base distintas possuídas, total de base do set e percentual de conclusão.
- [ ] Contagem de parallels possuídos como métrica separada, nunca somada ao percentual.
- [ ] Navegação de cada set para o catálogo já filtrado por aquele set.
- [ ] A contagem conta variantes distintas, nunca cópias — distinta do total do Req. 7.7.
- [ ] Set sem denominador conhecido aparece sem percentual, em vez de sumir ou exibir número inventado.
- [ ] A página inteira resolve em número fixo de consultas, independente da quantidade de sets.

## Out of Scope

| Feature | Reason |
|---|---|
| Export CSV (Req. 10.1) | `.context/tasks.md` §5.2. Feature `portabilidade`, spec própria. |
| Import CSV (Req. 10.2–10.5) | `.context/tasks.md` §5.3. Escrita em massa sobre o dado insubstituível do usuário; merece spec inteira só dela, com pré-visualização e confirmação. |
| Progresso da wishlist por set | Nenhum critério do Req. 9 o pede. A wishlist tem quantidade-alvo, não denominador de set — é outra pergunta. |
| Progresso por raridade, por cor ou por tipo de carta | Req. 9 recorta por set e só por set. Outros recortes são feature nova, não detalhe deste. |
| Correção da classificação de `art_kind` na ingestão | A divergência medida (21 de 62 sets) é defeito do subsistema de ingestão, não do de progresso. Corrigir aqui misturaria leitura com ingestão e violaria a separação que é o eixo do `design.md`. Registrado como achado; a decisão é do dono do produto. |
| Criação ou alteração de índice | Só entra se a medição com dado realista reprovar o alvo de desempenho. Precedente da T10 da `colecao`: medir antes, criar depois, e apenas se necessário. |
| Barra de progresso animada, gráfico ou visualização comparativa | Req. 9 pede o número e o percentual. Ornamento sem requisito. |
| Histórico de evolução do progresso ao longo do tempo | Exigiria persistir snapshots; nenhum critério do Req. 9 o pede. |

## Assumptions & Open Questions

| Assumption/decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| Existência do denominador no schema | Usar as colunas `sets.base_set_size` e `sets.total_set_size`, que **já existem e estão populadas**. Nenhuma migração nesta feature | Verificado em `db/structure.sql:278-279`. Medido: 62 dos 63 sets têm `base_set_size`; 62 dos 63 têm `total_set_size` | Sim — schema e banco |
| **Fonte do denominador do Req. 9.5** | **`sets.base_set_size`** (campo da fonte externa), **não** a contagem local de `card_variants.art_kind = 'base'` | As duas **já divergem hoje**, em **21 dos 62 sets** — não é risco futuro, é estado atual. A contagem local seria catastrófica em dois casos medidos: `FamilyDeckSet` daria denominador **0** (49 variantes classificadas `other`, nenhuma `base`) — divisão por zero e set invisível; `PRB01` daria **1** em vez de 113, exibindo 100% para quem possui uma única carta de 113. A causa é a ingestão classificar como `other` reimpressões que a fonte conta como base. `base_set_size` é ainda o que AD-003 e o Req. 9.5 nomeiam literalmente (`baseSetSize` da fonte) | Sim — medido, ver Edge Cases |
| **Numerador correspondente ao denominador escolhido** | Contar as variantes possuídas com `art_kind IN ('base','other')`, não apenas `'base'` | Numerador e denominador precisam contar o mesmo universo, senão o percentual é aritmeticamente incoerente. Medido: `base_set_size` bate com `count(art_kind IN ('base','other'))` em **61 de 62 sets** (única exceção: ST16, 7 contra 6), contra 41 de 62 se o numerador fosse só `'base'`. Com numerador só `'base'`, `FamilyDeckSet` exibiria 0/49 para quem possui o set inteiro | Sim — medido |
| **Tratamento de `art_kind = 'other'`** | `other` entra no **numerador e no denominador do percentual principal**, junto com `base`. **Não** entra na métrica separada de parallels | Decorre da decisão anterior: `other` são majoritariamente reimpressões que a fonte conta dentro de `baseSetSize` (medido: 49 de 49 em `FamilyDeckSet`, 112 de 113 em `PRB01`). Tratá-lo como terceira métrica separaria numerador de denominador e reintroduziria o erro que AD-003 existe para evitar. A métrica separada do Req. 9.6 permanece **exclusivamente** `art_kind = 'parallel'`, como o requisito diz literalmente | Sim — medido |
| Métrica separada do Req. 9.6 | Parallels possuídos exibidos como contagem absoluta (possuídos e total do set), sem percentual próprio | O Req. 9.6 pede "a contagem de parallels possuídos", não um segundo percentual. Um percentual de parallels exigiria um `parallelSetSize` que a fonte não fornece — seria derivado de `art_kind`, que é justamente a classificação cuja confiabilidade esta spec acaba de medir como divergente | Sim |
| **Denominador ausente (`PRB9cd8`)** | O set **é exibido**, com a contagem de possuídas e o total real de variantes, e **sem percentual** — apresentado como indisponível, nunca como `0%` nem como `100%` | Omitir o set esconderia posse real do usuário (ele pode ter as 3 cartas). Exibir `0%` é falso e desmotiva; exibir `100%` é falso e mente sobre completude. Medido: um único set, `PRB9cd8`, nome `"X"`, 3 variantes, `card_number` sintético (`PR-db8f29`) — um registro-lixo da fonte externa, não um set de verdade. Tratá-lo como dado ausente é o que a ausência de fato significa | Sim — medido |
| **Autorização da página** | **Exige sessão.** Sem `allow_unauthenticated_access`, herdando o default de `ApplicationController` | Diferente do catálogo, a página não tem conteúdo público: sem usuário, todo numerador é zero e a página inteira é uma lista de zeros — um 200 sem informação. Exigir sessão também evita, por construção, a armadilha que apareceu cinco vezes na `colecao`: em controller público `allow_unauthenticated_access` remove o `before_action` que resolvia a sessão, e ler `Current.user` sem chamar `authenticated?` responde 200 com tudo zerado, em silêncio. Aqui o `before_action :require_authentication` resolve a sessão antes da action, e o defeito não tem como existir | Sim — `app/controllers/concerns/authentication.rb:20` |
| Origem do usuário | `Current.user`, via `CollectionItem.for_user(user)`; nenhum identificador de usuário é lido do request | Req. 6.5 por construção. `for_user` exige o objeto `User` e levanta `ArgumentError` para um id — barreira desenhada na T5 da `colecao` | Sim — `app/models/collection_item.rb` |
| Zero é não-posse | O numerador parte de `CollectionItem.owned` (`quantity >= 1`); linha com `quantity = 0` não conta | Req. 7.3: zero é linha existente que significa "não tenho". O scope `owned` já é a definição vigente no projeto | Sim — `app/models/collection_item.rb` |
| Distinção entre as duas métricas de coleção | Progresso conta **variantes distintas** (`count`); o total do Req. 7.7 soma **cópias** (`sum(:quantity)`). São perguntas diferentes e coexistem | Req. 9.4 diz "contar variantes distintas, não cópias"; Req. 7.7 diz "contando cópias". Confundi-las produz dois números errados de uma vez. `CollectionItem.total_copies_for` já documenta essa fronteira | Sim — `app/models/collection_item.rb` |
| **Link para o catálogo filtrado (Req. 9.3)** | `catalog_path(sets: [ code ])`, usando o **código** do set | Contrato real verificado: `CatalogQuery::VARIANT_FILTERS` mapeia `sets` para a coluna `code` e resolve por `joins(:card_set).where(sets: { code: values })` (`app/queries/catalog_query.rb`). Parâmetro já exercido em `test/queries/catalog_query_test.rb:75`. Nenhum parâmetro novo é inventado | Sim — código e teste |
| Escopo do denominador: set de estreia vs. set da impressão | O progresso agrega por `card_variants.set_id` (o set **da impressão**), nunca por `cards.set_id` | É a mesma razão que `VARIANT_FILTERS` documenta: uma carta pode ter variantes em sets diferentes do seu set de estreia. Agregar por `cards.set_id` contaria a reimpressão no set errado | Sim — `app/queries/catalog_query.rb` |
| Forma da consulta | Agregação por set em número **fixo** de consultas, independente da quantidade de sets. A spec não escolhe a consulta; fixa o alvo | Um `count` por set é N+1: medido, 63 consultas custam ~213ms contra ~8ms de uma agregação única — ambos com a coleção vazia, logo o número mede **estrutura**, não seletividade. A medição com dado realista é da fase de verificação, seguindo o precedente da T10 | Sim — medido, ver Success Criteria |
| Verificação de comportamento visual | Teste de integração sobre HTML renderizado, com `SPEC_DEVIATION` registrado no cabeçalho do arquivo de teste | Não há navegador no container, logo não há system test. É o precedente já estabelecido em `test/integration/collection_ownership_ui_test.rb` | Sim — `CLAUDE.md` e validation.md da `colecao` |

**Open questions:** none — todas as decisões de design desta feature estão
resolvidas e registradas na tabela acima.

Resta um item que **não é questão de design e não se resolve nesta spec**: o
Req. 9.5 de `.context/requirements.md` diverge do banco medido, e corrigi-lo é
decisão do dono do produto (AD-005). A seção seguinte documenta a medição e a
escolha que esta spec fez para permanecer correta enquanto essa decisão não é
tomada.

## Conflito com `.context/requirements.md` — decisão do dono do produto

O Req. 9.5 diz que o denominador são as **variantes base** do set, e apõe a essa
frase a definição `baseSetSize` da fonte, tratando as duas como sinônimas. **No
banco real elas não são sinônimas.**

Medido no banco de desenvolvimento (63 sets, 4917 variantes, 2818 cartas):

| Comparação | Divergências |
|---|---|
| `base_set_size` vs. `count(art_kind = 'base')` | **21 de 62 sets** |
| `base_set_size` vs. `count(art_kind IN ('base','other'))` | **1 de 62 sets** (ST16: 7 contra 6) |

Casos extremos medidos:

- `FamilyDeckSet`: `base_set_size = 49`, `count(art_kind = 'base') = 0` — as 49 variantes estão classificadas como `other`.
- `PRB01`: `base_set_size = 113`, `count(art_kind = 'base') = 1`, `other = 112`.
- `ST15` e mais 17 starter decks: `base_set_size` entre 7 e 14, `count(base) = 5` em todos.

Esta spec resolve o conflito **preservando o Req. 9.5 na sua leitura literal**
(`baseSetSize` da fonte é o denominador) e ajustando o numerador para contar o
mesmo universo. Essa escolha mantém o requisito verdadeiro e entrega números
corretos hoje.

O que **não** está decidido, e não me cabe decidir:

**Se a leitura pretendida do Req. 9.5 era "variantes cujo `art_kind` é `base`",
então o requisito está factualmente errado e `.context/requirements.md` precisa
ser corrigido antes da fase de tasks** (AD-005: `.context/` é a fonte de
verdade, e corrigi-lo é decisão do dono do produto, não improviso na spec da
feature). A alternativa — manter o texto e corrigir a classificação de
`art_kind` na ingestão — é escopo de outra feature, listado em Out of Scope.

## User Stories

### P1: Progresso de conclusão por set ⭐ MVP

**User Story**: Como colecionador, quero ver quanto de cada set eu completei, para decidir o que caçar.

**Why P1**: É o Req. 9 inteiro em uma frase, e a razão de a feature existir. As demais histórias são navegação e recorte sobre este número.

**Acceptance Criteria**:
1. The system SHALL exibir, para cada set, a quantidade de variantes distintas possuídas pelo usuário da sessão e o total de variantes daquele set.
2. The system SHALL exibir o percentual de conclusão de cada set, calculado sobre as variantes base do set conforme AD-003.
3. The system SHALL contar variantes distintas, nunca cópias: uma variante com quantidade 5 conta exatamente 1.
4. WHEN uma variante tiver quantidade zero THEN the system SHALL tratá-la como não possuída no numerador do progresso.
5. The system SHALL usar como denominador do percentual o valor de `base_set_size` do set, e nunca o total de impressões do set.
6. The system SHALL contar no numerador do percentual as variantes possuídas do mesmo universo do denominador, excluindo as de tipo `parallel`.
7. IF um set não tiver `base_set_size` conhecido THEN the system SHALL exibir o set com sua contagem de possuídas e indicar o percentual como indisponível, sem omitir o set e sem apresentar zero ou cem por cento.

**Independent Test**: Autenticado, com posse registrada em variantes de dois sets distintos e uma variante zerada, abrir a página de progresso e conferir numerador, denominador e percentual de cada set; conferir que a variante zerada não entra; conferir que `PRB9cd8` aparece sem percentual.

### P1: Parallels como métrica separada ⭐ MVP

**User Story**: Como colecionador, quero ver quantos parallels eu tenho de cada set sem que isso afete o percentual de conclusão, para que sets dominados por parallels não fiquem travados perto de zero.

**Why P1**: É metade de AD-003 e o Req. 9.6 é explícito ("nunca somada ao percentual"). Sem esta história, o número principal volta a ser o que a decisão descartou.

**Acceptance Criteria**:
1. The system SHALL exibir, para cada set, a contagem de variantes de tipo `parallel` possuídas pelo usuário da sessão.
2. The system SHALL apresentar essa contagem como métrica separada, nunca somada ao numerador nem ao denominador do percentual de conclusão.
3. WHEN o usuário possuir parallels de um set THEN the system SHALL manter o percentual de conclusão daquele set inalterado por essa posse.
4. WHERE um set não tiver nenhuma variante de tipo `parallel`, the system SHALL apresentar a métrica como zero, sem ocultá-la nem tratá-la como erro.

**Independent Test**: Registrar posse apenas de parallels em um set, conferir que o percentual de conclusão continua zero e que a contagem de parallels reflete a posse; acrescentar uma variante base e conferir que só o percentual muda.

### P2: Navegação do set para o catálogo filtrado

**User Story**: Como colecionador, quero ir de um set direto para o catálogo já filtrado por aquele set, para ver quais cartas me faltam sem refazer o filtro à mão.

**Why P2**: Req. 9.3. É navegação sobre dado já entregue pelas histórias P1: o progresso é legível e correto sem ela.

**Acceptance Criteria**:
1. The system SHALL oferecer, para cada set exibido, um link que leva ao catálogo filtrado por aquele set.
2. The system SHALL montar esse link com o parâmetro `sets` do contrato de `design.md` §4.2, usando o código do set.
3. WHEN o usuário seguir esse link THEN the system SHALL apresentar no catálogo apenas cartas com variantes daquele set, pela semântica de filtro já vigente.

**Independent Test**: Seguir o link de um set conhecido e conferir que o catálogo responde 200 com o filtro ativo e que o conjunto retornado corresponde ao set.

### P2: Isolamento e desempenho da agregação

**User Story**: Como usuário, quero que meu progresso seja calculado só a partir da minha coleção e que a página abra rápido mesmo com o catálogo completo, para poder consultá-la no celular durante uma compra.

**Why P2**: Não acrescenta informação nova ao usuário, mas é o que torna as histórias P1 corretas e utilizáveis. Uma falha de isolamento aqui é vazamento, não usabilidade.

**Acceptance Criteria**:
1. The system SHALL derivar todo o cálculo de progresso do usuário da sessão corrente.
2. IF uma requisição informar um identificador de usuário THEN the system SHALL ignorá-lo e usar o usuário da sessão.
3. WHEN um usuário não autenticado acessar a página de progresso THEN the system SHALL redirecionar para a autenticação sem exibir dado de coleção.
4. WHILE dois usuários possuírem variantes do mesmo set, the system SHALL apresentar a cada um apenas o seu próprio progresso.
5. The system SHALL resolver a página em um número de consultas que não cresce com a quantidade de sets do catálogo.
6. The system SHALL apresentar a página em viewport de 360px sem scroll horizontal, conforme Req. 2.5.

**Independent Test**: Criar dois usuários com posse em um mesmo set e conferir que cada um vê apenas o seu número; contar as consultas emitidas pela requisição e verificar que não variam com a quantidade de sets; acessar anônimo e conferir o redirecionamento.

## Edge Cases

- WHEN o usuário autenticado não tiver nenhuma posse registrada, THEN todos os sets aparecem com numerador zero e percentual zero — a página é informativa, não vazia.
- IF um set não tiver `base_set_size`, THEN ele é exibido com contagem de possuídas e percentual indisponível. Medido: exatamente um caso, `PRB9cd8` (nome `"X"`, 3 variantes, `card_number` sintético `PR-db8f29`), um registro-lixo da fonte externa.
- IF o denominador de um set for zero, THEN nenhuma divisão é executada e o percentual é apresentado como indisponível, pelo mesmo caminho do denominador ausente — a implementação nunca divide por zero.
- WHEN a posse de uma variante for zerada, THEN o numerador daquele set diminui, porque `owned` filtra por quantidade e não por existência do registro (Req. 7.3).
- WHEN o numerador de um set exceder o denominador, THEN o percentual é apresentado limitado a cem por cento, sem erro. Isso é alcançável hoje: medido, ST16 tem `base_set_size = 7` e 6 variantes não-parallel, mas a divergência de classificação pode inverter o sinal em outro set após uma reingestão.
- IF a ingestão rodar entre duas visitas à página, THEN o denominador pode mudar sem que o usuário tenha alterado nada — o catálogo é regenerável e o denominador vem dele; nenhuma posse é afetada (Req. 1.7, AD-001).
- WHEN uma variante possuída pertencer a um set diferente do set de estreia da carta, THEN ela conta no set da impressão, nunca no set de estreia.
- IF uma variante referenciada pela coleção for marcada como ausente da fonte, THEN ela continua contando no progresso — a ingestão não deleta (Req. 1.7).
- WHEN a sessão expirar e o usuário recarregar a página, THEN ele é levado à autenticação e retorna à página de progresso depois, sem exibir dado parcial.

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| PRG-01 | Possuídas e total por set (Req. 9.1) | 5 | Pending |
| PRG-02 | Percentual de conclusão por set (Req. 9.2) | 5 | Pending |
| PRG-03 | Link para o catálogo filtrado por set (Req. 9.3) | 5 | Pending |
| PRG-04 | Contar variantes distintas, não cópias (Req. 9.4) | 5 | Pending |
| PRG-05 | Denominador = variantes base do set (Req. 9.5, AD-003) | 5 | Pending |
| PRG-06 | Parallels como métrica separada (Req. 9.6, AD-003) | 5 | Pending |
| PRG-07 | Quantidade zero não conta como posse (Req. 7.3) | 5 | Pending |
| PRG-08 | Progresso parte do usuário da sessão (Req. 6.5) | 5 | Pending |
| PRG-09 | Página exige sessão (Req. 6.4) | 5 | Pending |
| PRG-10 | Percentual indisponível sem denominador conhecido | 5 | Pending |
| PRG-11 | Número de consultas não cresce com a quantidade de sets (Req. 11.1) | 5 | Pending |
| PRG-12 | Viewport de 360px sem scroll horizontal (Req. 2.5) | 5 | Pending |

**Coverage:** 12 total, 0 mapped to tasks, 12 unmapped ⚠️ (tasks.md ainda não escrito — próxima fase, após revisão desta spec)

## Success Criteria

- [ ] Um colecionador abre a página, vê quanto falta para fechar cada set e vai direto ao catálogo filtrado do set que escolheu caçar.
- [ ] Existe teste que prova que uma variante com quantidade 5 conta 1 no progresso e 5 no total do Req. 7.7 — as duas métricas medidas lado a lado no mesmo cenário.
- [ ] Existe teste que prova que uma variante com quantidade zero não entra no numerador.
- [ ] Existe teste que prova que posse de parallel não altera o percentual de conclusão do set.
- [ ] Existe teste que prova que um set sem `base_set_size` é exibido sem percentual, e que nenhuma divisão por zero ocorre.
- [ ] Existe teste que prova que dois usuários com posse no mesmo set veem números diferentes e apenas o próprio.
- [ ] A página anônima redireciona para autenticação, sem 200 com zeros.
- [ ] O número de consultas da requisição é medido e não varia com a quantidade de sets do catálogo; a medição de tempo é feita com coleção povoada e registrada, seguindo o precedente da T10 da `colecao`.
- [ ] `bin/rails test` passa inteiro, sem alteração de asserção existente.
- [ ] `bin/rubocop` limpo.
