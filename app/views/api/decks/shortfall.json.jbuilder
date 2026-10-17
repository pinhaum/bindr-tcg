json.data @rows do |row|
  json.card_number row.card.card_number
  json.name row.card.name
  json.missing row.missing
  json.decks row.deck_ids.filter_map { |id| @decks[id] && { id: id, name: @decks[id] } }
end
