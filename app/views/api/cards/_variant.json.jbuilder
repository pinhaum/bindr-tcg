json.variant_code variant.variant_code
json.rarity variant.rarity
json.art_kind variant.art_kind
json.set do
  json.code variant.card_set.code
  json.name variant.card_set.name
end
json.illustrator variant.illustrator
json.image_url variant.image_url.present? ? card_image_path(variant.variant_code) : nil
json.in_source !absent_variant_ids.include?(variant.id)
json.owned_quantity holdings.owned_quantity(variant)
json.wishlist_target holdings.wishlist_target(variant)
if variant.priced?
  json.price { json.partial! "api/cards/price", variant: variant }
else
  json.price nil
end
