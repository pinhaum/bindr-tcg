json.id deck.id
json.name deck.name
json.leader deck.leader && { card_number: deck.leader.card_number, name: deck.leader.name }
json.main_total deck.main_total
json.status deck.legality.status
