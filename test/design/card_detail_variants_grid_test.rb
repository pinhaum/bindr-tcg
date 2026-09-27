require "test_helper"
require_relative "support/stylesheet"

# T30: Variantes do detalhe em linhas (NAV-49).
#
# Cada variante vira uma linha com grid de 3 colunas:
# 1. Miniatura (80px de largura)
# 2. Metadados (código, raridade, set)
# 3. Controles (posse e wishlist)
#
# Os rótulos (dt) saem da vista pelo padrão de recorte.
class CardDetailVariantsGridTest < ActiveSupport::TestCase
  setup do
    @stylesheet = Stylesheet.read_stylesheet
  end

  def content_outside_media
    match = @stylesheet.match(/\A(.*?)@media/m)
    return @stylesheet unless match
    match[1]
  end

  test ".variant-list fora de media query é flex coluna" do
    outside = content_outside_media

    match = outside.match(/\.variant-list\s*\{([^}]*)\}/)
    assert match, ".variant-list não encontrada"

    body = match[1]
    assert body.include?("display: flex"),
           ".variant-list deve ter 'display: flex'"
    assert body.include?("flex-direction: column"),
           ".variant-list deve ter 'flex-direction: column'"
  end

  test ".variant é grid de 3 colunas com gap" do
    outside = content_outside_media

    match = outside.match(/\.variant\s*\{([^}]*)\}/)
    assert match, ".variant não encontrada"

    body = match[1]
    assert body.include?("display: grid"),
           ".variant deve ter 'display: grid'"
    assert body.include?("grid-template-columns: auto 1fr auto"),
           ".variant deve ter 'grid-template-columns: auto 1fr auto' (miniatura, meta, controles)"
    assert body.include?("gap: var(--space-2)"),
           ".variant deve ter 'gap: var(--space-2)'"
  end

  test ".variant__art tem largura fixa de 80px" do
    outside = content_outside_media

    match = outside.match(/\.variant__art\s*\{([^}]*)\}/)
    assert match, ".variant__art não encontrada"

    body = match[1]
    assert body.include?("width: 80px"),
           ".variant__art deve ter 'width: 80px'"
    assert body.include?("height: 112px"),
           ".variant__art deve ter 'height: 112px' (proporção 5/7)"
  end

  test ".variant__meta dt sai da vista pelo padrão de recorte" do
    outside = content_outside_media

    match = outside.match(/\.variant__meta dt\s*\{([^}]*)\}/)
    assert match, ".variant__meta dt não encontrada"

    body = match[1]
    assert body.include?("position: absolute"),
           ".variant__meta dt deve ter 'position: absolute'"
    assert body.include?("width: var(--space-1)"),
           ".variant__meta dt deve ter 'width: var(--space-1)'"
    assert body.include?("height: var(--space-1)"),
           ".variant__meta dt deve ter 'height: var(--space-1)'"
    assert body.include?("clip-path: inset(50%)"),
           ".variant__meta dt deve ter 'clip-path: inset(50%)'"
    assert body.include?("white-space: nowrap"),
           ".variant__meta dt deve ter 'white-space: nowrap'"
  end

  test ".variant__meta margin é 0" do
    outside = content_outside_media

    match = outside.match(/\.variant__meta\s*\{([^}]*)\}/)
    assert match, ".variant__meta não encontrada"

    body = match[1]
    assert body.include?("margin: 0"),
           ".variant__meta deve ter 'margin: 0' (não mais margin-top)"
  end
end
