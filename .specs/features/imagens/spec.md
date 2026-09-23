# Especificação — Imagens servidas pela aplicação (§3.6)

Recorte da feature `imagens` sobre `.context/tasks.md` §3.6,
`.context/design.md` §7 e `.context/requirements.md` Req. 11.7. Em
divergência, `.context/` vence (AD-005).

A feature é governada por **AD-012**, que supersede a AD-004. A decisão não se
reabre aqui: cache em disco sob demanda, servido pela aplicação, sem Postgres e
sem Active Storage.

## Problem Statement

A grade e o detalhe do catálogo apontam o `<img>` para `image_url`, hotlink de
`asia-en.onepiece-cardgame.com`. Toda imagem dessa origem responde
`Cross-Origin-Resource-Policy: same-site`, e o navegador descarta a resposta em
qualquer página fora de `*.onepiece-cardgame.com`: o placeholder aparece em
**100% das cartas**. Verificado em 2026-09-22. Nenhum teste pegou porque
`curl` e os testes de HTML renderizado não aplicam CORP.

Esta feature faz a própria aplicação entregar a imagem ao navegador (Req. 11.7):
uma rota pública por `variant_code` baixa a arte servidor-a-servidor na primeira
requisição, grava em disco e serve do disco dali em diante. O risco desta
feature não é perder dado — é abrir **SSRF** e **path traversal** num endpoint
público que faz requisição de saída e escreve arquivo.

## Goals

- [x] O navegador recebe a arte das cartas pela origem da aplicação, na grade e no detalhe.
- [ ] Cada imagem é baixada da fonte no máximo uma vez com sucesso; as seguintes saem do disco.
- [ ] Nenhum dado do request decide para onde a aplicação faz requisição de saída nem onde grava arquivo.
- [ ] Falha da fonte vira placeholder, nunca 500, e não envenena o cache.
- [ ] Nenhum teste toca a rede.

## Out of Scope

| Feature | Reason |
|---|---|
| `image_url_large` e o Req. 5.1 ("imagem em resolução maior") | Pendência separada, registrada em `design.md` §7: a fonte não traz campo de imagem maior e a coluna está vazia nas 4933 variantes. O detalhe passa a servir a mesma imagem da grade. |
| Qualquer mudança de CSS | `catalog.css` é da feature `interface` (T4 e T5 em aberto) e é objeto de teste. O placeholder atual já funciona por camada; a feature não precisa de CSS. |
| Download na ingestão ou pré-aquecimento do cache | AD-012: sob demanda, custo proporcional ao que é visto; a ingestão continua sem rede para imagem. |
| Invalidação automática quando a fonte troca a arte | `design.md` §7: apagar o arquivo basta. Sem ETag nem revalidação. |
| Cache compartilhado entre containers | AD-012 trade-off (5): aceito enquanto houver um container só. |
| Redimensionamento, conversão de formato ou thumbnails | Nenhum requisito pede. |

## Assumptions & Open Questions

| Assumption/decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| Unicidade de `variant_code` | Busca por `CardVariant.find_by(variant_code:)` | O índice único é `(card_id, variant_code)`, não `variant_code` sozinho; mas o código embute o `card_number` (AD-001). Medido: 4933 variantes, **0** `variant_code` duplicado | Sim — medido no banco de desenvolvimento |
| Formato aceito de `variant_code` | `\A[A-Za-z0-9]+(-[A-Za-z0-9]+)*(_[a-z0-9]+)?\z` | Medido: os 4933 códigos casam o padrão (formas `OP01-001`, `OP01-001_p1`, `P-029_r1`, `ST01-001`). Exclui `/`, `.`, `..`, espaço e qualquer byte fora de alfanumérico, `-` e `_` | Sim — medido |
| Host permitido | Somente `asia-en.onepiece-cardgame.com`, esquema `https` | Medido: as 4914 variantes com `image_url` usam esse host. O host fica numa constante do serviço; qualquer outro host, esquema, porta diferente de 443 ou URL malformada é recusada antes do fetch | Sim — medido |
| Extensão do arquivo | Derivada do caminho de `image_url`, dentro de uma lista fechada (`.png`, `.jpg`, `.jpeg`, `.webp`); fora dela, recusa | Medido: 4914 de 4914 são `.png`. A lista fechada impede que a URL do banco decida um sufixo arbitrário no disco | Sim — medido |
| Validação do corpo baixado | Status 200 e corpo não vazio; `Content-Type` da resposta derivado da extensão, não repassado da fonte | O que o app serve é decidido pelo app. Não se inspeciona bytes mágicos: o host já é restrito à fonte oficial | Sim |
| Timeouts | Abertura e leitura curtos (ordem de segundos), não os 10 s / 120 s da ingestão | O fetch acontece dentro de uma requisição do navegador; a ingestão baixa um JSON grande fora de requisição | Sim |
| Cliente HTTP | `Net::HTTP`, no mesmo padrão injetável de `Ingestion::Fetch::NetHttpClient` (`get(url)` → `[status, corpo]`), sem gem nova | Pedido explícito; é o padrão do projeto para isolar a rede em teste | Sim — `app/services/ingestion/fetch.rb` |
| Redirecionamento da fonte | Não é seguido: qualquer status diferente de 200 é falha | Seguir redirect reabriria SSRF por um `Location` que o app não confere | Sim |
| Status de erro | Variante inexistente, formato inválido ou sem `image_url`: **404**. Falha, timeout ou URL recusada: **502**. Corpo vazio em todos | O `<img>` não pinta nada com erro, e o placeholder atrás dele aparece (Req. 2.3). 404 vs. 502 separa "não existe" de "fonte falhou" para quem lê log | Sim |
| Cache HTTP | `Cache-Control: public, max-age` de um ano | `design.md` §7: "cache HTTP longo"; o arquivo só muda se a arte mudar sob o mesmo código | Sim |
| Escrita concorrente | Arquivo temporário único por escrita no mesmo diretório + `File.rename` | Duas requisições simultâneas da mesma carta nunca servem arquivo pela metade; o último `rename` vence e ambos são idênticos | Sim — `design.md` §7 |
| Diretório de cache | `storage/card_images/`, injetável no serviço para que o teste use diretório temporário | `.gitignore` já cobre `/storage/*`; teste não suja o `storage/` real | Sim |
| Autorização | `allow_unauthenticated_access` no controller | Catálogo é público (Req. 6.3); a imagem aparece para o anônimo | Sim — `CatalogController` é o precedente |
| Verificação visual | Integração sobre HTML e resposta HTTP, mais verificação do dono no navegador dele antes do PASS | Não há navegador no container; CORP só se prova em navegador real | Sim — `CLAUDE.md` |

