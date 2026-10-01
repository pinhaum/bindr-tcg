require "test_helper"

module Ingestion
  class FetchTest < ActiveSupport::TestCase
    REVISION = "5669eab51096629faf90dbf0dc903128cff80a98".freeze
    PAYLOAD = '{"meta":{},"data":[]}'.freeze

    # O `SourceConfig` passou a descrever a apitcg (T8 da `fonte-apitcg`);
    # este Fetch da optcgjson só lê `source`, `revision` e `url` e sai na T14.
    LegacyConfig = Struct.new(:source, :revision, :url)

    setup do
      @storage = Pathname(Dir.mktmpdir("ingestion-test"))
      @config = LegacyConfig.new("optcgjson", REVISION,
                                 "https://raw.githubusercontent.com/hugoprudente/optcgjson/#{REVISION}/output/AllSets.json")
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
