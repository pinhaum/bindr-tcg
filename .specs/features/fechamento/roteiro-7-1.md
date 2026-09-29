# Roteiro de Teste Manual §7.1 — Critério de Sucesso do MVP

**Objetivo:** Verificar se é possível registrar uma caixa de boosters inteira pelo celular e responder "quanto falta?" em no máximo 3 toques.

**Duração esperada:** \~10 minutos.

---

## Preparação

- Celular (ou navegador em modo responsivo com viewport de 360px) conectado à mesma rede do computador.
- Aplicação rodando em `http://<ip-do-computador>:3000`.

---

## Passos

### **1. Subir a aplicação e abrir no celular**

1. No computador, executar `docker compose up`.
2. Anotar o IP local do computador (ex.: `192.168.1.100`).
3. No celular, abrir `http://<IP>:3000` no navegador.

**Toques esperados:** 3

---

### **2. Criar conta**

1. Tocar em "Entrar para registrar posse" (tela inicial do catálogo, ou procurar qualquer coisa e tentar incrementar uma carta).
2. Na tela de login, tocar em "Criar conta" (link no rodapé da tela de login).
3. Preencher email e senha.
4. Tocar em "Criar conta" (botão de envio do formulário, que já autentica e entra na conta).

**Toques esperados:** 4

---

### **3. Navegar até o catálogo**

1. Se não estiver no catálogo, tocar em "Catálogo" (barra inferior ou coluna lateral, conforme viewport).

**Toques esperados:** 1

---

### **4. Registrar uma caixa de boosters (24 boosters de um set)**

Procedimento: abrir um set, encontrar as cartas e incrementar cada uma com quantidade de cópias conforme saem dos boosters.

#### **Exemplo: Set OP01**

1. Procurar ou filtrar para **OP01**:
   - Em celular (&lt;1024px): tocar em "Filtros" (seção fechada acima da grade) para abrir.
   - Selecionar "Set" e escolher **OP01**.
   - Toques para entrada do set: 2–3 (toque para expandir + seleção ou scroll + toque).
2. Para cada carta da caixa que saiu:
   - Tocar na carta (abre o detalhe com `.card-detail`).
   - Descer até encontrar a variante desejada (arte base ou parallel, conforme o booster).
   - Tocar no botão **"+"** em "Variantes na pasta" (classe `ownership__button--increment`).
   - Tocar em "Voltar ao catálogo" ou usar o botão "voltar" do navegador.
   - Procurar a próxima carta.

**Observação sobre boosters reais:**
Com 24 boosters de um set, a composição típica é:

- 2–3 cartas commons (C): aparecem múltiplas vezes (2–3× cada).
- 2–3 cartas uncommons (UC): aparecem 2–3× cada.
- 1–2 cartas rares (R): aparecem 1–2× cada.
- 1 carta especial (SR, SEC, L, P, etc.): 1× cada (raríssima).

Nem toda variante única será registrada — o roteiro quer demonstrar fluidez com um recorte realista (15 variantes distintas incrementadas múltiplas vezes, de um total de 121).

**Toques esperados para registrar \~15 variantes distintas (com múltiplos incrementos cada):**

- 2 toques: filtrar OP01.
- Por cada variante:
  - 1 toque para abrir o detalhe.
  - 1–3 toques para incrementar (botão "+") múltiplas vezes conforme quantidade saída (um toque por unidade).
  - 1 toque para voltar ao catálogo.
- Caso realista (15 variantes, 1–2 incrementos cada): \~2 + (15 × 3) = **\~47 toques**.

**Critério de fluidez (não de contagem):**

- Feedback imediato no contador (Turbo Stream atualiza sem recarregar a página).
- Não há travamentos ao incrementar.
- Botão "+" está acessível e legível em 360px.
- Voltar ao catálogo é sempre fácil (link em `.site-header__back` ou navegador).

---

### **5. Responder "Quanto falta do set X?" — em máximo 3 toques**

