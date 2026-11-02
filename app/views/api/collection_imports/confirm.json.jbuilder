json.data do
  json.filename @collection_import&.filename
  json.created @result.criadas
  json.updated @result.atualizadas + @result.zeradas
  json.removed @result.zeradas
  json.unchanged @result.inalteradas
  json.rejected @result.rejeitadas_detalhadas do |linha|
    json.line linha.indice + 2
    json.card_number linha.card_number
    json.variant_code linha.variant_code
    json.card_name linha.card_name
    json.message linha.mensagem
  end
  json.failures @result.falhas do |falha|
    json.line falha[:indice] + 2
    json.card_number falha[:card_number]
    json.variant_code falha[:variant_code]
  end
end
