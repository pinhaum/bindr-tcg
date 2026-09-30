# Troca da fonte do catálogo para a apitcg — Specification

Recorte da feature `fonte-apitcg` sobre `.context/requirements.md` Req. 1, 9 e 11.
Em divergência, `.context/` vence (AD-005). Esta feature **reabre a AD-001** e a
substitui por uma AD nova no `STATE.md`.

## Problem Statement

A optcgjson (AD-001) não informa data de lançamento: os 62 sets da revisão fixada
têm `releaseDate: null`, e por isso a ordem padrão "mais recentes" do Req. 2.4
degenera em ordem por `card_number`. Ela também não cobre os sets mais novos com
a mesma amplitude (4.915 variantes contra 7.247 produtos na apitcg) e não traz
preço, que a Fase 3 vai precisar.

A apitcg (`GET /api/one-piece/cards`, `GET /api/one-piece/sets`, header
`x-api-key`) resolve os três pontos, mas custa o que a AD-001 protegia: não há
`id` de variante no formato `OP01-001_p1`, o tipo de arte só aparece como sufixo
do nome, os dados da carta divergem entre impressões e não existe `baseSetSize`.
Trocar a fonte também não pode custar um único registro de coleção: as variantes
da optcgjson não casam uma a uma com as da apitcg, e os `collection_items` e
`wishlist_items` apontam para variantes.

## Goals

- [ ] O catálogo passa a ser carregado só da apitcg, e os 85 sets com carta vêm com `released_on` preenchido (SRC-01..SRC-14).
- [ ] A ordem padrão "mais recentes" (Req. 2.4) abre a grade pelos sets lançados por último, sem código novo no catálogo (SRC-15).
- [ ] Nenhum `collection_item` nem `wishlist_item` é apagado ou tem a quantidade alterada pela troca (SRC-16..SRC-18).
- [ ] Cada item de coleção e de wishlist com exatamente um candidato na fonte nova passa a apontar para a variante nova; os demais aparecem num relatório (SRC-19..SRC-23).
- [ ] O progresso por set (Req. 9) continua com denominador conhecido nos sets da fonte nova e nunca passa de 100% (SRC-24..SRC-28).
- [ ] A ingestão continua testável sem rede, a partir de um recorte versionado do snapshot (SRC-29..SRC-30).

## Out of Scope

