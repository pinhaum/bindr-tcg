# Plano de implementação — Fase 1

Regras de execução:

- Uma task por vez. Não abra a próxima com a anterior incompleta.
- Cada task termina com **código que roda e teste que passa**. Nada de task cujo
  resultado seja "estrutura criada".
- `_Requisitos:_` referencia `requirements.md`. Se uma task não referencia
  requisito nenhum, questione se ela deveria existir.
- Se durante a execução um requisito se mostrar errado, **pare e corrija
  `requirements.md`** antes de continuar. Não improvise no código.

---

## Fase 0 — Desbloqueio (não escreva domínio antes disso)

- [x] **0.1 Investigar e escolher a fonte de dados do catálogo**
  - Identificar as opções realmente existentes hoje: lista oficial da Bandai,
    APIs comunitárias, datasets mantidos pela comunidade.
  - Para cada uma, registrar: cobertura de sets, presença de variantes/arts
    alternativas, estabilidade dos identificadores, formato, termos de uso.
  - Baixar uma amostra real e salvá-la em `spec/fixtures/` — ela será a fixture
    dos testes de ingestão.
  - Registrar a escolha e o motivo em um ADR.
  - _Resolve: P1. Bloqueia: todo o resto._

- [x] **0.2 Mapear o schema real a partir da amostra**
  - Listar os campos reais retornados pela fonte, com tipos e exemplos.
  - Extrair a lista **real e completa** de: raridades, códigos de set, attributes,
    tipos de carta.
  - Confrontar com o glossário em `product.md` §6 e **corrigir o glossário**.
  - _Resolve: P2._

- [x] **0.3 Decidir e registrar as pendências restantes**
  - Restam **P3** (definição de "set completo"), **P4** (stack) e **P6** (cache de
    imagens). P5 e P7 foram resolvidas na 0.1/0.2 — ver `design.md` §9.
  - Atualizar `design.md` §9 marcando cada uma como decidida.

---

## 1 — Fundação do projeto

- [x] **1.1 Inicializar o projeto na stack escolhida** (Rails 8 + Hotwire + PostgreSQL)
  - Projeto novo, PostgreSQL configurado, suíte de testes rodando com um teste
    trivial verde.
  - `docker-compose` ou equivalente, com um único comando de subida documentado
    no README.
  - _Requisitos: 11.6_

- [x] **1.2 Configurar CI**
  - Pipeline que roda linter e a suíte de testes em cada push.
  - _Requisitos: 11.4_

---

## 2 — Catálogo: modelo e ingestão

- [x] **2.1 Migrações de `sets`, `cards` e `card_variants`**
  - Schema conforme `design.md` §3.2, **ajustado ao resultado da task 0.2**.
  - Constraints no banco: `card_number` único, `(card_id, variant_code)` único.
  - Foreign keys **sem delete em cascata** em direção à coleção.
  - _Requisitos: 1.2, 1.3, 5.3_

- [x] **2.2 Índices do catálogo**
  - Todos os índices de `design.md` §3.4, incluindo GIN nas colunas de array e
    trigram no nome.
  - Habilitar as extensões necessárias do Postgres.
  - Teste que verifica, via plano de execução, que um filtro por cor e um filtro
    por faixa de custo não fazem varredura completa de tabela.
  - _Requisitos: 11.3_

- [x] **2.3 Estágio Fetch**
  - Buscar o payload da fonte externa e persistir o bruto em disco antes de
    qualquer processamento.
  - Abortar sem escrever no banco se a fonte estiver indisponível.
  - Ler a revisão da fonte (commit ou tag) da configuração e buscar exatamente
    essa revisão. Rejeitar na carga da configuração uma referência móvel como
    `main` ou `HEAD`.
  - Teste: configuração com referência móvel falha de forma explícita;
    configuração com commit fixo busca a URL daquela revisão.
  - _Requisitos: 1.8, 1.9, 1.11_

