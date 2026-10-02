# O deck de um usuário: nome, Leader opcional e as entradas do deck principal
# (DCK-02). Referencia `cards`, nunca `card_variants`: para jogar, qualquer
# impressão serve (design.md §10).
#
# As garantias de integridade são do schema (migração `20261002120000`,
# provadas em `test/models/deck_schema_test.rb`). As validações abaixo existem
# para que o formulário possa **dizer** o que está errado em vez de estourar
# 500, como em `CollectionItem`.
class Deck < ApplicationRecord
  NAME_LENGTH = 1..60

  # Ordem dos grupos da página do deck e da exportação (DCK-07, DCK-31). Tipo
  # fora da lista vai para o fim em vez de levantar erro: a fonte é um agregador
  # comunitário, e um tipo novo não pode derrubar a página.
  TYPE_ORDER = %w[character event stage].freeze

  belongs_to :user
  belongs_to :leader, class_name: "Card", foreign_key: :leader_card_id, optional: true

  # `delete_all`: as entradas só existem dentro do deck e não são dado de
  # coleção. A FK `ON DELETE CASCADE` faria o mesmo; esta linha só evita que o
  # Active Record carregue as entradas para apagá-las uma a uma.
  has_many :entries, class_name: "DeckEntry", dependent: :delete_all, inverse_of: :deck

  normalizes :name, with: ->(name) { name.strip }

  validates :name, length: { minimum: NAME_LENGTH.min, maximum: NAME_LENGTH.max,
                             too_short: "não pode ficar vazio",
                             too_long: "pode ter no máximo #{NAME_LENGTH.max} caracteres" }

  # Integridade do modelo, não regra do jogo: um Character no lugar do Leader
  # não é um deck ilegal, é um deck mal formado. Por isso recusa a gravação,
  # ao contrário das regras de montagem, que só mudam o status (DCK-18).
  validate :leader_must_be_a_leader

  # Em Ruby sobre as entradas carregadas, e não num `order` SQL: a lista de
  # decks faz `includes(entries: :card)` (design.md, Tech Decisions), e um
  # `order` aqui dispararia uma consulta por deck. Um deck tem no máximo 51
  # linhas.
  def ordered_entries
    entries.sort_by do |entry|
      card = entry.card
      [ TYPE_ORDER.index(card.card_type) || TYPE_ORDER.size,
        card.cost.nil? ? 1 : 0, card.cost.to_i, card.card_number ]
    end
  end

  # Só o deck principal: o Leader fica fora dos 50 (DCK-07).
  def main_total
    entries.sum(&:quantity)
  end

  private

  def leader_must_be_a_leader
    return if leader.nil? || leader.card_type == "leader"

    errors.add(:leader, "precisa ser uma carta Leader")
  end
end
