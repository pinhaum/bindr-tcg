# Fechamento do MVP — documentação e revisão dos specs — Specification

## Problem Statement

A Fase 1 chegou ao fim das features de código (`catalogo`, `colecao`,
`portabilidade`, `navegacao`, `conformidade`), mas a §7.2 de `.context/tasks.md`
segue aberta: o README não diz que `docker compose up` sobe um catálogo **vazio**
nem como rodar a ingestão, `requirements.md` e `design.md` não registram parte do
que as decisões AD-006..AD-018 mudaram na execução, e os `⚠️ VERIFICAR` não foram
reconciliados com o que já foi verificado. Sem isso o Req. 11.6 ("um único comando
documentado") é cumprido só pela metade e os documentos-fonte contradizem o código.

Esta feature só escreve documentação. Não muda código, teste, migração nem folha.

Fonte: `.context/tasks.md` §7.2 (Req. 11.6); `.specs/STATE.md` (AD-001..AD-018).

## Goals

- [ ] Quem clona o repositório sobe o app e carrega o catálogo seguindo só o README, sem ler outro arquivo (FEC-01..FEC-05).
- [ ] `requirements.md` e `design.md` descrevem o que existe, com cada mudança citando a AD que a originou (FEC-06..FEC-11).
- [ ] Nenhum `⚠️ VERIFICAR` resolvido permanece, e cada remoção tem a fonte registrada; os abertos estão listados (FEC-12..FEC-15).
- [ ] Qualquer requisito errado achado no caminho vira DECISÃO-DO-DONO registrada, sem código inventado (FEC-16..FEC-18).

## Out of Scope

Explicitamente excluído. Documentado para evitar scope creep.

| Feature | Reason |
|---|---|
| §7.1 "Verificação do critério de sucesso" (caixa de boosters pelo celular, três toques) | É verificação de uso pelo dono, não documentação; o atrito vira backlog da Fase 2 |
| Editar `.context/product.md`, `.context/README.md`, `docs/adr/*` | A §7.2 nomeia só README, `requirements.md` e `design.md`; o aviso "VERIFICAR resolvidos" de `product.md` §6 já aponta para o ADR 001 |
| Resolver os `⚠️ VERIFICAR` abertos (imagem em resolução maior, regras de deck) | Exigem fonte primária externa; regras de deck são da Fase 2 (`.context/tasks.md`, "Fora do escopo") |
| Mudar código, teste, migração ou folha para casar com o documento | Em divergência, a feature corrige o documento só quando a AD é inequívoca; o resto vira DECISÃO-DO-DONO (FEC-16) |
| Login sem limite de tentativas e cookie sem `secure` explícito | Dívidas registradas no `CLAUDE.md`; reabrem com Redis ou `solid_cache` |
| Reescrever seções que não mudaram | Mudança mínima e revisável; só entra o que uma AD ou emenda justifica |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| Qual é "o único comando" do Req. 11.6 | `docker compose up`; `cp .env.example .env` é opcional | `docker-compose.yml` usa `${VAR:-default}` em todas as variáveis e não declara `env_file`, então o `.env` só personaliza; o `command` do serviço `app` roda `db:prepare` antes do servidor | y (lido do `docker-compose.yml`) |
| A subida entrega catálogo vazio | O README diz isso e leva ao passo de ingestão | `db/seeds.rb` só tem comentários e `db:prepare` não ingere; o catálogo só existe depois de `ingestion:import` | y (lido de `db/seeds.rb` e `lib/tasks/ingestion.rake`) |
| Comando da ingestão | `docker compose exec app bin/rails ingestion:import`; `REUSE_PAYLOAD=1` reprocessa o payload salvo sem rede | `lib/tasks/ingestion.rake` e `Ingestion::Run.call(reuse_payload:)` | y |
| Revisão fixada | O README cita `config/ingestion.yml` e a regra de que `main`/`HEAD`/`latest` são rejeitados na carga (AD-001, Req. 1.9), sem copiar o hash | Não envelhece quando a revisão subir | y |
| Gates de teste no README | Os do `CLAUDE.md` (quick, full, build) mais `python3 spec/verify_fixture.py` | Uma fonte só de comandos | y |
| `requirements.md` não tem `⚠️ VERIFICAR` | Confirmado por `grep`: zero ocorrências | O único texto com o marcador está em `design.md` | y (medido em 2026-09-28) |
| Estado dos cinco marcadores de `design.md` | Resolvidos: `:330` (menção histórica a um marcador que a T4 do `catalogo` refutou) e `:355` (conferência de `gin_trgm_ops` e de `to_tsvector` de dois argumentos). Abertos: `:506`/`:516` (Req. 5.1, mesmo item) e `:579` (regras de deck) | `:330`/`:355`: §4.1.1 registra a verificação no PostgreSQL 17.11; a migração `20260919120100` e `test/models/catalog_indexes_test.rb` a provam. `:506`: `image_url_large` vazio e nada grava a coluna. `:579`: nenhum regulamento no repositório nem AD que confirme | y (a T4 reconfere cada fonte antes de remover) |
| Req. 5.1 ("imagem em resolução maior") | Continua aberto; o detalhe serve a mesma imagem da grade | Não há URL de resolução maior na fonte; não se deriva URL | y — relaxar o Req. 5.1 ou buscar outra fonte é do dono; a T5 registra DECISÃO-DO-DONO |
| O que AD-006, AD-007 e AD-008 mudam em `requirements.md` | Req. 10 ganha a substituição da quantidade (AD-006), o staging com expiração dono do usuário (AD-007) e o limite de 10.000 linhas de dado (AD-008) | STATE.md as marca `active`; `requirements.md` não cita nenhuma (`grep` = 0) | y |
| O que a AD-007 muda em `design.md` | §3 e §6 descrevem a tabela de staging do import, dona do usuário | Toda leitura parte de `Current.user`; a T3 confere o nome da tabela em `db/structure.sql` | y |
| O que AD-009, AD-010, AD-017 e AD-018 mudam em `design.md` | §8 ganha: relógio monotônico e drenagem da pending list GIN em testes de ordem e de plano (AD-009), teste não-transacional em série (AD-010), guardas protegidos e as edições aceitas (AD-017, AD-018) | São regras de teste que sobrevivem à feature que as originou | y |
| AD-011, AD-012, AD-013, AD-015, AD-016 | Já refletidas em `design.md` §7/§11 e `requirements.md` Req. 11.7/12/13; T2 e T3 só conferem | Refletidas no conteúdo, sem citação nominal de AD-011/013; conferidas em `design.md` §7/§11 | y |
| AD-014 (execução em paralelo) | Não entra nos documentos-fonte | É método do orquestrador, não requisito nem design | y |
| Forma da citação | Cada mudança termina com `(AD-NNN)` ou `(emenda de AAAA-MM-DD)` na linha alterada | Torna a auditoria um `grep`, no estilo que `requirements.md` já usa | y |
| Requisito errado achado na atualização | Corrige só se inequívoco pelas AD (e cita); senão registra em `decisoes-do-dono.md` e não altera | Alinha ao `CLAUDE.md` e evita a feature decidir sozinha | y |

**Open questions:** none — tudo resolvido ou logado acima. A decisão sobre o Req.
5.1 fica registrada como DECISÃO-DO-DONO pela T5, não como pergunta em aberto.

**`⚠️ VERIFICAR` que esta spec acredita abertos (permanecem, FEC-13):**

| Onde | Assunto | Por que continua aberto |
|---|---|---|
| `design.md:506`/`:516` | Req. 5.1, URL de imagem em resolução maior | `image_url_large` vazio nas 4933 variantes; a fixture só traz `imageUrl` |
| `design.md:579` | Regras de deck (1 Leader, 50 cartas, 4 cópias, cores) | Fase 2; exige regulamento oficial |

**Resolvidos (removidos, FEC-12):** `design.md:330` e `design.md:355`.

**Varredura de dimensões implícitas:** integridade de estado → FEC-14 e FEC-16
(remoção só com fonte; correção só quando inequívoca); validação → FEC-24 (nada
fora do `Where` muda); observabilidade → FEC-12 (log de remoções auditável).
Autorização, concorrência, idempotência, ciclo de vida de dado, falha parcial e
dependência externa: N/A, porque a feature só escreve documentos versionados.

---

## User Stories

### P1: README de subida e ingestão ⭐ MVP

**User Story**: Como desenvolvedor que acabou de clonar o repositório, quero subir
o app e carregar o catálogo só com o README, para ver o produto funcionando sem
perguntar a ninguém.

**Why P1**: É o Req. 11.6 e o único item da §7.2 que um estranho ao projeto usa.

**Acceptance Criteria**:

1. The README SHALL apresentar `docker compose up` como o único comando de subida local, indicando que `cp .env.example .env` é opcional e só personaliza credenciais. <!-- FEC-01 -->
2. The README SHALL informar que a subida entrega o catálogo vazio e que o passo seguinte é `docker compose exec app bin/rails ingestion:import`. <!-- FEC-02 -->
3. The README SHALL descrever a ingestão: a revisão vem de `config/ingestion.yml` e é imutável (referência móvel é rejeitada, AD-001), o payload bruto fica em `storage/ingestion/` (ignorado pelo git) e `REUSE_PAYLOAD=1` reprocessa esse payload sem rede. <!-- FEC-03 -->
4. The README SHALL listar os gates de teste do `CLAUDE.md` (quick, full, build) e `python3 spec/verify_fixture.py`, cada um com o comando exato. <!-- FEC-04 -->
5. IF um comando citado no README não existir no repositório (rake, script, arquivo) THEN the task SHALL corrigir o README em vez do repositório. <!-- FEC-05 -->

**Independent Test**: Cada comando do README aparece em `docker-compose.yml`,
`lib/tasks/ingestion.rake`, `config/ingestion.yml`, `spec/verify_fixture.py` ou
`CLAUDE.md`; a leitura na ordem chega a um catálogo carregado.

---

### P1: `requirements.md` e `design.md` atualizados ⭐ MVP

**User Story**: Como mantenedor, quero que os documentos-fonte descrevam o que foi
construído e por quê, para que a Fase 2 parta de um retrato fiel.

**Why P1**: `.context/` é a fonte de verdade (AD-005); um retrato velho engana a próxima fase.

**Acceptance Criteria**:

1. WHEN uma AD ativa (AD-001..AD-018) alterar comportamento, regra ou teste descritos em `.context/requirements.md` THEN the task SHALL registrar a mudança na seção afetada e citar `(AD-NNN)` na linha alterada. <!-- FEC-06 -->
2. WHEN uma AD ativa alterar modelo, arquitetura, teste ou regra descritos em `.context/design.md` THEN the task SHALL registrar a mudança na seção afetada e citar `(AD-NNN)` na linha alterada. <!-- FEC-07 -->
3. IF a AD já estiver refletida no documento (citada e coerente com o código) THEN the task SHALL NOT reescrevê-la. <!-- FEC-08 -->
4. The `requirements.md` SHALL registrar no Req. 10 a substituição da quantidade no import (AD-006), o staging com expiração dono do usuário (AD-007) e o limite de 10.000 linhas de dado (AD-008). <!-- FEC-09 -->
5. The `design.md` SHALL registrar em §3 e §6 a tabela de staging do import e em §8 as regras de teste das AD-009, AD-010, AD-017 e AD-018. <!-- FEC-10 -->
6. The `design.md` §9 SHALL manter P6 como revista pela AD-012 e listar P8 (cores do jogo) como pendência aberta, coerente com "Rastreamento de pendências" de `requirements.md`. <!-- FEC-11 -->

**Independent Test**: `grep -c "AD-00[678]" .context/requirements.md` ≥ 3;
`grep -c "AD-009\|AD-010\|AD-017\|AD-018" .context/design.md` ≥ 4; nenhum nome de
tabela, arquivo ou método citado que não exista no repositório.

---

### P1: `⚠️ VERIFICAR` resolvidos removidos, abertos preservados ⭐ MVP

**User Story**: Como leitor dos documentos, quero que um marcador de verificação
signifique "ainda não confirmado", para não desconfiar de fato já provado nem
confiar em fato ainda aberto.

**Why P1**: Está escrito na §7.2 ("Remover todos os `⚠️ VERIFICAR` já resolvidos").

**Acceptance Criteria**:

1. WHEN um `⚠️ VERIFICAR` de `requirements.md` ou `design.md` tiver fonte primária que o resolva (AD, fixture, código ou teste) THEN the task SHALL removê-lo do texto e registrar, em `.specs/features/fechamento/verificar-resolvidos.md`, o local original, o texto resumido e a fonte que o resolveu. <!-- FEC-12 -->
2. IF nenhuma fonte primária resolver o marcador THEN the task SHALL mantê-lo no documento e listá-lo na seção "Permanecem abertos" do `verificar-resolvidos.md`. <!-- FEC-13 -->
3. The task SHALL NOT remover um marcador sem abrir e conferir, na mesma task, a fonte citada. <!-- FEC-14 -->
4. The `verificar-resolvidos.md` SHALL registrar a contagem de `⚠️ VERIFICAR` de `requirements.md` depois da task (hoje zero). <!-- FEC-15 -->

**Independent Test**: o `verificar-resolvidos.md` tem duas linhas de resolvido e
duas de aberto, cada uma com fonte; `design.md` mantém só os marcadores abertos.

---

### P2: Requisito errado vira decisão do dono

**User Story**: Como dono do produto, quero ser avisado quando a atualização dos
documentos mostrar um requisito incorreto, para decidir eu mesmo em vez de ver o
requisito ajustado em silêncio.

**Why P2**: Protege o método (`CLAUDE.md`: requisito errado para a execução); não bloqueia a documentação.

**Acceptance Criteria**:

1. IF a atualização revelar um requisito que contradiz o código ou uma AD ativa e a correção não for inequívoca pelas AD THEN the task SHALL registrar em `.specs/features/fechamento/decisoes-do-dono.md` o requisito, a evidência, as opções e a pergunta ao dono, e SHALL NOT alterar o requisito. <!-- FEC-16 -->
2. WHERE a correção for inequívoca pelas AD, the task SHALL corrigir o documento, citar a AD na linha e registrar a correção em `decisoes-do-dono.md` sob "Corrigidos por AD". <!-- FEC-17 -->
3. The `decisoes-do-dono.md` SHALL incluir o Req. 5.1 (imagem em resolução maior) como decisão aberta, com a evidência de `design.md` §7. <!-- FEC-18 -->

**Independent Test**: `decisoes-do-dono.md` existe, tem a entrada do Req. 5.1 e
nenhuma alteração de requisito sem AD citada.

---

### P2: Fechamento no plano e no STATE

**User Story**: Como orquestrador da próxima fase, quero o plano e o Handoff
fechados, para retomar sem reler o histórico.

**Why P2**: Consolida o resultado; não altera a documentação de produto.

**Acceptance Criteria**:

1. WHEN as tasks de documento estiverem concluídas THEN the task SHALL marcar a §7.2 em `.context/tasks.md` e acrescentar o bloco *Handoff* em `.specs/STATE.md` com o ponto de retomada. <!-- FEC-19 -->
2. WHEN o Handoff for escrito THEN `validate_state.py` SHALL sair com 0 sobre o `STATE.md`. <!-- FEC-20 -->

**Independent Test**: `[x] **7.2` em `.context/tasks.md`; bloco *Handoff*
"fechamento" no `STATE.md`; o validador sai 0.

---

## Edge Cases

- IF um comando do README depender de estado que só existe depois de outro THEN the README SHALL apresentá-los na ordem em que funcionam (subida, depois ingestão). <!-- FEC-21 -->
- IF a ingestão não conseguir baixar a fonte THEN the README SHALL dizer que o processo aborta antes de escrever no banco (Req. 1.8) e apontar `REUSE_PAYLOAD=1` quando já houver payload salvo. <!-- FEC-22 -->
- WHEN o build do Docker falhar com `docker-credential-desktop.exe` THEN the README SHALL manter o contorno com `DOCKER_CONFIG` já documentado, sem alterá-lo. <!-- FEC-23 -->
- IF uma task precisar editar arquivo fora do seu `Where` THEN the task SHALL parar com `blocked` e nomear o arquivo. <!-- FEC-24 -->

---

## Requirement Traceability

| Requirement ID | Story | Origem | Task | Status |
|---|---|---|---|---|
| FEC-01 | P1: README | Req. 11.6, `docker-compose.yml` | T1 | Done |
| FEC-02 | P1: README | Req. 11.6, `db/seeds.rb`, `lib/tasks/ingestion.rake` | T1 | Done |
| FEC-03 | P1: README | Req. 1.1, 1.9, AD-001 | T1 | Done |
| FEC-04 | P1: README | `CLAUDE.md` (gates), Req. 11.5 | T1 | Done |
| FEC-05 | P1: README | §7.2 | T1 | Done |
| FEC-06 | P1: Documentos | §7.2, AD-005 | T2 | Done |
| FEC-07 | P1: Documentos | §7.2, AD-005 | T3 | Done |
| FEC-08 | P1: Documentos | §7.2 | T2, T3 | Done |
| FEC-09 | P1: Documentos | Req. 10, AD-006, AD-007, AD-008 | T2 | Done |
| FEC-10 | P1: Documentos | `design.md` §3, §6, §8, AD-007, AD-009, AD-010, AD-017, AD-018 | T3 | Done |
| FEC-11 | P1: Documentos | `design.md` §9, AD-012, P8 | T3 | Done |
| FEC-12 | P1: VERIFICAR | §7.2 | T4 | Done |
| FEC-13 | P1: VERIFICAR | §7.2 | T4 | Done |
| FEC-14 | P1: VERIFICAR | §7.2 | T4 | Done |
| FEC-15 | P1: VERIFICAR | §7.2 | T4 | Done |
| FEC-16 | P2: Decisão do dono | `CLAUDE.md` (método) | T5 | Done |
| FEC-17 | P2: Decisão do dono | `CLAUDE.md` (método) | T5 | Done |
| FEC-18 | P2: Decisão do dono | Req. 5.1, `design.md` §7 | T5 | Done |
| FEC-19 | P2: Fechamento | §7.2 | T6 | Done |
| FEC-20 | P2: Fechamento | §7.2 | T6 | Done |
| FEC-21 | Edge case | Req. 11.6 | T1 | Done |
| FEC-22 | Edge case | Req. 1.8 | T1 | Done |
| FEC-23 | Edge case | README existente | T1 | Done |
| FEC-24 | Edge case | método (`Where`) | T1..T6 | Done |

**Coverage:** 24 total, 24 mapped to tasks (T1–T6), 0 unmapped.

---

## Success Criteria

- [ ] Um leitor sem contexto chega, só pelo README, do clone a um catálogo carregado e a uma suíte verde.
- [ ] Toda mudança em `requirements.md` e `design.md` traz `(AD-NNN)` e nenhum nome citado deixa de existir no repositório.
- [ ] `design.md` mantém só os `⚠️ VERIFICAR` abertos, e cada remoção tem fonte em `verificar-resolvidos.md`.
- [ ] `decisoes-do-dono.md` registra o Req. 5.1 e qualquer outro requisito que a atualização tenha achado errado.
- [ ] Gate full verde (nenhuma linha de código muda, a contagem de runs se mantém) e `validate_state.py` com 0.