| Feature | Reason |
|---|---|
| Persistir e exibir preço | Fase 3. O preço fica no snapshot bruto, que já é salvo em disco; nada de coluna nem tela nesta feature. |
| Fonte híbrida (optcgjson para cartas, apitcg para datas) | Decisão do dono em 2026-09-29: troca completa. |
| Tabela manual com o tamanho oficial dos sets de reimpressão | Decisão do dono em 2026-09-29: derivar pela regra de SRC-24 e marcar a divergência `⚠️ VERIFICAR`. |
| Nome curto do set (pendência D12) | Continua pendente. A apitcg traz nomes como "Starter Deck 31: RED Monkey.D.Luffy"; encurtar é regra própria, com teste próprio. |
| Remover do banco as variantes e sets da optcgjson | A ingestão não tem delete (Req. 1.7). Eles ficam marcados como ausentes da fonte. |
| Converter CSVs exportados antes da troca | O import continua resolvendo pelo par `card_number` + `variant_code` (Req. 10); um CSV antigo casa com as variantes antigas, que continuam no banco. |
| Agendamento automático da ingestão | Nenhum requisito pede; a ingestão segue sob demanda (Req. 1.1). |
| Classificar `art_kind` a partir de algo além do sufixo do nome | A fonte não tem outro campo para isso. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| Identidade da variante | `variant_code = "tcgplayer:<markets.tcgplayer.id>"`; sem esse id, `"apitcg:<_id>"` | Medido no snapshot de 2026-09-29: os 7.247 produtos têm `tcgplayer.id`, todos distintos. O `_id` da apitcg é contador interno, só reserva | Sim — dono, 2026-09-29 |
| Estabilidade do `tcgplayer.id` entre buscas | `⚠️ VERIFICAR`: comparar dois snapshots separados no tempo antes de fechar a feature (SRC-31) | Um único snapshot não prova estabilidade. Se o id mudar, a idempotência (Req. 1.4) quebra e o usuário perde o vínculo com a coleção | Sim — dono |
| Impressão que define os dados da carta | A impressão com `art_kind = base` no set de estreia (código do set igual ao prefixo do `card_number`); sem ela, a impressão do set com `released_on` mais recente; empate resolvido pelo menor `variant_code` | O mesmo `OP01-016` vem com `Counterplus` 2000 e 1000 em impressões diferentes (errata). Uma regra determinística é o que mantém a ingestão idempotente | Sim — dono |
| Limpeza do efeito | Remover tags HTML, converter `<br>` em quebra de linha, remover disclaimers e links de errata | O Req. 5.4 exige o texto preservando quebras de linha; HTML cru vazaria na página | Sim — dono |
| `trigger_text` | Trecho após `[Trigger]` em `Description`; o efeito não repete esse trecho | Medido: 1.205 cartas trazem `[Trigger]` dentro de `Description`. O formato exato do separador é `⚠️ VERIFICAR` sobre a fixture | Sim — dono |
| `block_icon` | NULL para toda carta da fonte nova; a coluna continua existindo | A apitcg não traz esse dado. Inventá-lo seria pior que ausência | Sim — dono |
| `art_kind` | Pelo último sufixo entre parênteses do nome: `Parallel` → `parallel`; `Alternate Art` → `alternate_art`; `Manga` → `manga`; set de promoção → `promo`; sufixo numérico (`(054)`) ou igual a um `card_number` (`(OP01-016)`) → `base`; sem sufixo → `base`; qualquer outro → `other` | Medido: 3.569 produtos sem sufixo; `Alternate Art` 517, `Reprint` 254, `Parallel` 178, `SP` 139, e dezenas de sufixos de evento. Os sufixos numéricos só desambiguam o nome e não são arte diferente | Sim — dono |
| Raridade | Texto livre; o valor novo `PR` entra sem migração | A fonte tem `C UC R SR PR L SEC TR DON!!`. Rarity continua texto (design) | Sim — dono |
| O que entra no catálogo | Todo produto `type=card` com `code` preenchido e `CardType` diferente de `DON!!` | Medido: 240 `DON!!` marcados por `CardType` (P7); 5 produtos sem `code` além dos `DON!!` (líderes promocionais) vão para o `error_log` como descarte, sem virar falha: senão nenhuma execução terminaria `succeeded`, e a presença e o remapeamento dependem dela | Sim — dono |
| Código do set | `set.code` da apitcg sem o hífen entre letras e dígitos, e com espaço trocado por hífen (`ST-01` → `ST01`, `OP07 PRE` → `OP07-PRE`, `OP15-EB04` fica igual). Com `code` nulo, o prefixo de `card_number` que tiver maioria estrita entre as cartas do set, se nenhum outro set já usar esse código; senão o `_id` da apitcg sem o prefixo `one-piece-` | Medido: 14 dos 85 sets vêm com `code` nulo, entre eles OP16, OP17 e ST30–ST36. A maioria estrita dá OP16, OP17, OP18, EB05 e ST30–ST36; nos release events e no "Set Sail Deck Set" o código colide ou não há maioria, e o slug é o único identificador estável | Sim — dono, 2026-09-29 |
| `baseSetSize` derivado | Números de carta distintos do set cujo prefixo é o próprio código do set, quando eles são **maioria estrita** entre os números distintos do set; senão, todos os números distintos do set | Medido contra a optcgjson nos 48 sets comuns: 36 batem. Os 12 que divergem são reimpressões (PRB01, ST15–ST28), onde contar só o prefixo daria valores absurdos (PRB01 = 1 contra 113). Nestes 12 o valor fica `⚠️ VERIFICAR` contra as listas oficiais | Sim — dono, 2026-09-29 |
| Unidade do progresso | O progresso passa a contar **números de carta distintos**, não variantes distintas | Na apitcg, um mesmo número tem mais de uma impressão não-parallel no mesmo set (OP01: 6 números com `Box Topper` além da base). Contar variantes com denominador em números passaria de 100% | Sim — dono, 2026-09-29 |
| Presença na fonte | Uma variante está presente quando foi vista na última execução da ingestão com status `succeeded`; uma carta ou set está presente quando tem ao menos uma variante presente | É o `last_seen_at` que a ingestão já grava (Req. 1.7), sem coluna nova | Sim — dono, 2026-09-29 |
| Variantes ausentes no catálogo | Grade, busca, filtros, lista de sets e progresso consideram só o que está presente. Na página de detalhe, a variante ausente aparece só para o usuário que a tem na coleção ou na wishlist, marcada como "fora da fonte" | Sem isso a grade mostraria cada carta com as impressões das duas fontes somadas (OP01-016 com 9 + 12). Mostrar a ausente ao dono dela mantém o dado do usuário visível | Sim — dono, 2026-09-29 |
| Remapeamento da coleção | Promovido de P2 para **P1**. Um item migra quando há exatamente uma variante presente com o mesmo `card_number`, a mesma **classe de arte** e o mesmo código de set. Classe de arte: `base` casa só com `base`; qualquer `art_kind` diferente de `base` casa com qualquer `art_kind` diferente de `base`. Zero ou mais de um candidato: o item fica onde está e entra no relatório | Com as ausentes fora do catálogo, um item não remapeado some da grade e do progresso. O `art_kind` não é comparável entre as fontes: a optcgjson só produziu `base`, `parallel` (`isParallel`) e `other`, e o `parallel` dela cobre o que a apitcg separa em `Parallel` e `Alternate Art`; casar o valor literal migraria itens para a impressão errada sem relatório | Sim — dono, 2026-09-29; classe de arte, dono, 2026-09-30 |
| Colisão no remapeamento | Se dois itens do mesmo usuário apontarem para a mesma variante nova, ou se o usuário já tiver um item nela, nenhum migra e todos entram no relatório | Somar quantidades seria escrever um número que o usuário nunca registrou | Sim — dono, 2026-09-29 |
| Execução do remapeamento | Ato explícito (`ingestion:remap`), idempotente, depois de uma ingestão `succeeded` | O remapeamento escreve sobre dado insubstituível; não deve ser efeito colateral da ingestão | Sim — dono, 2026-09-29 |
| Identificação do snapshot | Cada busca grava `storage/ingestion/apitcg-<UTC>.json`; o `import_runs.source_revision` guarda o nome do arquivo e o SHA-256 dele. `SNAPSHOT=<arquivo>` reprocessa um snapshot existente sem rede | A apitcg não tem revisão imutável. O snapshot em disco cumpre o papel que a revisão fixada cumpria (Req. 1.9–1.11), que precisam ser reescritos | Sim — dono (decisão 7) |
| Paginação e falhas de rede | 100 produtos por requisição, timeout de 30s por requisição, até 3 tentativas por página com espera crescente | Medido em 2026-09-29: ~73 páginas, ~10s cada; uma página pendurou por minutos sem timeout e outra falhou. Os valores 30s e 3 são escolhidos, não derivados | Sim — dono, 2026-09-29 |
| Limite de requisições da apitcg | `⚠️ VERIFICAR`; a ingestão não paraleliza páginas | A documentação consultada não informa o limite | Sim — dono |
| Chave da API | `APITCG_API_KEY` no ambiente; nunca em log, nunca no snapshot, nunca em `error_log` | O `.env` já está no `.gitignore` | Sim — dono |
| Host de imagem | `CardImageCache::ALLOWED_HOST` passa a ser `tcgplayer-cdn.tcgplayer.com`; `image_url` usa a imagem `large` | As imagens da apitcg vêm todas desse host (medido); a restrição de host contra SSRF (AD-012) continua | Sim — dono (decisão 8) |
| Cache de imagens antigo | Continua em disco, indexado pelo `variant_code` antigo; nada é apagado | O cache é regenerável e a variante antiga continua existindo | Não — padrão do agente; não apresentado ao dono no aceite de 2026-09-29 |

