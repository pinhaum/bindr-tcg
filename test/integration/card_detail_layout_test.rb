require "test_helper"

# T10: HTML structure for detail layout — card-detail__data container (NAV-24, NAV-25)
class CardDetailLayoutTest < ActionDispatch::IntegrationTest
  setup do
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(set_id: @set.id, card_number: "OP01-001", name: "Roronoa Zoro",
                         card_type: "character", colors: [ "Red" ], power: 5000,
                         effect_text: "Quando entra em jogo, este personagem ganha +1/+1.",
                         trigger_text: "Ao atacar, você pode sacrificar outro personagem.")
    CardVariant.create!(card: @card, set_id: @set.id, variant_code: "OP01-001",
                        rarity: "R", art_kind: "base")
    CardVariant.create!(card: @card, set_id: @set.id, variant_code: "OP01-001_p1",
                        rarity: "SEC", art_kind: "alternate_art")
  end

  # T6 (conformidade), CNF-14: name e number saíram de `.card-detail__data`
  # para `.card-detail__head > .card-detail__heading`, ao lado da miniatura —
  # é o próprio requisito novo que move o título, não uma quebra acidental.
  test "detail page renders card-detail__data containing name and fields, with variants as sibling" do
    get card_path(@card.card_number)
    assert_response :success

    assert_select "main.card-detail" do
      assert_select ".card-detail__head" do
        assert_select "h1.card-detail__name", text: @card.name
        assert_select ".card-detail__number", text: @card.card_number
      end

      # Container de dados
      assert_select ".card-detail__data" do
        assert_select "dl.card-detail__fields"
        # T7 (conformidade), CNF-18: trigger não tem mais seção própria —
        # mora dentro do efeito, depois do texto principal.
        assert_select ".card-detail__effect" do
          assert_select ".card-detail__trigger-label", text: "Trigger"
        end
      end

      # Variants section, sibling of .card-detail__data
      assert_select ".card-detail__variants" do
        assert_select "li.variant", count: 2
      end
    end
  end

  test "card-detail__data is direct child of main, before variants" do
    get card_path(@card.card_number)

    assert_select "main.card-detail > .card-detail__data"
    assert_select "main.card-detail > .card-detail__variants"

    html = response.body
    data_pos = html.index('class="card-detail__data"')
    variants_pos = html.index('class="card-detail__variants"')

    assert_operator data_pos, :<, variants_pos,
                    ".card-detail__data must appear before .card-detail__variants"
  end

  # T20 (conformidade), CNF-23 — "Voltar ao catálogo" existe uma vez em
  # `.site-header__aside`, sem "←". O link deve estar dentro do aside da
  # navegação, não no `<main>`, para ser focado antes do conteúdo
  # (Android/iOS: eixo de navegação à esquerda, detalhe à direita).
  test "back to catalog link exists once in site-header__aside without arrow" do
    get card_path(@card.card_number)
    assert_response :success

    assert_select ".site-header__aside a.site-header__back", count: 1
    assert_select ".site-header__aside a.site-header__back", text: "Voltar ao catálogo"
    assert_select ".site-header__aside a.site-header__back", text: /←/, count: 0
    # CNF-23: link deve estar **dentro** de .site-header__aside, não no <main>
    assert_select "main.card-detail a.site-header__back", 0,
                  "Voltar ao catálogo deve estar no aside de navegação, não dentro de <main>"
  end
end
