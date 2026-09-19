require "test_helper"

module Ingestion
  # Req. 1.9 e 1.11 — a revisão é validada na carga da configuração, não no
  # download. Se a rejeição só acontecesse na hora de buscar, uma configuração
  # com `main` já estaria em produção esperando a próxima execução.
  class SourceConfigTest < ActiveSupport::TestCase
    def config(revision:)
      SourceConfig.new(source: "optcgjson", repository: "hugoprudente/optcgjson",
                       path: "output/AllSets.json", revision: revision)
    end

    # Done when: revisão fixada (commit/tag), nunca `main`.
    test "referência móvel é rejeitada na carga da configuração" do
      %w[main master HEAD latest Main].each do |movel|
        erro = assert_raises(SourceConfig::InvalidRevision, "aceitou `#{movel}`") do
          config(revision: movel)
        end
        assert_match(/referência móvel/, erro.message)
      end
    end

    test "revisão que não é commit nem tag é rejeitada" do
      assert_raises(SourceConfig::InvalidRevision) { config(revision: "v1-branch-do-fulano") }
      assert_raises(SourceConfig::InvalidRevision) { config(revision: "5669eab") }
    end

    test "commit de 40 caracteres é aceito" do
      sha = "5669eab51096629faf90dbf0dc903128cff80a98"
      assert_equal sha, config(revision: sha).revision
    end

    test "tag de versão é aceita" do
      assert_equal "v1.2.0", config(revision: "v1.2.0").revision
    end

    # Req. 1.9 — buscar exatamente a revisão configurada. A URL derivar da
    # revisão é o que impede que a CI semanal da fonte mude o que é baixado.
    test "a URL aponta para a revisão fixada, não para um branch" do
      sha = "5669eab51096629faf90dbf0dc903128cff80a98"
      url = config(revision: sha).url

      assert_equal "https://raw.githubusercontent.com/hugoprudente/optcgjson/#{sha}/output/AllSets.json", url
      refute_match(/\/main\/|\/HEAD\//, url)
    end

    test "a configuração versionada do projeto fixa uma revisão imutável" do
      carregada = SourceConfig.load

      assert_match(SourceConfig::COMMIT_SHA, carregada.revision)
      assert_equal "optcgjson", carregada.source
    end

    test "configuração sem revisão falha explicitamente" do
      assert_raises(SourceConfig::MissingSetting) do
        SourceConfig.new(source: "optcgjson", repository: "x/y", path: "a.json", revision: "")
      end
    end
  end

  class FetchTest < ActiveSupport::TestCase
    REVISION = "5669eab51096629faf90dbf0dc903128cff80a98".freeze
    PAYLOAD = '{"meta":{},"data":[]}'.freeze

    setup do
      @storage = Pathname(Dir.mktmpdir("ingestion-test"))
      @config = SourceConfig.new(source: "optcgjson", repository: "hugoprudente/optcgjson",
                                 path: "output/AllSets.json", revision: REVISION)
    end

    teardown do
      FileUtils.remove_entry(@storage) if @storage.exist?
    end

    def fetch(http:)
      Fetch.new(config: @config, storage_dir: @storage, http: http)
    end

    # Dublês de cliente HTTP. O teste não toca a rede (Req. 11.5) e exercita o
    # comportamento do estágio, não a biblioteca HTTP.
    ResponderCom = Struct.new(:status, :body) do
      def get(_url) = [ status, body ]
    end

    FalhaCom = Struct.new(:erro) do
      def get(_url) = raise(erro)
    end

    def fetch_ok(body = PAYLOAD) = fetch(http: ResponderCom.new(200, body))

    # Done when: payload bruto salvo em disco antes de qualquer processamento.
    test "grava o payload bruto em disco, idêntico ao recebido" do
      resultado = fetch_ok.call

      assert_predicate resultado.path, :exist?
      assert_equal PAYLOAD, resultado.path.read
      assert_equal PAYLOAD.bytesize, resultado.byte_size
    end

    # Req. 1.10 — a revisão precisa acompanhar o payload para o resumo da
    # execução poder registrá-la.
    test "o arquivo gravado identifica a revisão de origem" do
      resultado = fetch_ok.call

      assert_includes resultado.path.basename.to_s, REVISION
      assert_equal REVISION, resultado.revision
    end

    # Done when: aborta sem escrever no banco se a fonte estiver indisponível.
    # Req. 1.8 — falha explícita, nunca catálogo parcialmente sobrescrito.
    test "erro de rede aborta sem gravar payload" do
      erro = assert_raises(Fetch::SourceUnavailable) do
        fetch(http: FalhaCom.new(SocketError.new("getaddrinfo falhou"))).call
      end

      assert_match(/indisponível/, erro.message)
      assert_empty @storage.children, "não pode sobrar payload de uma execução que falhou"
    end

    test "timeout de leitura aborta sem gravar payload" do
      assert_raises(Fetch::SourceUnavailable) do
        fetch(http: FalhaCom.new(Net::ReadTimeout.new)).call
      end

      assert_empty @storage.children
    end

    test "resposta HTTP de erro aborta e não grava payload" do
      erro = assert_raises(Fetch::SourceUnavailable) do
        fetch(http: ResponderCom.new(404, "")).call
      end

      assert_match(/404/, erro.message)
      assert_empty @storage.children
    end

    # Req. 11.5 e design.md §5.1 — reprocessar sem refazer a chamada.
    test "o payload salvo fica disponível para reprocessamento sem rede" do
      assert_nil fetch_ok.cached_payload_path

      fetch_ok.call

      assert_equal PAYLOAD, fetch_ok.cached_payload_path.read
    end

    test "não sobra arquivo parcial após uma execução bem-sucedida" do
      fetch_ok.call

      assert_empty @storage.children.select { |f| f.to_s.end_with?(".part") }
    end
  end
end
