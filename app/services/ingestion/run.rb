module Ingestion
  # Liga os três estágios (design.md §5.1). Existe para que a importação seja
  # executável sob demanda (Req. 1.1) sem que ninguém precise conhecer a ordem
  # dos estágios.
  #
  # `reuse_payload` reprocessa o payload já salvo em disco, sem rede — é o que
  # torna o catálogo reconstruível a partir da revisão fixada.
  class Run
    def self.call(reuse_payload: false)
      config = SourceConfig.load
      fetch = Fetch.new(config: config)

      payload_path =
        if reuse_payload && (cached = fetch.cached_payload_path)
          cached
        else
          fetch.call.path
        end

      Upsert.new(Normalize.call(payload_path.read), source: config.source, revision: config.revision).call
    end
  end
end
