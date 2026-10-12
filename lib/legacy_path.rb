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

  PROTOCOL_RELATIVE = %r{\A/[/\\]}
  CONTROL = /[[:cntrl:]]/

  def self.destination(path, query)
    path = utf8(path)
    query = utf8(query)
    return if path.nil? || query.nil?

    target = translate(path)
    return if target.nil? || unsafe?(target) || query.match?(CONTROL)

    query.empty? ? target : "#{target}?#{query}"
  end

  # Bytes que não formam UTF-8 válido fariam o `match?` e o `redirect_to`
  # levantar `ArgumentError` (500): o destino é recusado (404).
  def self.utf8(string)
    text = string.dup.force_encoding(Encoding::UTF_8)
    text if text.valid_encoding?
  end
  private_class_method :utf8

  def self.unsafe?(target)
    target.match?(PROTOCOL_RELATIVE) || target.match?(CONTROL)
  end
  private_class_method :unsafe?

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
