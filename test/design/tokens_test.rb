require "test_helper"
require_relative "support/stylesheet"

class TokensTest < ActiveSupport::TestCase
  # Lista normativa de tokens esperados de .context/design.md §11.3–§11.5
  EXPECTED_TOKENS = {
    # Cores — §11.3
    "--surface-base" => "#051b23",
    "--surface-raised" => "#102b36",
    "--surface-sunken" => "#011018",
    "--border" => "#1c3a47",
    "--border-strong" => "#717e84",
    "--ink" => "#e9f0f3",
    "--ink-muted" => "#9ba7ad",
    "--accent" => "#ff9e14",
    "--on-accent" => "#051b23",
    "--danger" => "#ff5448",

    # Tipografia — §11.4 (tamanho, altura de linha, peso como separados, mais as pilhas)
    "--font-sans" => "system-ui, sans-serif",
    "--font-mono" => "monospace",
    "--display-size" => "28px",
    "--display-line-height" => "32px",
    "--display-weight" => "700",
    "--title-size" => "20px",
    "--title-line-height" => "26px",
    "--title-weight" => "600",
    "--body-size" => "15px",
    "--body-line-height" => "22px",
    "--body-weight" => "400",
    "--body-strong-size" => "15px",
    "--body-strong-line-height" => "22px",
    "--body-strong-weight" => "600",
    "--caption-size" => "13px",
    "--caption-line-height" => "18px",
    "--caption-weight" => "400",
    "--code-size" => "13px",
    "--code-line-height" => "18px",
    "--code-weight" => "500",

    # Espaçamento — §11.5
    "--space-1" => "4px",
    "--space-2" => "8px",
    "--space-3" => "16px",
    "--space-4" => "24px",

    # Raio — §11.5
    "--radius-sm" => "4px",
    "--radius-md" => "8px",
    "--radius-full" => "360px"
  }.freeze

  test "root declara todos os tokens de cor de §11.3" do
    tokens = Stylesheet.read_root_tokens
    color_tokens = EXPECTED_TOKENS.select { |k, _v| k.start_with?("--") && EXPECTED_TOKENS[k] && EXPECTED_TOKENS[k].start_with?("#") }

    color_tokens.each do |token_name, expected_value|
      assert_includes(
        tokens,
        token_name,
        "Token #{token_name} não encontrado em :root de catalog.css"
      )
      assert_equal(
        expected_value,
        tokens[token_name],
        "Token #{token_name} tem valor #{tokens[token_name].inspect}, esperado #{expected_value.inspect}"
      )
    end
  end

  test "root declara todos os tokens de tipografia de §11.4" do
    tokens = Stylesheet.read_root_tokens
    typography_tokens = {
      "--font-sans" => "system-ui, sans-serif",
      "--font-mono" => "monospace",
      "--display-size" => "28px",
      "--display-line-height" => "32px",
      "--display-weight" => "700",
      "--title-size" => "20px",
      "--title-line-height" => "26px",
      "--title-weight" => "600",
      "--body-size" => "15px",
      "--body-line-height" => "22px",
      "--body-weight" => "400",
      "--body-strong-size" => "15px",
      "--body-strong-line-height" => "22px",
      "--body-strong-weight" => "600",
      "--caption-size" => "13px",
      "--caption-line-height" => "18px",
      "--caption-weight" => "400",
      "--code-size" => "13px",
      "--code-line-height" => "18px",
      "--code-weight" => "500"
    }

    typography_tokens.each do |token_name, expected_value|
      assert_includes(
        tokens,
        token_name,
        "Token tipográfico #{token_name} não encontrado em :root de catalog.css"
      )
      assert_equal(
        expected_value,
        tokens[token_name],
        "Token #{token_name} tem valor #{tokens[token_name].inspect}, esperado #{expected_value.inspect}"
      )
    end
  end

  test "root declara tokens de espaçamento de §11.5" do
    tokens = Stylesheet.read_root_tokens
    space_tokens = {
      "--space-1" => "4px",
      "--space-2" => "8px",
      "--space-3" => "16px",
      "--space-4" => "24px"
    }

    space_tokens.each do |token_name, expected_value|
      assert_includes(
        tokens,
        token_name,
        "Token de espaçamento #{token_name} não encontrado em :root de catalog.css"
      )
      assert_equal(
        expected_value,
        tokens[token_name],
        "Token #{token_name} tem valor #{tokens[token_name].inspect}, esperado #{expected_value.inspect}"
      )
    end
  end

  test "root declara tokens de raio de §11.5" do
    tokens = Stylesheet.read_root_tokens
    radius_tokens = {
      "--radius-sm" => "4px",
      "--radius-md" => "8px",
      "--radius-full" => "360px"
    }

    radius_tokens.each do |token_name, expected_value|
      assert_includes(
        tokens,
        token_name,
        "Token de raio #{token_name} não encontrado em :root de catalog.css"
      )
      assert_equal(
        expected_value,
        tokens[token_name],
        "Token #{token_name} tem valor #{tokens[token_name].inspect}, esperado #{expected_value.inspect}"
      )
    end
  end

  test "root declara color-scheme: dark" do
    assert(
      Stylesheet.has_color_scheme_dark?,
      "color-scheme: dark não encontrado em :root de catalog.css"
    )
  end

  test "folha não contém prefers-color-scheme" do
    refute(
      Stylesheet.has_prefers_color_scheme?,
      "prefers-color-scheme encontrado em catalog.css (deve estar ausente)"
    )
  end

  test "body usa background-color e color como tokens" do
    stylesheet_path = Rails.root.join("app/assets/stylesheets/catalog.css")
    content = File.read(stylesheet_path)

    # Procura por body { ... } e verifica se tem background-color e color com var()
    body_match = content.match(/body\s*\{([^}]+)\}/m)
    assert body_match, "Seletor body não encontrado em catalog.css"

    body_rules = body_match[1]
    assert_match(
      /background-color:\s*var\(--surface-base\)/,
      body_rules,
      "body não usa background-color: var(--surface-base)"
    )
    assert_match(
      /color:\s*var\(--ink\)/,
      body_rules,
      "body não usa color: var(--ink)"
    )
  end

  test "root preserva tile-min e gap existentes" do
    tokens = Stylesheet.read_root_tokens
    assert_includes(tokens, "--tile-min", "Token --tile-min foi removido (deve ser preservado)")
    assert_includes(tokens, "--gap", "Token --gap foi removido (deve ser preservado)")
  end
end
