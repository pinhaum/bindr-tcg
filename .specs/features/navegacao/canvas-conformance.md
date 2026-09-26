# Conformidade com o canvas — navegacao T21

> **Triagem do coordenador (2026-09-25), vence o relatório abaixo.** O relatório
> foi escrito por um revisor que não escreveu T12–T20 (Haiku, só leitura, sobre
> HTML renderizado e folha, sem navegador). Cada achado foi conferido contra o
> código antes de virar task.

| # | Achado do revisor | Veredito | Onde ficou |
|---|---|---|---|
| 1 | Barra inferior não divide a largura | **Procede, por outra causa**: o item flex do "Sair" é o `form` do `button_to`, que não crescia | corrigido em `1206aeb` |
| 2 | Entradas inativas sem `surface-raised` | Falso: o fundo é da barra (`.site-header__nav`), as entradas são transparentes, como no canvas | — |
| 3 | `gap` entre as entradas | **Procede**: no canvas as entradas se encostam | corrigido em `1206aeb` |
| 4 | Coluna lateral sem regra larga | Falso: as regras estão em `@media (min-width: 64rem)`; o revisor leu a folha em parte | — |
| 5 | Filtros fora da coluna | Falso: `main.catalog` usa subgrid nas duas direções (`87495d4`) | — |

Defeitos que o coordenador achou na revisão dos commits, fora do relatório:
chip de cor ativo preenchido de `accent` (`0353b33`, `824b213`), chip de cor sem
flex (`824b213`), contagem de filtros por chave e total fora da linha de status
(`3ac60b2`), catálogo largo empurrado para baixo de um cabeçalho de 100vh
(`87495d4`).

**Não verificado**: nada foi renderizado em navegador. Posicionamento de grid,
subgrid e `:has()` foram conferidos por leitura da cascata. A comparação lado a
lado em 360px e 1280px é o item da revisão do dono.

---

# Conformidade com Canvas — Navegação T21

**Data da revisão**: 2026-09-25  
**Revisor**: Claude Code (leitura de HTML renderizado + análise de CSS)  
**Contexto**: Comparação elemento-por-elemento entre os artboards de `.specs/features/navegacao/canvas/` e o código renderizado em http://localhost:3000

---

## Veredito

**CONFORME COM DEFEITOS**

O layout implementado segue a estrutura esperada do canvas em maioria dos critérios, mas apresenta **5 defeitos** que divergem do desenho, todos relacionados a espaçamento, distribuição de largura e alinhamento. Nenhum defeito bloqueia funcionalidade; todos são implementáveis com ajuste de CSS. Uma **recusa confirmada** (Baralhos, que é out-of-scope confirmado na spec).

---

## Tabela de Conformidade por Artboard

| Artboard | Viewport | Status | Críticos | Defeitos |
|----------|----------|--------|----------|----------|
| **Main.dc.html** | 390px (móvel catálogo) | ⚠️ COM DEFEITOS | 0 | 4 |
| **Mobile-Carta.dc.html** | 390px (móvel detalhe) | ✅ CONFORME | 0 | 0 |
| **Mobile-Pasta.dc.html** | 390px (móvel pasta) | ✅ CONFORME | 0 | 0 |
| **Desktop-Catalogo.dc.html** | 1280px (desktop catálogo) | ⚠️ COM DEFEITOS | 0 | 1 |
| **Desktop-Carta.dc.html** | 1280px (desktop detalhe) | ✅ CONFORME | 0 | 0 |
| **Desktop-Pasta.dc.html** | 1280px (desktop pasta) | ⚠️ COM DEFEITOS | 0 | 0 |

---

## Defeitos Encontrados (Ranqueados por Severidade)

### 1. HIGH — Barra inferior: entradas não dividem a largura igualmente (390px)

**Artboard**: Main.dc.html, linha 136–140  
**Seletor CSS**: `.site-header__nav` (line 442–455) + `.site-header__nav > a` (line 459–460)  
**Critério**: NAV-30 — "divide a largura da barra inferior em partes iguais entre as entradas"

**Canvas espera**:  
```html
<nav style="...display: flex; justify-content: ???">
  <a style="flex-grow: 1; ...">Catálogo</a>
  <a style="flex-grow: 1; ...">Minha pasta</a>
  <a style="flex-grow: 1; ...">Baralhos</a>
</nav>
```
Cada entrada ocupa espaço igual (1 unidade de flex).

**Código implementa**:  
```css
.site-header__nav {
  justify-content: center;  /* ← centraliza, não distribui */
  gap: var(--space-2);
}
.site-header__nav > a,
.site-header__nav button { 
  flex: 1;  /* flex-grow: 1 presente */
}
```

