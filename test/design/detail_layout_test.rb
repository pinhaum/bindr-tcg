require "test_helper"
require_relative "support/stylesheet"

# T10: Detalhe em duas colunas a partir de 1024px (NAV-24, NAV-25, NAV-28)
class DetailLayoutTest < ActiveSupport::TestCase
  setup do
    @stylesheet = Stylesheet.read_stylesheet
  end

  # Extrai o conteúdo dentro de @media (min-width: 64rem) até o fim da folha
  def media_64rem_content
    match = @stylesheet.match(/@media\s*\([^)]*min-width:\s*64rem[^)]*\)\s*\{(.*)\}\s*\z/m)
    assert match, "@media (min-width: 64rem) não encontrada ou não é o último bloco"
    match[1]
  end

  # Extrai tudo que está FORA de @media queries (antes da primeira)
  def content_outside_media
    match = @stylesheet.match(/\A(.*?)@media/m)
    return @stylesheet unless match
    match[1]
  end

  test "fora de media query, .card-detail não tem display: grid" do
    outside = content_outside_media

    # Procura a última ocorrência de .card-detail fora de media query
    all_matches = outside.scan(/\.card-detail\s*\{([^}]*)\}/)
    assert all_matches.any?, "regra .card-detail não encontrada fora de media query"

    body = all_matches.last[0]
    refute body.include?("display: grid"),
           ".card-detail não deve ter 'display: grid' fora de media query"
  end

  test "dentro de @media (min-width: 64rem), .card-detail usa display: grid" do
    media = media_64rem_content

    assert media.include?(".card-detail"),
           ".card-detail não aparece em @media (min-width: 64rem)"

    card_match = media.match(/\.card-detail\s*\{([^}]*)\}/)
    assert card_match, ".card-detail não tem corpo em media query"

    body = card_match[1]
    assert body.include?("display: grid"),
           ".card-detail deve ter 'display: grid' em @media (min-width: 64rem)"
    assert body.include?("grid-template-columns:"),
           ".card-detail deve ter 'grid-template-columns:' em @media (min-width: 64rem)"
  end

  test "dentro de @media (min-width: 64rem), .card-detail__data está na coluna 2 (NAV-48)" do
    media = media_64rem_content

    assert media.include?(".card-detail__data"),
           ".card-detail__data não aparece em @media (min-width: 64rem)"

    data_match = media.match(/\.card-detail__data\s*\{([^}]*)\}/)
    assert data_match, ".card-detail__data não tem corpo em media query"

    body = data_match[1]
    assert body.include?("grid-column: 2"),
           ".card-detail__data deve ter 'grid-column: 2' em @media (min-width: 64rem) (NAV-48: imagem na coluna 1)"
  end

  test "dentro de @media (min-width: 64rem), .card-detail__variants está na coluna 2" do
    media = media_64rem_content

    assert media.include?(".card-detail__variants"),
           ".card-detail__variants não aparece em @media (min-width: 64rem)"

    variants_match = media.match(/\.card-detail__variants\s*\{([^}]*)\}/)
    assert variants_match, ".card-detail__variants não tem corpo em media query"

    body = variants_match[1]
    assert body.include?("grid-column: 2"),
           ".card-detail__variants deve ter 'grid-column: 2' em @media (min-width: 64rem)"
  end

  test "dentro de @media (min-width: 64rem), demais filhos (.card-detail > *) ocupam 1 / -1" do
    media = media_64rem_content

    assert media.include?(".card-detail > *"),
           ".card-detail > * não aparece em @media (min-width: 64rem)"

    rule_match = media.match(/\.card-detail\s*>\s*\*\s*\{([^}]*)\}/)
    assert rule_match, ".card-detail > * não tem corpo em media query"

    body = rule_match[1]
    assert body.include?("grid-column: 1 / -1"),
           ".card-detail > * deve ter 'grid-column: 1 / -1' em @media (min-width: 64rem)"
  end
end
