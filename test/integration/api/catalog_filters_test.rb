require "test_helper"

class Api::CatalogFiltersTest < ActionDispatch::IntegrationTest
  setup do
    set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    card = Card.create!(card_set: set, card_number: "OP01-001", name: "Nami", card_type: "character",
                        colors: [ "Blue" ], cost: 1, power: 1000)
    CardVariant.create!(card: card, card_set: set, variant_code: "tcgplayer:11", rarity: "R", art_kind: "base",
                        image_url: "https://cdn.example.com/tcgplayer:11.png")
    mark_catalog_present!
  end

  test "API-22: data é igual a CatalogQuery.filter_options, com sets em code e name" do
    get "/api/catalog/filters"

    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal CatalogQuery.filter_options.deep_stringify_keys, response.parsed_body["data"]
    assert_equal %w[card_types colors rarities sets], response.parsed_body["data"].keys.sort
    assert_equal [ { "code" => "OP01", "name" => "Romance Dawn" } ], response.parsed_body.dig("data", "sets")
  end

  test "API-16: falha em filter_options responde 500 internal_error genérico, sem vazar a exceção" do
    original = CatalogQuery.method(:filter_options)
    CatalogQuery.define_singleton_method(:filter_options) { raise RuntimeError, "segredo-interno" }
    begin
      get "/api/catalog/filters"
    ensure
      CatalogQuery.define_singleton_method(:filter_options, original)
    end

    assert_response :internal_server_error
    assert_equal "internal_error", response.parsed_body.dig("error", "code")
    assert_equal "Erro inesperado. Tente novamente.", response.parsed_body.dig("error", "message")
    assert_no_match(/RuntimeError|segredo-interno|\.rb/, response.body)
  end
end
