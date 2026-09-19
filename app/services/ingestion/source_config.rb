module Ingestion
  # Carrega e valida a configuração da fonte. A validação da revisão acontece
  # aqui, na carga, e não no download: o Req. 1.11 exige que atualizar o pin
  # seja um ato explícito de quem mantém o sistema. Uma referência móvel
  # aceita silenciosamente transformaria a CI semanal da fonte em uma
  # alteração não revisada do catálogo.
  class SourceConfig
    MOVING_REFERENCES = %w[main master head latest edge stable trunk default].freeze
    COMMIT_SHA = /\A[0-9a-f]{40}\z/
    # Tag de versão semântica, com pré-lançamento opcional
    # (`v1.2.0`, `1.2.0-rc.1`). Deliberadamente estreita: qualquer coisa que
    # pareça um nome de branch tem de cair fora, senão a checagem de
    # referência móvel vira uma lista negra furada.
    TAG = /\Av?\d+(\.\d+){1,2}(-(alpha|beta|rc)(\.\d+)?)?\z/

    class InvalidRevision < StandardError; end
    class MissingSetting < StandardError; end

    attr_reader :source, :repository, :path, :revision

    def self.load(path = Rails.root.join("config", "ingestion.yml"))
      new(**YAML.safe_load_file(path).symbolize_keys)
    end

    def initialize(source:, repository:, path:, revision:)
      @source = presence!(source, "source")
      @repository = presence!(repository, "repository")
      @path = presence!(path, "path")
      @revision = validate_revision!(presence!(revision, "revision"))
    end

    # A URL é derivada da revisão, nunca de um branch: é o que garante que a
    # importação busque exatamente a revisão configurada (Req. 1.9).
    def url
      "https://raw.githubusercontent.com/#{repository}/#{revision}/#{path}"
    end

    private

    def presence!(value, name)
      normalized = value.to_s.strip
      raise MissingSetting, "configuração da fonte sem `#{name}`" if normalized.empty?

      normalized
    end

    def validate_revision!(value)
      if MOVING_REFERENCES.include?(value.downcase)
        raise InvalidRevision,
              "revisão `#{value}` é uma referência móvel; fixe um commit ou tag imutável (Req. 1.9)"
      end

      unless value.match?(COMMIT_SHA) || value.match?(TAG)
        raise InvalidRevision,
              "revisão `#{value}` não é um commit de 40 caracteres nem uma tag de versão"
      end

      value
    end
  end
end
