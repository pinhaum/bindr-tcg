# Camada de apresentação — Especificação

## Problem Statement

O app tem doze telas funcionais e 1100 linhas de CSS, mas **nenhum token de cor**:
a folha não declara `color` nem `background-color` temáticos em lugar nenhum e
herda tudo do user-agent. Tamanhos de fonte são literais repetidos em seis valores
distintos, e vinte e três modificadores BEM foram escritos nas views e nunca
ganharam regra — entre eles `flash--notice` e `flash--alert`, que hoje deixam uma
mensagem de erro visualmente idêntica a uma de sucesso. Existe um design system
para este app (`.context/design.md` §11) que nunca foi aplicado.

## Goals

- [x] Todo valor de cor, tipografia, espaçamento e raio vem de token; zero literal
      duplicado nos blocos
- [x] Contraste verificado por teste automatizado nos pares texto/fundo, sem
      navegador
- [x] As 25 classes sem regra (15 modificadores + 10 elementos; a spec contava 23) passam a ter regra, e nenhum estado é
      comunicado apenas por cor
- [x] As verificações de 360px do Req. 2.5 continuam passando, byte a byte

## Out of Scope

| Feature | Reason |
|---|---|
| Tema claro | Design system define tema único escuro (`.context/design.md` §11.2); um claro exigiria valor novo para `on-accent` e `danger` já está no limite de contraste |
| Hexadecimais das seis cores do jogo | Pendência **P8**: precisam sair do material da Bandai, não de estimativa sobre a arte comprimida das cartas |
| Ícones | Nenhum conjunto escolhido; o design system manda escrever a palavra até haver decisão |
| Webfont | Grade de 2815 cartas com imagem cada (Req. 11.2; servidas pela aplicação desde a AD-012) — fonte na rota crítica competiria com o gargalo |
| Redesenho de fluxo ou marcação | Esta feature estiliza o que existe; nenhuma view muda de estrutura |
| Verificação real de viewport em navegador | Não há navegador no container; dívida registrada em `STATE.md` |
| Reorganizar ou dividir `catalog.css` | Seis testes asseveram sobre o texto do arquivo filtrando por prefixo de seletor |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| Fonte dos valores | Design system Bindr, copiado para `.context/design.md` §11 | Artifact é externo ao repo e pode mudar; `.context/` vence por AD-005 | y |
| Tema | Único, escuro | Decisão do design system, com justificativa de uso (arte saturada, celular perto do rosto) | y |
| Chips das seis cores enquanto P8 estiver aberta | Neutro: `border-strong` mais rótulo escrito | O design system proíbe preencher com `accent`, não proíbe ficar sem fill | y |
| Escopo de telas | Todas, em lotes verificados | Metade tokenizada e metade herdando cor do user-agent é pior que o estado atual | y |
| Modificadores BEM | Os 23, inclusive os decorativos | Já estão no HTML; `flash--alert` sem cor após declarar `danger` seria injustificável | y |
| Estratégia no `catalog.css` | Só acrescentar camada de tokens | Preserva os seis testes que leem a folha como texto; se um quebrar, o sinal é real | y |
| Valores de contraste do design system | Recalcular, não confiar | O design system declara 16 pares aprovados; o teste existe para provar, não para repetir | y |

**Open questions:** none — todas resolvidas ou registradas na tabela acima.

---

## User Stories

### P1: Interface que não disputa com a arte ⭐ MVP

**User Story**: Como colecionador em mesa de loja, com o celular perto do rosto e
um booster na outra mão, quero uma interface que não compita com a arte das cartas,
para achar o que procuro de relance.

**Why P1**: É o princípio do design system inteiro e o que torna as demais regras
verificáveis. Sem tokens não há nada a verificar.

**Acceptance Criteria**:

1. O sistema SHALL declarar todo valor de cor, tipografia, espaçamento e raio como
   custom property CSS em `:root`.
2. O sistema SHALL declarar `color-scheme: dark` e nenhuma regra
   `prefers-color-scheme`.
3. O sistema SHALL usar exatamente duas matizes — 228° em superfície, borda e
   tinta, 66° em ação — mais `danger` em 28° como única exceção.
4. O sistema SHALL renderizar toda interface sem sombra e sem gradiente.
5. WHERE um bloco BEM já existe em `catalog.css`, o sistema SHALL consumir tokens
   nele em vez de valores literais.
6. IF um valor literal duplicar um token existente THEN o sistema SHALL usar o
   token.

**Independent Test**: Abrir qualquer tela com `docker compose up` e ver fundo
azul-petróleo com ação em âmbar; `grep` na folha não encontra hex fora de `:root`.

