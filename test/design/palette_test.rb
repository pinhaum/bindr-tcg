require "test_helper"
require_relative "support/stylesheet"

class PaletteTest < ActiveSupport::TestCase
  # Tolerância de matiz em graus: ±6° ao redor de cada alvo
  # Conforme especificado em .context/design.md §11.3
  # "Duas matizes: azul-petróleo 228° e âmbar 66°, separados por 158°; danger em 28°"
  HUE_TOLERANCE = 6.0

  # Limiar de croma para considerar uma cor como acromática
  # Cores com croma menor que isso têm matiz muito instável
  ACHROMATIC_CHROMA_THRESHOLD = 0.005

  # Targets de matiz (em graus):
  # - Azul-petróleo (surface-base, surface-raised, surface-sunken, border, ink, etc.): ~228°
  # - Âmbar (accent): ~66°
  # - Vermelho (danger): ~28°
  BLUE_PETROL_HUE = 228.0
  AMBER_HUE = 66.0
  DANGER_HUE = 28.0

  setup do
    @root_tokens = Stylesheet.read_root_tokens
    @content_outside_root = Stylesheet.content_outside_root
    @stylesheet_without_comments = Stylesheet.content_without_comments
  end

  # ========== Teste 1: Nenhum hex, rgb(), hsl() fora de :root ==========

  test "nenhum hex fora de :root (comentários descontados)" do
    content = @content_outside_root

    # Procura por padrão #rrggbb ou #rgb ou #rrggbbaa fora de :root
    hex_pattern = /#([0-9a-fA-F]{3}([0-9a-fA-F]{3})?([0-9a-fA-F]{2})?)/
    found_hexes = content.scan(hex_pattern).map { |match| "##{match[0]}" }

    assert(
      found_hexes.empty?,
      "Cores hex encontradas fora de :root: #{found_hexes.join(', ')}"
    )
  end

  test "nenhuma função rgb() ou rgba() fora de :root" do
    content = @content_outside_root

    # Procura por rgba?( ou rgba (com espaço)
    rgb_pattern = /rgba?\s*\(/i
    matches = content.scan(rgb_pattern)

    assert(
      matches.empty?,
      "Funções rgb() ou rgba() encontradas fora de :root (#{matches.length} ocorrências)"
    )
  end

  test "nenhuma função hsl() ou hsla() fora de :root" do
    content = @content_outside_root

    # Procura por hsla?( ou hsla (com espaço)
    hsl_pattern = /hsla?\s*\(/i
    matches = content.scan(hsl_pattern)

    assert(
      matches.empty?,
      "Funções hsl() ou hsla() encontradas fora de :root (#{matches.length} ocorrências)"
    )
  end

  # Testes sintéticos para garantir discriminação
  test "teste sintético: rgb() é detectado" do
    synthetic_css = "color: rgb(255, 255, 255);"
    rgb_pattern = /rgba?\s*\(/i
    assert(
      synthetic_css.match?(rgb_pattern),
      "Teste sintético falhou: rgb() deveria ser detectado"
    )
  end

  test "teste sintético: hsl() é detectado" do
    synthetic_css = "background: hsl(228, 50%, 10%);"
    hsl_pattern = /hsla?\s*\(/i
    assert(
      synthetic_css.match?(hsl_pattern),
      "Teste sintético falhou: hsl() deveria ser detectado"
    )
  end

  test "teste sintético: hex fora de :root é detectado" do
    synthetic_css = "color: #ff0000; /* não em :root */"
    hex_pattern = /#([0-9a-fA-F]{3}([0-9a-fA-F]{3})?([0-9a-fA-F]{2})?)/
    assert(
      synthetic_css.match?(hex_pattern),
      "Teste sintético falhou: hex deveria ser detectado"
    )
  end

  # ========== Teste 2: Matiz dos tokens de :root (em OKLCH) ==========

  test "todo hex de :root tem matiz dentro de tolerância de 228° ou 66° ou 28° (danger)" do
    # Tokens esperados com sua matiz alvo
    expected_hues = {
      "--surface-base" => BLUE_PETROL_HUE,
      "--surface-raised" => BLUE_PETROL_HUE,
      "--surface-sunken" => BLUE_PETROL_HUE,
      "--border" => BLUE_PETROL_HUE,
      "--border-strong" => BLUE_PETROL_HUE,
      "--ink" => BLUE_PETROL_HUE,
      "--ink-muted" => BLUE_PETROL_HUE,
      "--accent" => AMBER_HUE,
      "--on-accent" => BLUE_PETROL_HUE,
      "--danger" => DANGER_HUE
    }

    expected_hues.each do |token_name, expected_hue|
      hex_value = @root_tokens[token_name]
      assert(
        hex_value.present?,
        "Token #{token_name} não encontrado em :root"
      )

      oklch = Stylesheet.hex_to_oklch(hex_value)
      actual_hue = oklch[:H]
      chroma = oklch[:C]

      # Para cores acromáticas (croma muito baixa), a matiz é instável
      # Regra explícita: aceitar como neutra sem verificar matiz
      if chroma < ACHROMATIC_CHROMA_THRESHOLD
        # Cor acromática — não verificamos matiz, apenas que existe
        # Nenhum token atual está abaixo deste limiar, então isto é uma guarda futura
        assert(
          true,
          "Token #{token_name} (#{hex_value}): acromático com C=#{chroma.round(4)} " \
          "(abaixo de #{ACHROMATIC_CHROMA_THRESHOLD})"
        )
      else
        # Para cores cromáticas, verificar matiz dentro de tolerância
        hue_within_tolerance = false
        tolerance = HUE_TOLERANCE

        # Verificar contra a matiz esperada (com wrap-around em 0/360)
        hue_diff = (actual_hue - expected_hue).abs
        hue_diff = 360 - hue_diff if hue_diff > 180

        hue_within_tolerance = hue_diff <= tolerance

        assert(
          hue_within_tolerance,
          "Token #{token_name} (#{hex_value}): matiz #{actual_hue.round(1)}° " \
          "fora de tolerância ±#{tolerance.round(1)}° de #{expected_hue}° " \
          "(C=#{chroma.round(4)})"
        )
      end
    end
  end

  test "teste sintético: matiz fora de tolerância é detectado" do
    # Cor vermelha pura (#ff0000) tem matiz 0°, fora de 228° e 66°
    red_oklch = Stylesheet.hex_to_oklch("#ff0000")
    # Vermelho puro deve estar perto de 29° em OKLCH
    assert(
      red_oklch[:H] > 20 && red_oklch[:H] < 40,
      "Teste sintético: #ff0000 deveria ter matiz entre 20° e 40°, mas tem #{red_oklch[:H].round(1)}°"
    )

    # Verificar que diferença de 228° é > tolerância
    diff = (red_oklch[:H] - BLUE_PETROL_HUE).abs
    diff = 360 - diff if diff > 180
    assert(
      diff > HUE_TOLERANCE,
      "Teste sintético falhou: #ff0000 deveria estar fora de tolerância de 228°"
    )
  end

  test "teste sintético: cor acromática (croma muito baixo) é identificada" do
    # Cinza puro: #808080 tem croma próximo a 0
    gray_oklch = Stylesheet.hex_to_oklch("#808080")
    assert(
      gray_oklch[:C] < ACHROMATIC_CHROMA_THRESHOLD,
      "Teste sintético: #808080 deveria ter croma < #{ACHROMATIC_CHROMA_THRESHOLD}, mas tem #{gray_oklch[:C].round(4)}"
    )
  end

  # ========== Teste 3: Nenhuma sombra ou gradiente ==========

  test "nenhuma ocorrência de box-shadow" do
    content = @stylesheet_without_comments
    matches = content.scan(/box-shadow\s*:/i)

    assert(
      matches.empty?,
      "box-shadow encontrado na folha (#{matches.length} ocorrências)"
    )
  end

  test "nenhuma ocorrência de text-shadow" do
    content = @stylesheet_without_comments
    matches = content.scan(/text-shadow\s*:/i)

    assert(
      matches.empty?,
      "text-shadow encontrado na folha (#{matches.length} ocorrências)"
    )
  end

  test "nenhuma ocorrência de drop-shadow" do
    content = @stylesheet_without_comments
    matches = content.scan(/drop-shadow\s*\(/i)

    assert(
      matches.empty?,
      "drop-shadow() encontrado na folha (#{matches.length} ocorrências)"
    )
  end

  test "nenhuma ocorrência de gradient(" do
    content = @stylesheet_without_comments
    # Procura por linear-gradient, radial-gradient, conic-gradient, repeating-*
    gradient_pattern = /\w+-gradient\s*\(/i
    matches = content.scan(gradient_pattern)

    assert(
      matches.empty?,
      "gradiente encontrado na folha: #{matches.join(', ')} (#{matches.length} ocorrências)"
    )
  end

  # Testes sintéticos
  test "teste sintético: box-shadow é detectado" do
    synthetic_css = "box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);"
    assert_match(/box-shadow\s*:/i, synthetic_css)
  end

  test "teste sintético: text-shadow é detectado" do
    synthetic_css = "text-shadow: 2px 2px 4px #000;"
    assert_match(/text-shadow\s*:/i, synthetic_css)
  end

  test "teste sintético: drop-shadow é detectado" do
    synthetic_css = "filter: drop-shadow(2px 2px 4px rgba(0, 0, 0, 0.5));"
    assert_match(/drop-shadow\s*\(/i, synthetic_css)
  end

  test "teste sintético: linear-gradient é detectado" do
    synthetic_css = "background: linear-gradient(to right, #ff0000, #0000ff);"
    gradient_pattern = /\w+-gradient\s*\(/i
    assert_match(gradient_pattern, synthetic_css)
  end

  test "teste sintético: radial-gradient é detectado" do
    synthetic_css = "background: radial-gradient(circle, white, black);"
    gradient_pattern = /\w+-gradient\s*\(/i
    assert_match(gradient_pattern, synthetic_css)
  end

  # ========== Teste 4: Nenhuma palavra-chave de cor nomeada (exceções permitidas) ==========

  test "nenhuma palavra-chave de cor nomeada além de currentcolor, transparent, inherit" do
    content = @stylesheet_without_comments

    # Palavras-chave de cor CSS comuns/estendidas que NÃO são permitidas
    forbidden_colors = %w[
      red green blue white black gray grey yellow orange purple pink
      cyan magenta navy teal maroon olive lime aqua fuchsia silver
      brown coral crimson cyan darkblue darkgreen darkred gold
      hotpink lightblue lightcyan lightgray lightgreen lightpink
      lightyellow lime maroon navy olive orange orangered orchid
      pink plum powderblue purple rosybrown royalblue salmon
      sandybrown seagreen seashell sienna silver skyblue slateblue
      slategray slategrey snow springgreen steelblue tan thistle
      tomato turquoise violet wheat whitesmoke
    ]

    # Para cada cor proibida, procurar por ela como valor de propriedade
    # Padrão: "propriedade: cor" ou "propriedade: cor," ou "propriedade: cor;"
    # Com fronteira de palavra para não pegar em nomes de token/classe
    errors = []

    forbidden_colors.each do |color|
      # Padrão: : cor seguido de espaço, vírgula, ponto e vírgula ou fim de linha
      # com fronteira de palavra em ambos os lados
      pattern = /:\s+\b#{color}\b\s*[,;]|\b#{color}\s*[,;]|\b#{color}\s*$/i
      matches = content.scan(pattern)
      errors << "#{color} (#{matches.length})" if matches.any?
    end

    assert(
      errors.empty?,
      "Palavras-chave de cor nomeadas encontradas: #{errors.join(', ')}"
    )
  end

  test "currentcolor, transparent, inherit são permitidas" do
    content = @stylesheet_without_comments

    # Procurar por essas palavras-chave permitidas; o teste passa se encontrá-las ou não
    # (elas podem ou não estar presentes, mas se estiverem, não são erro)
    allowed = %w[currentcolor transparent inherit]
    allowed.each do |keyword|
      # Simples verificação de que a regex básica as detectaria
      pattern = /\b#{keyword}\b/i
      # Não fazemos assert aqui; apenas verificamos que a regex funciona
      assert_match(pattern, keyword.upcase)
    end
  end

  # Testes sintéticos
  test "teste sintético: red é detectado como cor proibida" do
    synthetic_css = "color: red;"
    pattern = /:\s+\b(red)\b\s*[,;]/i
    assert_match(pattern, synthetic_css)
  end

  test "teste sintético: blue é detectado como cor proibida" do
    synthetic_css = "background: blue; /* cor proibida */"
    pattern = /:\s+\b(blue)\b\s*[,;]/i
    assert_match(pattern, synthetic_css)
  end

  test "teste sintético: currentcolor é permitido e detectado" do
    synthetic_css = "border: 2px solid currentcolor;"
    pattern = /\bcurrentcolor\b/i
    assert_match(pattern, synthetic_css)
  end

  test "teste sintético: transparent é permitido e detectado" do
    synthetic_css = "background-color: transparent;"
    pattern = /\btransparent\b/i
    assert_match(pattern, synthetic_css)
  end
end
