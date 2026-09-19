# Especificação — Coleção (Fase 4)

Recorte da feature `colecao` sobre `.context/requirements.md` Req. 6, 7 e 8, e
`.context/tasks.md` §4. Em divergência, `.context/` vence (AD-005).

## Problem Statement

O catálogo está completo e é público, mas nada no sistema pertence a ninguém: a
tabela `users` existe apenas para a task 2.6 provar que a ingestão não destrói
dado do usuário, e não há login, sessão nem forma de registrar posse. Sem isso,
o produto responde "quais cartas existem?" e não responde "quais cartas eu
tenho?" — que é a pergunta que justifica o projeto (`product.md` §7). Esta
feature entrega conta, coleção por variante e wishlist, sem quebrar a invariante
de que o catálogo é regenerável e a coleção é insubstituível.

## Goals

- [ ] Usuário cria conta, autentica e encerra sessão, com senha só como hash.
- [ ] Catálogo e busca continuam acessíveis sem sessão; toda mutação exige sessão.
- [ ] Quantidade possuída por variante, incrementável e decrementável em uma ação, sem recarregar a página.
- [ ] Filtro de posse integrado ao `CatalogQuery` existente, sem reescrevê-lo.
- [ ] Wishlist com quantidade-alvo e sinalização de item atendido.
- [ ] Nenhum usuário lê ou altera a coleção de outro, por construção e não por verificação.

## Out of Scope

| Feature | Reason |
|---|---|
| Reset de senha por e-mail (`PasswordsController`, `PasswordsMailer`) | O gerador do Rails o traz junto, mas nenhum critério do Req. 6 o pede e não há SMTP configurado. Entra quando houver requisito. |
| Progresso por set (Req. 9) | `.context/tasks.md` §5.1. Depende da coleção existir; é a feature seguinte, não esta. |
| Import/export CSV (Req. 10) | `.context/tasks.md` §5.2–5.3. Mesma dependência, mesma razão. |
| OAuth, login social, 2FA | Fora de `.context/requirements.md` §6 inteiro. |
| Confirmação de e-mail | Nenhum critério do Req. 6 a exige; adicionaria SMTP e um estado a mais no `User`. |
| Preço e valor da coleção | Fase 3 do produto, e AD-001 registra que a fonte atual não tem preço. |
| Deck building | `product.md` declara Fase 2; referencia `cards`, não `card_variants`. |

## Assumptions & Open Questions

