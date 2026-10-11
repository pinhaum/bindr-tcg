# Posse por variante (SCAR-42, SCAR-43). Sem `allow_unauthenticated_access`: o
# default do base exige sessão, e o 401 sai antes do 404 da variante. O usuário
# é sempre `Current.user` (SCAR-48); nenhum `user_id` do request é lido.
class Api::CardVariantsController < Api::BaseController
  before_action :set_card_variant

  def increment
    @owned_quantity = CollectionItem.increment_for!(Current.user, @card_variant)
  end

  # `nil` = nenhuma linha afetada: a quantidade já era zero, ou nem havia registro.
  def decrement
    @owned_quantity = CollectionItem.decrement_for!(Current.user, @card_variant).to_i
  end

  private
    # Variante de outra carta e carta inexistente caem igual no 404 do base.
    def set_card_variant
      @card_variant = CardVariant.joins(:card)
                                 .find_by!(cards: { card_number: params[:card_number] },
                                           variant_code: params[:variant_code])
    end
end
