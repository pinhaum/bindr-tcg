# Decisões do Dono — Fechamento do MVP

Requisitos e achados que exigem confirmação ou decisão do dono do produto, porque a evidência não permite uma correção inequívoca dentro das regras do projeto.

---

## Decisões abertas

### Req. 5.1 — Imagem em resolução maior

**Requisito original:**

> Req. 5 (critério 1): "O sistema DEVE exibir uma página de detalhe com todos os campos conhecidos da carta e **a imagem em resolução maior**."

**Evidência de que não está sendo cumprido:**

1. **Coluna do banco vazia:** A migração `20260919120000_create_catalog_tables.rb` define a coluna `image_url_large` em `card_variants`, mas os 4933 registros carregados no banco de desenvolvimento têm `image_url_large = NULL`. A fixture `spec/fixtures/optcgjson-subset.json` não traz o campo `image_url_large` — possui apenas `imageUrl`.
2. **Sem geração de valor:** Nenhum código em `app/services/ingestion/normalize.rb` ou `app/` escreve na coluna.
3. **Teste passa com valores iguais:** `test/integration/card_detail_test.rb:21` grava a mesma URL em `image_url` e `image_url_large` no fixture de teste, logo não prova comportamento de imagem maior.
4. **Referência em `design.md`:** A seção §7 ("Imagens") registra na linha 527 com `⚠️ VERIFICAR`: "Não é atendido hoje e fica fora do escopo da AD-012."

**Fonte primária faltante:** 

Não há evidência em fonte primária (documentação oficial da Bandai, site da Bandai, regulamento do jogo) de que existe uma URL de imagem em resolução maior. O detalhe hoje usa `image_url` (a mesma da grade), e nenhuma API ou scraper comunitário fornece resolução maior.

**Opções:**

1. **Relaxar o requisito:** Alterar Req. 5.1 de "imagem em resolução maior" para "imagem de layout" (a atual `image_url` já atende a exibição em coluna própria no detalhe, conforme Req. 13.19). A especificação de tamanho era intenção, mas a fonte não oferece alternativa maior.

2. **Procurar fonte com resolução maior:** Investigar se `hugoprudente/optcgjson` (a fonte atual) tem ou poderia ter campo de imagem maior, ou se outra fonte de dados (apitcg.com, dotgg.gg, scraper novo) oferece esse campo. Nota: trocar de fonte reintroduz fragilidades resolvidas na AD-001.

**Pergunta ao dono:**

Qual das duas opções: relaxar Req. 5.1 para "imagem de layout", ou investigar fonte alternativa com resolução maior?

---

## Requisitos devolvidos como `blocked` por T2, T3 e T4

Nenhum. T2, T3 e T4 completaram sem retorno de requisito como errado ou incoerente.

---

## Corrigidos por AD

Nenhum requisito foi **alterado** em T2 e T3. Os commits `051d06a` (T2) e `0dd8b31` (T3) **acrescentaram informação** sobre requisitos existentes, cada adição citando a AD correspondente:

| Operação | Requisito | Commit | AD citada |
|----------|-----------|--------|-----------|
| Acrescentar | Req. 10.2 (substituição de quantidade no import) | 051d06a | AD-006 |
| Acrescentar | Req. 10.5 (staging entre pré-visualização e confirmação) | 051d06a | AD-007 |
| Acrescentar | Req. 10 (limite de 10.000 linhas) | 051d06a | AD-008 |
| Acrescentar | `design.md` §3 (tabela `collection_imports`) | 0dd8b31 | AD-007 |
| Acrescentar | `design.md` §6 (autorização do staging) | 0dd8b31 | AD-007 |
| Acrescentar | `design.md` §8.1 (regras de teste com relógio e GIN) | 0dd8b31 | AD-009, AD-010, AD-017, AD-018 |

**Nota:** `design.md` §9 inclui P8 (cores do jogo) como pendência aberta, não como mudança decorrente de uma AD. P8 é uma restrição técnica do design system, registrada em AD-011.

Nenhuma **mudança** (remoção ou substituição de texto existente) foi feita sem AD citada.
