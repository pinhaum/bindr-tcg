# Handoff para a próxima sessão — início da Fase 4

Documento de entrada. Leia este primeiro, depois `.specs/STATE.md`.
Escrito em 2026-09-19, com HEAD em `d1454cf`.

---

## 1. Onde o projeto está

A feature **`catalogo` está encerrada**: 14 de 14 tasks, dois lotes verificados
por subagente independente (autor ≠ verificador), ambos **PASS**. Os achados dos
Verifiers e da revisão de acessibilidade foram corrigidos e commitados.

| Indicador | Estado |
| --- | --- |
| Suíte | 189 runs, 532 asserções, 0 falhas |
| RuboCop / Brakeman | 0 ofensas / 0 warnings |
| `python3 spec/verify_fixture.py` | 12/12 |
| `validate_state.py catalogo` | exit 0 |
| CI (GitHub Actions) | verde no primeiro run real (`35475280590`) |
| Catálogo em desenvolvimento | 2815 cartas, 4914 variantes, 62 sets |

O app sobe com `docker compose up`, catálogo em <http://localhost:3000/catalog>,
detalhe em `/cards/:card_number`.

**Relatórios de verificação**: `.specs/features/catalogo/validation.md` —
lote B1 (Fase 2) nas linhas 1–414, lote B2 (Fase 3) a partir da 419. Não
sobrescrever; anexar.

---

## 2. O próximo passo

**A Fase 4 é feature nova, não continuação de `catalogo`.**

Criar `.specs/features/colecao/` com spec própria **antes** de decompor em
tasks. Enfiar autenticação e coleção em `catalogo` reabriria uma feature
verificada e misturaria dois escopos no mesmo `validation.md`.

O plano já existe em `.context/tasks.md` §4 (tasks 4.1 a 4.5: autenticação,
modelo de `collection_items`, registrar posse, filtro de posse e totais,
wishlist). Os requisitos são `.context/requirements.md` §6, §7 e §8.

**Por que esta fase merece spec com cuidado extra:** até aqui todo dado era
regenerável — se a ingestão errar, roda de novo. A partir de `collection_items`
o projeto passa a guardar dado do usuário, que é insubstituível. É o ponto do
projeto onde improvisar custa mais caro.

### Três coisas que a Fase 4 esbarra logo

1. **`users` e `collection_items` já existem.** Foram criadas na T8 para provar
   que a ingestão não corrompe a coleção. Têm `UNIQUE (user_id, card_variant_id)`,
   `CHECK (quantity >= 0)` e FK `RESTRICT`. A task 4.2 vai encontrar as tabelas
   prontas.
2. **O gerador de autenticação do Rails 8 NÃO foi executado** — só foi
   verificado que atende o Req. 6. Ele cria `User` e `Session`, e **vai colidir
   com a `users` existente**. Decidir na spec como resolver, não improvisar na
   hora.
3. **Não há pipeline de JavaScript.** `app/javascript` e `config/importmap.rb`
   não existem; `stimulus-rails` está no Gemfile mas nunca foi instalado. O
   **Req. 7.2 (incremento/decremento sem recarregar a página) exige o importmap
   instalado** — é a primeira coisa a resolver na task 4.3, não uma descoberta
   para o meio do caminho.

O parâmetro `owned` do `design.md` §4.2 foi deixado **fora** do query object de
propósito, por depender de sessão. O objeto aceita o filtro depois sem
reescrita: hoje cai no saneador genérico e é ignorado. Como o escopo base é
`Card.all`, o predicado vai precisar de `EXISTS`.

---

## 3. Dívida herdada

Nada aqui bloqueia a Fase 4.

| Item | Situação |
| --- | --- |
| **Cobertura de navegador** | T12/T14 viraram teste de integração: não há chromedriver no container (`SPEC_DEVIATION` registrado em cada task). O 360px do Req. 2.5 foi verificado à mão em Chromium real. **Uma regressão de layout passaria no CI.** Decidir se vale chromedriver no `Dockerfile.dev`. |
| **Importmap** | Não instalado. Bloqueia o Req. 7.2 (ver acima). |
| **a11y, 3 melhorias** | `lang="en"` no conteúdo em inglês (nome, `effect_text`, `trigger_text`); `min-height/min-width: 24px` nos alvos de toque (SC 2.5.8); reforço do indicador de foco (SC 2.4.11). Nenhuma bloqueante. |
| **Flakiness** | `guarantees_test.rb` falhou 1 vez em ~20 execuções, por contenção entre os 4 workers (`last_seen_at` do presente menor que o do ausente). Se voltar: **congelar o relógio** (`Upsert` já aceita `clock:`), nunca afrouxar a asserção. |

