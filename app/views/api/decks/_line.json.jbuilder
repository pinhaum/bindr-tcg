row = shortfall.fetch(card.id)
json.card_number card.card_number
json.name card.name
json.card_type card.card_type
json.cost card.cost
json.in_source absent_card_ids.exclude?(card.id)
json.required row.required
json.owned row.owned
json.missing row.missing
