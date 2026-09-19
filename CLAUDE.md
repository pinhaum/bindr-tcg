# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Estado atual: spec-only, sem código

Este repositório contém **apenas documentos de especificação** (`.context/`) e um
README de uma linha. Não existe código, stack escolhida, gerenciador de pacotes,
suíte de testes ou build. **Não há comandos de build/lint/test para documentar
ainda** — eles só existirão depois da task 1.1.

Consequência prática: a resposta certa para "implemente X" quase sempre é
verificar antes se as pendências bloqueantes já foram resolvidas (ver abaixo).

## O que é o Bindr

Galeria de cartas do One Piece Card Game (OPTCG) + registro de coleção pessoal.
Uso pessoal, não comercial. Fase 1 (MVP) = catálogo navegável com busca/filtros,
coleção por variante, wishlist, progresso por set, import/export CSV e pipeline de
ingestão. Deck builder é Fase 2; preços são Fase 3 — ver `.context/product.md` §4
para os non-goals explícitos.

## Método de trabalho: spec-driven

O fluxo é `requirements` → `design` → `tasks`, documentado em `.context/README.md`.
Regras que valem para qualquer sessão de trabalho aqui:

- **Uma task por vez**, em ordem, de `.context/tasks.md`. Não abrir a próxima com a
  anterior incompleta. Marcar o checkbox ao terminar.
- **Toda task termina com código que roda e teste que passa.** "Estrutura criada"
  não conta como task concluída.
- **Se um requisito se mostrar errado durante a execução, pare e corrija
  `requirements.md`** antes de continuar. Não improvisar no código — corrigir só o
  código desalinha o spec e destrói o valor do método.
- Mudança de escopo volta ao documento de origem e se propaga para baixo.

### Convenções nos documentos

- `SHALL` / `DEVE` — requisito obrigatório e testável.
- `⚠️ VERIFICAR` — afirmação sobre o jogo, uma API ou uma biblioteca que **não foi
  confirmada**. Precisa de validação em fonte primária antes de virar código. Não
  tratar como fato.
- `DECISÃO PENDENTE` — ponto onde o design deliberadamente não escolheu.

Os documentos estão em português brasileiro. Escrever novos documentos e commits
na mesma língua.

## Pendências que bloqueiam código

`.context/design.md` §9 lista P1–P7. **P1 e P2 bloqueiam qualquer linha de código
de domínio** e correspondem às tasks 0.1 e 0.2:

| # | Pendência | Default sugerido |
|---|---|---|
| P1 | Fonte de dados do catálogo | sem default — precisa investigação |
| P2 | Campos, raridades, sets e attributes reais do jogo | sem default |
| P3 | Definição de "set completo" | variantes base; parallels em métrica separada |
| P4 | Stack | Rails 8 + Hotwire + PostgreSQL |
| P5 | `variant_code` estável quando a fonte não fornece | hash determinístico de `card_number + rarity + art_kind` |
| P6 | Cache de imagens na Fase 1 | não; aceitar hotlink e medir |
| P7 | `DON!!` entra no catálogo | não na Fase 1 |

Antes de escrever schema ou ingestão, confirmar que 0.1/0.2 foram feitas. O
glossário de domínio em `product.md` §6 é o entendimento do autor sobre o jogo,
**não fonte confirmada** — a task 0.2 existe para corrigi-lo contra a lista oficial.

## Arquitetura (de `.context/design.md`)

Três subsistemas, e a separação entre eles é o eixo do design inteiro:

```
Fonte externa → INGESTÃO (Fetch → Normalize → Upsert) → CATÁLOGO → COLEÇÃO
                                                     (read-only)  (escrita do usuário)
```

**O catálogo é regenerável; a coleção é insubstituível.** Todas as invariantes
abaixo existem para impedir que a ingestão corrompa dados do usuário:

- A ingestão **não tem operação de delete**. Carta ausente da fonte é marcada,
  nunca removida (Req. 1.7).
- **Nenhuma foreign key da coleção usa delete em cascata** — deletar uma variante
  apagaria em cascata o registro do usuário.