**Open questions:** none. Os padrões do agente foram aceitos pelo dono em
2026-09-29, junto com duas emendas vindas do mapeamento do código: colisão com
item já existente na variante nova (SRC-21) e produto sem `code` como descarte
registrado, fora de `failed_count` (SRC-11).

---

## User Stories

### P1: Ingestão a partir da apitcg ⭐ MVP

**User Story**: Como mantenedor, quero carregar o catálogo da apitcg para ter as datas de lançamento e os sets mais novos.

**Why P1**: É a troca em si.

**Acceptance Criteria**:

1. WHEN o mantenedor executa `ingestion:import` THEN the system SHALL buscar todas as páginas de `GET /api/one-piece/cards` e `GET /api/one-piece/sets` com o header `x-api-key` lido de `APITCG_API_KEY`. <!-- SRC-01 -->
2. IF `APITCG_API_KEY` estiver ausente ou vazia THEN the system SHALL abortar antes de qualquer requisição, com a mensagem "APITCG_API_KEY não configurada", sem escrever no banco. <!-- SRC-02 -->
3. WHEN todas as páginas forem recebidas THEN the system SHALL gravar o payload bruto em `storage/ingestion/apitcg-<UTC>.json` antes de normalizar qualquer registro. <!-- SRC-03 -->
4. IF uma requisição não responder em 30s ou responder com status diferente de 2xx THEN the system SHALL repeti-la até 3 tentativas no total, e SE a terceira falhar ENTÃO SHALL encerrar a execução com status `failed` sem ter gravado nenhuma carta, variante ou set. <!-- SRC-04 -->
5. The system SHALL nunca escrever o valor de `APITCG_API_KEY` no snapshot, no `error_log`, na saída do rake ou em log. <!-- SRC-05 -->
6. WHEN a ingestão terminar THEN the system SHALL registrar em `import_runs.source_revision` o nome do arquivo do snapshot e o SHA-256 do conteúdo. <!-- SRC-06 -->
7. WHEN o mantenedor executa `ingestion:import SNAPSHOT=<arquivo>` THEN the system SHALL processar esse snapshot sem nenhuma requisição de rede. <!-- SRC-07 -->
8. WHEN o mesmo snapshot é processado duas vezes THEN the system SHALL manter o número de cartas, variantes e sets idêntico ao da primeira execução. <!-- SRC-08 -->
9. The system SHALL gravar cada produto como variante com `variant_code = "tcgplayer:<markets.tcgplayer.id>"`, ou `"apitcg:<_id>"` quando o produto não tiver `tcgplayer.id`. <!-- SRC-09 -->
10. The system SHALL descartar os produtos com `CardType = "DON!!"` sem registrá-los como falha. <!-- SRC-10 -->
11. IF um produto não tiver `code` THEN the system SHALL registrá-lo no `error_log` como descarte, com o `_id` do produto, sem contá-lo em `failed_count` e sem alterar o status da execução, e continuar. <!-- SRC-11 -->
12. The system SHALL definir os campos da carta pela impressão da regra de Assumptions ("Impressão que define os dados da carta"), com o efeito sem HTML, `<br>` convertido em quebra de linha, e o trecho após `[Trigger]` gravado em `trigger_text`. <!-- SRC-12 -->
13. The system SHALL classificar `art_kind` pelo último sufixo entre parênteses do nome, conforme a tabela de Assumptions. <!-- SRC-13 -->
14. The system SHALL gravar o código de cada set pela regra de Assumptions ("Código do set") e `released_on` a partir de `release_date`. <!-- SRC-14 -->