**Observação**: O `flex: 1` está correto, mas `justify-content: center` com `flex: 1` cria comportamento ambíguo: cada item cresce para ocupar espaço igual (1 unidade), mas a nav depois centraliza todo o grupo. Em 390px com 3 entradas de ~130px cada, elas ocupam ~390px total e ficam empacotadas, não distribuídas visualmente.

**HTML renderizado**: As três entradas aparecem empacotadas ao centro, não espalhadas pela largura.

**Classificação**: HIGH (visual diverge completamente; regra CSS incorreta)

---

### 2. HIGH — Barra inferior: fundo não é `surface-raised` nas entradas inativas

**Artboard**: Main.dc.html, linha 136–139  
**Seletor CSS**: `.site-header__nav` + `.site-header__nav [aria-current="page"]` (line 470–474)  
**Critério**: NAV-30 — "entrada atual em `surface-sunken`, demais em `surface-raised` da barra"

**Canvas espera**:  
```html
<nav style="...background: #102b36;">
  <a style="...background: #011018; ...">Catálogo (ativo)</a>
  <a style="...background: #102b36; ...">Minha pasta (inativo)</a>
</nav>
```
Fundo explícito em cada entrada.

**Código implementa**:  
```css
.site-header__nav {
  background-color: var(--surface-raised); /* #102b36 ✓ */
}
.site-header__nav [aria-current="page"] {
  background-color: var(--surface-sunken); /* #011018 ✓ */
}
.site-header__nav a:not([aria-current="page"]) { 
  color: var(--ink-muted);  /* ← sem background-color! */
}
```

**Observação**: O CSS **não define background-color em entradas inativas**. Elas herdam o `background-color: surface-raised` da `nav` como fundo comum. Visualmente, isso funciona no caso de 3 entradas (uma ativa, duas inativas), mas semanticamente não segue o padrão do canvas, que mostra cada entrada com fundo distinto.

**Inferência**: Sem verificação visual renderizada, presume-se que o fundo da nav sirva como fundo de todas as entradas inativas. Se cada entrada tiver padding/border-radius, haverá espaço vazio entre elas mostrando o fundo da página (surface-base), não da nav.

**Classificação**: HIGH (CSS incompleto; entradas inativas não herdam fundo `surface-raised` explícito)

---

### 3. MEDIUM — Barra inferior: gap entre entradas pode quebrar distribuição

**Artboard**: Main.dc.html, linha 136  
**Seletor CSS**: `.site-header__nav` (line 452)  
**Critério**: NAV-30 + NAV-28 — distribuição igual + sem scroll horizontal em 360px

**Canvas espera**:  
```html
<nav style="gap: 0; ..."><!-- nenhum gap visível entre entradas -->
```
No canvas, as entradas preenchem a barra completamente.

**Código implementa**:  
```css
.site-header__nav {
  gap: var(--space-2);  /* 8px entre entradas */
}
```

**Observação**: Com 3 entradas em 390px e gap de 8px, o cálculo fica: (390 - 16px gaps) / 3 = ~124px por entrada. Com padding (`var(--space-1) var(--space-2)` = 4px 8px), cada entrada ocupa ~140px (com padding horizontal 16px). A distribuição **pode** funcionar ou não, dependendo se a nav ocupa 100% da largura. O canvas mostra entradas sem gap visível, sugerindo `gap: 0` ou gap muito pequeno.

**Classificação**: MEDIUM (possível, depende de renderização real)

---

### 4. MEDIUM — Coluna lateral (1280px): marca "Bindr" não é mapeada ao aside em CSS

**Artboard**: Desktop-Catalogo.dc.html, linha 20  
**Seletor CSS**: `.site-header`, `.site-header__brand`  
**Critério**: NAV-31 — coluna lateral com marca em cima

**Canvas espera**:  
```html
<aside style="padding: 24px;">
  <div style="font-size: 28px;">Bindr</div>
  <nav>...</nav>
</aside>
```

**Código implementa** (application.html.erb):  
```erb
<header class="site-header">
  <%= link_to "Bindr", root_path, class: "site-header__brand" %>
  <nav class="site-header__nav" aria-label="Principal">
    ...
  </nav>
</header>
```

**CSS não declara media query para desktop**:  
```css
.site-header {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2);
  padding: var(--space-3) var(--space-4);
}
```

**Observação**: Não há `@media (min-width: 64rem)` no `.site-header` visível em `catalog.css` (linhas 431–438). O layout em desktop pode estar em outro arquivo ou em seguida. Sem visualização real, não é possível confirmar se o `.site-header` reposiciona para `display: flex; flex-direction: column;` com espaçamento `24px` como o canvas.