- [x] **2.4 Estágio Normalize**
  - Mapear o formato externo para o modelo interno. Todo conhecimento do formato
    externo isolado nesta unidade.
  - Normalizar `traits` (caixa e espaçamento) para evitar duplicatas semânticas.
  - Derivar `variant_code` estável conforme decidido em P5.
  - Testes rodando sobre a fixture da task 0.1, **sem rede**.
  - _Requisitos: 1.1, 11.5_

- [x] **2.5 Estágio Upsert + `import_runs`**
  - Upsert por chave natural. Cada registro em transação própria.
  - Erro em um registro é logado em `import_runs.error_log` e o processamento
    continua.
  - Resumo persistido ao final: início, fim, status, criados, atualizados,
    falhados e a revisão da fonte usada (`source_revision`).
  - _Requisitos: 1.2, 1.3, 1.5, 1.6, 1.10_

- [x] **2.6 Testes de garantia da ingestão** ← *task mais importante do projeto*
  - Rodar a ingestão duas vezes sobre a mesma fixture e verificar que a contagem
    de registros não muda.
  - Criar um `collection_item`, rodar a ingestão novamente, verificar que a
    quantidade permanece intacta.
  - Verificar que uma carta ausente da fonte **não** é deletada.
  - _Requisitos: 1.4, 1.7_

- [x] **2.7 Carregar o catálogo completo em desenvolvimento**
  - Executar a ingestão real. Registrar o número final de cartas e variantes.
  - Inspecionar manualmente 10 cartas contra a fonte oficial, incluindo pelo
    menos um Leader dual-color e uma carta com arte alternativa.
  - _Requisitos: 1.1_

---

## 3 — Catálogo: busca, filtros e exibição

- [x] **3.1 Query object do catálogo**
  - Implementar o contrato de `design.md` §4.2: todos os filtros, faixas,
    ordenação e paginação.
  - `OU` dentro da categoria, `E` entre categorias.
  - Filtro de cor incluindo cartas multicoloridas.
  - Parâmetro inválido é ignorado, nunca causa erro.
  - Retornar `total_count` e os filtros ativos normalizados.
  - Testes: cada filtro isolado, duas combinações, e o caso multicolor.
  - _Requisitos: 4.1, 4.2, 4.3, 4.4, 4.5, 4.8, 2.4_

- [x] **3.2 Busca textual**
  - Nome com tolerância a erro de digitação e insensível a caixa e acento.
  - Texto de efeito por full-text.
  - `card_number` com match exato prependido como primeiro resultado.
  - Combinável com todos os filtros.
  - _Requisitos: 3.1, 3.2, 3.3, 3.4, 3.6_

- [x] **3.3 Grade do catálogo**
  - Grade com imagem, nome e `card_number`. Paginação. Lazy loading nas imagens.
  - Placeholder com nome e código quando a imagem falhar.
  - Estado vazio explícito com o termo buscado e ação de limpar filtros.
  - Filtros ativos exibidos como chips removíveis individualmente.
  - Estado completo refletido na URL; recarregar reproduz o resultado.
  - Usável em viewport de 360px sem scroll horizontal.
  - _Requisitos: 2.1, 2.2, 2.3, 2.5, 3.5, 4.6, 4.7, 11.2_

- [x] **3.4 Medir a latência do filtro** ← *validação da premissa de stack*
  - Medir o p95 de uma consulta com busca e três filtros combinados, com o
    catálogo completo carregado.
  - Se exceder 500ms: otimizar índices e consulta antes de considerar mudança
    arquitetural. Registrar o resultado da medição.
  - _Requisitos: 11.1_

- [x] **3.5 Página de detalhe da carta**
  - Todos os campos conhecidos, imagem em resolução maior.
  - Lista de todas as variantes, cada uma com raridade, set e imagem própria.
  - `effect_text` e `trigger_text` preservando quebras de linha.
  - Campos não aplicáveis ao tipo de carta são omitidos, não exibidos vazios.
  - _Requisitos: 5.1, 5.2, 5.4, 5.5_