- Upsert por chave natural (`card_number` para cartas, `card_id + variant_code`
  para variantes), nunca `create` cego. Cada registro em transação própria; erro em
  um registro vai para `import_runs.error_log` e o loop continua.
- O teste mais valioso do projeto (task 2.6): rodar a ingestão duas vezes com um
  `collection_item` existente e verificar que a quantidade continua intacta.

### `Card` ≠ `CardVariant` — a decisão central do modelo

- **Card** = a carta do jogo, identificada por `card_number` (`OP01-001`). É sobre
  ela que as regras e textos falam.
- **CardVariant** = uma impressão física específica (base, alternate art, parallel,
  manga, promo). Mesmo `card_number`, mesmo efeito, **objeto de coleção diferente**.

Coleção e wishlist referenciam **variantes**. Busca e filtros operam sobre
**cartas**, exibindo variantes agregadas. Colapsar as duas entidades destrói metade
do sentido do produto e é o erro mais caro de corrigir depois. Preço (Fase 3) e
deck (Fase 2) dependem dessa mesma distinção: deck referencia `cards`, coleção
referencia `card_variants`.

### Isolamento da fonte externa

Todo conhecimento sobre o formato da fonte vive **no estágio Normalize e em nenhum
outro lugar**. Trocar de fonte de dados deve significar escrever um normalizador
novo, nada mais. O estágio Fetch salva o payload bruto em disco antes de processar
— é isso que permite reprocessar sem rede e transforma o payload em fixture de
teste (Req. 11.5).

### Busca e filtros

Tudo em PostgreSQL, sem serviço de busca dedicado (dataset pequeno, consultas
estruturadas): `pg_trgm` + GIN para nome com tolerância a typo, `unaccent` para
acentos, `tsvector` para texto de efeito, e uma **consulta separada** para match
exato de `card_number` cujo resultado é prependido. Não tentar resolver ranking
exato dentro do full-text.

Um **único query object** traduz parâmetros de URL em consulta e serve tanto HTML
quanto JSON — é o único lugar que precisa de teste de filtro. Contrato em
`design.md` §4.2. Semântica: `OU` dentro de uma categoria, `E` entre categorias;
filtro de cor inclui multicoloridas. **Parâmetro desconhecido ou inválido é
ignorado, nunca causa erro** — uma URL compartilhada não pode dar 500 porque um
filtro foi renomeado.

### Detalhes de modelagem fáceis de errar

- `counter` **NULL ≠ 0**: "não tem counter" não é "counter de 0". Nunca usar 0 como
  sentinela.
- `colors`, `traits`, `attributes` como arrays Postgres + GIN (não tabelas de
  junção). `traits` vem de texto livre da fonte → **normalizar caixa e espaçamento
  na ingestão**, senão `"Straw Hat Crew"` e `"Straw hat crew"` viram traits
  distintos e o filtro fica furado.
- `rarity` como **texto, não enum** — a lista completa de raridades não está
  confirmada, e enum incompleto faz a ingestão explodir com um valor novo.
- `variant_code` precisa ser **estável entre execuções**, senão a idempotência
  quebra e o usuário perde o vínculo com a coleção. É a parte mais frágil do design.

### Autorização

**Toda** consulta a coleção ou wishlist parte do usuário da sessão, nunca de um ID
vindo do request. Isso satisfaz o Req. 6.5 por construção em vez de por verificação.
Catálogo é público; qualquer mutação exige sessão.

## Alvos não-funcionais que já têm task de validação

- Filtro combinado com busca: **p95 < 500ms** com catálogo completo (Req. 11.1,
  task 3.4). Se falhar, a saída é otimizar índice/consulta e depois hidratar
  filtros no cliente — **não** trocar de stack.
- Filtros do Req. 4 **sem full table scan**, verificável por plano de execução
  (Req. 11.3, task 2.2).
- Usável em viewport de **360px sem scroll horizontal** (Req. 2.5).
- Subida local em **um único comando documentado** (Req. 11.6).
