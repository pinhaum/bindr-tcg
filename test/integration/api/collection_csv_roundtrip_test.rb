require "test_helper"
require "csv"
require "stringio"

# STRO-31: a ida e volta do CSV pela API. O arquivo sai de `GET /collection/export`
# (o link da pasta) e volta por `POST /api/collection/imports` + `confirm`, pelo
# mesmo cookie de sessão. Prova, por retrato inteiro de `collection_items`, que
# substituir (AD-006) fecha a volta, e que a confirmação de um usuário não toca
# a coleção do outro.
#
# O cenário discrimina de propósito: quantidades todas distintas (trocar a
# quantidade de uma variante pela de outra mudaria o retrato), acento, vírgula e
# aspas nos nomes (o escape é exercido nos dois sentidos), dois sets (a chave é o
# par `card_number` + `variant_code`) e uma variante possuída com zero, que o
# export não escreve.
class Api::CollectionCsvRoundtripTest < ActionDispatch::IntegrationTest
  PASSWORD = "thousand-sunny-16".freeze

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    @nami = User.create!(email: "nami-api-rt@example.com", password: PASSWORD)
    @zoro = User.create!(email: "zoro-api-rt@example.com", password: PASSWORD)

    @romance = CardSet.create!(code: "OPa31", name: "Romance Dawn", kind: "booster",
                               base_set_size: 6, total_set_size: 6)
    @paramount = CardSet.create!(code: "OPb31", name: "Paramount War", kind: "booster",
                                 base_set_size: 6, total_set_size: 6)

    @acento = variant(@romance, "A31", "r1", "Bell-mère")
    @virgula = variant(@romance, "A31", "r2", "Nami, a Navegadora")
    @aspas = variant(@paramount, "B31", "p1", "Sanji \"Perna Preta\"")
    @simples = variant(@paramount, "B31", "p2", "Roronoa Zoro")
    @zerada = variant(@romance, "A31", "r3", "Nefertari Vivi")
    @so_do_zoro = variant(@paramount, "B31", "p3", "Tony Tony Chopper")

    own(@nami, @acento, 2)
    own(@nami, @virgula, 3)
    own(@nami, @aspas, 5)
    own(@nami, @simples, 7)
    own(@nami, @zerada, 0)

    own(@zoro, @acento, 11)
    own(@zoro, @simples, 13)
    own(@zoro, @so_do_zoro, 17)
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery
  end

  def variant(card_set, prefixo, suffix, card_name)
    card = Card.create!(card_set: card_set, card_number: "#{prefixo}-#{suffix}",
                        name: card_name, card_type: "character", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: card_set, variant_code: suffix,
                        rarity: "C", art_kind: "base")
  end

  def own(user, card_variant, quantity)
    CollectionItem.create!(user: user, card_variant: card_variant, quantity: quantity)
  end

  def csrf
    get "/api/session"
    response.parsed_body.dig("data", "csrf_token")
  end

  def sign_in(user)
    post "/api/session", params: { email: user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => csrf }
    assert_response :ok
  end

  def sign_out
    delete "/api/session", headers: { "X-CSRF-Token" => csrf }
    assert_response :ok
  end

  # `dup` evita que a codificação do corpo capturado mude quando o próprio
  # upload o lê (artefato do harness, não do produto).
  def exportar
    get "/collection/export"
    assert_response :ok
    response.body.dup
  end

  def previsualizar(conteudo)
    file = Rack::Test::UploadedFile.new(StringIO.new(conteudo), "text/csv", original_filename: "colecao.csv")
    post "/api/collection/imports", params: { file: file }, headers: { "X-CSRF-Token" => csrf }
    assert_response :created
    response.parsed_body.dig("data", "token")
  end

  def confirmar(token)
    post "/api/collection/imports/#{token}/confirm", headers: { "X-CSRF-Token" => csrf }
    assert_response :ok
    response.parsed_body["data"]
  end

  def ciclo(conteudo)
    confirmar(previsualizar(conteudo))
  end

  # Todo registro do usuário, inclusive os de quantidade zero: é o que faz o
  # teste perceber um registro apagado ou ressuscitado.
  def retrato_de(user)
    CollectionItem.for_user(user).pluck(:card_variant_id, :quantity).to_h
  end

  def linhas_do_csv(conteudo)
    CSV.parse(conteudo, headers: true, col_sep: CollectionCsv::Format::DELIMITER)
  end

  def alterar_quantidade(conteudo, card_number, nova)
    tabela = linhas_do_csv(conteudo)
    linha = tabela.find { |l| l["card_number"] == card_number }
    assert_not_nil linha, "pré-condição: #{card_number} precisa estar no arquivo"
    linha["quantity"] = nova.to_s
    tabela.to_csv(col_sep: CollectionCsv::Format::DELIMITER)
  end

  test "export, import e confirm deixam collection_items idêntica, com nomes difíceis e dois sets" do
    sign_in(@nami)
    arquivo = exportar
    nomes = linhas_do_csv(arquivo).map { |l| l["card_name"] }
    numeros = linhas_do_csv(arquivo).map { |l| l["card_number"] }

    assert_includes nomes, "Bell-mère"
    assert_includes nomes, "Nami, a Navegadora"
    assert_includes nomes, "Sanji \"Perna Preta\""
    assert numeros.any? { |n| n.start_with?("A31-") }
    assert numeros.any? { |n| n.start_with?("B31-") }

    antes = retrato_de(@nami)
    resumo = ciclo(arquivo)

    assert_equal antes, retrato_de(@nami)
    assert_equal 0, resumo["created"]
    assert_equal 0, resumo["updated"]
    assert_equal 4, resumo["unchanged"]
    assert_equal [], resumo["rejected"]
    assert_equal [], resumo["failures"]
  end

  test "o segundo export é igual byte a byte ao primeiro" do
    sign_in(@nami)
    primeiro = exportar

    ciclo(primeiro)

    assert_equal primeiro.b, exportar.b
  end

  test "três ciclos seguidos mantêm a coleção e o arquivo estáveis" do
    sign_in(@nami)
    antes = retrato_de(@nami)
    arquivo = exportar

    3.times do |n|
      ciclo(exportar)

      assert_equal antes, retrato_de(@nami), "a coleção mudou no ciclo #{n + 1}"
      assert_equal arquivo.b, exportar.b, "o arquivo mudou no ciclo #{n + 1}"
    end
  end

  test "quantidade zero não vai para o arquivo e o registro zerado fica intacto" do
    sign_in(@nami)
    arquivo = exportar
    par = [ @zerada.card.card_number, @zerada.variant_code ]

    assert_not_includes linhas_do_csv(arquivo).map { |l| [ l["card_number"], l["variant_code"] ] }, par

    registro = CollectionItem.for_user(@nami).find_by!(card_variant: @zerada)
    versao = registro.updated_at
    ciclo(arquivo)

    registro.reload
    assert_equal 0, registro.quantity
    assert_equal versao, registro.updated_at, "a volta não pode reescrever o registro zerado"
  end

  test "linha com quantidade zero zera quem existia e cria só registro zerado, sem posse" do
    sign_in(@nami)
    arquivo = alterar_quantidade(exportar, @simples.card.card_number, 0)
    inexistente = variant(@paramount, "B31", "p4", "Franky")
    arquivo = arquivo.chomp + "\n#{inexistente.card.card_number},#{inexistente.variant_code},Franky,0\n"

    resumo = ciclo(arquivo)

    assert_equal 0, CollectionItem.for_user(@nami).find_by!(card_variant: @simples).quantity
    criado = CollectionItem.for_user(@nami).find_by(card_variant: inexistente)
    assert_not_nil criado, "a linha zero sobre variante sem registro cria o registro zerado (:cria, como no HTML)"
    assert_equal 0, criado.quantity
    assert_not_includes CollectionItem.for_user(@nami).owned.pluck(:card_variant_id), inexistente.id
    assert_not_includes linhas_do_csv(exportar).map { |l| [ l["card_number"], l["variant_code"] ] },
                        [ inexistente.card.card_number, inexistente.variant_code ],
                        "o registro zerado não aparece no export"
    assert_equal 1, resumo["created"]
    assert_equal 1, resumo["removed"]
  end

  test "dois usuários que importam o mesmo arquivo têm coleções independentes" do
    sign_in(@nami)
    arquivo = exportar
    da_nami = retrato_de(@nami)
    ciclo(arquivo)
    sign_out

    assert_equal da_nami, retrato_de(@nami)

    sign_in(@zoro)
    resumo = ciclo(arquivo)

    assert_equal da_nami, retrato_de(@nami), "a confirmação do Zoro não pode tocar na coleção da Nami"
    assert_operator resumo["created"], :>=, 1

    do_zoro = retrato_de(@zoro)
    assert_equal 2, do_zoro[@acento.id]
    assert_equal 7, do_zoro[@simples.id]
    assert_equal 3, do_zoro[@virgula.id], "o que o arquivo cria nasce na coleção de quem confirmou"
    assert_equal 17, do_zoro[@so_do_zoro.id], "o que não está no arquivo não é tocado"
  end

  test "a confirmação com escrita de A não muda nenhuma linha de B" do
    sign_in(@zoro)
    do_zoro = CollectionItem.for_user(@zoro).order(:id).pluck(:id, :card_variant_id, :quantity, :updated_at)
    sign_out

    sign_in(@nami)
    editado = alterar_quantidade(exportar, @acento.card.card_number, 9)
    editado = alterar_quantidade(editado, @simples.card.card_number, 0)
    resumo = ciclo(editado)

    assert_equal 2, resumo["updated"]
    assert_equal 1, resumo["removed"]
    assert_equal 9, CollectionItem.for_user(@nami).find_by!(card_variant: @acento).quantity
    assert_equal 0, CollectionItem.for_user(@nami).find_by!(card_variant: @simples).quantity
    assert_equal do_zoro, CollectionItem.for_user(@zoro).order(:id).pluck(:id, :card_variant_id, :quantity, :updated_at)
  end
end
