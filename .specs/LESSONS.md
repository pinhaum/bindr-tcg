# LESSONS - auto-maintained by scripts/lessons.py

> Machine-owned. Do NOT hand-edit. Changes are overwritten on the next `lessons.py` write.
> Canonical state lives in `.specs/lessons.json`. Edit lessons only via the script.
> promote_threshold=2 distinct features · window_days=45 · quarantine_threshold=2

## Confirmed (load these at Specify/Design)

Corroborated across multiple features. Safe to apply as guidance.

_none_

## Candidates (under observation - do NOT load as guidance yet)

Seen once or not yet corroborated. Tracked, not trusted.

### L-001 - Conversor string→número: testar o caminho da string NÃO-numérica, não só nil e vazio; a guarda de nil responde antes e mascara o mutante que devolve 0 no lugar de nil.
- signal: `surviving_mutant` · recurrence: 1 feature(s) · scope: `ingestion/normalize` · harmful: 0
- features: catalogo
- evidence: app/services/ingestion/normalize.rb:189 (mutante M10) (ingestion/normalize)
- last seen: 2026-09-19T21:52:58Z

### L-002 - Quando o spec proíbe um sentinela (0 para ausência), declarar a proibição para todos os campos numéricos, não só o exemplo citado — senão os demais campos ficam sem critério de aceite.
- signal: `spec_precision_gap` · recurrence: 1 feature(s) · scope: `spec/edge-cases` · harmful: 0
- features: catalogo
- evidence: .specs/features/catalogo/spec.md (Edge Cases) — proibição de sentinela citada só para counter (spec/edge-cases)
- last seen: 2026-09-19T21:53:12Z

## Quarantined (failed when applied - ignore)

A confirmed lesson that recurred alongside failure. Kept for the maintainer to review.

_none_
