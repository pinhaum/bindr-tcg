require "test_helper"
require_relative "support/stylesheet"

class ProgressLineTest < ActiveSupport::TestCase
  include Stylesheet

  setup do
    @sheet = File.read(Rails.root.join("app/assets/stylesheets/catalog.css"))
  end

  test "progress-set não tem border" do
    regra = extrair_regra(".progress-set")
    assert regra.present?, "regra .progress-set deve existir na folha"

    refute regra.match?(/\bborder\s*:(?!\s*none)/i),
           "\.progress-set não deve ter border (exceto border: none)"
  end

  test "progress-set__header é flex com justify-content space-between" do
    regra = extrair_regra(".progress-set__header")
    assert regra.present?, "regra .progress-set__header deve existir"
    assert regra.match?(/display\s*:\s*flex/i), "deve ser flex"
    assert regra.match?(/justify-content\s*:\s*space-between/i),
           "deve ter justify-content: space-between"
  end

  def extrair_regra(seletor)
    folha_sem_comentarios = @sheet.gsub(%r{/\*.*?\*/}m, "")
    padrao = /#{Regexp.escape(seletor)}\s*\{([^}]*)\}/
    match = folha_sem_comentarios.match(padrao)
    match ? match[1] : nil
  end
end