**Independent Test**: processar a fixture versionada e verificar contagens, um `variant_code`, um `art_kind` de cada tipo, um `trigger_text` e um set com `code` nulo na fonte.

---

### P1: Catálogo mostra só o que a fonte atual tem ⭐ MVP

**User Story**: Como colecionador, quero ver cada carta uma vez, com as impressões da fonte atual, e abrir o catálogo pelos lançamentos mais novos.

**Why P1**: Sem isso a grade soma as impressões das duas fontes.

**Acceptance Criteria**:

1. WHEN o catálogo é aberto sem parâmetros THEN the system SHALL listar primeiro as cartas do set presente com `released_on` mais recente, como já define o Req. 2.4. <!-- SRC-15 -->
2. The system SHALL considerar na grade, na busca, nos filtros, na lista de sets do filtro e no progresso só as variantes, cartas e sets presentes na fonte, conforme a definição de presença de Assumptions. <!-- SRC-16 -->
3. WHILE uma variante estiver ausente da fonte, the system SHALL exibi-la na página de detalhe da carta só para o usuário que a tem na coleção ou na wishlist, com o rótulo "fora da fonte". <!-- SRC-17 -->
4. The system SHALL nunca apagar nem alterar a quantidade de um `collection_item` ou `wishlist_item` durante a ingestão, inclusive quando a variante dele deixar de estar presente. <!-- SRC-18 -->

