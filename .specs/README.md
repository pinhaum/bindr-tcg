# `.specs/` — convivência com `.context/`

Este projeto tem **dois** diretórios de especificação, de propósito. Ver AD-005
em `STATE.md`.

| Diretório | Papel | Fonte de verdade para |
| --------- | ----- | --------------------- |
| `.context/` | Documentos originais do projeto, em português, com convenções próprias (`⚠️ VERIFICAR`, `DECISÃO PENDENTE`, P1–P7) | Requisitos, design e plano de tasks |
| `.specs/` | Recorte por feature no formato do fluxo spec-driven, log de decisões e artefatos de verificação | Decisões (AD-NNN), handoff entre sessões, relatórios do Verifier |

**Em caso de divergência, `.context/` vence.** Os IDs `CAT-NN` em
`features/catalogo/spec.md` apontam para os requisitos numerados de
`.context/requirements.md`.

## Regra prática ao executar uma task

1. A task vem de `.context/tasks.md`, na ordem.
2. `features/catalogo/tasks.md` traz a mesma task com dependências e gate explícitos.
3. Ao concluir, **marcar nos dois arquivos** e commitar junto com o código.

## Validadores

```bash
SKILL=~/.claude/skills/tlc-spec-driven
python3 $SKILL/scripts/validate_spec.py  .specs/features/catalogo/spec.md
python3 $SKILL/scripts/validate_tasks.py .specs/features/catalogo/tasks.md
python3 $SKILL/scripts/validate_state.py catalogo   # só depois que houver validation.md
```

`validate_state.py` falha até a feature terminar e o Verifier escrever
`features/catalogo/validation.md` — é o gate de conclusão, não de progresso.

## Features

- `features/catalogo/` — ingestão, busca, filtros, grade e detalhe (Req. 1–5).
- Coleção, wishlist, progresso e CSV (Req. 6–10) entram como feature própria
  quando a fase 4 de `.context/tasks.md` começar.
