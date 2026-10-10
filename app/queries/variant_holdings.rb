# Posse e meta do usuário para um conjunto de variantes, uma consulta por hash
# (API-31, API-32). O usuário entra por argumento, nunca por `Current`: um
# controller público não resolve a sessão sozinho, e ler `Current.user` aqui
# devolveria vazio calado para quem está logado. `for_user(nil)` é `none`, então
# o anônimo não consulta nada.
class VariantHoldings
  def initialize(user, variants)
    @user = user
    @variant_ids = variants.map(&:id)
  end

  # `card_variant_id => quantity`. Item com quantidade zero entra no hash.
  def owned_quantities
    @owned_quantities ||= CollectionItem.for_user(@user)
                                        .where(card_variant_id: @variant_ids)
                                        .pluck(:card_variant_id, :quantity)
                                        .to_h
  end

  # `card_variant_id => target_quantity`.
  def wishlist_targets
    @wishlist_targets ||= WishlistItem.for_user(@user)
                                      .where(card_variant_id: @variant_ids)
                                      .pluck(:card_variant_id, :target_quantity)
                                      .to_h
  end

  def owned_quantity(variant)
    return unless @user

    owned_quantities.fetch(variant.id, 0)
  end

  def wishlist_target(variant)
    return unless @user

    wishlist_targets[variant.id]
  end
end
