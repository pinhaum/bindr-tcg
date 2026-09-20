# Quantas cópias de uma **variante** o usuário quer adquirir. Referencia
# variante e não carta, pela mesma razão de `CollectionItem`: a arte base e a
# alternativa são objetos de coleção distintos, e "tenho a base, quero a
# alternativa" é metade do sentido do produto (design.md §3.1).
#
# As garantias de integridade não são daqui: `UNIQUE (user_id,
# card_variant_id)`, `CHECK (target_quantity >= 1)` e as duas FKs `on_delete:
# :restrict` nasceram na migração `20260919120500` e estão provadas contra o
# banco em `test/models/wishlist_item_test.rb`. As validações abaixo existem
# para que o formulário possa **dizer** o que está errado em vez de estourar
# 500 — a garantia real continua sendo do schema, que nenhuma corrida
# atravessa e nenhum `UPDATE` direto contorna.
class WishlistItem < ApplicationRecord
  belongs_to :user
  belongs_to :card_variant

  # Req. 8.1 — alvo inteiro e maior que zero. O piso é `1` e não `0`, ao
  # contrário de `CollectionItem#quantity`: posse zero é estado legítimo,
  # desejo zero não é (a forma de não querer mais é remover o item, Req. 8.4).
  # A justificativa completa da assimetria está na migração.
  validates :target_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :card_variant_id, uniqueness: { scope: :user_id }

  # Req. 6.5 / design.md §7 — toda consulta a wishlist parte do usuário da
  # sessão. O argumento é o **objeto** `User`, nunca um id, exatamente como em
  # `CollectionItem.for_user`: aceitar um id deixaria
  # `WishlistItem.for_user(params[:user_id])` compilar, e a violação de
  # autorização passaria despercebida na revisão.
  #
  # `nil` devolve relação vazia em vez de levantar erro, pelo mesmo motivo do
  # catálogo público: quem não tem sessão simplesmente não tem wishlist.
  scope :for_user, ->(user) {
    case user
    when nil then none
    when User then where(user: user)
    else raise ArgumentError, "for_user espera um User ou nil, recebeu #{user.class}"
    end
  }
end
