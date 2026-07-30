# Bindr - Estrutura inicial

Conjunto de documentos para desenvolvimento spec-driven, no formato
`requirements` → `design` → `tasks`.

## Arquivos

| Arquivo           | Papel                                                                | Quando muda                       |
| ----------------- | -------------------------------------------------------------------- | --------------------------------- |
| `product.md`      | Contexto de produto persistente: visão, escopo, non-goals, glossário | Raramente                         |
| `requirements.md` | **O QUÊ.** Requisitos com critérios de aceitação testáveis           | Quando o escopo muda              |
| `design.md`       | **COMO.** Arquitetura, avaliação de stack, modelo de dados, decisões | Quando a solução técnica muda     |
| `tasks.md`        | **EM QUE ORDEM.** Plano de implementação incremental                 | Continuamente, durante a execução |

## Fluxo de trabalho

1. Revise e aprove `requirements.md`. **Não avance com requisito ambíguo** — o
   custo de corrigir isso no `design` é 10x maior.
2. Revise `design.md`. Resolva as **decisões pendentes** (seção 9) ou aceite
   explicitamente o default proposto.
3. Execute `tasks.md` uma task por vez. Cada task referencia os requisitos que
   satisfaz; ao terminar, marque o checkbox.
4. Mudou de ideia? Volte ao documento de origem (requirements ou design) e
   propague. Não corrija apenas o código — isso desalinha o spec e você perde o
   valor do método.

## Onde colocar no repositório

Sugestões (nenhuma é obrigatória):

```
.kiro/steering/product.md          # se usar Kiro
.kiro/specs/card-gallery/*.md
```

ou, agnóstico de ferramenta:

```
docs/specs/card-gallery/{requirements,design,tasks}.md
docs/product.md
```

> Não tenho certeza sobre os caminhos exatos que a versão atual do Kiro espera
> (`.kiro/specs/<feature>/`). Confira na documentação oficial da ferramenta
> antes de assumir. Os documentos em si são portáveis — funcionam com Claude
> Code, Cursor, ou lidos por humanos.

## Convenções usadas nos documentos

- `SHALL` / `DEVE` — requisito obrigatório e testável.
- `⚠️ VERIFICAR` — afirmação sobre o jogo, uma API ou uma biblioteca que **não
  foi confirmada** e precisa de validação em fonte primária antes de virar
  código.
- `DECISÃO PENDENTE` — ponto em que o design deliberadamente não escolheu.
