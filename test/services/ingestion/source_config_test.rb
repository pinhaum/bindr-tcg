require "test_helper"

module Ingestion
  # SRC-02 e SRC-05 — a chave vem do ambiente, a falta dela é um erro explícito
  # e o valor nunca sai do objeto por representação textual.
  class SourceConfigTest < ActiveSupport::TestCase
    CHAVE = "chave-de-teste".freeze

    def config(env: { "APITCG_API_KEY" => CHAVE })
      SourceConfig.load(env: env)
    end

    test "a configuração versionada do projeto descreve a apitcg" do
      carregada = config

      assert_equal "apitcg", carregada.source
      assert_match %r{\Ahttps://}, carregada.base_url
      assert_equal 100, carregada.page_size
      assert_equal 30, carregada.timeout
      assert_equal 3, carregada.attempts
    end

    test "a chave é lida de APITCG_API_KEY" do
      assert_equal CHAVE, config.api_key
    end

    test "chave ausente levanta o erro de SRC-02" do
      erro = assert_raises(SourceConfig::MissingApiKey) { config(env: {}).api_key }

      assert_equal "APITCG_API_KEY não configurada", erro.message
    end

    test "chave vazia ou só com espaços levanta o mesmo erro" do
      [ "", "   " ].each do |vazia|
        erro = assert_raises(SourceConfig::MissingApiKey, "aceitou #{vazia.inspect}") do
          config(env: { "APITCG_API_KEY" => vazia }).api_key
        end
        assert_equal "APITCG_API_KEY não configurada", erro.message
      end
    end

    # Sem a chave a configuração ainda carrega: reprocessar um snapshot em
    # disco não faz requisição e não pode exigir a chave (SRC-07).
    test "a falta da chave só é cobrada quando ela é pedida" do
      assert_equal "apitcg", config(env: {}).source
    end

    test "o erro de chave ausente é um MissingSetting" do
      assert_operator SourceConfig::MissingApiKey, :<, SourceConfig::MissingSetting
    end

    test "inspect e to_s não contêm o valor da chave" do
      carregada = config

      [ carregada.inspect, carregada.to_s, "#{carregada}" ].each do |texto|
        refute_includes texto, CHAVE
      end
      assert_includes carregada.inspect, "apitcg"
    end

    test "a serialização em JSON não contém o valor da chave" do
      json = config.to_json

      refute_includes json, CHAVE
      assert_includes json, "apitcg"
    end

    test "nenhuma mensagem de erro da configuração contém a chave" do
      mensagens = []
      mensagens << assert_raises(SourceConfig::MissingSetting) do
        SourceConfig.new(source: "apitcg", base_url: "", page_size: 100, timeout: 30, attempts: 3, api_key: CHAVE)
      end.message
      mensagens << assert_raises(SourceConfig::MissingSetting) do
        SourceConfig.new(source: "apitcg", base_url: "https://x", page_size: 0, timeout: 30, attempts: 3, api_key: CHAVE)
      end.message

      mensagens.each { |mensagem| refute_includes mensagem, CHAVE }
    end

    test "configuração sem base_url falha explicitamente" do
      erro = assert_raises(SourceConfig::MissingSetting) do
        SourceConfig.new(source: "apitcg", base_url: " ", page_size: 100, timeout: 30, attempts: 3)
      end

      assert_match(/base_url/, erro.message)
    end

    test "base_url sem https é recusada, porque a chave vai em todo header" do
      erro = assert_raises(SourceConfig::MissingSetting) do
        SourceConfig.new(source: "apitcg", base_url: "http://apitcg.com/api/one-piece", page_size: 100,
                         timeout: 30, attempts: 3)
      end

      assert_match(/https/, erro.message)
    end

    test "limite que não é inteiro positivo é recusado" do
      [ 0, -1, "trinta", nil ].each do |invalido|
        assert_raises(SourceConfig::MissingSetting, "aceitou timeout #{invalido.inspect}") do
          SourceConfig.new(source: "apitcg", base_url: "https://x", page_size: 100, timeout: invalido, attempts: 3)
        end
      end
    end
  end
end