| Assumption/decision | Chosen default | Rationale | Confirmed? |
|---|---|---|---|
| Colisão do gerador de autenticação com a tabela `users` existente | **Não executar `bin/rails generate authentication`.** Portar à mão `Session`, `Current`, o concern `Authentication` e `SessionsController` a partir dos templates de `railties-8.0.5.1`, mantendo a coluna `email` e preservando o `User` atual | Quatro conflitos verificados no fonte da gem (`authentication_generator.rb`): (1) `generate "migration CreateUsers ... --force"` cria um segundo `create_table :users` e quebra `db:migrate`; (2) usa `email_address`, enquanto a tabela tem `email` e `index_users_on_lower_email`; (3) `template "app/models/user.rb"` sobrescreve o model e apaga `has_many :collection_items, dependent: :restrict_with_exception` — a linha que protege o dado irrecuperável do Req. 1.7; (4) `uncomment_lines "Gemfile"` + `bundle install` não atravessa o volume `bundle` que sombreia as gems da imagem. `ActiveRecord.authenticate_by` particiona os argumentos por `has_attribute?`, logo `email:` funciona sem adaptação — a doc da própria gem usa `email:` | Sim — `/usr/local/bundle/gems/railties-8.0.5.1/.../authentication_generator.rb` e `activerecord-8.0.5.1/lib/active_record/secure_password.rb:41` |
| Nome da coluna de identidade | `email`, mantida como está | Renomear para `email_address` exigiria migração de rename, recriar `index_users_on_lower_email` e reescrever a T8. Não compra nada: nenhuma API do Rails exige o nome | Sim |
| `bcrypt` no Gemfile | Adicionar `gem "bcrypt", "~> 3.1.7"` e instalar com `docker compose run --rm --no-deps app bundle install` | `has_secure_password` carrega bcrypt sob demanda (`active_model/secure_password.rb:117`); a gem está comentada no Gemfile. O volume nomeado `bundle` sombreia as gems da imagem, então reconstruir a imagem não basta — dívida já registrada em `STATE.md` | Sim |
| Hotwire para o Req. 7.2/7.5 | Instalar o importmap (`bin/rails importmap:install`) na task que implementa o incremento | Não há pipeline de JS: `app/javascript` e `config/importmap.rb` não existem, `stimulus-rails` está no Gemfile mas nunca foi executado. `STATE.md` registra isso como a primeira coisa a resolver aqui | Sim — ambos ausentes |
| Como o filtro de posse entra no catálogo | Novo parâmetro `owned` no `CatalogQuery`, aceitando `all`/`owned`/`missing` conforme `design.md` §4.2, com o usuário injetado pelo controller e nunca lido da URL | `design.md` §4.2 deixou `owned` fora do query object de propósito por depender de sessão, e o objeto aceita o filtro sem reescrita. O `CatalogQuery` já ignora parâmetro desconhecido ou inválido em vez de levantar erro (`catalog_query.rb:12`), então uma URL compartilhada com `owned` por um anônimo não dá 500 | Sim |
| Escopo de autorização | Toda consulta parte de `Current.user`; nenhuma action aceita `user_id` do request | Req. 6.5 vira invariante de construção em vez de checagem espalhada. É a regra que o `CLAUDE.md` já fixa para o projeto | Sim |
| Unicidade de `collection_items` | Já garantida no banco pela migração `20260919120200` (`UNIQUE (user_id, card_variant_id)` e `CHECK (quantity >= 0)`) | Req. 7.8 e 7.4 já estão satisfeitos no schema; esta feature consome, não recria | Sim — `db/structure.sql` |
| Modelagem da wishlist | Tabela nova `wishlist_items` (`user_id`, `card_variant_id`, `target_quantity`), com `UNIQUE (user_id, card_variant_id)`, `CHECK (target_quantity >= 1)` e FK `on_delete: :restrict` | Desejo e posse são estados independentes: querer 3 cópias e ter 0 precisa ser representável, e uma coluna em `collection_items` forçaria criar registro de posse para exprimir desejo. `restrict` pela mesma razão do `design.md` §5.2 — a ingestão não pode apagar dado do usuário em cascata | Sim |
| Item da wishlist "atendido" (Req. 8.3) | Derivado na consulta, comparando quantidade possuída com a alvo; nunca persistido como flag | Uma flag persistida fica obsoleta no instante em que a posse muda e exigiria sincronizar duas escritas. Derivar torna o Req. 8.3 verdadeiro por construção | Sim |

**Open questions:** none — all resolved or logged above

## User Stories

### P1: Conta e sessão ⭐ MVP

**User Story**: Como usuário, quero criar conta, autenticar e encerrar sessão, para que minha coleção esteja vinculada a mim e acessível de mais de um dispositivo.

**Why P1**: Nada da coleção ou da wishlist existe sem identidade. É a base das outras três histórias.

**Acceptance Criteria**:
1. The system SHALL permitir criar conta, autenticar e encerrar sessão.
2. The system SHALL armazenar a senha apenas como hash bcrypt, via `has_secure_password`, sem nenhuma coluna de senha em texto claro.
3. WHEN um usuário não autenticado acessar o catálogo, a busca ou o detalhe de uma carta THEN the system SHALL permitir a navegação sem exigir sessão.
4. WHEN um usuário não autenticado tentar alterar coleção ou wishlist THEN the system SHALL redirecionar para a tela de autenticação sem aplicar a alteração.
5. The system SHALL tratar o e-mail como identidade única, comparada sem distinção de caixa.
6. IF as credenciais informadas não corresponderem a um usuário THEN the system SHALL reapresentar a tela de autenticação com mensagem de erro em português que não revela se o e-mail existe.

**Independent Test**: Criar conta, encerrar sessão, autenticar de novo e acessar `/catalog` autenticado e anônimo; verificar em `db/structure.sql` que não há coluna de senha em claro.

### P1: Registrar posse por variante ⭐ MVP

