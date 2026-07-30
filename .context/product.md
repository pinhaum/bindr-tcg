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
- **Preferir referenciar imagens por URL da fonte original** a redistribuir os
  arquivos. Cache local, se necessário, é detalhe de performance — ver
  `design.md` §7.
- Nenhuma arte deve ser servida como se fosse conteúdo próprio da aplicação.

### 5.2 Fonte de dados

O catálogo **não será digitado à mão**. Depende de uma fonte externa.

> ⚠️ VERIFICAR — **não tenho fonte verificada para recomendar aqui.** Existem
> APIs comunitárias e repositórios de scraping para OPTCG citados na comunidade,
> mas não consigo confirmar quais existem hoje, se estão ativas, sua cobertura de
> sets recentes ou seus termos de uso. **Esta é a primeira coisa a investigar** —
> ver task 0 em `tasks.md`. Categorias de opção a avaliar:
>
> 1. Lista oficial de cartas da Bandai (site oficial do jogo), via scraping.
> 2. API comunitária de terceiros.
> 3. Dataset estático (CSV/JSON) mantido pela comunidade, importado manualmente.
>
> A escolha muda o design da ingestão, então ela é pré-requisito de código.

## 6. Glossário do domínio

Termos do OPTCG usados nos outros documentos. Baseado no meu entendimento do
jogo — **confira contra a lista oficial de cartas antes de virar schema.**

| Termo | Significado |
|---|---|
| **Leader** | Carta líder. Uma por deck, fica em jogo desde o início. Tem `life` e `power`, não tem `cost`. Pode ser de duas cores. |
| **Character** | Criatura jogável. Tem `cost` e `power`. |
| **Event** | Efeito pontual. Tem `cost`, não tem `power`. |
| **Stage** | Carta de campo. Tem `cost`. |
| **DON!!** | Carta de recurso, deck separado de 10. Não faz parte do catálogo colecionável da mesma forma — ⚠️ VERIFICAR se deve entrar no modelo. |
| **Cost** | Custo em DON!! para jogar a carta. |
| **Life** | Vida do Leader. |
| **Power** | Poder de combate. |
| **Counter** | Valor de counter usável na defesa (ex.: 1000, 2000). Muitas cartas não têm. |
| **Attribute** | Ícone de tipo de ataque. Entendo que os valores são: Slash, Strike, Ranged, Special, Wisdom — ⚠️ VERIFICAR lista completa e se uma carta pode ter mais de um. |
| **Type / Trait** | Afiliações da carta (ex.: "Straw Hat Crew", "Animal Kingdom Pirates"). Uma carta tem uma ou mais. |
| **Trigger** | Efeito ativável quando a carta é revelada da Life. Presente em parte das cartas. |
| **Card number** | Identificador do jogo, ex.: `OP01-001`. Identifica a **carta**, não a impressão específica. |
| **Set** | Coleção de lançamento. Prefixos que conheço: `OP` (booster), `ST` (starter deck), `EB` (extra booster), `P`/`PRB` (promo/premium) — ⚠️ VERIFICAR lista atual e completa. |
| **Rarity** | Raridade. Valores que conheço: C, UC, R, SR, SEC, L, P — ⚠️ VERIFICAR completude, incluindo tratamentos tipo SP. |
| **Variante / Printing** | Impressão específica de uma carta: arte base, arte alternativa, parallel, manga rare, promo. **Mesmo `card_number`, objeto de coleção diferente.** Central para este produto. |

## 7. Critério de sucesso do MVP

O MVP está pronto quando você consegue, sozinho, abrir uma caixa de boosters e
registrar toda a coleção pelo celular sem abrir uma planilha — e responder
"quantas cartas do OP09 ainda me faltam?" em menos de três toques.
