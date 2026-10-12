module LegacyPath
  FIXED = {
    "/catalog" => "/",
    "/session/new" => "/entrar",
    "/registration/new" => "/criar-conta",
    "/progress" => "/pasta",
    "/wishlist" => "/pasta/desejos",
    "/collection/import" => "/pasta/importar",
    "/decks" => "/baralhos",
    "/decks/new" => "/baralhos/novo",
    "/decks/import" => "/baralhos/importar",
    "/app" => "/"
  }.freeze

  PATTERNS = [
    [ %r{\A/cards/([^/]+)\z}, "/cartas/%s" ],
    [ %r{\A/collection/import/([^/]+)\z}, "/pasta/importar/%s" ],
    [ %r{\A/decks/([^/]+)\z}, "/baralhos/%s" ],
    [ %r{\A/decks/([^/]+)/edit\z}, "/baralhos/%s/renomear" ],
    [ %r{\A/decks/([^/]+)/delete\z}, "/baralhos/%s/excluir" ],
    [ %r{\A/app/(.+)\z}m, "/%s" ]
  ].freeze

  def self.destination(path, query)
    target = translate(path)
    return if target.nil? || target.start_with?("//")

    query.empty? ? target : "#{target}?#{query}"
  end

  def self.translate(path)
    return FIXED[path] if FIXED.key?(path)

    PATTERNS.each do |pattern, template|
      match = pattern.match(path)
      return format(template, match[1]) if match
    end
    nil
  end
  private_class_method :translate
end