**Independent Test**: com uma variante antiga ausente e um item de coleção sobre ela, rodar a ingestão e verificar a grade sem a variante, a quantidade intacta e o detalhe com o rótulo para o dono.

---

### P1: Remapeamento da coleção para as variantes novas ⭐ MVP

**User Story**: Como colecionador, quero que minha coleção e minha wishlist passem a apontar para as impressões da fonte nova, para não perdê-las de vista na troca.

**Why P1**: Com as ausentes fora do catálogo (SRC-16), um item não remapeado some da grade e do progresso.

**Acceptance Criteria**:

1. WHEN o mantenedor executa `ingestion:remap` THEN the system SHALL mover para a variante nova cada `collection_item` e `wishlist_item` cuja variante esteja ausente e que tenha exatamente uma variante presente com o mesmo `card_number`, a mesma classe de arte (`base` com `base`; qualquer outro `art_kind` com qualquer outro que não `base`) e o mesmo código de set. <!-- SRC-19 -->
2. The system SHALL preservar `quantity` e `target_quantity` de cada item movido. <!-- SRC-20 -->
3. IF um item tiver zero ou mais de um candidato, se dois itens do mesmo usuário tiverem o mesmo candidato, ou se o usuário já tiver um item na variante candidata, THEN the system SHALL deixá-los na variante antiga e listá-los no relatório com `card_number`, `variant_code` antigo e o motivo ("sem candidato", "ambíguo" ou "colisão"). <!-- SRC-21 -->
4. WHEN `ingestion:remap` é executado duas vezes seguidas THEN the system SHALL não mover nenhum item na segunda execução. <!-- SRC-22 -->
5. IF não houver nenhuma execução da ingestão com status `succeeded` THEN the system SHALL abortar o remapeamento com a mensagem "nenhuma ingestão concluída; rode ingestion:import antes", sem mover nenhum item. <!-- SRC-23 -->

**Independent Test**: três itens (um com candidato único, um ambíguo, um sem candidato), rodar o remapeamento duas vezes e conferir movimentos, quantidades e relatório.

---

### P1: Progresso por set com denominador derivado ⭐ MVP

**User Story**: Como colecionador, quero continuar vendo quanto falta para fechar cada set depois da troca.

