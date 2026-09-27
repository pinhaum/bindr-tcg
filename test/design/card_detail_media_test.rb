require "test_helper"
require_relative "support/stylesheet"

# T29: Imagem maior do detalhe da carta (NAV-48, NAV-24, NAV-25).
#
# O elemento novo `.card-detail__media` fica numa coluna de 320px em viewport
# larga (≥64rem) à esquerda dos dados. Abaixo disso, ele é empilhado acima.
class CardDetailMediaTest < ActiveSupport::TestCase
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

  test "fora de media query, .card-detail__media tem aspect-ratio 5/7" do
    outside = content_outside_media

    all_matches = outside.scan(/\.card-detail__media\s*\{([^}]*)\}/)
    assert all_matches.any?, "regra .card-detail__media não encontrada fora de media query"

    body = all_matches.last[0]
    assert body.include?("aspect-ratio: 5 / 7"),
           ".card-detail__media deve ter 'aspect-ratio: 5 / 7' fora de media query"
  end

  test "fora de media query, .card-detail__media tem background var(--surface-sunken)" do
    outside = content_outside_media

    all_matches = outside.scan(/\.card-detail__media\s*\{([^}]*)\}/)
    assert all_matches.any?, "regra .card-detail__media não encontrada"

    body = all_matches.last[0]
    assert body.include?("background: var(--surface-sunken)"),
           ".card-detail__media deve ter 'background: var(--surface-sunken)'"
  end

  test "fora de media query, .card-detail__image e .card-detail__placeholder são absolutos" do
    outside = content_outside_media

    combined_match = outside.match(/\.card-detail__image,\s*\.card-detail__placeholder\s*\{([^}]*)\}/)
    assert combined_match, ".card-detail__image, .card-detail__placeholder combinados não encontrados"

    body = combined_match[1]
    assert body.include?("position: absolute"),
           "regra combinada deve ter 'position: absolute'"
    assert body.include?("inset: 0"),
           "regra combinada deve ter 'inset: 0'"
  end

  test "dentro de @media (min-width: 64rem), .card-detail tem grid com 320px na primeira coluna" do
    media = media_64rem_content

    assert media.include?(".card-detail {"),
           ".card-detail não aparece em @media (min-width: 64rem)"

    card_match = media.match(/\.card-detail\s*\{([^}]*)\}/)
    assert card_match, ".card-detail não tem corpo em media query"

    body = card_match[1]
    assert body.include?("display: grid"),
           ".card-detail deve ter 'display: grid' em @media (min-width: 64rem)"
    assert body.include?("grid-template-columns: 320px"),
           ".card-detail deve ter 'grid-template-columns: 320px' em @media (min-width: 64rem)"
  end

  test "dentro de @media (min-width: 64rem), .card-detail__media está na coluna 1" do
    media = media_64rem_content

    assert media.include?(".card-detail__media"),
           ".card-detail__media não aparece em @media (min-width: 64rem)"

    media_match = media.match(/\.card-detail__media\s*\{([^}]*)\}/)
    assert media_match, ".card-detail__media não tem corpo em media query"

    body = media_match[1]
    assert body.include?("grid-column: 1"),
           ".card-detail__media deve ter 'grid-column: 1' em @media (min-width: 64rem)"
  end

  test "dentro de @media (min-width: 64rem), .card-detail__data está na coluna 2" do
    media = media_64rem_content

    assert media.include?(".card-detail__data"),
           ".card-detail__data não aparece em @media (min-width: 64rem)"

    data_match = media.match(/\.card-detail__data\s*\{([^}]*)\}/)
    assert data_match, ".card-detail__data não tem corpo em media query"

    body = data_match[1]
    assert body.include?("grid-column: 2"),
           ".card-detail__data deve ter 'grid-column: 2' em @media (min-width: 64rem)"
  end
end
