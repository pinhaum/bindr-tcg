# Quantas cópias de uma **variante** o usuário possui. Referencia variante, e
# não carta: a arte base e a alternativa são objetos de coleção distintos
# (design.md §3.1).
#
# As garantias de integridade não são daqui: `UNIQUE (user_id,
# card_variant_id)`, `CHECK (quantity >= 0)` e as duas FKs `on_delete:
# :restrict` nasceram na migração `20260919120200` e estão provadas contra o
# banco em `test/models/collection_item_test.rb`. As validações abaixo existem
# para que o formulário possa **dizer** o que está errado em vez de estourar
# 500 — a garantia real continua sendo do schema, que nenhuma corrida
# atravessa e nenhum `UPDATE` direto contorna.
class CollectionItem < ApplicationRecord
  belongs_to :user
  belongs_to :card_variant

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :card_variant_id, uniqueness: { scope: :user_id }

  # Req. 7.3 — zero é representável e significa "não possuída". Zero **não** é
  # ausência de registro: o usuário que zera uma quantidade mantém a linha, e
  # é por isso que `owned` filtra pela quantidade (`1..`, que o
  # `CHECK (quantity >= 0)` torna equivalente a "maior que zero") em vez de
  # testar existência do registro. Usar ausência de linha como sentinela de "não tem" quebraria o
  # filtro do Req. 7.6 para quem já teve a carta e não tem mais.
  scope :owned, -> { where(quantity: 1..) }
  scope :unowned, -> { where(quantity: 0) }

  # Req. 6.5 / design.md §7 — toda consulta a coleção parte do usuário da
  # sessão. O argumento é o **objeto** `User`, nunca um id: aceitar um id
  # deixaria `CollectionItem.for_user(params[:user_id])` compilar, e a violação
  # de autorização passaria despercebida na revisão. Com o tipo exigido aqui, a
  # única forma de escrever a consulta errada é construir um `User` a partir do
  # request — o que não acontece por acidente.
  #
  # `nil` (o anônimo do catálogo público) devolve relação vazia em vez de
  # levantar erro: o catálogo renderiza para quem não tem sessão, e ali a
  # coleção simplesmente não existe.
  scope :for_user, ->(user) {
    case user
    when nil then none
    when User then where(user: user)
    else raise ArgumentError, "for_user espera um User ou nil, recebeu #{user.class}"
    end
  }

  # Req. 7.7 / COL-12 — o total de **cópias** da coleção de um usuário.
  #
  # `sum(:quantity)` e não `count`: o requisito diz "contando cópias". Quem tem
  # três cópias de uma variante e duas de outra tem total 5, não 2 — `count`
  # responderia quantas variantes distintas, que é a métrica do Req. 9
  # (progresso por set), com denominador próprio decidido em AD-003.
  #
  # O `owned` é aritmeticamente redundante (uma linha com zero soma zero) e
  # está aqui assim mesmo: ele é a definição de "possuída" do Req. 7.3, e é o
  # que segura o número no dia em que alguém trocar a agregação. Sem ele,
  # `count` passaria a contar as linhas zeradas em silêncio.
  #
  # Aqui e não no controller porque são dois os chamadores: a grade do catálogo
  # exibe o total e o Turbo Stream da posse o re-renderiza. Duas somas escritas
  # à mão divergiriam na primeira mudança de critério.
  def self.total_copies_for(user)
    for_user(user).owned.sum(:quantity)
  end

  # Req. 13.4 / NAV-17, NAV-18 — os dois indicadores de Minha pasta em uma única
  # consulta: total de cópias e variantes distintas. Retorna um Hash com as chaves
  # `:total_copies` e `:distinct_variants`.
  #
  # O uso é em `views/progress/index.html.erb` para renderizar os indicadores sem
  # adicionar uma segunda consulta à página. O teste de plano
  # (`set_progress_plan_test.rb`) mede que a página resolve com duas consultas de
  # sessão + uma agregação por set + uma agregação dos indicadores = três consultas
  # no total (sem contar a conclusão de transação).
  #
  # Req. 15 (PRC-11..PRC-16) — a mesma consulta traz o valor da coleção,
  # agrupada pelo set da **variante**: total e indicadores são a soma das linhas,
  # então a soma dos subtotais é o total por construção, com as cópias de
  # variante ausente da fonte incluídas. Só preço em USD entra na soma (AD-022).
  def self.collection_stats_for(user)
    rows = for_user(user).owned.joins(:card_variant).group("card_variants.set_id").pluck(*STATS_COLUMNS)

    {
      total_copies: rows.sum { |row| row[1] },
      distinct_variants: rows.sum { |row| row[2] },
      estimated_value: rows.sum(BigDecimal("0")) { |row| row[3] },
      unpriced_copies: rows.sum { |row| row[4] },
      value_by_set_id: rows.to_h { |row| [ row[0], row[3] ] }
    }
  end

  STATS_COLUMNS = [
    "card_variants.set_id",
    "SUM(collection_items.quantity)",
    "COUNT(*)",
    "COALESCE(SUM(collection_items.quantity * card_variants.price_amount) " \
    "FILTER (WHERE card_variants.price_currency = 'USD'), 0)",
    "COALESCE(SUM(collection_items.quantity) FILTER (WHERE card_variants.price_amount IS NULL), 0)"
  ].map { |column| Arel.sql(column) }.freeze
  private_constant :STATS_COLUMNS

  # Req. 7.2 — incremento atômico no banco. Devolve a quantidade resultante.
  #
  # `INSERT ... ON CONFLICT DO UPDATE SET quantity = <tabela>.quantity + 1`
  # resolve leitura e escrita num único statement. A alternativa ingênua
  # (`item.update!(quantity: item.quantity + 1)`) lê em Ruby e escreve depois:
  # duas abas incrementando de 1 ao mesmo tempo leem 1 as duas, escrevem 2 as
  # duas, e uma das operações do usuário evapora — *lost update* clássico,
  # apontado pelo `ecc:database-reviewer` na T5 como problema desta camada.
  # Um `SELECT ... FOR UPDATE` também resolveria, mas custa uma ida a mais ao
  # banco e uma transação explícita para proteger um contador de inteiro;
  # `ON CONFLICT` faz o mesmo com o lock de linha que o próprio `UPDATE` já
  # toma. E é o `ON CONFLICT` que transforma a corrida de **criação** (duas
  # abas incrementando uma variante ainda não possuída) em atualização em vez
  # de `RecordNotUnique`, como a spec exige nos Edge Cases.
  def self.increment_for!(user, variant)
    execute_returning_quantity(<<~SQL, user.id, variant.id)
      INSERT INTO collection_items (user_id, card_variant_id, quantity, created_at, updated_at)
      VALUES ($1, $2, 1, now(), now())
      ON CONFLICT (user_id, card_variant_id)
      DO UPDATE SET quantity = collection_items.quantity + 1, updated_at = now()
      RETURNING quantity
    SQL
  end

  # Req. 7.4 / COL-09 — o piso de zero mora no `WHERE`, não num `if` em Ruby.
  # Devolve a quantidade resultante, ou `nil` quando nenhuma linha foi afetada.
  #
  # `quantity > 0` como condição do próprio `UPDATE` faz o banco decidir, na
  # mesma linha travada que ele vai escrever, se ainda há o que decrementar.
  # Checar antes em Ruby e escrever depois reabriria a janela: duas abas
  # decrementando de 1 leriam 1 as duas e as duas tentariam escrever 0 — aqui a
  # segunda simplesmente não casa o `WHERE` e afeta zero linhas.
  #
  # Zero linha afetada cobre os dois casos de rejeição do "Done when" com o
  # mesmo statement: quantidade já em zero e variante **sem registro nenhum**.
  # O `UPDATE` não cria linha, então decrementar o que não existe não pode
  # produzir registro negativo — não há o que inserir.
  #
  # O `CHECK (quantity >= 0)` do schema continua sendo a garantia real (a T5 o
  # prova por `UPDATE` direto); este `WHERE` é o que transforma a violação em
  # mensagem para o usuário em vez de 500.
  def self.decrement_for!(user, variant)
    execute_returning_quantity(<<~SQL, user.id, variant.id)
      UPDATE collection_items
      SET quantity = quantity - 1, updated_at = now()
      WHERE user_id = $1 AND card_variant_id = $2 AND quantity > 0
      RETURNING quantity
    SQL
  end

  # `exec_query` com bind params, não interpolação. `BigInteger`, como as
  # colunas `bigint`: `Integer` recusaria um id acima de 2³¹ com `RangeError`.
  def self.execute_returning_quantity(sql, user_id, card_variant_id)
    binds = [
      ActiveRecord::Relation::QueryAttribute.new("user_id", user_id, ActiveRecord::Type::BigInteger.new),
      ActiveRecord::Relation::QueryAttribute.new("card_variant_id", card_variant_id, ActiveRecord::Type::BigInteger.new)
    ]
    connection.exec_query(sql, "CollectionItem Quantity", binds).rows.dig(0, 0)
  end
  private_class_method :execute_returning_quantity

  # Req. 7.3 — a pergunta "o usuário tem esta variante?" é sobre a quantidade,
  # não sobre a existência do registro.
  def owned?
    quantity.to_i.positive?
  end
end
