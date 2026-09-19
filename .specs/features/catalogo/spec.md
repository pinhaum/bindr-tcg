# Catálogo de Cartas — Especificação

> **Fonte de verdade:** `.context/requirements.md` (Req. 1–5) e `.context/design.md`.
> Este documento é o recorte da feature "catálogo" no formato do fluxo
> spec-driven, com IDs rastreáveis. Divergência entre os dois se resolve **a favor
> de `.context/`** — ver AD-005 em `.specs/STATE.md`.

## Problem Statement

Registrar e consultar uma coleção de OPTCG em planilha não escala: não há busca
tolerante a erro de digitação, não há filtro combinado, e não há como saber quanto
falta de um set sem contar à mão. O catálogo precisa vir de fonte externa — são
milhares de cartas — e precisa distinguir a carta do jogo da impressão física,
porque é a impressão que se coleciona.

## Goals

- [ ] Catálogo completo navegável (2815 cartas / 4915 variantes) carregado por ingestão automatizada.
- [ ] Busca e filtros combinados respondendo em p95 < 500ms com o catálogo completo.
- [ ] Ingestão idempotente que nunca corrompe dados de coleção do usuário.

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Deck builder e validador | Fase 2 — regras do jogo precisam de confirmação no regulamento oficial |
| Preços e valor da coleção | Fase 3 — optcgjson não traz preço; depende de outra fonte |
| Cache local de imagens | AD-004 — hotlink e medir; só entra se o Req. 11.2 falhar na prática |
| Cartas DON!! | P7 — a fonte não as traz |
| Scanner por câmera / OCR | Fora da Fase 1 |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Fonte do catálogo | `hugoprudente/optcgjson` em revisão fixa | Única fonte que preserva Card × CardVariant (AD-001) | y |
| `variant_code` | campo `id` da fonte, sem hash | A fonte fornece identificador estável por impressão | y |
| Stack | Rails 8 + Hotwire + PostgreSQL | Recursos de busca do Postgres são o núcleo do design (AD-002) | y |
| Imagens | hotlink, sem cache | Preferir referenciar a redistribuir arte (AD-004) | y |
| Licença da fonte | uso pessoal, não comercial | O repositório não declara licença; risco aceito e registrado | y |
| Variante em dois sets | `variant_code` único global | `P-029_r1` aparece em PRB01 e ST16 — relação variante↔set não é 1:1 | y |

**Open questions:** none — todas resolvidas nas tasks 0.1–0.3 ou registradas acima.

---

## User Stories

### P1: Ingestão do catálogo ⭐ MVP

**User Story**: Como usuário, quero que o catálogo seja carregado automaticamente de uma fonte externa, para não digitar milhares de cartas à mão.

**Why P1**: Sem catálogo não há produto. Toda outra história depende desta.

**Acceptance Criteria**:

1. O sistema SHALL oferecer um processo de importação executável sob demanda que popule cartas, variantes e sets a partir de uma fonte externa configurável.
2. WHEN a importação encontrar um `card_number` que já existe THEN o sistema SHALL atualizar os campos da carta existente em vez de criar duplicata.
3. WHEN a importação encontrar uma variante já existente (mesma carta + mesmo `variant_code`) THEN o sistema SHALL atualizar essa variante em vez de criar duplicata.
4. O sistema SHALL manter a importação idempotente: executá-la duas vezes com a mesma entrada SHALL preservar o número de registros.
5. IF a importação falhar em um registro individual THEN o sistema SHALL registrar o erro com o identificador do registro e continuar processando os demais.
6. WHEN uma execução de importação terminar THEN o sistema SHALL persistir um resumo com início, fim, status, quantidade criada, atualizada e falhada.
7. O sistema SHALL preservar os registros de coleção do usuário em toda importação, mesmo quando uma carta desaparecer da fonte externa.
8. IF a fonte externa estiver indisponível THEN o sistema SHALL falhar de forma explícita, sem deixar o catálogo parcialmente sobrescrito.
9. O sistema SHALL fixar uma revisão imutável do dataset (commit ou tag), nunca uma referência móvel como `main`.
10. WHEN a importação for executada THEN o sistema SHALL registrar no resumo a revisão utilizada.
11. O sistema SHALL exigir ato explícito do mantenedor para atualizar a revisão fixada, nunca como efeito colateral da importação.

**Independent Test**: rodar a ingestão duas vezes sobre a fixture e verificar que a contagem de registros não muda e que um `collection_item` preexistente continua intacto.

---

### P1: Navegação do catálogo ⭐ MVP

**User Story**: Como usuário, quero navegar por todas as cartas em uma grade visual, para reconhecer cartas pela arte.

**Why P1**: É a superfície principal do produto.

**Acceptance Criteria**:

1. O sistema SHALL exibir as cartas em grade com imagem, nome e `card_number`.
2. O sistema SHALL paginar os resultados.
3. IF a imagem de uma carta não carregar THEN o sistema SHALL exibir um placeholder com nome e `card_number`, sem quebrar o layout.
4. O sistema SHALL refletir o estado completo de busca e filtros na URL, de modo que recarregar reproduza o mesmo resultado.
5. O sistema SHALL permanecer utilizável em viewport de 360px sem scroll horizontal.