**Open questions:**

- ⚠️ VERIFICAR — **Req. 5.1 ("imagem em resolução maior") é pendência aberta.**
  Fora do escopo de implementação desta feature; não atendido hoje. Fatos
  medidos em 2026-09-22:
  - `image_url_large` está vazio nas **4933** variantes do banco de
    desenvolvimento (0 com valor), e nenhum código de `app/` ou `lib/` grava a
    coluna.
  - A fixture `spec/fixtures/optcgjson-subset.json` não traz campo de imagem
    maior: o único campo de imagem é `imageUrl`.
  - `test/integration/card_detail_test.rb:21` grava a mesma URL em `image_url`
    e `image_url_large` e por isso **não prova nada** sobre imagem maior.

  Continua `⚠️ VERIFICAR` até alguém confirmar em fonte primária se existe uma
  URL de resolução maior e qual é. Não se deriva nem se adivinha URL.

## User Stories

### P1: Arte real na grade e no detalhe ⭐ MVP

**User Story**: Como colecionador, quero ver a arte das cartas no catálogo, para reconhecê-las de relance.

**Why P1**: É o Req. 11.7 e a razão de a feature existir; sem ele a grade e o detalhe não mostram nenhuma arte.

**Acceptance Criteria**:
1. WHEN uma variante tiver `image_url` THEN the system SHALL renderizar o `<img>` da grade e do detalhe com `src` apontando para `GET /card_images/:variant_code` da própria aplicação, e nunca para `image_url`.
2. WHEN uma variante não tiver `image_url` THEN the system SHALL renderizar apenas o placeholder, sem `<img>` (Req. 2.3).
3. The system SHALL manter `loading="lazy"` no `<img>` da grade (Req. 11.2).
4. WHEN `GET /card_images/:variant_code` for requisitado sem sessão THEN the system SHALL responder sem redirecionar para autenticação.

### P1: Cache em disco sob demanda ⭐ MVP

**User Story**: Como dono da aplicação, quero que cada imagem seja baixada uma vez e servida do disco, para não depender da fonte a cada visualização.

**Why P1**: Sem cache cada tile da grade vira uma requisição de saída; é o que AD-012 decide.

**Acceptance Criteria**:
1. WHEN a imagem de uma variante não estiver em disco THEN the system SHALL baixar `image_url` servidor-a-servidor, gravar em `storage/card_images/<variant_code>.<ext>` e responder 200 com os bytes baixados.
2. WHEN a imagem já estiver em disco THEN the system SHALL responder 200 com o arquivo sem fazer requisição de saída.
3. The system SHALL gravar o arquivo por arquivo temporário seguido de `rename`, de modo que o caminho final nunca contenha arquivo parcial.
4. The system SHALL responder com `Content-Type` derivado da extensão e `Cache-Control` público com validade de um ano.

### P1: Endpoint sem SSRF e sem path traversal ⭐ MVP

**User Story**: Como dono da aplicação, quero que um endpoint público com requisição de saída não possa ser usado para alcançar outro host nem escrever fora do diretório de cache.

