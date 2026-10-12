require "test_helper"

class LegacyPathTest < ActiveSupport::TestCase
  LegacyPath::FIXED.each do |origin, expected|
    test "#{origin} vai para #{expected}" do
      assert_equal expected, LegacyPath.destination(origin, "")
    end
  end

  test "carta, token e deck levam o segmento" do
    assert_equal "/cartas/OP01-001", LegacyPath.destination("/cards/OP01-001", "")
    assert_equal "/cartas/P.029", LegacyPath.destination("/cards/P.029", "")
    assert_equal "/pasta/importar/abc123", LegacyPath.destination("/collection/import/abc123", "")
    assert_equal "/baralhos/7", LegacyPath.destination("/decks/7", "")
    assert_equal "/baralhos/7/renomear", LegacyPath.destination("/decks/7/edit", "")
    assert_equal "/baralhos/7/excluir", LegacyPath.destination("/decks/7/delete", "")
  end

  test "o resto de /app vira o caminho, inclusive com barras" do
    assert_equal "/pasta/desejos", LegacyPath.destination("/app/pasta/desejos", "")
    assert_equal "/cartas/OP01-001", LegacyPath.destination("/app/cartas/OP01-001", "")
    assert_equal "/200.html", LegacyPath.destination("/app/200.html", "")
  end

  test "a query volta crua e sem query não há interrogação" do
    assert_equal "/cartas/OP01-001?variant=tcgplayer%3A123",
      LegacyPath.destination("/cards/OP01-001", "variant=tcgplayer%3A123")
    assert_equal "/?colors[]=Red&colors[]=Green&sort=name",
      LegacyPath.destination("/catalog", "colors[]=Red&colors[]=Green&sort=name")
    assert_equal "/", LegacyPath.destination("/catalog", "")
  end

  test "a codificação percentual do segmento passa igual" do
    assert_equal "/cartas/P%2E029", LegacyPath.destination("/cards/P%2E029", "")
    assert_equal "/baralhos/a%3Ab", LegacyPath.destination("/decks/a%3Ab", "")
  end

  test "destino que começaria por // é recusado" do
    assert_nil LegacyPath.destination("/app//evil.com", "")
    assert_nil LegacyPath.destination("/app//evil.com", "x=1")
  end

  test "destino que começaria por barra invertida é recusado" do
    assert_nil LegacyPath.destination("/app/\\evil.com", "")
    assert_nil LegacyPath.destination("/app/\\/evil.com", "x=1")
  end

  test "caractere de controle cru no caminho ou na query é recusado" do
    assert_nil LegacyPath.destination("/app/\t/evil", "")
    assert_nil LegacyPath.destination("/app/\r\n/evil", "")
    assert_nil LegacyPath.destination("/app/a\u0000b", "")
    assert_nil LegacyPath.destination("/cards/OP01-001", "x=\r\nLocation: /evil")
    assert_nil LegacyPath.destination("/catalog", "a=\tb")
  end

  test "/app/ com barra final e query não tem regra" do
    assert_nil LegacyPath.destination("/app/", "")
    assert_nil LegacyPath.destination("/app/", "x=1")
  end

  test "barras codificadas ficam como caminho local" do
    assert_equal "/%2F%2Fevil.com", LegacyPath.destination("/app/%2F%2Fevil.com", "")
  end

  test "caminho sem regra devolve nil" do
    assert_nil LegacyPath.destination("/decks/1/x", "")
    assert_nil LegacyPath.destination("/cards/a/b", "")
    assert_nil LegacyPath.destination("/catalog/", "")
    assert_nil LegacyPath.destination("/outra", "")
    assert_nil LegacyPath.destination("/application", "")
  end
end
