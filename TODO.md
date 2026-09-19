# Bindr-TCG – To‑Do List (Fase 1)

## Fase 0 – Desbloqueio (pré‑requisitos)
- [x] **0.1 Investigar e escolher a fonte de dados do catálogo**
  - Identificar opções reais hoje:
    - Lista oficial da Bandai (site oficial) via scraping
    - API comunitária de terceiros
    - Dataset estático (CSV/JSON) mantido pela comunidade
  - Para cada opção registrar:
    - Cobertura de sets
    - Presença de variantes/arts alternativas
    - Estabilidade dos identificadores
    - Formato de retorno
    - Termos de uso
  - Baixar uma amostra real e salvar em `spec/fixtures/` (usará como fixture nos testes de ingestão)
  - Registrar a escolha e o motivo em um ADR (ex.: `docs/adr/001-catalog-source.md`)
  - *Resolve P1; bloqueia todo o resto.*

- [x] **0.2 Mapear o schema real a partir da amostra**
  - Listar campos reais retornados pela fonte, com tipos e exemplos
  - Extrair lista **real e completa** de:
    - Raridades
    - Códigos de set
    - Attributes
    - Tipos de carta
  - Confrontar com o glossário em `product.md` §6 e **corrigir o glossário** conforme necessário
  - *Resolve P2.*

- [x] **0.3 Decidir e registrar as pendências restantes**
  - Atualizar `design.md` §9 marcando cada uma como decidida:
    - P3: definição de "set completo" (variantes base vs. parallels/secret rares)
    - P4: escolha de stack (default proposto: Rails 8 + Hotwire + Postgres; validar se atende requisitos)
    - ~~P5: `variant_code` estável~~ — **resolvida na 0.1**: a fonte fornece `id` estável (`OP01-001_p1`), sem hash derivado
    - P6: cache de imagens na Fase 1 (recomenda‑se aceitar hotlink e medir)
    - ~~P7: `DON!!` entra no catálogo?~~ — **resolvida na 0.2**: a fonte não traz DON!!, fica fora da Fase 1
  - Anotar decisões em `design.md` e, se necessário, em ADRs adicionais

## Fase 1 – Implementação

### 1 – Fundação do projeto
- [ ] **1.1 Inicializar o projeto na stack escolhida** (Rails 8 + Hotwire + PostgreSQL)
  - Criar repositório novo, configurar PostgreSQL, garantir suíte de testes rodando com teste trivial verde
  - Preparar `docker-compose` (ou equivalente) com único comando de subida documentado no README
  - *Atende requisito 11.6*

- [ ] **1.2 Configurar CI**
  - Pipeline que roda linter e suíte de testes em cada push
  - *Atende requisito 11.4*

### 2 – Catálogo: modelo e ingestão
- [ ] **2.1 Migrações de `sets`, `cards` e `card_variants`**
  - Schema conforme `design.md` §3.2, ajustado ao resultado da task 0.2
  - Constraints no banco: `card_number` único, `(card_id, variant_code)` único
  - Foreign keys **sem delete em cascata** em direção à coleção
  - *Atende requisitos 1.2, 1.3, 5.3*

- [ ] **2.2 Índices do catálogo**
  - Todos os índices de `design.md` §3.4 (GIN em arrays, trigram no nome, etc.)
  - Habilitar extensões necessárias do Postgres
  - Teste que verifica, via plano de execução, que filtro por cor e faixa de custo não fazem varredura completa de tabela
  - *Atende requisito 11.3*

- [ ] **2.3 Estágio Fetch**
  - Buscar payload da fonte externa e persistir bruto em disco antes de qualquer processamento
  - Abortar sem escrever no banco se a fonte estiver indisponível
  - *Atende requisito 1.8*

- [ ] **2.4 Estágio Normalize**
  - Mapear formato externo para modelo interno (todo conhecimento do formato externo isolado aqui)
  - Normalizar `traits` (caixa e espaçamento) para evitar duplicatas semânticas
  - Derivar `variant_code` estável conforme decidido em P5
  - Testes rodando sobre a fixture da task 0.1, **sem rede**
  - *Atende requisitos 1.1, 11.5*

- [ ] **2.5 Estágio Upsert + `import_runs`**
  - Upsert por chave natural; cada registro em transação própria
  - Erro em registro logado em `import_runs.error_log` e processamento continua
  - Resumo persistido ao final: início, fim, status, criados, atualizados, falhados
  - *Atende requisitos 1.2, 1.3, 1.5, 1.6*

- [ ] **2.6 Testes de garantia da ingestão** ← *task mais importante do projeto*
  - Rodar ingestão duas vezes sobre a mesma fixture e verificar que contagem de registros não muda
  - Criar um `collection_item`, rodar ingestão novamente, verificar que quantidade permanece intacta
  - Verificar que carta ausente da fonte **não** é deletada
  - *Atende requisitos 1.4, 1.7*

- [ ] **2.7 Carregar o catálogo completo em desenvolvimento**
  - Executar ingestão real; registrar número final de cartas e variantes
  - Inspecionar manualmente 10 cartas contra a fonte oficial (incluir Leader dual‑color e carta com arte alternativa)
  - *Atende requisito 1.1*