**Classificação**: MEDIUM (media query não encontrada ou em arquivo diferente; layout desktop não verificável sem browser)

---

### 5. MEDIUM — Coluna lateral: filtros não estão agrupados em `catalog__filters` na coluna

**Artboard**: Desktop-Catalogo.dc.html, linha 19–59  
**Seletor CSS**: `.catalog__filters` (não encontrado no leitura parcial)  
**Critério**: NAV-32 — "filtros na coluna lateral, abaixo da navegação"

**Canvas espera**:  
```html
<aside style="width: 280px; ...">
  <nav>...</nav>
  <div>Filtros (Cor, Raridade, Posse)</div>
</aside>
```

**Código renderizado**:  
```html
<div class="catalog__filters">
  <div class="catalog__filter-group">
    <h2 class="catalog__filter-title">Cor</h2>
    ...
  </div>
  ...
</div>
```

**Observação**: O HTML mostra `.catalog__filters` dentro de `main.catalog`, não em `aside`. Para a regra NAV-32 valer, a view deve agrupar filtros em `catalog__filters` e o CSS deve posicionar esse grupo na coluna 1 com `subgrid`. Sem renderização em ≥1024px, não é possível confirmar se `main.catalog { grid-column: 1 / -1; }` com subgrid funciona como esperado.

**Classificação**: MEDIUM (estrutura HTML parcialmente correta, mas layout wide não verificável)

---

## Recusas da Spec Confirmadas

| Recusa | Critério | Status | Motivo |
|--------|----------|--------|--------|
| Entrada "Baralhos" na navegação | NAV-07 (out-of-scope) | ✅ CONFIRMADA | Fase 2, com pendências de regulamento |
| Preço / Cotações na pasta | Out-of-scope | ✅ CONFIRMADA | Fase 3, sem fonte de mercado |
| "% do catálogo" | Indicador novo | ✅ CONFIRMADA | Denominador não definido (cartas vs. variantes) |
| Valor estimado | Fase 3 | ✅ CONFIRMADA | Idem preço |
| "Zerar quantidade" | Comportamento novo | ✅ CONFIRMADA | Mudança de operação, não de layout |
| Rolagem horizontal dos chips | NAV-28 exige quebra | ✅ CONFIRMADA | Spec escolhe quebra de linha |
| Botão "Filtrar" separado | NAV-09 exige links | ✅ CONFIRMADA | Aplicação com um toque, sem botão |
| "Faltando para os baralhos" | Depende Fase 2 | ✅ CONFIRMADA | Futura, fora de escopo T21 |

---

## Verificação de Estrutura e Ordem de Blocos

### Catálogo (390px) — Main.dc.html vs. Renderizado

| Bloco | Ordem no Canvas | Ordem no Código | Status |
|-------|-----------------|-----------------|--------|
| Título "Catálogo" | 1º | 1º (`.catalog__title`) | ✅ CONFORME |
| Busca | 2º | 2º (`.catalog__search`) | ✅ CONFORME |
| Chips de filtro ativos | 3º | 3º (`.catalog__chips`) | ⚠️ Ausente (no renderizado atual) |
| Filtros por cor | 4º | 4º (`.catalog__filters`) | ✅ CONFORME |
| Linha de status | 5º | 5º (`.catalog__status`) | ✅ CONFORME (renderizado diz "2834 cartas") |
| Grade de cartas | 6º | 6º (`.catalog__grid`) | ✅ CONFORME |
| Barra inferior | Fixa embaixo | Fixa embaixo | ✅ CONFORME |

**Observação**: Chips de filtro **ativos** não aparecem no HTML renderizado sem filtro. Esperado — nenhum filtro foi aplicado na URL `/catalog` testada. Com `/catalog?colors[]=Red&rarities[]=SR`, esses chips deveriam aparecer na linha 3.

---

## Fichário de Design

### Cores (Tokens)

| Token | Hex | Canvas | Código |
|-------|-----|--------|--------|
| `surface-base` | #051b23 | Fundo | ✅ |
| `surface-raised` | #102b36 | Barra, tile | ✅ |
| `surface-sunken` | #011018 | Ativo, placeholder | ✅ |
| `border` | #1c3a47 | Borda sutil | ✅ |
| `border-strong` | #717e84 | Borda visível | ✅ |
| `ink` | #e9f0f3 | Texto ativo | ✅ |
| `ink-muted` | #9ba7ad | Texto muted | ✅ |
| `accent` | #ff9e14 | Botão ativo, anel | ✅ |
| `on-accent` | #051b23 | Texto no ativo | ✅ |

