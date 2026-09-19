require "test_helper"

# T11 — busca textual (Req. 3.1 a 3.4 e 3.6).
#
# Os três caminhos de busca são testados pelo resultado, não pelo SQL: nome com
# tolerância a typo, texto de efeito por full-text, e `card_number` exato
# prependido. O caso do typo é o que mais importa — o default do `pg_trgm` não
# atende o Req. 3.3 sozinho, e um teste que só buscasse o nome inteiro certo
# passaria sem provar nada.
class CatalogSearchTest < ActiveSupport::TestCase
  setup do
    @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")

    @zoro = create_card(
      card_number: "OP01-001", name: "Roronoa Zoro", card_type: "leader",
      colors: [ "Red" ], cost: 3, power: 5000,
      effect_text: "Rest this Character to draw one card."
    )
    # Acento real do catálogo: buscar "Bell-mere" tem que achar "Bell-mère".
    @bellmere = create_card(
      card_number: "OP01-002", name: "Bell-mère", card_type: "character",
      colors: [ "Green" ], cost: 2, power: 3000,
      effect_text: "Give up to one of your Characters plus one thousand power."
    )
    @nami = create_card(
      card_number: "OP01-003", name: "Nami", card_type: "character",
      colors: [ "Blue" ], cost: 1, power: 1000,
      effect_text: "Draw two cards and trash one card from your hand."
    )
    # O nome desta carta contém o card_number de outra, e o `card_number` dela
    # ordena **antes** do exato na ordenação padrão (`card_number asc`). Isso é
    # deliberado: se o decoy viesse depois, o exato apareceria em primeiro por
    # sorte da ordenação e o teste passaria mesmo sem prepend nenhum.
    @homenagem = create_card(
      card_number: "OP01-000", name: "Tribute to OP01-001", card_type: "event",
      colors: [ "Red" ], cost: 1,
      effect_text: "Look at the top card of your deck."
    )

    [ @zoro, @bellmere, @nami, @homenagem ].each do |card|
      CardVariant.create!(card: card, set_id: @op01.id,
                          variant_code: card.card_number, rarity: "C", art_kind: "base")
    end
  end

  def create_card(**attrs)
    Card.create!(set_id: @op01.id, **attrs)
  end

  def numbers(result) = result.records.map(&:card_number)

  def search(term, **params) = CatalogQuery.new(q: term, **params).call

  def seed_for_planner(connection)
    connection.execute(<<~SQL)
      INSERT INTO cards (set_id, card_number, name, card_type, colors, created_at, updated_at)
      SELECT #{@op01.id}, 'SEED-' || lpad(i::text, 6, '0'),
             'Personagem Generico ' || i, 'character', ARRAY['Purple'], now(), now()
      FROM generate_series(1, 20000) AS i
    SQL
    connection.execute("ANALYZE cards")
  end

  # --- Req. 3.2: caixa e acento ---

  test "busca por nome é insensível a maiúsculas e minúsculas" do
    assert_includes numbers(search("roronoa zoro")), "OP01-001"
    assert_includes numbers(search("RORONOA ZORO")), "OP01-001"
  end

  test "busca por nome é insensível a acentuação nos dois sentidos" do
    assert_includes numbers(search("Bell-mere")), "OP01-002",
                    "termo sem acento tem que achar o nome acentuado"
    assert_includes numbers(search("Bell-mère")), "OP01-002"
  end

  # --- Req. 3.3: tolerância a erro de digitação ---

  test "erro de digitação de um caractere ainda acha a carta" do
    assert_includes numbers(search("Zorro")), "OP01-001"
    assert_includes numbers(search("Namy")), "OP01-003"
  end

  test "erro de digitação em nome acentuado ainda acha a carta" do
    assert_includes numbers(search("Belmere")), "OP01-002"
  end

  # --- Req. 3.1: texto de efeito ---

  test "busca casa o texto de efeito" do
    resultado = numbers(search("trash"))

    assert_includes resultado, "OP01-003"
    refute_includes resultado, "OP01-001"
  end

  test "busca no efeito casa flexão da palavra via full-text" do
    # "drawing" precisa achar "draw": é o que o stemming do full-text entrega e
    # um LIKE não entregaria.
    assert_includes numbers(search("drawing")), "OP01-003"
  end

  # --- Req. 3.4: card_number exato prependido ---

  test "match exato de card_number vem como primeiro resultado" do
    resultado = numbers(search("OP01-001"))

    assert_equal "OP01-001", resultado.first
  end

  # A carta cujo *nome* contém "OP01-001" também casa a busca. O exato tem que
  # vir antes dela, e nenhuma das duas pode sumir nem duplicar.
  test "carta exata precede outra que apenas menciona o código, sem duplicar" do
    resultado = numbers(search("OP01-001"))

    assert_equal "OP01-001", resultado.first
    assert_includes resultado, "OP01-000"
    assert_equal resultado.uniq, resultado, "nenhuma carta pode aparecer duas vezes"
  end

  # O decoy `OP01-000` ordena antes de `OP01-001` na ordenação padrão. Se o
  # prepend for removido, é ele que vem primeiro — é esta asserção que separa
  # "prependido" de "veio primeiro por acaso".
  test "exato precede carta que ordenaria antes dele" do
    resultado = numbers(search("OP01-001"))

    assert_equal "OP01-001", resultado.first
    assert_equal "OP01-000", resultado.second,
                 "o decoy tem que continuar no resultado, logo depois do exato"
  end

  # Mesmo com ordenação escolhida pelo usuário, o exato continua à frente:
  # prepend é uma consulta separada, não um critério de ordenação.
  test "exato continua em primeiro sob ordenação por nome" do
    resultado = numbers(search("OP01-001", sort: "name", dir: "asc"))

    assert_equal "OP01-001", resultado.first
  end

  test "match exato de card_number é insensível a caixa" do
    assert_equal "OP01-001", numbers(search("op01-001")).first
  end

  test "card_number exato é prependido mesmo quando cairia em outra página" do
    resultado = search("OP01-001", per_page: 1)

    assert_equal [ "OP01-001" ], numbers(resultado)
  end

  # --- Req. 3.6: combinável com todos os filtros ---

  test "busca combina com filtro de cor" do
    resultado = numbers(search("Zorro", colors: [ "Red" ]))

    assert_includes resultado, "OP01-001"
  end

  test "filtro exclui a carta encontrada pela busca quando não casa" do
    resultado = numbers(search("Zorro", colors: [ "Green" ]))

    refute_includes resultado, "OP01-001",
                    "o filtro tem que valer sobre o resultado da busca (E, não OU)"
  end

  test "card_number exato prependido continua sujeito aos filtros" do
    resultado = numbers(search("OP01-001", colors: [ "Blue" ]))

    refute_includes resultado, "OP01-001",
                    "prepender não pode passar por cima do filtro ativo"
  end

  test "busca combina com faixa de custo" do
    resultado = numbers(search("Nami", cost_max: 1))

    assert_includes resultado, "OP01-003"
    assert_empty numbers(search("Nami", cost_min: 5))
  end

  # --- total_count e robustez ---

  test "total_count reflete o resultado da busca, não o catálogo inteiro" do
    resultado = search("Zorro")

    assert_operator resultado.total_count, :<, Card.count
    assert_operator resultado.total_count, :>=, 1
  end

  test "total_count conta o exato prependido uma única vez" do
    resultado = search("OP01-001")

    assert_equal numbers(resultado).uniq.size, resultado.total_count
  end

  test "termo sem resultado devolve vazio sem erro" do
    resultado = search("xyzqwkjhgf")

    assert_empty resultado.records
    assert_equal 0, resultado.total_count
  end

  test "termo em branco não filtra nada" do
    assert_equal Card.count, search("   ").total_count
  end

  test "termo com caractere especial de SQL não levanta erro" do
    resultado = search("'); DROP TABLE cards; --")

    assert_equal 0, resultado.total_count
    assert_equal 4, Card.count
  end

  # Req. 11.3 — o índice GIN trigram só é usado se a consulta chamar
  # `immutable_unaccent(name)`; com `unaccent` direto o Postgres cai em
  # varredura completa (design.md §4.1.1). Sem esta asserção, trocar uma pela
  # outra passa despercebido: o resultado é idêntico, só a latência muda.
  test "a busca por nome usa o índice trigram, sem varredura completa" do
    connection = ActiveRecord::Base.connection
    # Com quatro linhas o planejador escolhe Seq Scan *com razão*, e o teste
    # não distinguiria índice ausente de índice ignorado por custo — a mesma
    # lição da T4. O volume aqui é o mínimo para o índice ser a escolha barata.
    seed_for_planner(connection)
    plano = connection.uncached do
      connection.select_values("EXPLAIN #{CatalogQuery.new(q: "Zorro").search_match_sql}")
    end.join("\n")

    refute_match(/Seq Scan on cards/, plano,
                 "a busca fez varredura completa. Plano:\n#{plano}")
    assert_match(/index_cards_on_unaccent_name_trgm/, plano,
                 "a ramificação de nome não usou o índice trigram. Plano:\n#{plano}")
    assert_match(/index_cards_on_effect_text_tsvector/, plano,
                 "a ramificação de efeito não usou o índice full-text. Plano:\n#{plano}")
    assert_match(/index_cards_on_card_number_trgm/, plano,
                 "a ramificação de card_number não usou o índice trigram. Plano:\n#{plano}")
  end

  # O match exato é a consulta mais quente da busca e a única com índice único
  # disponível. `upper(card_number) = upper(?)` devolve o mesmo resultado e
  # descarta o índice — defeito que nenhum teste funcional pega, porque só a
  # latência muda.
  test "o match exato de card_number usa o índice único" do
    connection = ActiveRecord::Base.connection
    seed_for_planner(connection)
    sql = CatalogQuery.new(q: "OP01-001").exact_match_sql
    plano = connection.uncached { connection.select_values("EXPLAIN #{sql}") }.join("\n")

    assert_match(/index_cards_on_card_number/, plano,
                 "o match exato não usou o índice único. Plano:\n#{plano}")
    refute_match(/Seq Scan on cards/, plano)
  end

  # Req. 3.1 — código parcial é busca real: "OP01" casa 121 cartas no catálogo,
  # 13 delas em outro set, que o filtro de set sozinho não acharia.
  test "busca casa card_number por substring, não só exato" do
    resultado = numbers(search("OP01-0"))

    assert_operator resultado.size, :>=, 3
    assert_includes resultado, "OP01-003"
  end

  test "o termo buscado aparece nos filtros ativos para o estado vazio" do
    assert_equal "Zorro", search("Zorro").active_filters[:q]
  end
end