**User Story**: Como colecionador, quero registrar quantas cópias de cada variante eu tenho, para saber minha coleção real.

**Why P1**: É o critério de sucesso do produto — registrar uma caixa de boosters pelo celular, sem planilha (`product.md` §7).

**Acceptance Criteria**:
1. The system SHALL permitir definir para cada variante uma quantidade possuída inteira e não-negativa.
2. WHEN o usuário acionar incremento ou decremento THEN the system SHALL aplicar a alteração em uma única ação, sem abrir formulário.
3. WHEN o usuário registrar posse a partir da grade do catálogo THEN the system SHALL atualizar a quantidade exibida sem recarregar a página inteira.
4. IF uma operação levar a quantidade abaixo de zero THEN the system SHALL rejeitar a operação e manter a quantidade anterior.
5. WHEN a quantidade de uma variante for definida como zero THEN the system SHALL tratá-la como não possuída em contagens e filtros.
6. The system SHALL garantir no banco de dados, e não apenas na aplicação, no máximo um registro de coleção por par (usuário, variante).
7. The system SHALL oferecer o registro de posse tanto na grade do catálogo quanto no detalhe da carta, sempre por variante.

**Independent Test**: Autenticado, incrementar uma variante na grade e conferir que a quantidade muda sem navegação; tentar decrementar abaixo de zero; conferir `UNIQUE` e `CHECK` em `db/structure.sql`.

### P1: Isolamento entre usuários ⭐ MVP

**User Story**: Como usuário, quero que minha coleção seja só minha, para que ninguém possa lê-la ou alterá-la.

**Why P1**: Req. 6.5 é absoluto ("NUNCA"). Uma falha aqui é vazamento de dados, não defeito de usabilidade.

**Acceptance Criteria**:
1. The system SHALL derivar toda consulta e toda escrita de coleção e wishlist do usuário da sessão corrente.
2. IF uma requisição informar um identificador de usuário THEN the system SHALL ignorá-lo e usar o usuário da sessão.
3. WHILE dois usuários distintos possuírem a mesma variante, the system SHALL apresentar a cada um apenas a sua própria quantidade.
4. WHEN um usuário autenticado solicitar um item de coleção ou wishlist que pertence a outro usuário THEN the system SHALL responder com 404 sem revelar a existência do item.

**Independent Test**: Criar dois usuários com posse da mesma variante; autenticado como o primeiro, tentar ler e alterar o item do segundo por id.

### P2: Filtro de posse e total

**User Story**: Como colecionador, quero filtrar o catálogo pelo que tenho e pelo que falta, e ver meu total, para decidir o que caçar.

**Why P2**: Depende das três histórias P1 e agrega navegação sobre dado que já existe; a coleção é utilizável sem ele.

**Acceptance Criteria**:
1. The system SHALL aceitar no catálogo o parâmetro `owned` com os valores `all`, `owned` e `missing`, conforme o contrato de `design.md` §4.2.
2. WHEN o filtro de posse estiver ativo THEN the system SHALL combiná-lo com os demais filtros e com a busca pela semântica já vigente: OU dentro da categoria, E entre categorias.
3. WHERE o filtro de posse for informado por um usuário sem sessão, the system SHALL ignorá-lo e apresentar o catálogo completo, sem erro.
4. The system SHALL exibir o total de cartas possuídas contando cópias.
5. WHEN uma variante tiver quantidade zero THEN the system SHALL contá-la como não possuída no filtro e no total.

**Independent Test**: Com posse registrada, aplicar cada valor do filtro e conferir a contagem; abrir a mesma URL anônimo e verificar que responde 200 com catálogo completo.

### P2: Wishlist

**User Story**: Como colecionador, quero marcar cartas que quero adquirir com uma quantidade-alvo, para levar essa lista a trocas e compras.

**Why P2**: Valor real, mas a coleção cumpre o critério de sucesso do produto sem ela.

**Acceptance Criteria**:
1. The system SHALL permitir marcar uma variante como desejada com uma quantidade-alvo inteira e maior que zero.
2. The system SHALL permitir listar apenas os itens desejados do usuário da sessão.
3. WHEN a quantidade possuída de uma variante atingir ou exceder a quantidade-alvo THEN the system SHALL sinalizar esse item como atendido.
4. The system SHALL permitir remover um item da wishlist.
5. The system SHALL garantir no banco de dados no máximo um item de wishlist por par (usuário, variante).

