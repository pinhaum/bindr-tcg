# ADR 001 — Fonte de dados do catálogo

- **Status:** aceita
- **Data:** 2026-09-19
- **Resolve:** P1 (`design.md` §9), task 0.1
- **Decisão:** usar **`hugoprudente/optcgjson`** (`output/*.json`) como fonte do catálogo.

## Contexto

O catálogo não será digitado à mão (`product.md` §5.2). A escolha da fonte muda o
design da ingestão inteira, então é pré-requisito de qualquer código de domínio.

O critério que separa as opções não é cobertura nem conveniência de formato: é se
a fonte **preserva a distinção `Card` × `CardVariant`**. Colapsar as duas destrói
metade do sentido do produto e é o erro mais caro de corrigir depois.

## Opções avaliadas

Todas verificadas por requisição real em 2026-09-19, não por documentação.

### 1. apitcg.com — REST autenticada

- **Auth:** exige `x-api-key`; sem chave devolve `401` (verificado). Não há chave
  disponível no ambiente hoje.
- **Variantes:** **não distingue.** O contrato (`openapi.json`, schema `Product`)
  não expõe nenhum identificador de impressão; `_id` é auto-incremental, portanto
  instável entre reimportações — inadequado como chave natural.
- **Campos ausentes:** `Counter` e `Trigger` não existem no contrato. `attributes`
  é um mapa de strings cujas chaves variam por jogo.
- **Divergências** entre `docs/pesquisa/apitcg.md` e o OpenAPI real: `_id` é
  inteiro (não string); `images` é array (não objeto); `Subtypes` é string
  `"A;B"` (não array `Traits`); `Attribute` é singular (não `Attributes`);
  o texto de efeito é `Description`, com HTML embutido.
- **Preços:** `markets.tcgplayer.prices` e `/api/history-prices/{id}` existem —
  relevante para a Fase 3, não para a Fase 1.

### 2. dotgg.gg — JSON aberto

- **Auth:** nenhuma. 3,1 MB, 5538 cartas numa requisição.
- **Variantes:** **não distingue.** 5538 registros para 5538 `id` distintos, um
  por `card_number`. Descartada por isto.
- Tem `Counter` e `Trigger` como campos próprios, e preços (`price`, `cmPrice`).

### 3. hugoprudente/optcgjson — dataset versionado (escolhida)

- **Origem:** scraping do **site oficial da Bandai**, com CI semanal
  (`weekly-sync.yml`) que commita `output/` quando os dados mudam.
- **Auth:** nenhuma. `output/AllSets.json` = 12 MB com o catálogo inteiro.
- **Cobertura:** 62 sets (até OP17), 2815 cartas, 4915 variantes.
- **Variantes: preservadas.** `OP01-001` e `OP01-001_p1` são registros distintos
  com o mesmo `number`, cada um com `imageUrl` própria e flag `isParallel`.
  Em OP01: 121 cartas → 154 variantes, 32 cartas com múltiplas impressões.
- `counter` vem `null` quando não se aplica (64 de 154 em OP01), preservando a
  distinção NULL ≠ 0 exigida pelo modelo.
- **Licença:** o repositório **não declara licença** (verificado via API do
  GitHub). Uso pessoal e não comercial, consistente com `product.md` §5.1.

## Decisão e consequências

- **`variant_code` = campo `id` da fonte** (`OP01-001_p1`). Estável entre
  execuções porque deriva do código oficial da carta, não de ordem de inserção.
  **Isto resolve P5 sem hash derivado** e elimina a parte que o design apontava
  como a mais frágil.
- `card_number` = campo `number`; a relação `number` → vários `id` é o eixo
  `Card` → `CardVariant`, já materializado na fonte.
- O estágio Normalize passa a ter pouco trabalho de adivinhação: `color`,
  `attribute` e `feature` já vêm como arrays, então **não há split por `;`** como
  seria necessário na apitcg.
- **Risco assumido:** a fonte é um scraper mantido por uma pessoa, sem licença
  declarada. Mitigação em três camadas: o estágio Fetch salva o payload bruto em
  disco antes de processar (Req. 1.8), então o catálogo é reconstruível sem rede;
  a ingestão busca uma **revisão fixada** (commit ou tag), nunca `main`, de modo
  que a CI semanal do repositório não altera o comportamento da importação sem um
  ato explícito (Req. 1.9 e 1.11); e trocar de fonte significa reescrever só o
  Normalize.
- **Fase 3 (preços) não tem fonte aqui.** optcgjson não traz preço. Quando a Fase
  3 chegar, apitcg ou dotgg voltam à mesa só para esse fim.

## Fixtures

- `spec/fixtures/optcgjson-subset.json` — OP01 (set completo), OP13, PRB01, ST01 e
  ST16 (679 variantes), escolhidos por conterem os dois casos-limite abaixo.
- `spec/fixtures/apitcg-openapi.json` — contrato da opção descartada, como prova.

## Casos-limite achados na amostra (entram como teste)

1. **`P-029_r1` aparece em dois sets** (PRB01 e ST16), mesma imagem e raridade.
   É uma promo distribuída em dois produtos, não um defeito. Consequência:
   `variant_code` é único **globalmente**, mas a relação variante↔set não é 1:1 —
   a ingestão não pode assumir dono exclusivo ao carregar `AllSets.json`.
2. **`attribute: "?"`** em OP13-079 (Imu), nas duas impressões. É o valor real
   publicado pela Bandai. Confirma manter `rarity` e attributes como **texto,
   nunca enum**.
