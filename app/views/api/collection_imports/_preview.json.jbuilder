json.token collection_import.token
json.filename collection_import.filename
json.rows collection_import.linhas_resolvidas.each_with_index.to_a do |(linha, indice)|
  json.line indice + 2
  json.classification Api::CollectionImportsController::CLASSIFICATIONS.fetch(linha.classificacao)
  json.card_number linha.card_number
  json.variant_code linha.variant_code
  json.card_name linha.card_name
  json.quantity_before linha.quantidade_antes
  json.quantity_after linha.rejeitada? ? nil : linha.quantidade_depois
  json.message linha.rejeitada? ? linha.mensagem : nil
end