### 3 – Catálogo: busca, filtros e exibição
- [ ] **3.1 Query object do catálogo**
  - Implementar contrato de `design.md` §4.2: todos os filtros, faixas, ordenação e paginação
  - `OU` dentro da categoria, `E` entre categorias
  - Filtro de cor incluindo cartas multicoloridas
  - Parâmetro inválido ignorado (não causa erro)
  - Retornar `total_count` e filtros ativos normalizados
  - Testes: cada filtro isolado, duas combinações, caso multicolor
  - *Atende requisitos 4.1, 4.2, 4.3, 4.4, 4.5, 4.8, 2.4*

- [ ] **3.2 Busca textual**
  - Nome com tolerância a erro de digitação e insensível a caixa e acento
  - Texto de efeito por full‑text
  - `card_number` com match exato prependido como primeiro resultado
  - Combinável com todos os filtros
  - *Atende requisitos 3.1, 3.2, 3.3, 3.4, 3.6*

- [ ] **3.3 Grade do catálogo**
  - Grade com imagem, nome e `card_number`; paginação; lazy loading nas imagens
  - Placeholder com nome e código quando a imagem falhar
  - Estado vazio explícito com termo buscado e ação de limpar filtros
  - Filtros ativos exibidos como chips removíveis individualmente
  - Estado completo refletido na URL; recarregar reproduz o resultado
  - Usável em viewport de 360px sem scroll horizontal
  - *Atende requisitos 2.1, 2.2, 2.3, 2.5, 3.5, 4.6, 4.7, 11.2*

- [ ] **3.4 Medir a latência do filtro** ← *validação da premissa de stack*
  - Medir p95 de consulta com busca e três filtros combinados, catálogo completo carregado
  - Se exceder 500ms: otimizar índices e consulta antes de considerar mudança arquitetural; registrar resultado
  - *Atende requisito 11.1*

- [ ] **3.5 Página de detalhe da carta**
  - Todos os campos conhecidos, imagem em resolução maior
  - Lista de todas as variantes, cada uma com raridade, set e imagem própria
  - `effect_text` e `trigger_text` preservando quebras de linha
  - Campos não aplicáveis ao tipo de carta omitidos (não exibidos vazios)
  - *Atende requisitos 5.1, 5.2, 5.4, 5.5*

### 4 – Usuário e coleção
- [ ] **4.1 Autenticação**
  - Cadastro, login, logout; senha apenas como hash (algoritmo reconhecido)
  - Catálogo e busca acessíveis sem sessão; mutações exigem sessão
  - *Atende requisitos 6.1, 6.2, 6.3, 6.4*

- [ ] **4.2 Modelo de `collection_items`**
  - Migração com `UNIQUE (user_id, card_variant_id)` e `CHECK (quantity >= 0)` no banco
  - Testes que provam que constraint é do banco, não só da aplicação
  - Toda consulta parte do usuário da sessão; teste de que usuário não acessa coleção de outro
  - *Atende requisitos 6.5, 7.1, 7.4, 7.8*

- [ ] **4.3 Registrar posse**
  - Incremento e decremento em ação única, sem formulário, sem recarregar página inteira
  - Quantidade zero equivale a não possuída
  - Disponível tanto na grade quanto no detalhe, sempre por variante
  - *Atende requisitos 7.2, 7.3, 7.5, 5.3*

- [ ] **4.4 Filtro de posse e totais**
  - Filtro "somente as que eu tenho" / "somente as que eu não tenho", integrado ao query object da task 3.1
  - Total de cartas possuídas contando cópias
  - *Atende requisitos 7.6, 7.7*

- [ ] **4.5 Wishlist**
  - Marcar variante como desejada com quantidade‑alvo
  - Listar apenas itens desejados; remover item
  - Sinalizar item atendido quando quantidade possuída atingir ou exceder o alvo
  - *Atende requisitos 8.1, 8.2, 8.3, 8.4*

### 5 – Progresso e portabilidade
- [ ] **5.1 Progresso por set**
  - Por set: variantes distintas possuídas, total de variantes, percentual
  - Contar variantes distintas, não cópias
  - Link para catálogo já filtrado por aquele set
  - Denominador = `baseSetSize` (variantes base); parallels em métrica separada (P3)
  - *Atende requisitos 9.1, 9.2, 9.3, 9.4, 9.5, 9.6*

- [ ] **5.2 Export CSV**
  - Exportar coleção em CSV contendo, no mínimo: `card_number`, identificador da variante, nome da carta e quantidade
  - *Atende requisito 10.1*

- [ ] **5.3 Import CSV**
  - Aceitar mesmo formato do export
  - Pré‑visualização com confirmação obrigatória antes de gravar
  - Linha com variante inexistente rejeitada com motivo; as demais seguem
  - Resumo final: importadas, atualizadas, rejeitadas, com motivo
  - *Atende requisitos 10.2, 10.3, 10.4, 10.5*

### 6 – Fechamento do MVP
- [ ] **6.1 Verificação do critério de sucesso**
  - Registrar uma caixa de boosters inteira pelo celular, sem planilha
  - Responder "quanto falta do set X?" em no máximo três toques
  - Anotar todo atrito encontrado (viра backlog da Fase 2)
  - *Referência: product.md §7*

- [ ] **6.2 Documentar e revisar os specs**
  - README com subida local em um comando e execução da ingestão
  - Atualizar `requirements.md` e `design.md` com tudo que mudou durante a execução; remover todos os `⚠️ VERIFICAR` já resolvidos
  - *Atende requisito 11.6*