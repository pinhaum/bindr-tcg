json.data do
  json.id @deck.id
  json.name @deck.name
  json.editing @editing
  json.status @legality.status
  json.reasons @legality.reasons
  json.warnings @legality.warnings
  json.main_total @deck.main_total
  json.missing_total @shortfall.values.sum(&:missing)
  if @deck.leader
    json.leader do
      json.partial! "api/decks/line", card: @deck.leader, shortfall: @shortfall, absent_card_ids: @absent_card_ids
    end
  else
    json.leader nil
  end
  json.entries @deck.ordered_entries do |entry|
    json.partial! "api/decks/line", card: entry.card, shortfall: @shortfall, absent_card_ids: @absent_card_ids
    json.quantity entry.quantity
  end
end