**Why P1**: A apitcg não tem `baseSetSize`, e o Req. 9.5 depende dele.

**Acceptance Criteria**:

1. The system SHALL gravar `sets.base_set_size` como o número de `card_number` distintos do set com prefixo igual ao código do set quando eles forem maioria estrita entre os `card_number` distintos do set, e como o número total de `card_number` distintos do set nos demais casos. <!-- SRC-24 -->
2. The system SHALL contar no numerador do percentual os `card_number` distintos do universo do denominador para os quais o usuário possui ao menos uma variante presente do set com `art_kind` diferente de `parallel`. <!-- SRC-25 -->
3. The system SHALL nunca exibir percentual acima de 100% para um set. <!-- SRC-26 -->
4. The system SHALL exibir a contagem de parallels possuídos do set como métrica separada, como define o Req. 9.6. <!-- SRC-27 -->
5. WHEN o usuário possui duas impressões não-parallel do mesmo `card_number` no mesmo set THEN the system SHALL contar esse número uma única vez no numerador. <!-- SRC-28 -->

**Independent Test**: um set com numeração própria e um de reimpressão na fixture, usuário com base + Box Topper do mesmo número, conferir denominador, numerador e teto de 100%.

---

### P1: Fixture offline da fonte nova ⭐ MVP

**User Story**: Como mantenedor, quero testar a ingestão sem rede e sem chave.

**Why P1**: Req. 11.5.

**Acceptance Criteria**:

1. The system SHALL versionar `spec/fixtures/apitcg-subset.json`, recortado de um snapshot real, com ao menos: uma carta com impressão base e parallel, um sufixo `Alternate Art`, `Manga`, `Reprint` e um sufixo numérico, um `[Trigger]`, um `DON!!`, um produto sem `code`, um set com `code` nulo e um set de reimpressão. <!-- SRC-29 -->
2. WHEN `python3 spec/verify_fixture.py` é executado THEN the system SHALL verificar a presença de cada caso de SRC-29 na fixture nova, sem Docker e sem Ruby. <!-- SRC-30 -->

**Independent Test**: `python3 spec/verify_fixture.py` e a suíte de ingestão sem rede.

---

### P2: Estabilidade do identificador verificada

**User Story**: Como mantenedor, quero saber se o `tcgplayer.id` é estável antes de confiar nele como chave da coleção.

**Why P2**: A feature funciona sem isso, mas o risco fica aberto.

**Acceptance Criteria**:

1. WHEN existirem dois snapshots com ao menos 24h de diferença THEN the system SHALL oferecer uma verificação (`ingestion:compare_snapshots A=<arq> B=<arq>`) que informe quantos produtos presentes nos dois mudaram de `tcgplayer.id` para o mesmo `_id`. <!-- SRC-31 -->

---

## Edge Cases

- IF a apitcg responder 401 THEN the system SHALL encerrar com status `failed` e a mensagem "chave da apitcg recusada (401)", sem repetir a requisição. <!-- SRC-32 -->
- IF o total de páginas mudar durante a busca (produto novo entre páginas) THEN the system SHALL deduplicar pelo `variant_code` antes de normalizar. <!-- SRC-33 -->
- WHEN a mesma variante aparecer em dois sets THEN the system SHALL gravá-la uma única vez, no primeiro set em que aparecer no snapshot (regra do caso P-029_r1). <!-- SRC-34 -->
- IF um set não tiver nenhum `card_number` com prefixo igual ao seu código THEN the system SHALL aplicar o ramo "todos os números distintos" de SRC-24, sem divisão por zero. <!-- SRC-35 -->

---

## Requirement Traceability

