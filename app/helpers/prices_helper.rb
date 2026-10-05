# O único lugar que sabe escrever um preço (Req. 15). O app não tem locale
# pt-BR e trocar o locale global mudaria outras saídas, então os separadores
# ficam fixos aqui: `US$ 1.234,56`.
module PricesHelper
  CURRENCY_UNITS = { "USD" => "US$" }.freeze
  # A data é a do import que leu o preço; o app roda em UTC, e um import às 23h
  # de Brasília mostraria o dia seguinte.
  PRICE_TIME_ZONE = "America/Sao_Paulo".freeze

  def format_price(amount, currency)
    number_to_currency(amount, unit: CURRENCY_UNITS.fetch(currency, currency),
                               separator: ",", delimiter: ".", format: "%u %n")
  end

  def price_label(variant)
    "TCGplayer · market · #{variant.price_observed_at.in_time_zone(PRICE_TIME_ZONE).strftime('%d/%m/%Y')}"
  end
end
