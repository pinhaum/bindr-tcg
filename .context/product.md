# Produto — Galeria de Cartas OPTCG

## 1. Visão

Uma aplicação para **navegar o catálogo completo de cartas do One Piece Card
Game** e **registrar a coleção pessoal** (o que possuo, em que quantidade, e o
que quero adquirir).

O diferencial pretendido não é ter os dados — é ter busca e filtros rápidos o
suficiente para uso durante abertura de boosters e negociação de trocas, com
controle por **variante de impressão**, não apenas por carta.

## 2. Usuário-alvo

Jogador ou colecionador de OPTCG que:

- abre boosters e precisa registrar o que saiu, rápido, no celular;
- quer saber o que falta para completar um set;
- mantém uma lista de desejos para trocas e compras.

Fase 1 assume **usuário único ou poucos usuários** (uso pessoal). Multiusuário
público não é objetivo do MVP, mas o modelo de dados não deve impedir isso.

## 3. Escopo — Fase 1 (MVP)

Dentro do escopo:

1. Catálogo de cartas navegável, com busca textual e filtros combinados.
2. Página de detalhe da carta, exibindo todas as variantes de impressão.
3. Coleção pessoal: quantidade possuída por variante.
4. Wishlist: cartas/variantes desejadas com quantidade-alvo.
5. Visão de progresso por set.
6. Import/export CSV da coleção.
7. Pipeline de ingestão e atualização do catálogo a partir de fonte externa.

## 4. Non-goals explícitos (Fase 1)

Estes itens estão **fora** do MVP e o design não deve pagar custo por eles agora,
apenas evitar bloqueá-los:

- **Construtor e validador de decks** — planejado para a Fase 2.
- **Preços e valor estimado da coleção** — planejado para a Fase 3. É o item mais
  arriscado do roadmap: depende de fonte de dados de mercado, que pode não
  existir de forma gratuita e confiável para OPTCG.
- Simulador de partidas, mão inicial, ou qualquer regra de jogo.
- Rede social, perfis públicos, feed, comentários.
- Scanner de cartas por câmera / OCR.
- App nativo publicado em loja.

## 5. Restrições

### 5.1 Propriedade intelectual

Nomes, artes e textos das cartas são propriedade da Bandai / Eiichiro Oda /
Shueisha. Consequências de design, não jurídicas — não sou advogado e isto não é
orientação legal:

- O projeto é de uso pessoal e não comercial. Se em algum momento virar público
  ou monetizado, a questão precisa de avaliação real, não de um parágrafo num
  spec.
- ~~Preferir referenciar imagens por URL da fonte original a redistribuir os
  arquivos.~~ **Inviável (AD-012, 2026-09-22):** a fonte bloqueia carregamento
  fora do próprio domínio por CORP, então a aplicação serve as imagens a partir
  de cache local — ver `design.md` §7. Isso só se sustenta enquanto o projeto for
  pessoal e não comercial.
- Nenhuma arte deve ser servida como se fosse conteúdo próprio da aplicação.

### 5.2 Fonte de dados

O catálogo **não será digitado à mão**. Depende de uma fonte externa.

**Fonte escolhida (task 0.1, 2026-09-19):** `hugoprudente/optcgjson` — dataset
JSON versionado, gerado por scraping do site oficial da Bandai, com CI semanal e
sem autenticação. Cobre 62 sets (até OP17), 2815 cartas e 4915 variantes, e
**preserva a distinção entre carta e impressão**, que foi o critério decisivo.

As alternativas avaliadas e descartadas (apitcg.com e dotgg.gg) colapsam
variantes numa linha por carta. Comparação completa e riscos em
`docs/adr/001-fonte-de-dados-do-catalogo.md`.

## 6. Glossário do domínio

Termos do OPTCG usados nos outros documentos. **Corrigido na task 0.2** contra a
amostra real de `hugoprudente/optcgjson` (62 sets, 2815 cartas, 4915 variantes,
verificado em 2026-09-19). Os `⚠️ VERIFICAR` desta seção estão resolvidos — ver
`docs/adr/001-fonte-de-dados-do-catalogo.md`.

| Termo | Significado |
|---|---|
| **Leader** | Carta líder. Uma por deck, fica em jogo desde o início. Tem `life` e `power`, **nunca tem `cost`** (confirmado: 338 de 338 com `cost` nulo). Pode ser de duas cores. |
| **Character** | Criatura jogável. Tem `cost` e `power`. |
| **Event** | Efeito pontual. Tem `cost`, **nunca tem `power`** (confirmado: 0 ocorrências). |
| **Stage** | Carta de campo. Tem `cost`. |
| **DON!!** | Carta de recurso, deck separado de 10. **Não está no catálogo da fonte** e fica fora da Fase 1 — resolve P7. |
| **Cost** | Custo em DON!! para jogar a carta. Nulo em Leader. |
| **Life** | Vida do Leader. **Exclusivo de Leader** (confirmado: 0 ocorrências fora). |
| **Power** | Poder de combate. |
| **Counter** | Valor de counter usável na defesa (ex.: 1000, 2000). Vem **`null`** quando a carta não tem — `null` nunca é `0`. |
| **Attribute** | Ícone de tipo de ataque. Lista real e completa: **Slash, Strike, Ranged, Special, Wisdom**, mais o valor literal **`?`** (OP13-079, Imu). Uma carta **pode ter mais de um** (31 ocorrências, ex.: EB01-003 = Slash + Special) — por isso é array. |
| **Type / Trait** | Afiliações da carta (ex.: "Straw Hat Crew"). Uma ou mais. Na fonte é o campo `feature`, **já em array** — não precisa split. |
| **Trigger** | Efeito ativável quando revelada da Life. Presente em 834 das 4915 variantes. |
| **Card number** | Identificador do jogo, ex.: `OP01-001`. Identifica a **carta**, não a impressão. Na fonte é o campo `number`. |
| **Set** | Coleção de lançamento. Prefixos reais: `OP` (booster, OP01–OP17), `ST` (starter, ST01–ST36), `EB` (extra booster, EB01–EB04), `PRB` (premium, PRB01–PRB02), mais os avulsos `Promotioncard`, `LimitedProductCard` e `FamilyDeckSet`. |
| **Rarity** | Raridade. Lista real e completa: **C, UC, R, SR, SEC, L, P, SP CARD, TR**. Armazenar como **texto, nunca enum**. |
| **Cor** | Seis cores: Red, Green, Blue, Purple, Black, Yellow. **157 cartas são multicoloridas**, todas Leader — o filtro de cor precisa incluí-las. |
| **Variante / Printing** | Impressão específica de uma carta: arte base, parallel, promo. **Mesmo `card_number`, objeto de coleção diferente.** Central para este produto. Na fonte é o campo `id` (ex.: `OP01-001_p1`), com flag `isParallel`. |

## 7. Critério de sucesso do MVP

O MVP está pronto quando você consegue, sozinho, abrir uma caixa de boosters e
registrar toda a coleção pelo celular sem abrir uma planilha — e responder
"quantas cartas do OP09 ainda me faltam?" em menos de três toques.
