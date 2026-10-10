json.data @result.records do |card|
  json.partial! "api/cards/card", card: card, variants: card.card_variants.sort_by(&:variant_code),
                                  holdings: @holdings
end
json.meta do
  json.page @result.page
  json.per_page @result.per_page
  json.total_count @result.total_count
  json.total_pages @result.total_pages
  json.active_filters @result.active_filters
end