---

## 4 — Usuário e coleção

- [x] **4.1 Autenticação**
  - Cadastro, login, logout. Senha apenas como hash.
  - Catálogo e busca acessíveis sem sessão; mutações exigem sessão.
  - _Requisitos: 6.1, 6.2, 6.3, 6.4_

- [x] **4.2 Modelo de `collection_items`**
  - Migração com `UNIQUE (user_id, card_variant_id)` e `CHECK (quantity >= 0)` no
    banco.
  - Testes que provam que a constraint é do banco, não só da aplicação.
  - Toda consulta parte do usuário da sessão. Teste de que um usuário não acessa
    a coleção de outro.
  - _Requisitos: 6.5, 7.1, 7.4, 7.8_

- [x] **4.3 Registrar posse**
  - Incremento e decremento em ação única, sem formulário, sem recarregar a
    página inteira.
  - Quantidade zero equivale a não possuída.
  - Disponível tanto na grade quanto no detalhe, sempre por variante.
  - _Requisitos: 7.2, 7.3, 7.5, 5.3_

- [x] **4.4 Filtro de posse e totais**
  - Filtro "somente as que eu tenho" / "somente as que eu não tenho", integrado
    ao query object da task 3.1.
  - Total de cartas possuídas contando cópias.
  - _Requisitos: 7.6, 7.7_

- [ ] **4.5 Wishlist**
  - Marcar variante como desejada com quantidade-alvo. Listar. Remover.
  - Sinalizar item atendido quando a quantidade possuída atingir a alvo.
  - _Requisitos: 8.1, 8.2, 8.3, 8.4_

---

## 5 — Progresso e portabilidade

- [ ] **5.1 Progresso por set**
  - Por set: variantes distintas possuídas, total de variantes, percentual.
  - Contar variantes distintas, não cópias.
  - Link para o catálogo já filtrado por aquele set.
  - Denominador = `baseSetSize` (variantes base); parallels como métrica separada (P3).
  - _Requisitos: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

- [ ] **5.2 Export CSV**
  - `card_number`, identificador da variante, nome e quantidade.
  - _Requisitos: 10.1_

- [ ] **5.3 Import CSV**
  - Aceitar o mesmo formato do export.
  - Pré-visualização com confirmação obrigatória antes de gravar.
  - Linha com variante inexistente é rejeitada com motivo; as demais seguem.
  - Resumo final: importadas, atualizadas, rejeitadas, com motivo.
  - _Requisitos: 10.2, 10.3, 10.4, 10.5_

---

## 6 — Fechamento do MVP

- [ ] **6.1 Verificação do critério de sucesso**
  - Registrar uma caixa de boosters inteira pelo celular, sem planilha.
  - Responder "quanto falta do set X?" em no máximo três toques.
  - Anotar todo atrito encontrado — isso vira o backlog da Fase 2, não correção
    de última hora.
  - _Referência: `product.md` §7_

- [ ] **6.2 Documentar e revisar os specs**
  - README com subida local em um comando e execução da ingestão.
  - Atualizar `requirements.md` e `design.md` com tudo que mudou durante a
    execução. Remover todos os `⚠️ VERIFICAR` já resolvidos.
  - _Requisitos: 11.6_

---

## Fora do escopo da Fase 1

Não implemente, mesmo que pareça rápido — cada um destes precisa passar por
`requirements.md` primeiro:

- Deck builder e validador (Fase 2) — regras do jogo precisam de confirmação no
  regulamento oficial antes de qualquer código.
- Preços e valor da coleção (Fase 3) — depende de fonte de mercado ainda não
  identificada.
- Cache local de imagens — só se o Req. 11.2 falhar na prática.
- Uso offline / PWA — não é requisito hoje. Se importar, vira requisito antes de
  virar task.