**Pergunta:** "Quantas variantes do OP01 ainda faltam para completar o set base?"

**Caminho esperado (≤3 toques):**

1. Tocar em **"Minha pasta"** (barra inferior em celular, coluna lateral em desktop).
2. Procurar **OP01** na lista de sets. Se a lista for longa e OP01 não estiver visível, scroll (1 toque adicional, mas ainda dentro de 3).
3. Ler a resposta na linha do set: o número de variantes possuídas e o total (ex.: "17 / 154 · 12%").

**Toques concretos:**

- Toque 1: "Minha pasta".
- Toque 2: OP01 já visível, apenas ler. (Ou 1 toque de scroll se necessário.)
- **Total: ≤3 toques**.

**Resposta esperada (exemplo ilustrativo):**

```
17 / 154 · 12%
15 de 121 do set base · 2 de 33 parallels
```

(A barra de progresso visual é complementar, não substitui o número.)

**Critério de sucesso:**

- A resposta é **legível numa linha única** ou em duas linhas (base + parallels).
- O número de variantes possuídas (17) e o total (154) aparecem juntos, com o denominador do set base (121) na linha seguinte.
- O percentual aparece quando há denominador (baseSetSize conhecido).
- **Sem necessidade de clicar em mais nada** — a informação está pronta no cartão do set.

---

## Onde Anotar Atritos

Preencha a tabela com tudo que exigir mais de um toque ou causar confusão. Atritos são registrados como **backlog da Fase 2**, não são corrigidos agora.


| Passo     | Atrito              | Gravidade            | Toques a Mais | Notas                   |
| --------- | ------------------- | -------------------- | ------------- | ----------------------- |
| \[passo\] | \[descrição breve\] | Alta / Média / Baixa | \[número\]    | \[contexto ou cenário\] |
|           |                     |                      |               |                         |
|           |                     |                      |               |                         |
|           |                     |                      |               |                         |


**Gravidade:**

- **Alta:** Bloqueia o fluxo ou causa erro.
- **Média:** Exige desvio de rota ou toque extra (3+ toques em uma etapa).
- **Baixa:** Confusão menor, contorno óbvio, mas melhorável.

---

## Critério de Sucesso Atendido?

Marque **SIM** ou **NÃO** (e descreva o bloqueio se NÃO):

- [x] **Sim:** Registrei 15+ variantes distintas com fluidez (incrementos imediatos, sem recarregar) e respondi "quanto falta do OP01?" em ≤3 toques com a resposta legível.
- [ ] **Não:** \[Descreva o bloqueio.\]

---

## Notas Técnicas (Uso Interno)

- **Catálogo público:** Anônimo consegue procurar, filtrar e ver detalhe sem entrar. O botão **"+"** aparece apenas após `authenticated?` ser verdadeiro (concern `Authentication`).
- **Filtro de set:** Elemento `<details>` com classe `catalog__filters-toggle`, entrada via `sets[]` na query string. Em celular, fechado por padrão; usuário abre tocando "Filtros".
- **Página de detalhe:** Rota `/cards/:id` (onde `:id` é `card_number`). Variantes aparecem em `.card-detail__variants` com controles de posse por variante.
- **Ownership (posse):** Partial `collection_items/_ownership.html.erb`. Botões "+"/`-` submetem formulário via Turbo (Req. 7.5 / COL-10). Resposta é HTML renderizado, substitui o contêiner via `turbo_stream.update`.
- **Minha pasta:** Rota `/progress`. Exibe sets com posse em `.progress__list`. Cada set é `<li class="progress-set">` com métrica na `.progress-set__owned-line` (ex.: "15 de 121 do set base").
- **Contagem de cópias vs. variantes:** "15 de 121 do set base" = 15 variantes distintas possuídas de 121 variantes base do set OP01 (Req. 9.1 / AD-003).
- **Sem planilha:** O roteiro **não depende** do import CSV (Fase 5). Cada incremento é entrada manual.