---

## 4. Decisões que não se reabrem sem motivo novo

Estão em `.specs/STATE.md` como AD-001 a AD-005. As que mais afetam código novo:

- **`Card` ≠ `CardVariant`.** Card é a carta do jogo (`card_number`);
  CardVariant é uma impressão física. **Coleção e wishlist referenciam
  variantes**; busca e filtros operam sobre cartas. Colapsar as duas destrói
  metade do sentido do produto.
- **A ingestão não tem operação de delete**, e **nenhuma FK da coleção
  cascateia**. Deletar uma variante apagaria o registro do usuário.
- **`counter` NULL ≠ 0.** Nunca usar 0 como sentinela. Vale para todo campo
  numérico, não só `counter` (lição L-002).
- **`rarity` é texto, não enum** — a fonte é scraper comunitário.
- **Toda consulta a coleção parte do usuário da sessão**, nunca de um ID vindo
  do request (Req. 6.5, por construção).
- **Set completo usa `baseSetSize`**; parallels em métrica separada (AD-003).

### Decisões técnicas descobertas durante a execução

- **`unaccent` não é indexável** (é `STABLE`). Existe `immutable_unaccent(text)`.
  **A consulta precisa chamar `immutable_unaccent(name)`**, senão o índice GIN
  trigram não é usado. `design.md` §4.1.1.
- **A busca só é indexável com GIN trigram em `card_number`** (`design.md`
  §4.1.2). O `UNION` das ramificações é escolha de previsibilidade de plano, e
  **não** o que resolve o Seq Scan — isso foi medido e o parágrafo original,
  que creditava ao `UNION`, foi corrigido.
- **Typo exige `word_similarity`, não `similarity`** (`design.md` §4.1.3):
  `similarity('Zorro','Roronoa Zoro')` = 0,286, abaixo do limiar default.
  Limiar em uso: 0,5, travado por teste nos dois sentidos.
- **`schema_format = :sql`** — `db/structure.sql`, não `schema.rb`. Forçado:
  `schema.rb` não representa funções.
- **Model é `CardSet`**, não `Set` (colisão com a stdlib); a coluna é
  **`attributes_list`**, não `attributes` (colisão com `ActiveRecord#attributes`).
  Ambos com `SPEC_DEVIATION` no código. A tabela continua `sets`.
- **Gem `json` pinada em `~> 2.7`**: a 3.0.2 removeu `quirks_mode`, que o
  ActiveSupport 8.0.5.1 ainda passa. Soltar o pin quebra **toda** escrita em
  `jsonb`, e com ela `import_runs.error_log` e o Req. 1.5. Verificado, não é
  superstição.
- **CI: `pg_dump` precisa vir da major 17.** O runner traz um
  `postgresql-client-16` pré-instalado e instalar o 17 só reassume o `psql`;
  `/usr/bin/pg_dump` continua 16. O workflow põe
  `/usr/lib/postgresql/17/bin` na frente do PATH e falha o job se a major não
  for 17. Importa porque `schema_format = :sql` regenera o dump.

---

## 5. Armadilhas de ambiente (todas custaram tempo de verdade)

- **`RAILS_ENV` posicional NÃO é lido pelo `bin/rails`.**
  `bin/rails db:drop db:create RAILS_ENV=test` atinge o banco de
  **desenvolvimento** — já apagou o catálogo uma vez. Use
  `env RAILS_ENV=test bin/rails ...` ou `bin/rails db:test:prepare`.
  Recuperação **sem rede**: `REUSE_PAYLOAD=1 bin/rails ingestion:import`.
- **`tmp/pids/server.pid` órfão impede o app de subir**, com
  `A server is already running (pid: 1)`. O serviço fica fora do ar sem erro
  óbvio. `rm -f tmp/pids/server.pid && docker compose up -d app`.
