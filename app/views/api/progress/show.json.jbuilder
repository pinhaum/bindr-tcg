json.data do
  json.order @order
  json.summary do
    json.total_copies @stats[:total_copies]
    json.distinct_variants @stats[:distinct_variants]
    json.estimated_value do
      json.amount format("%.2f", @stats[:estimated_value])
      json.currency "USD"
    end
    json.unpriced_copies @stats[:unpriced_copies]
  end
  json.sets @rows do |row|
    json.code row.set_code
    json.name row.set_name
    json.owned_numbers row.displayed_owned_numbers
    json.base_size row.completion_percent_known? ? row.base_size : nil
    json.completion_percent row.completion_percent&.round
    json.parallel_owned row.parallel_owned_variants
    json.parallel_total row.parallel_variants
    json.value do
      json.amount format("%.2f", @stats[:value_by_set_id].fetch(row.set_id, 0))
      json.currency "USD"
    end
  end
end
