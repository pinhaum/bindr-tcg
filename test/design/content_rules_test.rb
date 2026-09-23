require "test_helper"
require_relative "support/stylesheet"

# INT-10 (Req. 12.10): nenhum emoji na interface — até haver conjunto de
# ícones, escreve-se a palavra (§11.6).
# INT-11 (Req. 12.11): o chip das seis cores do jogo nunca é preenchido com
# `accent`; enquanto a P8 estiver aberta, tratamento neutro com `border-strong`
# mais o rótulo escrito.
class ContentRulesTest < ActiveSupport::TestCase
  SOURCES = %w[app/views app/helpers config/locales].freeze

  # Faixas de emoji. As setas (U+2190…) e sinais tipográficos (×, −) usados
  # nas views ficam de fora: são texto, não pictograma.
  EMOJI = Regexp.union(
    /[\u{1F000}-\u{1FAFF}]/, # pictogramas, emoticons, bandeiras, símbolos suplementares
    /[\u{2600}-\u{27BF}]/,   # símbolos diversos e dingbats
    /[\u{2B00}-\u{2BFF}]/,   # setas e estrelas pictográficas (U+2B50, U+2B06)
    /[\u{231A}\u{231B}\u{23E9}-\u{23FA}]/, # relógio, ampulheta, controles de mídia
    /[\u{3030}\u{303D}\u{3297}\u{3299}]/,
    /[\u{FE0F}\u{200D}\u{20E3}]/  # seletor de variação, ZWJ, keycap
  )

  def self.emoji_offenses(text)
    text.each_line.with_index(1).filter_map do |line, number|
      found = line.scan(EMOJI)
      "#{number}: #{found.map { |char| format('U+%04X', char.ord) }.join(' ')}" if found.any?
    end
  end

  def self.accent_filled_chips(rules)
    rules.select do |selector, body|
      Stylesheet.blocks_of(selector).include?("filter-chip") &&
        Stylesheet.declarations(body).any? { |property, value| property.match?(/\Abackground(?:-color)?\z/) && value.include?("var(--accent)") }
    end.map(&:first)
  end

  test "nenhuma view, helper ou locale contém emoji" do
    files = SOURCES.flat_map { |dir| Dir[Rails.root.join(dir, "**/*")] }.select { |path| File.file?(path) }
    assert_operator files.size, :>, 10, "a varredura parou de encontrar arquivos"

    offenses = files.flat_map do |path|
      self.class.emoji_offenses(File.read(path, encoding: "UTF-8")).map { |line| "#{path.delete_prefix("#{Rails.root}/")}:#{line}" }
    end

    assert_empty offenses, "emoji na interface:\n#{offenses.join("\n")}"
  end

  test "a varredura de emoji acusa pictograma, dingbat e seletor de variação" do
    text = "Atendido \u{2705}\nFogo \u{1F525}\nEstrela \u{2B50}\nCoração \u{2764}\u{FE0F}\n← Voltar × −1\n"

    assert_equal [ "1: U+2705", "2: U+1F525", "3: U+2B50", "4: U+2764 U+FE0F" ], self.class.emoji_offenses(text)
  end

  test "o chip de filtro nunca é preenchido com accent" do
    assert_empty self.class.accent_filled_chips(Stylesheet.rules)

    body = Stylesheet.rules.find { |selector, _| selector == ".filter-chip" }&.last
    assert body, "regra .filter-chip sumiu da folha"
    assert_match(/border:\s*1px solid var\(--border-strong\)/, body)
  end

  test "a guarda do chip acusa fill accent em chip e descendente" do
    css = <<~CSS
      .filter-chip { background-color: var(--accent); }
      .filter-chip__label { background: var(--accent); }
      .filter-chip__remove { color: var(--accent); }
      .auth__submit { background-color: var(--accent); }
    CSS

    assert_equal %w[.filter-chip .filter-chip__label], self.class.accent_filled_chips(Stylesheet.rules(css))
  end
end
