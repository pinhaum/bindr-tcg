require "test_helper"
require_relative "support/stylesheet"
require_relative "class_coverage_test"

# T20 da `decks` — telas de deck a 360px (DCK-07, DCK-34; Req. 2.5) e alvos de
# toque de 44px. Como os demais testes de `test/design/`, a prova é textual
# sobre `catalog.css` (`.context/design.md` §11.7); as capturas da task são
# evidência, não gate.
class DeckLayoutTest < ActiveSupport::TestCase
  DECK_VIEWS = %w[app/views/decks app/views/deck_imports].freeze
  DECK_BLOCKS = %w[deck deck-controls deck-shortfall].freeze

  # Os botões do Done when: `−`, `+` e "Usar como Leader" (`deck-controls__button`),
  # "Editar este deck" e "Excluir deck" (`deck__button`) e o submit do nome e da
  # importação (`deck__submit`). O alvo é o do `.ownership__button` no detalhe.
  TOUCH_CLASSES = %w[deck-controls__button deck__button deck__submit].freeze
  OWNERSHIP_TARGET = ".card-detail .ownership__button".freeze

  # Texto que vem do usuário ou da fonte (nome de deck até 60 caracteres sem
  # espaço, nome de carta) e precisa quebrar em vez de empurrar a página.
  WRAPPING_CLASSES = %w[
    deck__title deck__item-link deck__entry-link deck__action deck__fact-value
    deck-controls__target deck-shortfall__name deck-shortfall__decks
  ].freeze

  # Propriedades que fixam largura; o maior valor aceito é o alvo de toque.
  WIDTH_PROPERTY = /\A(?:width|min-width|flex-basis)\z/

  setup do
    @rules = Stylesheet.rules
    @tokens = Stylesheet.read_root_tokens
  end

  def deck_rules(rules = @rules)
    rules.select { |selector, _| (Stylesheet.blocks_of(selector) & DECK_BLOCKS).any? }
  end

  # Declarações de uma regra de deck que impedem a quebra de linha a 360px.
  def blocking_declarations(rules)
    deck_rules(rules).flat_map do |selector, body|
      Stylesheet.declarations(body).filter_map do |property, value|
        problem =
          case property
          when "white-space" then "nowrap" if value.include?("nowrap")
          when "flex-wrap" then "nowrap" if value == "nowrap"
          when "overflow-x" then "overflow-x"
          when "grid-template-columns" then "trilha fixa" if value.match?(/\d+(?:px|rem)/)
          when WIDTH_PROPERTY then "largura fixa" if fixed_width_over_target?(value)
          end
        "#{selector} { #{property}: #{value} } — #{problem}" if problem
      end
    end
  end

  def fixed_width_over_target?(value)
    return false if %w[0 auto 100%].include?(value)

    Stylesheet.to_pixels(value, @tokens) > Stylesheet.to_pixels("var(--touch-target)", @tokens)
  rescue ArgumentError
    true
  end

  def pixels(klass, property)
    value = Stylesheet.resolved(klass, @rules)[property]
    assert value, ".#{klass} não declara #{property}"
    Stylesheet.to_pixels(value, @tokens)
  end

  test "toda classe das telas de deck tem regra na folha" do
    classes = DECK_VIEWS.flat_map { |dir| Dir[Rails.root.join(dir, "*.erb")] }
                        .flat_map { |path| ClassCoverageTest.classes_in(File.read(path)) }.uniq
    deck_classes = classes.select { |name| (Stylesheet.blocks_of(".#{name}") & DECK_BLOCKS).any? }

    assert_operator deck_classes.size, :>=, 30, "as views de deck pararam de usar as classes da T20"
    assert_includes classes, "deck-shortfall"
    assert_includes classes, "deck-controls__button"
    assert_empty deck_classes - ClassCoverageTest.styled_classes(@rules)
  end

  test "botões de deck têm 44px de altura e de largura, como o da posse no detalhe" do
    ownership = Stylesheet.declarations(@rules.find { |selector, _| selector == OWNERSHIP_TARGET }.last).to_h
    target = Stylesheet.to_pixels(ownership.fetch("min-height"), @tokens)
    assert_equal 44.0, target

    TOUCH_CLASSES.each do |klass|
      assert_equal target, pixels(klass, "min-height"), ".#{klass} min-height"
      assert_equal target, pixels(klass, "min-width"), ".#{klass} min-width"
    end
  end

  test "os links de ação da página do deck ficam a pelo menos 24px uns dos outros" do
    assert_operator pixels("deck__actions", "column-gap"), :>=, 24.0
    assert_operator pixels("deck__actions", "row-gap"), :>=, 8.0
    assert_equal "wrap", Stylesheet.resolved("deck__actions", @rules)["flex-wrap"]
  end

  test "nenhuma regra de deck impede a quebra de linha a 360px" do
    assert_operator deck_rules.size, :>=, 30, "as regras de deck sumiram da folha"
    assert_empty blocking_declarations(@rules)
  end

  test "nome de deck e de carta quebra em qualquer ponto" do
    WRAPPING_CLASSES.each do |klass|
      assert_equal "anywhere", Stylesheet.resolved(klass, @rules)["overflow-wrap"], ".#{klass}"
    end
  end

  test "a guarda de 360px acusa nowrap, largura fixa e trilha fixa" do
    css = <<~CSS
      .deck__a { white-space: nowrap; }
      .deck-controls__b { min-width: 120px; }
      .deck-shortfall__c { grid-template-columns: 200px 1fr; }
      .deck__d { flex-wrap: nowrap; }
      .deck__e { min-width: var(--touch-target); width: 100%; }
      .wishlist__f { white-space: nowrap; }
    CSS

    assert_equal %w[.deck__a .deck-controls__b .deck-shortfall__c .deck__d],
                 blocking_declarations(Stylesheet.rules(css)).map { |line| line.split.first }
  end
end