- **Exit code:** redirecione para arquivo e use `echo $?`. Pipe para `tail`
  perde o código e faz teste vermelho parecer verde.
- **O volume nomeado `bundle` sombreia as gems da imagem.** Mudar o `Gemfile` e
  reconstruir não basta: `docker compose run --rm --no-deps app bundle install`.
- **Docker em WSL:** `~/.docker/config.json` tem `credsStore: desktop.exe`, que
  não existe no PATH. Contorno: `DOCKER_CONFIG` apontando para um config `{}`
  vazio. **Não editar o config global do usuário.**
- **A rota do catálogo é `/catalog`**, não `/cards`. `/cards/:id` é o detalhe.

---

## 6. Método de trabalho (não negociável)

Fluxo `requirements` → `design` → `tasks`, com o skill `tlc-spec-driven`
ativado **pelo nome**.

- **Uma task por vez**, em ordem. Toda task termina com código que roda e teste
  que passa. "Estrutura criada" não conta.
- **Um commit atômico por task**, Conventional Commits em inglês.
- **Marcar o checkbox nos DOIS planos** (`.context/tasks.md` e o de `.specs/`) e
  commitar junto com o código.
- **Teste derivado do critério de aceite do spec**, nunca espelhando a
  implementação. Nunca enfraquecer, pular ou deletar teste para passar.
- **Se um requisito se mostrar errado, PARE e corrija o documento de origem**
  antes de seguir. Aconteceu três vezes nesta feature (`unaccent`, `UNION`,
  `similarity`) e foi o que impediu o spec de desalinhar do código.
- **Nunca adicionar linha de atribuição** (`Co-Authored-By`, `Generated with`)
  em commit. Regra dura do usuário.
- **Nunca `git stash`** — há trabalho não commitado com frequência. Isolar por
  cópia de arquivo.
- **Nunca `push`, `reset --hard`, `rebase` ou force-push sem pedir.**
- Em divergência entre `.context/` e `.specs/`, **`.context/` vence** (AD-005).

### Gates

- **quick**: `bin/rails test test/models test/lib`
- **full**: `bin/rails test && bin/rubocop`
- **build**: `docker compose build`

Tudo em Docker, sempre com `-T`:
`docker compose exec -T app bin/rails test`

### Delegação e verificação

O plano de lotes está em `.specs/features/catalogo/tasks.md` §"Plano de
delegação" e funcionou bem: ~7 tasks por worker, nunca partindo uma fase, lotes
sequenciais. **O Verifier ao fim de cada lote é obrigatório e não se pergunta** —
autor ≠ verificador, com sensor de discriminação (mutação isolada por cópia de
arquivo).

**Não existe agente `ruby-reviewer` nem `rails-reviewer` instalado.** Use os
agnósticos de linguagem: `ecc:database-reviewer` (schema/índices),
`ecc:silent-failure-hunter` (erro engolido), `ecc:pr-test-analyzer` (qualidade
de teste), `ecc:a11y-architect` (views) e **`ecc:security-reviewer` antes de
expor rotas de sessão** — este último é especialmente relevante na Fase 4.

---

## 7. O que a experiência desta feature ensinou

Registrado como lições em `.specs/LESSONS.md` (L-001 a L-005), mas o resumo
prático:

1. **Suíte verde não é prova.** Três defeitos reais passaram por suítes
   inteiramente verdes: o limiar do trigram que não sobrevivia à transação (a
   suíte era *estruturalmente* cega, porque todo teste do Rails roda em
   transação), o prepend do match exato repetindo em toda página, e a guarda de
   aplicabilidade de campo sem cobertura. **Rodar a aplicação de verdade achou o
   que 49 testes não acharam.**
2. **Teste que não discrimina não é teste.** Várias asserções escritas aqui
   passavam mas não falhavam contra o bug — fixtures onde o valor é `nil` dos
   dois lados, ou nomes que pontuam 0 em qualquer limiar. Sempre verifique que o
   teste **falha** contra o código errado.
3. **Limiar precisa de trava nos dois sentidos.** Só por cima deixa baixar à
   vontade.
4. **Medir antes de copiar o padrão.** O teste de plano do `counter` não podia
   copiar o do `cost`: no catálogo real a faixa larga casa 61% das linhas e o
   Seq Scan é a escolha *certa* do planejador.