**Independent Test**: abrir a grade em 360px, aplicar filtro, recarregar a página e confirmar que o resultado é idêntico.

---

### P1: Busca textual ⭐ MVP

**User Story**: Como usuário, quero buscar cartas por nome, efeito ou código, para achar uma carta específica rápido.

**Why P1**: Busca lenta ou imprecisa inviabiliza o uso durante abertura de boosters.

**Acceptance Criteria**:

1. O sistema SHALL buscar por nome de forma insensível a caixa e a acento.
2. O sistema SHALL tolerar erro de digitação na busca por nome.
3. O sistema SHALL buscar no texto de efeito da carta.
4. WHEN o termo buscado corresponder exatamente a um `card_number` THEN o sistema SHALL apresentar essa carta como primeiro resultado.
5. O sistema SHALL permitir combinar busca textual com todos os filtros.
6. WHEN a busca não retornar resultados THEN o sistema SHALL exibir estado vazio com o termo buscado e ação de limpar filtros.

**Independent Test**: buscar `OP01-001` e confirmar que a carta exata vem primeiro; buscar "lufy" e confirmar que Luffy aparece.

---

### P1: Filtros ⭐ MVP

**User Story**: Como usuário, quero filtrar por cor, tipo, custo, raridade e set, para reduzir o catálogo ao que me interessa.

**Why P1**: É o que torna um catálogo de 4915 variantes navegável.

**Acceptance Criteria**:

1. O sistema SHALL oferecer filtros por cor, tipo de carta, custo, raridade e set.
2. O sistema SHALL aplicar semântica OU dentro de uma mesma categoria de filtro.
3. O sistema SHALL aplicar semântica E entre categorias de filtro distintas.
4. WHERE uma carta é multicolorida, o sistema SHALL incluí-la no resultado do filtro de qualquer uma de suas cores.
5. IF um parâmetro de filtro for desconhecido ou inválido THEN o sistema SHALL ignorá-lo e retornar resultado válido, nunca erro.
6. O sistema SHALL exibir os filtros ativos como chips removíveis individualmente.
7. O sistema SHALL retornar a contagem total de resultados junto com a página atual.

**Independent Test**: filtrar por Red e confirmar que Leaders Red/Green aparecem; passar `?cor=roxo_invalido` e confirmar resposta 200.

---

### P2: Detalhe da carta e variantes

**User Story**: Como colecionador, quero ver todas as impressões de uma carta, para saber qual delas eu tenho.

**Why P2**: Essencial para coleção, mas a grade e a busca precisam existir antes.

**Acceptance Criteria**:

1. O sistema SHALL exibir, na página de detalhe, todos os campos conhecidos da carta e a imagem em resolução maior.
2. O sistema SHALL listar todas as variantes da carta, cada uma com sua raridade, set e imagem própria.
3. O sistema SHALL preservar as quebras de linha de `effect_text` e `trigger_text`.
4. WHERE um campo não se aplica ao tipo da carta, o sistema SHALL omiti-lo em vez de exibi-lo vazio.

**Independent Test**: abrir OP01-001 e confirmar que base e parallel aparecem como impressões distintas, e que o Leader não mostra campo `cost`.

---

## Edge Cases

- IF o mesmo `variant_code` aparecer em mais de um set THEN o sistema SHALL tratá-lo como uma única variante (caso real: `P-029_r1` em PRB01 e ST16).
- IF a fonte trouxer um valor de raridade ou attribute desconhecido THEN o sistema SHALL persistí-lo como texto sem falhar (caso real: `attribute: "?"` em OP13-079).
- The system SHALL distinguir `counter` nulo de `counter` zero, nunca usando 0 como sentinela de ausência.
- IF a fonte trouxer `traits` com variação de caixa ou espaçamento THEN o sistema SHALL normalizá-los antes de persistir.

---

## Requirement Traceability

| Requirement ID | Story | Origem em `.context/requirements.md` | Status |
| -------------- | ----- | ------------------------------------ | ------ |
| CAT-01 | P1: Ingestão | Req. 1.1–1.11 | Pending |
| CAT-02 | P1: Navegação | Req. 2.1–2.5 | Pending |
| CAT-03 | P1: Busca | Req. 3.1–3.6 | Pending |
| CAT-04 | P1: Filtros | Req. 4.1–4.8 | Pending |
| CAT-05 | P2: Detalhe | Req. 5.1–5.5 | Pending |

**ID format:** `CAT-NN`
**Status values:** Pending → In Design → In Tasks → Implementing → Verified
**Coverage:** 5 total, 0 mapeados a tasks, 5 pendentes ⚠️

---

## Success Criteria

- Registrar uma caixa de boosters inteira pelo celular, sem planilha.
- Responder "quanto falta do set X?" em no máximo três toques.
- Ingestão rodada duas vezes não altera contagem nem toca a coleção do usuário.
