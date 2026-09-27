require "test_helper"
require_relative "support/stylesheet"

class ProgressBarRenderTest < Minitest::Test
  def setup
    @rules = Stylesheet.rules
  end

  def find_rule(selector)
    # Normaliza espaço em branco no seletor procurado
    normalized_sel = selector.gsub(/\s+/, " ").strip
    @rules.find do |sel, _|
      sel.gsub(/\s+/, " ").strip == normalized_sel
    end&.last
  end

  def parse_declarations(body)
    Stylesheet.declarations(body).to_h
  end

  # NAV-38: Barra de progresso desenhada corretamente em 0%
  # AC 1: .progress-set__bar tem appearance: none
  def test_progress_bar_has_appearance_none
    rule = find_rule(".progress-set__bar")
    assert rule, ".progress-set__bar deve existir"
    decl = parse_declarations(rule)
    assert_equal "none", decl["appearance"],
      ".progress-set__bar deve ter appearance: none para desabilitar estilo nativo"
  end

  # AC 2: ::-webkit-progress-bar (Chromium) tem fundo surface-sunken
  def test_progress_bar_webkit_has_surface_sunken_background
    rule = find_rule(".progress-set__bar::-webkit-progress-bar")
    assert rule, ".progress-set__bar::-webkit-progress-bar deve existir (sem ele, o trilho fica cinza no Chromium)"
    decl = parse_declarations(rule)
    assert_equal "var(--surface-sunken)", decl["background-color"],
      ".progress-set__bar::-webkit-progress-bar deve ter background-color: var(--surface-sunken)"
  end

  # AC 3: ::-webkit-progress-value (Chromium) tem fundo border-strong
  def test_progress_bar_webkit_value_has_border_strong_background
    rule = find_rule(".progress-set__bar::-webkit-progress-value")
    assert rule, ".progress-set__bar::-webkit-progress-value deve existir (sem ele, o preenchimento fica azul nativo no Chromium)"
    decl = parse_declarations(rule)
    assert_equal "var(--border-strong)", decl["background-color"],
      ".progress-set__bar::-webkit-progress-value deve ter background-color: var(--border-strong)"
  end

  # AC 4: ::-moz-progress-bar (Firefox) tem fundo border-strong
  def test_progress_bar_moz_has_border_strong_background
    rule = find_rule(".progress-set__bar::-moz-progress-bar")
    assert rule, ".progress-set__bar::-moz-progress-bar deve existir (sem ele, o preenchimento fica azul nativo no Firefox)"
    decl = parse_declarations(rule)
    assert_equal "var(--border-strong)", decl["background-color"],
      ".progress-set__bar::-moz-progress-bar deve ter background-color: var(--border-strong)"
  end
end
