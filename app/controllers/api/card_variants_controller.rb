# Posse e desejo por variante (SCAR-42, SCAR-43, SCAR-45). Sem
# `allow_unauthenticated_access`: o default do base exige sessão, e o 401 sai
# antes do 404 da variante. O usuário é sempre `Current.user` (SCAR-48); nenhum
# `user_id` do request é lido.
class Api::CardVariantsController < Api::BaseController
  INVALID_TARGET_MESSAGE = "Informe um número inteiro maior ou igual a 1.".freeze
  MAX_TARGET = 2_147_483_647 # teto da coluna `integer`; acima disso o banco estoura em 500

  before_action :set_card_variant

  def increment
    @owned_quantity = CollectionItem.increment_for!(Current.user, @card_variant)
  end

  # `nil` = nenhuma linha afetada: a quantidade já era zero, ou nem havia registro.
  def decrement
    @owned_quantity = CollectionItem.decrement_for!(Current.user, @card_variant).to_i
  end

  def wishlist
    target = parse_target(params[:target_quantity])
    return render_error(:unprocessable_entity, "validation_failed", "Dados inválidos.",
                        target_quantity: [ INVALID_TARGET_MESSAGE ]) unless target

    @wishlist_target = save_wishlist_target(target)
  end

  # Idempotente (AD-027): sem desejo, nada a apagar e a resposta é a mesma.
  def unwish
    WishlistItem.for_user(Current.user).where(card_variant: @card_variant).delete_all
  end

  private
    # Variante de outra carta e carta inexistente caem igual no 404 do base.
    def set_card_variant
      @card_variant = CardVariant.joins(:card)
                                 .find_by!(cards: { card_number: params[:card_number] },
                                           variant_code: params[:variant_code])
    end

    # Só `Integer` JSON ou string de dígitos, ambos >= 1. `Float`, `true`, array,
    # hash e `nil` não passam; `"1.5"` e `" 2"` também não (o regex é ancorado).
    def parse_target(value)
      number = case value
      when Integer then value
      when /\A\d+\z/ then value.to_i
      end
      number if number&.between?(1, MAX_TARGET)
    end

    # Duas abas criando o mesmo desejo colidem no `UNIQUE`: a segunda tentativa já
    # encontra o registro e só atualiza.
    def save_wishlist_target(target)
      attempts = 0
      begin
        item = WishlistItem.find_or_initialize_by(user: Current.user, card_variant: @card_variant)
        item.target_quantity = target
        item.save!
        item.target_quantity
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        attempts += 1
        retry if attempts < 2
        raise
      end
    end
end
