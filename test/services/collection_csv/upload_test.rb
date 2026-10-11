require "test_helper"
require "stringio"

module CollectionCsv
  # Envio do CSV da coleção para a API (SPOR-36, SPOR-37). Mesmas regras do
  # `CollectionImportsController#create`, num objeto testável fora do request.
  class UploadTest < ActiveSupport::TestCase
    Arquivo = Struct.new(:conteudo, :original_filename) do
      def read(limite = nil)
        bytes = conteudo.b
        limite ? bytes.byteslice(0, limite) : bytes
      end
    end

    class ArquivoIntocavel
      def read = raise("não deveria ser lido")
      def original_filename = "x.csv"
    end

    def create_user(email: "upload@exemplo.test")
      User.create!(email: email, password: "senha-correta")
    end

    def create_variant(suffix: "001")
      set = CardSet.create!(code: "OP#{suffix}", name: "Romance Dawn", kind: "booster")
      card = Card.create!(card_set: set, card_number: "OP01-#{suffix}", name: "Roronoa Zoro",
        card_type: "leader", colors: [ "Red" ])
      CardVariant.create!(card: card, card_set: set, variant_code: "OP01-#{suffix}",
        rarity: "L", art_kind: "base")
    end

    def csv_para(variant, quantidade = 2)
      "card_number,variant_code,card_name,quantity\n" \
        "#{variant.card.card_number},#{variant.variant_code},#{variant.card.name},#{quantidade}\n"
    end

    def enviar(user, conteudo, nome: "colecao.csv", length: conteudo.bytesize)
      Upload.new(user, Arquivo.new(conteudo, nome), length).call
    end

    test "arquivo aceito grava a pré-visualização do usuário com as linhas do Resolver" do
      user = create_user
      variant = create_variant
      conteudo = csv_para(variant)
      esperadas = Resolver.new(user, Parser.new(conteudo.dup.force_encoding(Encoding::UTF_8)).call.linhas).call.linhas

      resultado = nil
      assert_no_changes -> { CollectionItem.pluck(:id, :card_variant_id, :quantity) } do
        assert_difference -> { CollectionImport.for_user(user).count }, 1 do
          resultado = enviar(user, conteudo)
        end
      end

      assert_predicate resultado, :aceito?
      assert_nil resultado.error
      assert_equal user, resultado.preview.user
      assert_equal esperadas, resultado.preview.reload.linhas_resolvidas
    end

    test "content_length acima de 12 MB recusa sem ler o arquivo" do
      user = create_user

      assert_no_difference -> { CollectionImport.count } do
        resultado = Upload.new(user, ArquivoIntocavel.new, Upload::MAX_BODY_BYTES + 1).call

        assert_not_predicate resultado, :aceito?
        assert_nil resultado.preview
        assert_equal Upload::BODY_TOO_LARGE_MESSAGE, resultado.error
        assert_includes resultado.error, "8 MB"
      end
    end

    test "content_length ausente (0) não burla o teto: o corpo lido acima de 8 MB é recusado" do
      user = create_user
      grande = "card_number,variant_code,card_name,quantity\n" + ("a" * Parser::MAX_BYTES)

      assert_no_difference -> { CollectionImport.count } do
        resultado = enviar(user, grande, length: 0)

        assert_equal Upload::BODY_TOO_LARGE_MESSAGE, resultado.error
        assert_nil resultado.preview
      end
    end

    test "8 MB de linhas curtas são recusados por contagem sem chamar o Parser" do
      user = create_user
      curtas = "card_number,variant_code,card_name,quantity\n" + ("1\n" * ((Parser::MAX_BYTES - 100) / 2))

      chamadas = 0
      original = Parser.method(:new)
      Parser.define_singleton_method(:new) { |*args| (chamadas += 1) && original.call(*args) }

      begin
        assert_no_difference -> { CollectionImport.count } do
          inicio = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          resultado = enviar(user, curtas)

          assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - inicio, :<, 2
          assert_not_predicate resultado, :aceito?
          assert_includes resultado.error, "linhas de dados e o limite é de 10.000 linhas"
        end
      ensure
        Parser.singleton_class.send(:remove_method, :new)
      end

      assert_equal 0, chamadas
    end

    test "arquivo ausente para nil, string e objeto sem read" do
      user = create_user

      assert_no_difference -> { CollectionImport.count } do
        [ nil, "texto.csv", Object.new ].each do |file|
          resultado = Upload.new(user, file, 100).call

          assert_equal Upload::MISSING_FILE_MESSAGE, resultado.error
          assert_nil resultado.preview
        end
      end
    end

    test "recusas do Parser viram a frase dele e não gravam nada" do
      user = create_user
      variant = create_variant
      linhas_demais = "card_number,variant_code,card_name,quantity\n" + ("X,Y,Z,1\n" * 10_001)
      casos = {
        "ponto e vírgula" => "card_number;variant_code;card_name;quantity\n",
        "vazio" => "",
        "latin-1" => "card_number,variant_code,card_name,quantity\n#{variant.card.card_number},caf\xE9,L,1\n",
        "linhas demais" => linhas_demais
      }

      assert_no_difference -> { CollectionImport.count } do
        casos.each do |nome, conteudo|
          resultado = enviar(user, conteudo.b)

          assert_not_predicate resultado, :aceito?, nome
          assert_nil resultado.preview, nome
          assert_predicate resultado.error, :present?, nome
          assert_equal Parser.new(conteudo.dup.force_encoding(Encoding::UTF_8)).call.erro, resultado.error, nome
        end
      end
    end

    test "o nome é saneado como no controller HTML" do
      user = create_user
      conteudo = csv_para(create_variant)

      {
        "..\\x/../Minha Coleção!.csv" => "Minha_Coleção_.csv",
        "!!!" => "___",
        "" => "colecao.csv",
        "." => "colecao.csv",
        ("a" * 200) => "a" * 120
      }.each do |bruto, esperado|
        nome = enviar(user, conteudo, nome: bruto).preview.filename

        assert_equal esperado, nome, bruto.inspect
      end
    end

    test "as constantes são as do controller HTML" do
      assert_equal CollectionImportsController::MAX_CORPO_BYTES, Upload::MAX_BODY_BYTES
      assert_equal CollectionImportsController::MENSAGEM_SEM_ARQUIVO, Upload::MISSING_FILE_MESSAGE
      assert_equal CollectionImportsController::MENSAGEM_CORPO_GRANDE, Upload::BODY_TOO_LARGE_MESSAGE
    end

    test "usuário que não é User levanta ArgumentError" do
      conteudo = csv_para(create_variant)

      assert_raises(ArgumentError) { enviar("1", conteudo) }
    end
  end
end