| Requirement ID | Story | Origem | Status |
|---|---|---|---|
| SRC-01 | P1: Ingestão | Req. 1.1 | Pending |
| SRC-02 | P1: Ingestão | Req. 1.8 | Pending |
| SRC-03 | P1: Ingestão | Req. 11.5, design §5.1 | Pending |
| SRC-04 | P1: Ingestão | Req. 1.8 | Pending |
| SRC-05 | P1: Ingestão | CLAUDE.md (segredos) | Pending |
| SRC-06 | P1: Ingestão | Req. 1.10 (a reescrever) | Pending |
| SRC-07 | P1: Ingestão | Req. 1.9, 11.5 (a reescrever) | Pending |
| SRC-08 | P1: Ingestão | Req. 1.4 | Pending |
| SRC-09 | P1: Ingestão | Req. 1.3, AD nova | Pending |
| SRC-10 | P1: Ingestão | P7 | Pending |
| SRC-11 | P1: Ingestão | Req. 1.5 | Pending |
| SRC-12 | P1: Ingestão | Req. 1.2, 5.4 | Pending |
| SRC-13 | P1: Ingestão | design §3 (`art_kind`) | Pending |
| SRC-14 | P1: Ingestão | Req. 2.4 | Pending |
| SRC-15 | P1: Catálogo | Req. 2.4 | Pending |
| SRC-16 | P1: Catálogo | Req. 1.7 | Pending |
| SRC-17 | P1: Catálogo | Req. 1.7, 5.2 | Pending |
| SRC-18 | P1: Catálogo | Req. 1.7 | Pending |
| SRC-19 | P1: Remapeamento | Req. 1.7 | Pending |
| SRC-20 | P1: Remapeamento | Req. 7 | Pending |
| SRC-21 | P1: Remapeamento | Req. 1.7 | Pending |
| SRC-22 | P1: Remapeamento | Req. 1.4 | Pending |
| SRC-23 | P1: Remapeamento | — | Pending |
| SRC-24 | P1: Progresso | Req. 9.5 (a reescrever), AD-003 | Pending |
| SRC-25 | P1: Progresso | Req. 9.1, 9.4 (a reescrever) | Pending |
| SRC-26 | P1: Progresso | Req. 9.2 | Pending |
| SRC-27 | P1: Progresso | Req. 9.6 | Pending |
| SRC-28 | P1: Progresso | Req. 9.4 | Pending |
| SRC-29 | P1: Fixture | Req. 11.5 | Pending |
| SRC-30 | P1: Fixture | CLAUDE.md (`verify_fixture.py`) | Pending |
| SRC-31 | P2: Estabilidade | AD nova | Pending |
| SRC-32 | Edge case | Req. 1.8 | Pending |
| SRC-33 | Edge case | Req. 1.4 | Pending |
| SRC-34 | Edge case | Req. 1.3 | Pending |
| SRC-35 | Edge case | Req. 9.5 | Pending |

**Coverage:** 35 total, 0 mapped to tasks, 35 unmapped ⚠️ (tasks ainda não escritas).

**Emendas em `.context/` que precedem o código:** Req. 1.1, 1.9, 1.10 e 1.11
(snapshot no lugar da revisão imutável), Req. 9.1, 9.4 e 9.5 (números de carta
distintos, `baseSetSize` derivado), Req. 11.5 (fixture nova), Req. 11.7 e
`design.md` §7 (host de imagem), `design.md` §5 (Fetch e Normalize) e a AD nova
que substitui a AD-001 no `STATE.md`, com a tabela P1–P7 do `CLAUDE.md`.

---

## Success Criteria

- [ ] Depois de `ingestion:import` com a chave real, os 85 sets com carta têm `released_on` preenchido, e a grade abre por OP18/ST36 ou pelo set de `release_date` mais recente que já tenha carta.
- [ ] A contagem total de `collection_items` e a soma de `quantity` são idênticas antes e depois de `ingestion:import` seguido de `ingestion:remap`.
- [ ] Nenhum set exibe progresso acima de 100%.
- [ ] A suíte completa passa sem rede e sem `APITCG_API_KEY`; rubocop limpo.
