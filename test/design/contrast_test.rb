require "test_helper"
require_relative "support/stylesheet"

class ContrastTest < ActiveSupport::TestCase
  # Fórmula WCAG 2.2: https://www.w3.org/TR/WCAG22/
  # Definição de relative luminance usa 0.04045 (Note 2: updated May 2021)
  # "Before May 2021 the value of 0.04045 in the definition was different (0.03928).
  # It has no practical effect on the calculations."
  LINEARIZATION_THRESHOLD = 0.04045

  # Setup: lê tokens uma vez para todos os testes
  def setup
    @tokens = Stylesheet.read_root_tokens
  end

  # Calcula a luminância relativa de uma cor hex (com #)
  # Retorna valor entre 0 e 1
  def relative_luminance(hex_color)
    # Remove # e converte para RGB
    hex = hex_color.sub(/^#/, "")
    r = hex[0..1].to_i(16) / 255.0
    g = hex[2..3].to_i(16) / 255.0
    b = hex[4..5].to_i(16) / 255.0

    # Linearizar cada componente (WCAG 2.2, fórmula de sRGB)
    r_linear = if r <= LINEARIZATION_THRESHOLD
                 r / 12.92
    else
                 ((r + 0.055) / 1.055) ** 2.4
    end

    g_linear = if g <= LINEARIZATION_THRESHOLD
                 g / 12.92
    else
                 ((g + 0.055) / 1.055) ** 2.4
    end

    b_linear = if b <= LINEARIZATION_THRESHOLD
                 b / 12.92
    else
                 ((b + 0.055) / 1.055) ** 2.4
    end

    # Calcular luminância relativa: L = 0.2126*R + 0.7152*G + 0.0722*B
    0.2126 * r_linear + 0.7152 * g_linear + 0.0722 * b_linear
  end

  # Calcula a razão de contraste entre duas cores
  # Retorna razão com base na mais clara: (L1 + 0.05) / (L2 + 0.05)
  def contrast_ratio(color1, color2)
    l1 = relative_luminance(color1)
    l2 = relative_luminance(color2)

    # A razão é sempre (L_mais_clara + 0.05) / (L_mais_escura + 0.05)
    lighter = [ l1, l2 ].max
    darker = [ l1, l2 ].min

    (lighter + 0.05) / (darker + 0.05)
  end

  # Verifica presença de token
  def assert_token_present(token_name)
    assert(
      @tokens[token_name].present?,
      "Token #{token_name} não encontrado na folha"
    )
  end

  # Prova da fórmula contra valores conhecidos
  test "contraste #000000/#ffffff = 21:1" do
    ratio = contrast_ratio("#000000", "#ffffff")
    assert_in_delta(21.0, ratio, 0.01, "Esperado 21:1, obtive #{ratio.round(2)}:1")
  end

  test "contraste de cor idêntica = 1:1" do
    ratio = contrast_ratio("#ff9e14", "#ff9e14")
    assert_in_delta(1.0, ratio, 0.01, "Esperado 1:1, obtive #{ratio.round(2)}:1")
  end

  # Testes dos pares reais: 4.5:1 para texto
  test "ink sobre surface-base ≥ 4.5:1" do
    assert_token_present("--ink")
    assert_token_present("--surface-base")

    ratio = contrast_ratio(@tokens["--ink"], @tokens["--surface-base"])
    assert(
      ratio >= 4.5,
      "Contraste ink/surface-base: #{ratio.round(2)}:1 (mínimo 4.5:1)"
    )
  end

  test "ink sobre surface-raised ≥ 4.5:1" do
    assert_token_present("--ink")
    assert_token_present("--surface-raised")

    ratio = contrast_ratio(@tokens["--ink"], @tokens["--surface-raised"])
    assert(
      ratio >= 4.5,
      "Contraste ink/surface-raised: #{ratio.round(2)}:1 (mínimo 4.5:1)"
    )
  end

  test "ink sobre surface-sunken ≥ 4.5:1" do
    assert_token_present("--ink")
    assert_token_present("--surface-sunken")

    ratio = contrast_ratio(@tokens["--ink"], @tokens["--surface-sunken"])
    assert(
      ratio >= 4.5,
      "Contraste ink/surface-sunken: #{ratio.round(2)}:1 (mínimo 4.5:1)"
    )
  end

  test "ink-muted sobre surface-base ≥ 4.5:1" do
    assert_token_present("--ink-muted")
    assert_token_present("--surface-base")

    ratio = contrast_ratio(@tokens["--ink-muted"], @tokens["--surface-base"])
    assert(
      ratio >= 4.5,
      "Contraste ink-muted/surface-base: #{ratio.round(2)}:1 (mínimo 4.5:1)"
    )
  end

  test "ink-muted sobre surface-raised ≥ 4.5:1" do
    assert_token_present("--ink-muted")
    assert_token_present("--surface-raised")

    ratio = contrast_ratio(@tokens["--ink-muted"], @tokens["--surface-raised"])
    assert(
      ratio >= 4.5,
      "Contraste ink-muted/surface-raised: #{ratio.round(2)}:1 (mínimo 4.5:1)"
    )
  end

  test "ink-muted sobre surface-sunken ≥ 4.5:1" do
    assert_token_present("--ink-muted")
    assert_token_present("--surface-sunken")

    ratio = contrast_ratio(@tokens["--ink-muted"], @tokens["--surface-sunken"])
    assert(
      ratio >= 4.5,
      "Contraste ink-muted/surface-sunken: #{ratio.round(2)}:1 (mínimo 4.5:1)"
    )
  end

  test "accent sobre surface-base ≥ 4.5:1" do
    assert_token_present("--accent")
    assert_token_present("--surface-base")

    ratio = contrast_ratio(@tokens["--accent"], @tokens["--surface-base"])
    assert(
      ratio >= 4.5,
      "Contraste accent/surface-base: #{ratio.round(2)}:1 (mínimo 4.5:1)"
    )
  end

  test "accent sobre surface-raised ≥ 4.5:1" do
    assert_token_present("--accent")
    assert_token_present("--surface-raised")

    ratio = contrast_ratio(@tokens["--accent"], @tokens["--surface-raised"])
    assert(
      ratio >= 4.5,
      "Contraste accent/surface-raised: #{ratio.round(2)}:1 (mínimo 4.5:1)"
    )
  end

  test "accent sobre surface-sunken ≥ 4.5:1" do
    assert_token_present("--accent")
    assert_token_present("--surface-sunken")

    ratio = contrast_ratio(@tokens["--accent"], @tokens["--surface-sunken"])
    assert(
      ratio >= 4.5,
      "Contraste accent/surface-sunken: #{ratio.round(2)}:1 (mínimo 4.5:1)"
    )
  end

  test "on-accent sobre accent ≥ 4.5:1" do
    assert_token_present("--on-accent")
    assert_token_present("--accent")

    ratio = contrast_ratio(@tokens["--on-accent"], @tokens["--accent"])
    assert(
      ratio >= 4.5,
      "Contraste on-accent/accent: #{ratio.round(2)}:1 (mínimo 4.5:1)"
    )
  end

  test "on-accent sobre danger ≥ 4.5:1" do
    assert_token_present("--on-accent")
    assert_token_present("--danger")

    ratio = contrast_ratio(@tokens["--on-accent"], @tokens["--danger"])
    assert(
      ratio >= 4.5,
      "Contraste on-accent/danger: #{ratio.round(2)}:1 (mínimo 4.5:1)"
    )
  end

  test "danger sobre surface-base ≥ 4.5:1" do
    assert_token_present("--danger")
    assert_token_present("--surface-base")

    ratio = contrast_ratio(@tokens["--danger"], @tokens["--surface-base"])
    assert(
      ratio >= 4.5,
      "Contraste danger/surface-base: #{ratio.round(2)}:1 (mínimo 4.5:1)"
    )
  end

  # Testes de 3:1 para borda de controle e foco
  test "border-strong sobre surface-base ≥ 3:1" do
    assert_token_present("--border-strong")
    assert_token_present("--surface-base")

    ratio = contrast_ratio(@tokens["--border-strong"], @tokens["--surface-base"])
    assert(
      ratio >= 3.0,
      "Contraste border-strong/surface-base: #{ratio.round(2)}:1 (mínimo 3:1)"
    )
  end

  test "border-strong sobre surface-raised ≥ 3:1" do
    assert_token_present("--border-strong")
    assert_token_present("--surface-raised")

    ratio = contrast_ratio(@tokens["--border-strong"], @tokens["--surface-raised"])
    assert(
      ratio >= 3.0,
      "Contraste border-strong/surface-raised: #{ratio.round(2)}:1 (mínimo 3:1)"
    )
  end

  test "border-strong sobre surface-sunken ≥ 3:1" do
    assert_token_present("--border-strong")
    assert_token_present("--surface-sunken")

    ratio = contrast_ratio(@tokens["--border-strong"], @tokens["--surface-sunken"])
    assert(
      ratio >= 3.0,
      "Contraste border-strong/surface-sunken: #{ratio.round(2)}:1 (mínimo 3:1)"
    )
  end

  test "accent (anel de foco) sobre surface-base ≥ 3:1" do
    assert_token_present("--accent")
    assert_token_present("--surface-base")

    ratio = contrast_ratio(@tokens["--accent"], @tokens["--surface-base"])
    assert(
      ratio >= 3.0,
      "Contraste accent/surface-base: #{ratio.round(2)}:1 (mínimo 3:1)"
    )
  end

  test "accent (anel de foco) sobre surface-raised ≥ 3:1" do
    assert_token_present("--accent")
    assert_token_present("--surface-raised")

    ratio = contrast_ratio(@tokens["--accent"], @tokens["--surface-raised"])
    assert(
      ratio >= 3.0,
      "Contraste accent/surface-raised: #{ratio.round(2)}:1 (mínimo 3:1)"
    )
  end

  test "accent (anel de foco) sobre surface-sunken ≥ 3:1" do
    assert_token_present("--accent")
    assert_token_present("--surface-sunken")

    ratio = contrast_ratio(@tokens["--accent"], @tokens["--surface-sunken"])
    assert(
      ratio >= 3.0,
      "Contraste accent/surface-sunken: #{ratio.round(2)}:1 (mínimo 3:1)"
    )
  end

  # Edge case: token ausente deve falhar, não passar silenciosamente
  test "token ausente da folha falha" do
    # Simula um par onde um token não existe
    empty_tokens = {}
    error = assert_raises(Minitest::Assertion) do
      assert(
        empty_tokens["--fake-token-nonexistent"].present?,
        "Token --fake-token-nonexistent não encontrado na folha"
      )
    end

    assert_match(/--fake-token-nonexistent/, error.message)
  end

  # Edge case: par sintético reprovado deve falhar com razão medida
  test "par sintético reprovado falha nomeando razão medida" do
    error = assert_raises(Minitest::Assertion) do
      # Simula um par de contraste baixo (sintético)
      light = "#e0e0e0"
      dark = "#f0f0f0"
      ratio = contrast_ratio(light, dark)
      assert(
        ratio >= 4.5,
        "Contraste e0e0e0/f0f0f0: #{ratio.round(2)}:1 (mínimo 4.5:1)"
      )
    end

    # Verifica se a mensagem contém a razão medida
    assert_match(/\d+\.\d+:1/, error.message)
  end
end
