require "test_helper"
require_relative "../design/support/stylesheet"
require_relative "../design/catalog_grid_canvas_test"

# T7 (conformidade) — CNF-17, CNF-18, CNF-39: chips de tipo, raridade e cor no
# cabeçalho do detalhe, counter como chip (visível só em ≥1024px), a linha
# "{nome do set} · {código}" da primeira variante e o trigger dentro da seção
# "Efeito".
class CardDetailHeaderTest < ActionDispatch::IntegrationTest
  setup do
    @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
  end

  def create_card(**attrs) = Card.create!(set_id: @op01.id, **attrs)

  def add_variant(card, code, rarity:, card_set: @op01)
    CardVariant.create!(card: card, set_id: card_set.id, variant_code: code,
                        rarity: rarity, art_kind: "base")
  end

  # --- CNF-17: chips de tipo, raridade e cor ---

  test "cabeçalho tem chip de tipo, chip da raridade da primeira variante e chip de cor" do
    zoro = create_card(card_number: "OP01-001", name: "Roronoa Zoro",
                       card_type: "leader", colors: [ "Red" ], power: 5000, life: 5)
    add_variant(zoro, "OP01-001", rarity: "L")

    get card_path("OP01-001")

    assert_response :success
    assert_select ".card-detail__chips" do
      assert_select ".card-detail__chip", text: "Leader"
      assert_select ".card-detail__chip", text: "L"
      assert_select ".card-detail__chip", text: "Red"
    end
  end

  # A raridade do chip é da **primeira** variante listada (ordenada por
  # variant_code em CatalogController#show), não de qualquer variante.
  test "o chip de raridade é da primeira variante, não das demais" do
    zoro = create_card(card_number: "OP01-001", name: "Roronoa Zoro",
                       card_type: "leader", colors: [ "Red" ], power: 5000, life: 5)
    add_variant(zoro, "OP01-001", rarity: "L")
    add_variant(zoro, "OP01-001_p1", rarity: "SEC")

    get card_path("OP01-001")

    assert_select ".card-detail__chip", text: "L"
    assert_select ".card-detail__chip", { text: "SEC", count: 0 }
  end

  # --- CNF-39: carta com mais de uma cor tem um chip por cor ---

  test "carta Red/Green tem dois chips de cor" do
    duas_cores = create_card(card_number: "OP01-006", name: "Multicor",
                             card_type: "character", colors: [ "Red", "Green" ],
                             cost: 3, power: 4000)
    add_variant(duas_cores, "OP01-006", rarity: "R")

    get card_path("OP01-006")

    assert_select ".card-detail__chip", text: "Red"
    assert_select ".card-detail__chip", text: "Green"
  end

  # --- CNF-17: counter NULL não gera chip; counter presente gera ---

  test "counter NULL não gera chip de counter" do
    sem_counter = create_card(card_number: "OP01-010", name: "Sem Counter",
                              card_type: "character", colors: [ "Blue" ],
                              cost: 3, power: 4000, counter: nil)
    add_variant(sem_counter, "OP01-010", rarity: "C")

    get card_path("OP01-010")

    assert_select ".card-detail__chip--counter", 0
  end

  test "counter presente gera chip de counter" do
    com_counter = create_card(card_number: "OP01-011", name: "Com Counter",
                              card_type: "character", colors: [ "Blue" ],
                              cost: 3, power: 4000, counter: 2000)
    add_variant(com_counter, "OP01-011", rarity: "C")

    get card_path("OP01-011")

    assert_select ".card-detail__chip--counter", text: /2000/
  end

  # --- linha "{nome do set} · {código}" da primeira variante ---

  test "linha do set mostra nome e código da primeira variante, abaixo do título" do
    st01 = CardSet.create!(code: "ST01", name: "Straw Hat Crew", kind: "starter")
    zoro = create_card(card_number: "OP01-001", name: "Roronoa Zoro",
                       card_type: "leader", colors: [ "Red" ], power: 5000, life: 5)
    add_variant(zoro, "OP01-001", rarity: "L", card_set: @op01)
    add_variant(zoro, "ST01-001", rarity: "C", card_set: st01)

    get card_path("OP01-001")

    assert_select ".card-detail__set", text: "Romance Dawn · OP01"
  end

  # --- CNF-18: trigger dentro da seção "Efeito", sem seção própria ---

  test "trigger aparece dentro da seção Efeito, depois do efeito, com rótulo Trigger" do
    com_trigger = create_card(card_number: "OP01-021", name: "Com Trigger",
                              card_type: "event", colors: [ "Red" ], cost: 1,
                              effect_text: "Main effect.",
                              trigger_text: "Play this card.")
    add_variant(com_trigger, "OP01-021", rarity: "C")

    get card_path("OP01-021")

    assert_select ".card-detail__effect" do
      assert_select ".card-detail__trigger-label", text: "Trigger"
    end
    assert_select ".card-detail__trigger", 0,
                  "não pode existir mais seção própria de trigger (CNF-18)"
  end

  test "carta sem trigger não exibe o rótulo Trigger" do
    sem_trigger = create_card(card_number: "OP01-022", name: "Sem Trigger",
                              card_type: "character", colors: [ "Red" ],
                              cost: 1, power: 1000, effect_text: "Só efeito.",
                              trigger_text: nil)
    add_variant(sem_trigger, "OP01-022", rarity: "C")

    get card_path("OP01-022")

    assert_select ".card-detail__trigger-label", 0
  end
end

# Unit (folha) — CNF-17: o chip de counter só é visível em ≥1024px. A regra
# fora da media query esconde (`display: none`); a mesma classe, dentro de
# `@media (min-width: 64rem)`, reabre (`CatalogGridCanvasTest.wide_block` +
# `Stylesheet.resolved`, mesmo padrão de `card_detail_media_test.rb`).
class CardDetailHeaderStylesheetTest < ActiveSupport::TestCase
  setup do
    css = Stylesheet.content_without_comments
    @wide = CatalogGridCanvasTest.wide_block(css)
    @narrow_rules = Stylesheet.rules(css.sub(@wide, ""))
    @wide_rules = Stylesheet.rules(@wide)
  end

  test "fora de media query, o chip de counter está escondido" do
    chip = Stylesheet.resolved("card-detail__chip--counter", @narrow_rules)

    assert_equal "none", chip["display"]
  end

  test "dentro de @media (min-width: 64rem), o chip de counter fica visível" do
    chip = Stylesheet.resolved("card-detail__chip--counter", @wide_rules)

    assert_equal "inline-block", chip["display"]
  end

  test "dentro de @media (min-width: 64rem), o efeito fica limitado a 62ch" do
    effect = Stylesheet.resolved("card-detail__effect", @wide_rules)

    assert_equal "62ch", effect["max-width"]
  end
end
