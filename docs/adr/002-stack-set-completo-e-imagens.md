# ADR 002 — Stack, definição de "set completo" e cache de imagens

- **Status:** aceita
- **Data:** 2026-09-19
- **Resolve:** P3, P4, P6 (`design.md` §9), task 0.3
- **Depende de:** ADR 001 (fonte de dados)

Com isto, P1–P7 estão todas decididas e a Fase 1 está desbloqueada para código.

---

## P4 — Stack: Rails 8 + Hotwire + PostgreSQL

**Decisão:** o default proposto pelo design, confirmado.

Razões, na ordem em que pesam:

- **PostgreSQL é requisito de design, não preferência.** `design.md` §4 apoia a
  busca inteira em `pg_trgm` + GIN, `unaccent` e `tsvector`, e os filtros em
  arrays Postgres com índice GIN. Trocar o banco reescreve o subsistema de busca.
- **Hotwire cobre o Req. 7.2** — incremento/decremento em ação única, sem
  formulário e sem recarregar a página — sem introduzir uma SPA. É o caso de uso
  canônico de Turbo Streams.
- **Ambiente já existe.** Há dois projetos Rails 8 em `~/lab/ruby` (`store`,
  `spotcode`), então toolchain e familiaridade não são custo novo.
- O Req. 11.6 (subida em um comando) é atendido por `docker-compose` com app +
  Postgres.

**Alternativa considerada:** Next.js + Prisma + Postgres (há cinco apps Next em
`~/lab/next`). Descartada porque Prisma tem suporte limitado a arrays Postgres
com GIN e a `pg_trgm` — exatamente o núcleo do design de busca. Boa parte das
consultas do Req. 3 e 4 cairia em SQL cru, perdendo a vantagem do ORM sem ganhar
nada.

**Revalidação:** a task 3.4 mede o p95 do filtro combinado (Req. 11.1, < 500ms).
Se falhar, a saída é otimizar índice e consulta — **não** trocar de stack.

---

## P3 — "Set completo" = variantes base; parallels em métrica separada

**Decisão:** o default sugerido, agora sustentado por dados da fonte.

A ingestão recebe os dois números prontos, e eles são confiáveis:

- `baseSetSize` — impressões base do set.
- `totalSetSize` — todas as impressões, parallels incluídos.
- Verificado em **todos os 62 sets**: `totalSetSize` é igual à contagem real de
  registros, e nenhum set deixa de declarar os dois campos.

Portanto as duas métricas saem sem cálculo derivado nem heurística.

**O que decidiu o caso:** sob a leitura "todas as variantes", sets dominados por
impressões especiais ficam permanentemente perto de zero. Em
`LimitedProductCard`, 171 de 192 registros são parallels — o progresso travaria
em ~11% por construção, o que não informa nada ao colecionador. A leitura por
variantes base responde a pergunta que o Req. 9 existe para responder ("o que
falta caçar"), e o número de parallels continua visível como métrica separada
para quem persegue completar tudo.

**Consequência para o Req. 9:** o percentual principal usa `baseSetSize` como
denominador; a contagem de parallels possuídos aparece ao lado, nunca somada ao
percentual principal. `requirements.md` §9 foi atualizado e o `DECISÃO PENDENTE`
removido.

---

## P6 — Sem cache de imagens na Fase 1

**Decisão:** hotlink direto de `imageUrl` (`onepiece-cardgame.com`), medir, e só
reconsiderar se doer.

- Coerente com `product.md` §5.1, que prefere **referenciar** imagens da fonte
  original a redistribuir os arquivos.
- Custo zero de storage, invalidação e pipeline de download — nenhum deles é
  requisito hoje.
- O Req. 11.2 (lazy loading) e o Req. 2.2 (placeholder com nome e código quando a
  imagem falha) já cobrem o comportamento degradado. O placeholder deixa de ser
  detalhe de robustez e passa a ser **a mitigação desta decisão**.

**Risco assumido:** se a Bandai bloquear hotlink ou o servidor sair do ar, a
grade fica sem arte. Sintoma visível, reversível, e sem perda de dado do usuário
— a coleção não depende de imagem. Cache local entra como resposta a um problema
medido, não como precaução antecipada.
