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
end
