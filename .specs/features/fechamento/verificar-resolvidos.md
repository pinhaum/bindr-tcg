# Verificar — Auditoria de Marcadores Resolvidos

Executado na task T4 para remover marcadores `⚠️ VERIFICAR` resolvidos de `design.md` e registrar a fonte de cada remoção, além de documentar os que permanecem abertos.

---

## Resolvidos (removidos de design.md)

| Local | Assunto | Texto resumido | Fonte verificada | Data |
|-------|---------|---|---|---|
| `design.md §4.1.1 (marcador removido)` | `unaccent` e IMMUTABILITY | `unaccent` é STABLE (não IMMUTABLE) em ambas as assinaturas, exige wrapper | `pg_proc` + `db/migrate/20260919120100_add_catalog_indexes.rb` linhas 2-19 | 2026-09-28 |
| `design.md §4.1.1 (marcador removido)` | `gin_trgm_ops` e `to_tsvector` | A forma de dois argumentos de `to_tsvector` é a única IMMUTABLE e indexável | `db/migrate/20260919120100_add_catalog_indexes.rb` linhas 6-12 + `test/models/catalog_indexes_test.rb` linhas 127-128, 160 | 2026-09-28 |

---

## Permanecem abertos

| Local | Assunto | Por que não foi resolvido |
|-------|---------|---|
| `.context/design.md:527, 537` | `image_url_large` — Req. 5.1 | Coluna vazia nas 4933 variantes. Fixture não traz campo. Teste `card_detail_test.rb:21` grava a mesma URL em ambos. Exige confirmação em fonte primária (site oficial ou documentação Bandai) de que existe URL de resolução maior. Não se deriva nem se adivinha URL. |
| `.context/design.md:627` | Regras de deck — Fase 2 | Afirmação sobre limite (1 Leader, 50 cartas, 4 cópias max por `card_number`, cores compatíveis) ainda não confirmada em regulamento oficial. Regra de jogo errada num validador é pior que nenhum validador. |

---

## Contagem após task T4

- **design.md**: `grep -c "⚠️ VERIFICAR" .context/design.md` → **3 ocorrências** correspondentes a **2 pendências abertas** (linhas 527, 537 — Req. 5.1; linha 627 — regras de deck)
- **requirements.md**: `grep -c "⚠️ VERIFICAR" .context/requirements.md` → **0 marcadores**

Total na codebase: 2 pendências abertas, ambas em design.md, ambas legítimas e sem data de resolução prevista.
