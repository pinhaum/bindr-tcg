require "test_helper"
require_relative "support/stylesheet"

class NavigationButtonStylingTest < Minitest::Test
  def setup
    @rules = Stylesheet.rules
  end

  def find_rule(selector)
    normalized_sel = selector.gsub(/\s+/, " ").strip
    @rules.find do |sel, _|
      sel.gsub(/\s+/, " ").strip == normalized_sel
    end&.last
  end

  def parse_declarations(body)
    Stylesheet.declarations(body).to_h
  end

  # NAV-41: .site-header__nav button com background-color transparente e border none
  def test_nav_button_no_native_styling
    rule = find_rule(".site-header__nav button")
    assert rule, ".site-header__nav button deve existir"
    decl = parse_declarations(rule)
    assert_equal "var(--transparent)", decl["background-color"],
      ".site-header__nav button deve ter background-color: var(--transparent)"
    assert_equal "none", decl["border"],
      ".site-header__nav button deve ter border: none"
  end

  # NAV-41: .site-header__nav a com text-decoration: none
  def test_nav_link_no_underline
    rule = find_rule(".site-header__nav a")
    assert rule, ".site-header__nav a deve existir"
    decl = parse_declarations(rule)
    assert_equal "none", decl["text-decoration"],
      ".site-header__nav a deve ter text-decoration: none"
  end
end
