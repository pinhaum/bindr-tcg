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

  # Req. 8.3 / COL-16 — "atendido" **derivado na consulta**, nunca persistido.
  #
  # Não existe coluna de flag e não deve passar a existir: uma flag ficaria
  # obsoleta no instante em que a posse mudasse, e sincronizá-la exigiria que
  # todo incremento e todo decremento de `collection_items` lembrassem de
  # escrever em outra tabela. Derivar torna o requisito verdadeiro por
  # construção (spec.md, *Assumptions*).
  #
  # **`LEFT JOIN`, e a escolha é a decisão central deste scope.** Desejar uma
  # variante que nunca se teve é o caso **normal** da wishlist — é para isso
  # que ela serve. Um `INNER JOIN` sumiria da lista exatamente com os itens que
  # mais importam, e o defeito seria silencioso: a página responderia 200 com
  # uma lista curta demais. Posse ausente vira `0` pelo `COALESCE`.
  #
  # O join é por **par completo** (`user_id` **e** `card_variant_id`): sem o
  # `user_id` na condição, a posse de outro usuário da mesma variante entraria
  # na comparação e um item alheio marcaria o desejo como atendido — violação
  # do Req. 6.5 por vazamento de leitura, não de escrita.
  #
  # `quantity >= target_quantity` compara com a coluna da própria linha, e não
  # com um número em Ruby, porque o alvo varia item a item. `>=` e não `=`:
  # "atingir **ou exceder**" é o texto do critério — quem tem 4 de um alvo 2
  # está atendido.
  #
  # Uma consulta só para a lista inteira, com `includes` do lado do chamador
  # para carta e variante: a alternativa seria perguntar a posse item a item
  # dentro do loop da view, que é N+1 pelo número de desejos.
  scope :with_fulfillment, -> {
    joins(<<~SQL.squish)
      LEFT JOIN collection_items
        ON collection_items.card_variant_id = wishlist_items.card_variant_id
       AND collection_items.user_id = wishlist_items.user_id
    SQL
      .select("wishlist_items.*",
              "COALESCE(collection_items.quantity, 0) AS owned_quantity")
      .includes(card_variant: :card)
      .order("wishlist_items.created_at ASC", "wishlist_items.id ASC")
  }

  # A quantidade possuída da variante desejada, vinda do `LEFT JOIN` de
  # `with_fulfillment`. Fora dele o atributo não existe, e a consulta extra
  # aqui é o preço de ler o item isoladamente — o caminho da view sempre passa
  # pelo scope.
  def owned_quantity
    if has_attribute?(:owned_quantity)
      self[:owned_quantity].to_i
    else
      CollectionItem.where(user_id: user_id, card_variant_id: card_variant_id).pick(:quantity).to_i
    end
  end

  # Req. 8.3 — atingir **ou exceder** o alvo.
  def fulfilled?
    owned_quantity >= target_quantity
  end
end
