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

  # Req. 7.3 — a pergunta "o usuário tem esta variante?" é sobre a quantidade,
  # não sobre a existência do registro.
  def owned?
    quantity.to_i.positive?
  end
end
