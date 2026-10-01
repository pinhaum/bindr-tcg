require "test_helper"

# T7 (fonte-apitcg) — `GET /card_images/tcgplayer:123` responde como hoje
# responde um código antigo: 200, bytes da fonte, tipo pela extensão, cache
# público de um ano e disposição inline.
class CardImagesTcgplayerTest < ActionDispatch::IntegrationTest
  Responder = Struct.new(:status, :body) do
    def calls = (@calls ||= [])

    def get(url)
      calls << url
      [ status, body ]
    end
  end

  setup do
    @dir = Dir.mktmpdir("card-images-tcgplayer-integration")
    @http_default = CardImageCache.default_http
    @storage_default = CardImageCache.default_storage_dir
    @http = Responder.new(200, "JPG-BYTES")
    CardImageCache.default_http = @http
    CardImageCache.default_storage_dir = -> { Pathname(@dir) }

    set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(set_id: set.id, card_number: "OP01-001", name: "Luffy", card_type: "leader",
                         colors: [ "Red" ])
    @variant = CardVariant.create!(card: @card, set_id: set.id, variant_code: "tcgplayer:123", art_kind: "base",
                                   image_url: "https://tcgplayer-cdn.tcgplayer.com/product/123_in_1000x1000.jpg")
  end

  teardown do
    CardImageCache.default_http = @http_default
    CardImageCache.default_storage_dir = @storage_default
    FileUtils.remove_entry(@dir)
  end

  test "GET /card_images/tcgplayer:123 serve a imagem como um código antigo" do
    CardVariant.create!(card: @card, set_id: @variant.set_id, variant_code: "OP01-001_p1", art_kind: "parallel",
                        image_url: "https://tcgplayer-cdn.tcgplayer.com/product/124_in_1000x1000.jpg")
    get card_image_path("OP01-001_p1")
    antigo = [ status, response.media_type, response.headers["Cache-Control"],
               response.headers["Content-Disposition"].split(";").first ]

    get card_image_path("tcgplayer:123")

    assert_equal "/card_images/tcgplayer:123", card_image_path("tcgplayer:123")
    assert_response :success
    assert_equal "JPG-BYTES", response.body
    assert_equal [ 200, "image/jpeg" ], [ status, response.media_type ]
    assert_equal antigo, [ status, response.media_type, response.headers["Cache-Control"],
                           response.headers["Content-Disposition"].split(";").first ]
    assert_match(/public/, response.headers["Cache-Control"])
    assert_includes Dir.children(@dir), "tcgplayer__123.jpg"
  end

  test "a segunda requisição serve do disco, sem chamar a fonte" do
    2.times { get card_image_path("tcgplayer:123") }

    assert_response :success
    assert_equal 1, @http.calls.size
  end

  test "código apitcg com / não chega ao banco nem à fonte" do
    get "/card_images/apitcg:..%2Fx"

    assert_response :not_found
    assert_empty @http.calls
  end
end