---

### P2: Contraste provado, não afirmado ⭐ MVP

**User Story**: Como usuário com baixa visão, quero que todo texto tenha contraste
suficiente, para ler a tela sem esforço.

**Why P2**: O projeto já cobre semântica de acessibilidade em dezesseis arquivos de
teste; cor é a dimensão que falta e a única verificável sem navegador.

**Acceptance Criteria**:

1. The system SHALL atingir 4.5:1 em todo par de texto normal sobre seu fundo.
2. The system SHALL atingir 3:1 em texto a partir de 24px, borda de controle, anel
   de foco e ícone.
3. WHEN um par reprovar o limiar THEN o teste SHALL falhar nomeando o par e a razão
   medida.
4. The system SHALL usar `border` apenas como hairline decorativa, nunca em borda
   de controle, foco ou marca com significado.

**Independent Test**: `bin/rails test test/design/` passa; alterar um token para um
valor de baixo contraste faz o teste falhar nomeando o par.

---

### P3: Estado legível sem depender de cor ⭐ MVP

**User Story**: Como usuário que não discrimina cor, quero distinguir erro de
sucesso e possuída de faltante, para usar o app sem depender de matiz.

**Why P3**: É o único ponto desta feature que corrige defeito percebido —
`flash--notice` e `flash--alert` são hoje visualmente idênticos.

**Acceptance Criteria**:

1. WHEN uma mensagem for de erro THEN o sistema SHALL distingui-la de uma de
   sucesso por mais do que a cor.
2. WHILE uma variante estiver possuída, o sistema SHALL exibir badge com a
   quantidade; variante faltante SHALL não receber badge.
3. The system SHALL renderizar `card_number` e `variant_code` no estilo `code` em
   toda ocorrência, inclusive inline em texto corrido, exceto em mensagem de
   flash, que é texto puro (Req. 12.7, emendado em 2026-09-22).
4. The system SHALL renderizar o anel de foco sólido de 2px em `accent` com 2px de
   deslocamento.
5. The system SHALL não usar emoji em nenhum ponto da interface.
6. The system SHALL não preencher chip das seis cores do jogo com `accent`.

**Independent Test**: Provocar um flash de erro e um de sucesso e ver que diferem
por mais que matiz; uma variante com quantidade zero não exibe badge.

---

## Edge Cases

- IF um token for removido ou renomeado THEN o teste de contraste SHALL falhar em
  vez de passar silenciosamente sobre um par inexistente.
- IF a aplicação dos tokens introduzir largura fixa acima de 360px THEN as
  verificações existentes do Req. 2.5 SHALL falhar.
- WHEN uma imagem de carta falhar ao carregar THEN o placeholder SHALL ocupar
  exatamente a mesma caixa, sem reflow do layout.
- IF um par de contraste do design system reprovar no recálculo THEN a saída SHALL
  ser corrigir o valor do token, nunca afrouxar o limiar do teste.

---

## Requirement Traceability

| Requirement ID | Story | Origem em `.context` | Status |
|---|---|---|---|
| INT-01 | P1 | Req. 12.1 | Verified (T1, T4–T7) |
| INT-02 | P1 | Req. 12.2 | Verified (T1) |
| INT-03 | P1 | Req. 12.4 | Verified (T3) |
| INT-04 | P1 | Req. 12.5 | Verified (T3) |
| INT-05 | P2 | Req. 12.3 | Verified (T2, T12) |
| INT-06 | P3 | Req. 12.8 | Verified (T8, T10) |
| INT-07 | P3 | Req. 12.6 | Verified (T9, T10) |
| INT-08 | P3 | Req. 12.7 | Verified (T11) |
| INT-09 | P3 | Req. 12.9 | Verified (T12) |
| INT-10 | P3 | Req. 12.10 | Verified (T13) |
| INT-11 | P3 | Req. 12.11 | Verified (T13) |
| INT-12 | P1 | Req. 12.12 | Verified (T4, T7) |

**Coverage:** 12 no total, 12 verificados (Verifier PASS na rodada 3, `validation.md`), 0 sem origem.

---

## Success Criteria

- [x] Nenhum valor de cor, tamanho de fonte, espaçamento ou raio aparece literal
      fora de `:root`
- [x] Teste de contraste cobre todo par texto/fundo dos tokens e passa
- [x] As 25 classes sem regra (a spec contava 23) têm regra; erro e sucesso são distinguíveis sem cor
- [x] As seis verificações de 360px existentes passam sem edição
- [x] `bin/rails test && bin/rubocop` limpos
- [ ] Revisão visual aprovada pelo dono do produto em `docker compose up`