**Why P1**: É a superfície de ataque que a feature cria (AD-012 trade-off 4); sem ela a feature não pode ir ao ar.

**Acceptance Criteria**:
1. The system SHALL obter a URL de saída exclusivamente de `card_variants.image_url`; nenhum parâmetro do request entra na URL.
2. WHEN `image_url` tiver host diferente de `asia-en.onepiece-cardgame.com`, esquema diferente de `https`, porta diferente de 443 ou for malformada THEN the system SHALL recusar sem fazer requisição de saída e responder erro sem imagem.
3. WHEN `variant_code` não casar o formato aceito THEN the system SHALL responder 404 sem consultar a fonte e sem tocar o disco.
4. WHEN a extensão de `image_url` estiver fora da lista fechada THEN the system SHALL recusar sem fazer requisição de saída.
5. WHEN a fonte responder redirecionamento THEN the system SHALL tratá-lo como falha, sem seguir o `Location`.

### P1: Falha vira placeholder e não é cacheada ⭐ MVP

**User Story**: Como colecionador, quero ver o placeholder quando a arte não puder ser obtida, e ver a arte assim que a fonte voltar.

**Why P1**: Falha cacheada deixaria a carta sem arte para sempre; falha como 500 poluiria a grade.

**Acceptance Criteria**:
1. WHEN o `variant_code` não existir no banco THEN the system SHALL responder 404 sem corpo de imagem.
2. WHEN a variante existir sem `image_url` THEN the system SHALL responder 404 sem corpo de imagem e sem requisição de saída.
3. WHEN a fonte responder status diferente de 200, corpo vazio, erro de rede ou timeout THEN the system SHALL responder 502 sem corpo de imagem.
4. WHEN o fetch falhar THEN the system SHALL não deixar arquivo final nem temporário no diretório de cache, e a requisição seguinte SHALL tentar a fonte de novo.

## Edge Cases

- WHEN duas requisições simultâneas pedirem a mesma imagem ausente, THEN ambas podem baixar, e o caminho final só recebe arquivo completo (rename atômico); nenhuma serve arquivo pela metade.
- IF o arquivo em disco for apagado à mão, THEN a próxima requisição baixa de novo — é o mecanismo de invalidação de `design.md` §7.
- IF a ingestão marcar a variante como ausente da fonte, THEN a imagem continua servida se estiver em disco ou se `image_url` ainda existir; a ingestão não deleta (Req. 1.7).
- WHEN `variant_code` vier com `.png` ou outro sufixo na URL, THEN o formato recusa (o ponto não é aceito) — a rota não tem formato.
- IF a variante tiver `image_url_large`, THEN ela é ignorada nesta feature (Out of Scope).

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| IMG-01 | `<img>` aponta para a rota da aplicação, nunca para `image_url` (Req. 11.7, 2.1, 5.2) | 3.6 | Done |
| IMG-02 | Sem `image_url`, só placeholder (Req. 2.3) | 3.6 | Done |
| IMG-03 | Lazy loading mantido na grade (Req. 11.2) | 3.6 | Done |
| IMG-04 | Rota pública, sem sessão (Req. 6.3) | 3.6 | Done |
| IMG-05 | Primeira requisição baixa e grava; seguintes servem do disco | 3.6 | Done |
| IMG-06 | Escrita atômica (temporário + rename) | 3.6 | Done |
| IMG-07 | `Content-Type` pela extensão e cache HTTP de um ano | 3.6 | Done |
| IMG-08 | URL de saída só do banco; host, esquema e porta restritos (SSRF) | 3.6 | Done |
| IMG-09 | `variant_code` validado por formato antes de virar caminho | 3.6 | Done |
| IMG-10 | Extensão em lista fechada; redirect não é seguido | 3.6 | Done |
| IMG-11 | Inexistente ou sem `image_url` → 404 sem imagem | 3.6 | Done |
| IMG-12 | Falha ou timeout da fonte → 502 sem imagem, nada gravado | 3.6 | Done |
| IMG-13 | Testes sem rede (Req. 11.5, por analogia) | 3.6 | Done |

**Coverage:** 13 total, 13 mapeados a T1–T3.

## Success Criteria

- [x] O dono abre a grade no navegador e vê arte real, sem placeholder, nas cartas com `image_url`.
- [x] Existe teste que prova que o segundo pedido da mesma imagem não chama o cliente HTTP.
- [x] Existe teste que prova que uma `image_url` com host alheio não chama o cliente HTTP.
- [x] Existe teste que prova que `variant_code` com `..`, `/` ou `.` responde 404 sem tocar disco nem rede.
- [x] Existe teste que prova que falha da fonte não deixa arquivo no diretório de cache.
- [x] Os testes de placeholder de `catalog_grid_test.rb` e `card_detail_test.rb` continuam passando e provando o Req. 2.3.
- [x] `bin/rails test`, `bin/rubocop` e `bin/brakeman` limpos.