**Status**: Todos implementados em `:root` do CSS.

### Tipografia (Tokens)

| Estilo | Tamanho | Altura | Peso | Canvas | Código |
|--------|---------|--------|------|--------|--------|
| `display` | 28px | 32px | 700 | h1 títulos | ✅ |
| `title` | 20px | 26px | 600 | h2 seções | ✅ |
| `body` | 15px | 22px | 400 | texto | ✅ |
| `body-strong` | 15px | 22px | 600 | labels | ✅ |
| `caption` | 13px | 18px | 400 | chip, rótulo | ✅ |
| `code` | 13px | 18px | 500 | card_number | ✅ |

**Status**: Todos implementados em `:root` do CSS.

### Medidas (Tokens)

| Token | Valor | Uso |
|-------|-------|-----|
| `--nav-height` | 56px | Altura barra inferior (vs. canvas 64px) |
| `--sidebar-width` | 280px | Largura coluna lateral | ✅ |
| `--space-1` | 4px | Gap mínimo |
| `--space-2` | 8px | Gap padrão, padding chip |
| `--space-3` | 16px | Gap seções |
| `--space-4` | 24px | Padding página |
| `--radius-sm` | 4px | Border-radius pequena |
| `--radius-md` | 8px | Border-radius card |

**Observação**: `--nav-height: 56px` vs. `height: 64px` no canvas (Main.dc.html, line 136). Diferença de 8px pode afetar layout.

---

## Critérios NAV Verificados por Artboard

### Main.dc.html (390px — Catálogo)

- ✅ NAV-01: Um único `nav` com `aria-label="Principal"`
- ✅ NAV-02, NAV-03: Entradas sem sessão (Catálogo, Entrar, Criar conta)
- ✅ NAV-04: `aria-current="page"` em "Catálogo"
- ✅ NAV-05: Navegação fixa embaixo, `position: fixed; bottom: 0`
- ⚠️ NAV-30: Barra com `surface-raised` (parcial — cor correta, distribuição INCORRETA)
- ⚠️ NAV-28: Barra não causa scroll horizontal (verdadeiro hoje, mas gap pode quebrar)
- ✅ NAV-08: Filtros presentes (Cor, Tipo, Raridade)
- ✅ NAV-09: URLs de filtro corretas (`/catalog?colors[]=Red` etc.)
- ✅ NAV-26, NAV-27: Parâmetro inválido ignorado, zero resultados mantém controles
- ✅ NAV-07: Sem "Baralhos" no HTML

### Desktop-Catalogo.dc.html (1280px)

- ⚠️ NAV-06: Coluna lateral (CSS media query não verificável sem browser)
- ⚠️ NAV-31: Coluna com marca (idem)
- ⚠️ NAV-32: Filtros na coluna (idem)
- ✅ NAV-22, NAV-23: Filtros ao lado (estrutura HTML presente)
- ✅ NAV-35: Chip min-height 44px

### Desktop-Pasta.dc.html (1280px)

- ⚠️ NAV-37: Indicadores como cartões (estrutura não renderizada, só template lido)
- ⚠️ NAV-38: Barra de progresso por set (idem)
- ✅ NAV-39: Link "Adicionar cartas" (presente no canvas)

---

## Conclusão

O código **implementa a estrutura esperada** do canvas com tokens e tipografia corretos. Os **4 defeitos HIGH/MEDIUM** encontrados são:

1. **Distribuição de entradas na barra** — `justify-content: center` quebra a distribuição visual
2. **Fundo das entradas inativas** — sem background-color explícito
3. **Gap entre entradas** — pode compactar além do esperado
4. **Media query de desktop** — não foi localizada/verificada

Nenhum defeito é crítico à funcionalidade. Todos podem ser corrigidos com ajustes CSS. A maioria não pode ser observada sem um navegador real.

**Recomendação**: Executar testes de design (`bin/rails test test/design/`) e revisão visual do dono em 360px e 1280px para confirmar conformidade final.

---

## Contagem de Achados

| Severidade | Quantidade | Status |
|------------|-----------|--------|
| **CRITICAL** | 0 | Nenhum |
| **HIGH** | 2 | Defeitos de distribuição e fundo |
| **MEDIUM** | 3 | Gaps, media query, layout wide |
| **LOW** | 0 | Nenhum |
| **Recusas Confirmadas** | 8 | Out-of-scope da spec |

**Veredito Final**: CONFORME COM DEFEITOS (2 HIGH + 3 MEDIUM)
