# Helper reutilizável para ler tokens de :root em catalog.css
module Stylesheet
  # Extrai pares token=valor de :root em catalog.css
  # Retorna um Hash { 'nome-do-token' => 'valor' }
  def self.read_root_tokens
    stylesheet_path = Rails.root.join("app/assets/stylesheets/catalog.css")
    content = File.read(stylesheet_path)

    # Extrai o bloco :root
    root_match = content.match(/:root\s*\{([^}]+)\}/m)
    return {} unless root_match

    declarations = root_match[1]

    # Extrai pares --nome: valor
    tokens = {}
    declarations.scan(/--([a-z0-9-]+):\s*([^;]+);/) do |name, value|
      tokens["--#{name}"] = value.strip
    end

    tokens
  end

  # Verifica se color-scheme está presente em :root
  def self.has_color_scheme_dark?
    stylesheet_path = Rails.root.join("app/assets/stylesheets/catalog.css")
    content = File.read(stylesheet_path)
    root_match = content.match(/:root\s*\{([^}]+)\}/m)
    return false unless root_match
    root_match[1].include?("color-scheme: dark")
  end

  # Verifica se prefers-color-scheme existe em qualquer lugar (não deve existir)
  def self.has_prefers_color_scheme?
    stylesheet_path = Rails.root.join("app/assets/stylesheets/catalog.css")
    content = File.read(stylesheet_path)
    content.include?("prefers-color-scheme")
  end

  # Lê a folha inteira
  def self.read_stylesheet
    stylesheet_path = Rails.root.join("app/assets/stylesheets/catalog.css")
    File.read(stylesheet_path)
  end

  # Remove comentários /* */ da folha
  # Retorna o conteúdo sem comentários de bloco
  def self.content_without_comments
    content = read_stylesheet
    # Remove comentários de bloco /* ... */
    content.gsub(%r{/\*.*?\*/}m, "")
  end

  # Extrai o conteúdo fora de :root
  # Retorna tudo que está fora do bloco :root { ... }
  def self.content_outside_root
    content = content_without_comments
    # Remove o bloco :root inteiro
    content.gsub(/:root\s*\{[^}]+\}/m, "")
  end

  # Converte hex para OKLCH (matiz, croma, luminância)
  # Björn Ottosson algorithm: sRGB → linearized → OKLab → OKLCH
  # Retorna { H: hue (0-360), C: chroma (0-0.4), L: lightness (0-1) }
  def self.hex_to_oklch(hex)
    hex = hex.sub(/^#/, "")
    r = hex[0..1].to_i(16) / 255.0
    g = hex[2..3].to_i(16) / 255.0
    b = hex[4..5].to_i(16) / 255.0

    # Linearize sRGB
    r = r <= 0.04045 ? r / 12.92 : ((r + 0.055) / 1.055) ** 2.4
    g = g <= 0.04045 ? g / 12.92 : ((g + 0.055) / 1.055) ** 2.4
    b = b <= 0.04045 ? b / 12.92 : ((b + 0.055) / 1.055) ** 2.4

    # Convert to OKLab
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s_val = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

    l = l ** (1.0 / 3.0)
    m = m ** (1.0 / 3.0)
    s_val = s_val ** (1.0 / 3.0)

    lab_l = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s_val
    lab_a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s_val
    lab_b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s_val

    # Convert OKLab to OKLCH
    c = Math.hypot(lab_a, lab_b)
    h = Math.atan2(lab_b, lab_a) * 180 / Math::PI
    h = h < 0 ? h + 360 : h

    {
      H: h.round(1),
      C: c.round(4),
      L: lab_l.round(4)
    }
  end

  # Regras da folha fora de :root, comentários descontados.
  # Retorna [[seletor, corpo], ...] na ordem em que aparecem.
  def self.rules(css = read_stylesheet)
    css.gsub(%r{/\*.*?\*/}m, "")
       .scan(/([^{}]+)\{([^{}]*)\}/)
       .map { |selector, body| [ selector.strip, body ] }
       .reject { |selector, _| selector == ":root" }
  end

  # Declarações de um corpo de regra: [[propriedade, valor], ...]
  def self.declarations(body)
    body.split(";").filter_map do |declaration|
      property, value = declaration.split(":", 2)
      next if value.nil?

      [ property.strip.downcase, value.strip ]
    end
  end

  # Blocos BEM citados por um seletor: `.card-tile__art, .flash--alert` → card-tile, flash.
  # Seletor sem classe (`*`, `body`) não cita bloco nenhum.
  def self.blocks_of(selector)
    selector.scan(/\.([a-z0-9]+(?:-[a-z0-9]+)*)/).flatten.uniq
  end

  # Resolve um valor com var(--x) encadeado até pixels. `rem` assume raiz de 16px,
  # o default do navegador: a folha não redefine `font-size` em `:root` nem em `html`.
  REM_IN_PIXELS = 16.0

  def self.to_pixels(value, tokens = read_root_tokens)
    value = value.strip
    if (name = value[/\Avar\((--[a-z0-9-]+)\)\z/, 1])
      raise ArgumentError, "token #{name} não declarado em :root" unless tokens.key?(name)

      return to_pixels(tokens[name], tokens)
    end

    case value
    when "0" then 0.0
    when /\A(\d+(?:\.\d+)?)px\z/ then Regexp.last_match(1).to_f
    when /\A(\d+(?:\.\d+)?)rem\z/ then Regexp.last_match(1).to_f * REM_IN_PIXELS
    else raise ArgumentError, "valor sem conversão para pixel: #{value.inspect}"
    end
  end

  # Declarações que valem para uma classe sozinha: as de toda regra em que
  # `.classe` aparece como seletor de uma parte da lista, a última vencendo.
  # Retorna { "propriedade" => "valor" }.
  def self.resolved(klass, rules = self.rules)
    rules.select { |selector, _| selector.split(",").map(&:strip).include?(".#{klass}") }
         .flat_map { |_, body| declarations(body) }
         .to_h
  end

  CODE_STYLE = {
    "font-family" => "var(--font-mono)",
    "font-size" => "var(--code-size)",
    "line-height" => "var(--code-line-height)",
    "font-weight" => "var(--code-weight)"
  }.freeze

  # A classe renderiza no estilo `code` de §11.4?
  def self.code_styled?(klass, rules = self.rules)
    resolved(klass, rules).slice(*CODE_STYLE.keys) == CODE_STYLE
  end
end
