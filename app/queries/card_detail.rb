# As regras do detalhe da carta (API-23, API-24, API-25), fora do controller
# para que HTML e JSON respondam o mesmo. O usuário entra por argumento, nunca
# por `Current` (ver `VariantHoldings`).
#
# Lista as variantes presentes na fonte (SRC-16) e, para o usuário, as ausentes
# que ele tem na coleção ou na wishlist (SRC-17). Carta inexistente, ou cujas
# variantes ficaram todas ocultas para este usuário, é `RecordNotFound`; carta
# sem variante nenhuma abre o detalhe.
class CardDetail
  Result = Struct.new(:card, :variants, :absent_variant_ids, :featured_variant, :holdings)

  def initialize(card_number:, user:, requested_variant: nil)
    @card_number = card_number
    @user = user
    @requested_variant = requested_variant.to_s
  end

  def call
    card = Card.includes(card_variants: :card_set).find_by!(card_number: @card_number)
    present_ids = card.card_variants.present.pluck(:id).to_set
    absent = card.card_variants.reject { |variant| present_ids.include?(variant.id) }
    absent_ids = held_variant_ids(absent)

    variants = card.card_variants
                   .select { |variant| present_ids.include?(variant.id) || absent_ids.include?(variant.id) }
                   .sort_by(&:variant_code)
    raise ActiveRecord::RecordNotFound if variants.empty? && card.card_variants.any?

    Result.new(card, variants, absent_ids, featured_variant(variants, absent_ids),
               VariantHoldings.new(@user, variants))
  end

  private
    # CNF-42 — o destaque vem do código pedido, mas só entre as variantes
    # listadas: código de outra carta, de ausente que o usuário não tem, ou
    # lixo cai no padrão. O padrão é a primeira presente; a ausente só sobe
    # quando é tudo o que o usuário tem (SRC-17).
    def featured_variant(variants, absent_ids)
      variants.find { |variant| variant.variant_code == @requested_variant } ||
        variants.find { |variant| !absent_ids.include?(variant.id) } ||
        variants.first
    end

    # Os ids, entre `variants`, em que o usuário tem item de coleção ou de
    # wishlist. Item de coleção com quantidade zero conta: continua sendo
    # registro do usuário sobre aquela impressão. `for_user(nil)` é `none`.
    def held_variant_ids(variants)
      ids = variants.map(&:id)

      (CollectionItem.for_user(@user).where(card_variant_id: ids).pluck(:card_variant_id) +
        WishlistItem.for_user(@user).where(card_variant_id: ids).pluck(:card_variant_id)).to_set
    end
end
