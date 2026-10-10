# Campos ausentes saem `null`, nunca 0 (API-28); o `Card` não tem default numérico.
json.card_number card.card_number
json.name card.name
json.card_type card.card_type
json.colors card.colors
json.cost card.cost
json.life card.life
json.power card.power
json.counter card.counter
json.block_icon card.block_icon
json.attributes card.attributes_list
json.traits card.traits
json.effect_text card.effect_text
json.trigger_text card.trigger_text
json.variants variants do |variant|
  json.partial! "api/cards/variant", variant: variant, holdings: holdings,
                                     absent_variant_ids: local_assigns.fetch(:absent_variant_ids, Set.new)
end
