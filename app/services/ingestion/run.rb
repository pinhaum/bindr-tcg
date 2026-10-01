module Ingestion
  # Liga os três estágios (design.md §5.1). Existe para que a importação seja
  # executável sob demanda (Req. 1.1) sem que ninguém precise conhecer a ordem
  # dos estágios.
  #
  # Com `snapshot:` (caminho de um arquivo), reprocessa o que já está em disco:
  # não constrói o Fetch, não lê a chave e não abre rede (SRC-07, Req. 11.5).
  # Sem ele, busca pela apitcg e processa o snapshot gravado.
  class Run
    class SnapshotUnreadable < StandardError; end

    FETCH_INCOMPLETE_REVISION = "(busca não concluída)".freeze

    # `config:` e `fetch:` existem para teste; o padrão é a configuração real
    # e o Fetch da T9.
    def self.call(snapshot: nil, config: SourceConfig.load, fetch: nil)
      new(snapshot: snapshot, config: config, fetch: fetch).call
    end

    def initialize(snapshot:, config:, fetch:)
      @snapshot = snapshot
      @config = config
      @fetch = fetch
    end

    def call
      return process(@snapshot) if @snapshot

      # Antes de tudo: sem chave não há `ImportRun`, banco tocado nem rede (SRC-02).
      @config.api_key
      fetched = (@fetch || Apitcg::Fetch.new(config: @config)).call
      process(fetched.path)
    rescue Apitcg::Fetch::SourceUnavailable, Apitcg::Fetch::SnapshotExists => e
      record_fetch_failure(e)
    end

    private

    # O arquivo é lido e validado antes de o `Upsert` criar o `ImportRun`: um
    # caminho errado não deixa run `running` para trás.
    def process(path)
      content = File.read(path)
      result = Apitcg::Normalize.call(content)
      Upsert.new(result, source: @config.source, snapshot: path).call
    rescue SystemCallError, IOError => e
      raise SnapshotUnreadable, "não foi possível ler o snapshot #{path}: #{e.message}"
    rescue JSON::ParserError
      raise SnapshotUnreadable, "o snapshot #{path} não é um JSON válido"
    end

    # A busca falhou antes de qualquer escrita no catálogo (SRC-04, SRC-32).
    # Devolve o run em vez de propagar: o chamador decide o código de saída
    # pelo status. `failed_count` fica em 0 porque nenhum registro chegou a ser
    # processado; o erro está no `error_log`. A chave nunca entra no log (SRC-05).
    def record_fetch_failure(error)
      now = Time.current
      ImportRun.create!(
        source: @config.source, source_revision: FETCH_INCOMPLETE_REVISION, status: "failed",
        started_at: now, finished_at: now, failed_count: 0,
        error_log: [ { "identifier" => "fetch", "error" => error.class.name,
                       "message" => error.message.gsub(@config.api_key, "[FILTRADA]") } ]
      )
    end
  end
end
