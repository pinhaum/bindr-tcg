require "test_helper"

# T7 (fonte-apitcg) — `CardImageCache` com o host e os códigos da apitcg
# (Req. 11.7 emendado, AD-012, AD-019).
#
# A arte da apitcg vem de `tcgplayer-cdn.tcgplayer.com`, e o `variant_code`
# passa a ser `tcgplayer:<id>` ou `apitcg:<id>`. O `:` não vai para o nome do
# arquivo (vira `-`), e a restrição de host contra SSRF continua. As variantes
# da optcgjson ficam no banco com o cache em disco, que continua sendo lido.
class CardImageCacheTcgplayerTest < ActiveSupport::TestCase
  TCGPLAYER_URL = "https://tcgplayer-cdn.tcgplayer.com/product/453505_in_1000x1000.jpg".freeze
  OLD_HOST_URL = "https://asia-en.onepiece-cardgame.com/images/cardlist/card/OP01-001_p1.png".freeze

  Responder = Struct.new(:status, :body) do
    def calls = (@calls ||= [])

    def get(url)
      calls << url
      [ status, body ]
    end
  end

  setup do
    @storage = Pathname(Dir.mktmpdir("card-images-tcgplayer")).join("card_images")
    @http = Responder.new(200, "JPG-BYTES")
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(set_id: @set.id, card_number: "OP01-001", name: "Luffy", card_type: "leader",
                         colors: [ "Red" ])
  end

  teardown { FileUtils.remove_entry(@storage.dirname) }

  def cache = CardImageCache.new(storage_dir: @storage, http: @http)

  def variant(code, url)
    CardVariant.new(card: @card, set_id: @set.id, variant_code: code, art_kind: "base", image_url: url)
  end

  # --- Host ---

  test "URL https em tcgplayer-cdn.tcgplayer.com é aceita e baixada" do
    result = cache.fetch(variant("tcgplayer:453505", TCGPLAYER_URL))

    assert_equal [ TCGPLAYER_URL ], @http.calls
    assert_equal "JPG-BYTES", result.path.binread
  end

  test "o host antigo é recusado sem chamar o cliente" do
    assert_raises(CardImageCache::Unavailable) { cache.fetch(variant("OP01-001_p1", OLD_HOST_URL)) }

    assert_empty @http.calls
  end

  test "qualquer outro host é recusado sem chamar o cliente" do
    [ "https://evil.test/x.jpg", "https://tcgplayer-cdn.tcgplayer.com.evil.test/x.jpg",
      "https://cdn.tcgplayer.com/x.jpg" ].each do |url|
      assert_raises(CardImageCache::Unavailable, url) { cache.fetch(variant("tcgplayer:1", url)) }
    end

    assert_empty @http.calls
  end

  # --- Formato do código ---

  test "tcgplayer:123 e apitcg:abc123 são aceitos" do
    assert_match CardImageCache::VARIANT_CODE_FORMAT, "tcgplayer:123"
    assert_match CardImageCache::VARIANT_CODE_FORMAT, "apitcg:abc123"
  end

  test "tcgplayer:../x, tcgplayer: e códigos com / são recusados" do
    [ "tcgplayer:../x", "tcgplayer:", "tcgplayer:12/3", "apitcg:a/b", "tcgplayer:/etc" ].each do |code|
      assert_no_match CardImageCache::VARIANT_CODE_FORMAT, code
      assert_raises(CardImageCache::NotFound, code) { cache.fetch(variant(code, TCGPLAYER_URL)) }
    end

    assert_empty @http.calls
  end

  # --- Nome do arquivo ---

  test "o cache de tcgplayer:123 é tcgplayer-123.<ext> dentro do diretório de imagens" do
    result = cache.fetch(variant("tcgplayer:123", TCGPLAYER_URL))

    assert_equal @storage.join("tcgplayer-123.jpg"), result.path
    assert result.path.exist?
    assert_equal [ "tcgplayer-123.jpg" ], Dir.children(@storage)
  end

  test "o diretório padrão continua sendo storage/card_images" do
    assert_equal Rails.root.join("storage", "card_images"), CardImageCache.default_storage_dir.call
  end

  # --- Códigos antigos ---

  test "o código antigo continua aceito" do
    assert_match CardImageCache::VARIANT_CODE_FORMAT, "OP01-001_p1"
  end

  test "o cache em disco de um código antigo continua sendo lido, sem rede" do
    @storage.mkpath
    @storage.join("OP01-001_p1.png").binwrite("PNG-ANTIGO")

    result = cache.fetch(variant("OP01-001_p1", OLD_HOST_URL))

    assert_equal "PNG-ANTIGO", result.path.binread
    assert_equal "image/png", result.content_type
    assert_empty @http.calls
  end
end
