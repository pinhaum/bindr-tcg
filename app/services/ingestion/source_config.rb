module Ingestion
  # Carrega a configuração da apitcg (AD-019) e a chave da API.
  #
  # A chave é lida do ambiente na carga, mas só é exigida em `#api_key`: o
  # reprocessamento de um snapshot em disco não toca a rede e não precisa dela.
  # Quem vai fazer requisição chama `#api_key` antes da primeira, e é isso que
  # faz a falta da chave abortar antes da rede e do banco (SRC-02).
  #
  # O valor da chave nunca sai deste objeto por `inspect`, `to_s` ou mensagem
  # de erro (SRC-05): um `p config` num console ou um erro com o objeto
  # interpolado não pode vazar o segredo para log.
  class SourceConfig
    API_KEY_VARIABLE = "APITCG_API_KEY".freeze

    class MissingSetting < StandardError; end
    class MissingApiKey < MissingSetting; end

    attr_reader :source, :base_url, :page_size, :timeout, :attempts

    def self.load(path = Rails.root.join("config", "ingestion.yml"), env: ENV)
      settings = YAML.safe_load_file(path).symbolize_keys
      new(**settings, api_key: env[API_KEY_VARIABLE])
    end

    def initialize(source:, base_url:, page_size:, timeout:, attempts:, api_key: nil)
      @source = presence!(source, "source")
      @base_url = presence!(base_url, "base_url")
      @page_size = positive_integer!(page_size, "page_size")
      @timeout = positive_integer!(timeout, "timeout")
      @attempts = positive_integer!(attempts, "attempts")
      @api_key = api_key.to_s.strip
    end

    def api_key
      raise MissingApiKey, "#{API_KEY_VARIABLE} não configurada" if @api_key.empty?

      @api_key
    end

    def inspect
      "#<#{self.class.name} source=#{source} base_url=#{base_url} page_size=#{page_size} " \
        "timeout=#{timeout} attempts=#{attempts} api_key=#{@api_key.empty? ? '(ausente)' : '[FILTRADA]'}>"
    end
    alias_method :to_s, :inspect

    # O `as_json` do ActiveSupport serializa as variáveis de instância, e com
    # elas a chave: um `config.to_json` num `error_log` a vazaria.
    def as_json(*)
      { "source" => source, "base_url" => base_url, "page_size" => page_size,
        "timeout" => timeout, "attempts" => attempts }
    end

    private

    def presence!(value, name)
      normalized = value.to_s.strip
      raise MissingSetting, "configuração da fonte sem `#{name}`" if normalized.empty?

      normalized
    end

    def positive_integer!(value, name)
      number = Integer(presence!(value, name), exception: false)
      raise MissingSetting, "configuração da fonte com `#{name}` inválido" unless number&.positive?

      number
    end
  end
end
