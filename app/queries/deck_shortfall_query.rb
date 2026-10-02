# O que falta na pasta para montar os decks (DCK-20..23, DCK-33).
#
# A pergunta é uma só, "quantas cópias desta carta os decks pedem e quantas eu
# tenho?", e só o escopo muda: com `deck:`, um deck (a página do deck); sem,
# todos os decks do usuário (o bloco da pasta). Por isso a consulta também é
# uma só.
#
# ## Uma consulta, com o `Card` junto
#
# Dois CTEs e um join, executados por `Card.find_by_sql`: o resultado já traz a
# carta instanciada, e a página não precisa de uma segunda consulta para o nome
# e o número. O teste conta as consultas com 1 e com 3 decks.
#
# - `demand`: `UNION ALL` das entradas com o Leader (quantidade 1), agrupado por
#   carta com `MAX(quantity)`. Com um deck só o `MAX` é a própria quantidade;
#   com vários, vale o **maior** uso, porque um deck é desmontado para montar
#   outro (decisão do dono em 2026-10-01).
# - `owned`: soma de `collection_items.quantity` do usuário por carta, **sem**
#   filtro de presença. Variante ausente da fonte continua sendo uma carta
#   física na pasta (Req. 1.7), e para jogar qualquer impressão serve (DCK-20).
#
# Nada é gravado: a falta é derivada da coleção atual a cada chamada (DCK-23).
#
# ## O usuário é o objeto
#
# Como em `SetProgressQuery` e `CollectionItem.for_user`, o usuário entra como
# `User` ou `nil`, nunca um id (Req. 6.5 por construção). O filtro por
# `decks.user_id` vale também com `deck:`: um deck de outro usuário devolve
# vazio, em vez de expor a demanda dele.
class DeckShortfallQuery
  Row = Data.define(:card, :required, :owned, :missing, :deck_ids)

  def initialize(user, deck: nil)
    unless user.nil? || user.is_a?(User)
      raise ArgumentError, "DeckShortfallQuery espera um User ou nil, recebeu #{user.class}"
    end

    @user = user
    @deck = deck
  end

  def call
    return [] if @user.nil?

    Card.find_by_sql([ sql, { user_id: @user.id, deck_id: @deck&.id } ]).map do |card|
      Row.new(card: card, required: card.required_quantity, owned: card.owned_quantity,
              missing: card.missing_quantity, deck_ids: card.demand_deck_ids)
    end
  end

  private

  def sql
    deck_filter = @deck ? "AND decks.id = :deck_id" : ""

    <<~SQL
      WITH demand AS (
        SELECT used.card_id,
               MAX(used.quantity) AS required_quantity,
               array_agg(DISTINCT used.deck_id ORDER BY used.deck_id) AS deck_ids
        FROM (
          SELECT deck_entries.deck_id, deck_entries.card_id, deck_entries.quantity
          FROM deck_entries
          INNER JOIN decks ON decks.id = deck_entries.deck_id
          WHERE decks.user_id = :user_id #{deck_filter}
          UNION ALL
          SELECT decks.id, decks.leader_card_id, 1
          FROM decks
          WHERE decks.user_id = :user_id AND decks.leader_card_id IS NOT NULL #{deck_filter}
        ) used
        GROUP BY used.card_id
      ),
      owned AS (
        SELECT card_variants.card_id, SUM(collection_items.quantity) AS owned_quantity
        FROM collection_items
        INNER JOIN card_variants ON card_variants.id = collection_items.card_variant_id
        WHERE collection_items.user_id = :user_id
          AND card_variants.card_id IN (SELECT card_id FROM demand)
        GROUP BY card_variants.card_id
      )
      SELECT cards.*,
             demand.required_quantity,
             COALESCE(owned.owned_quantity, 0) AS owned_quantity,
             GREATEST(0, demand.required_quantity - COALESCE(owned.owned_quantity, 0)) AS missing_quantity,
             demand.deck_ids AS demand_deck_ids
      FROM demand
      INNER JOIN cards ON cards.id = demand.card_id
      LEFT JOIN owned ON owned.card_id = demand.card_id
      ORDER BY cards.card_number
    SQL
  end
end
