json.data @items do |item|
  json.card_number item.card_variant.card.card_number
  json.card_name item.card_variant.card.name
  json.variant_code item.card_variant.variant_code
  json.target_quantity item.target_quantity
  json.owned_quantity item.owned_quantity
  json.fulfilled item.fulfilled?
end