**Independent Test**: Marcar variante com alvo 2, registrar posse 1 (não atendido), subir para 2 (atendido), remover o item.

## Edge Cases

- WHEN a ingestão rodar com itens de coleção e wishlist existentes, THEN as quantidades permanecem intactas — a FK `on_delete: :restrict` transforma tentativa de remoção em erro barulhento em vez de perda calada (Req. 1.7, AD-001).
- IF o usuário acionar incremento em duas abas ao mesmo tempo, THEN a unicidade `(user_id, card_variant_id)` do banco impede registro duplicado; a segunda escrita atualiza, não insere.
- IF uma variante referenciada pela wishlist for marcada como ausente da fonte, THEN o item continua listado — a ingestão não deleta (Req. 1.7).
- WHEN `owned` chegar com valor fora de `all|owned|missing`, THEN é ignorado como qualquer parâmetro inválido do `CatalogQuery`, sem erro.
- IF o decremento chegar para uma variante sem registro de coleção, THEN a operação é rejeitada sem criar registro com quantidade negativa.
- WHEN a sessão expirar durante a navegação e o usuário acionar incremento, THEN a alteração não é aplicada e o usuário é levado à autenticação, retornando à página de origem depois.
- IF o JavaScript não estiver disponível, THEN incremento e decremento continuam funcionando por submissão normal, com recarga — o Req. 7.5 é melhoria progressiva, não pré-requisito de funcionamento.

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| COL-01 | Conta e sessão (Req. 6.1) | 4 | Pending |
| COL-02 | Senha só como hash (Req. 6.2) | 4 | Pending |
| COL-03 | Catálogo público sem sessão (Req. 6.3) | 4 | Pending |
| COL-04 | Mutação exige sessão (Req. 6.4) | 4 | Pending |
| COL-05 | Isolamento entre usuários (Req. 6.5) | 4 | Pending |
| COL-06 | Quantidade possuída não-negativa (Req. 7.1) | 4 | Pending |
| COL-07 | Incremento/decremento em ação única (Req. 7.2) | 4 | Pending |
| COL-08 | Zero equivale a não possuída (Req. 7.3) | 4 | Pending |
| COL-09 | Quantidade nunca negativa (Req. 7.4) | 4 | Pending |
| COL-10 | Atualização sem recarregar a página (Req. 7.5) | 4 | Pending |
| COL-11 | Filtro de posse no catálogo (Req. 7.6) | 4 | Pending |
| COL-12 | Total de cartas possuídas (Req. 7.7) | 4 | Pending |
| COL-13 | Um registro por (usuário, variante), no banco (Req. 7.8) | 4 | Pending |
| COL-14 | Marcar desejada com quantidade-alvo (Req. 8.1) | 4 | Pending |
| COL-15 | Listar itens desejados (Req. 8.2) | 4 | Pending |
| COL-16 | Sinalizar item atendido (Req. 8.3) | 4 | Pending |
| COL-17 | Remover item da wishlist (Req. 8.4) | 4 | Pending |
| COL-18 | Registro de posse na grade e no detalhe (Req. 5.3) | 4 | Pending |

**Coverage:** 18 total, 0 mapped to tasks, 18 unmapped ⚠️ (tasks.md ainda não escrito — próxima fase)

## Success Criteria

- [ ] Um usuário registra uma caixa de boosters inteira pelo celular, por variante, sem planilha (`product.md` §7).
- [ ] `bin/rails test` passa inteiro, incluindo os testes de catálogo já existentes, sem alteração de asserção.
- [ ] Existe teste que prova que um usuário não lê nem altera a coleção de outro.
- [ ] Existe teste que prova que `UNIQUE (user_id, card_variant_id)` e `CHECK (quantity >= 0)` são do banco, não da aplicação.
- [ ] A ingestão roda duas vezes com coleção e wishlist povoadas e nenhuma quantidade muda.
- [ ] `/catalog` responde 200 sem sessão, inclusive com `owned` na URL.
- [ ] `bin/rubocop` limpo.
