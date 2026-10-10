json.data do
  json.partial! "api/cards/card", card: @detail.card, variants: @detail.variants,
                                  holdings: @detail.holdings, absent_variant_ids: @detail.absent_variant_ids
  json.featured_variant_code @detail.featured_variant&.variant_code
end
