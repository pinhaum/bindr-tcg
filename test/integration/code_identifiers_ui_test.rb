require "test_helper"
require_relative "../design/support/stylesheet"

# INT-08 (Req. 12.7): em toda tela que renderiza `card_number` ou
# `variant_code`, o texto do identificador está dentro de um elemento cuja
# classe a folha resolve para o estilo `code` (§11.4).
class CodeIdentifiersUiTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "code@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "OPcd", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "OP01-cd1", name: "Nami",
                         card_type: "character", colors: [ "Blue" ], cost: 1, power: 2000)
    @variant = CardVariant.create!(card: @card, card_set: @set, variant_code: "OP01-cd1_p1",
                                   rarity: "C", art_kind: "base")
    @rules = Stylesheet.rules
  end

  def sign_in = post(session_path, params: { email: @user.email, password: PASSWORD })

  # Algum elemento de `selector` tem exatamente `text`, e ele está em `code`.
  def assert_code(selector, text)
    elements = css_select(selector).select { |element| element.text.squish == text }

    assert_not_empty elements, "nenhum #{selector} com o texto #{text.inspect}"
    elements.each do |element|
      classes = element["class"].to_s.split
      assert classes.any? { |klass| Stylesheet.code_styled?(klass, @rules) },
             "#{selector} com #{text.inspect} não está em estilo code (classes: #{classes.inspect})"
    end
  end

  def upload(content)
    Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: "colecao.csv")
  end

  def csv
    [ CollectionCsv::Format.header_row.join(","),
      "#{@card.card_number},#{@variant.variant_code},#{@card.name},3" ].join("\n") + "\n"
  end

  test "grade" do
    get catalog_path

    assert_code ".card-tile__number", @card.card_number
    assert_code ".card-tile__placeholder-number", @card.card_number
  end

  test "detalhe" do
    get card_path(@card.card_number)

    assert_code ".card-detail__number", @card.card_number
    assert_code ".variant__code", @variant.variant_code
    assert_code ".variant__placeholder code", @variant.variant_code
  end

  test "posse" do
    sign_in
    get card_path(@card.card_number)

    assert_code ".ownership__variant code", @variant.variant_code
  end

  test "wishlist" do
    sign_in
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 2)

    get wishlist_items_path

    assert_code ".wishlist-item__link code", @variant.variant_code
    assert_select ".wishlist-item__link", text: "#{@card.name} #{@variant.variant_code}"
  end

  test "pré-visualização do import" do
    sign_in
    post collection_imports_path, params: { arquivo: upload(csv) }
    follow_redirect! if response.redirect?

    assert_code ".import-preview__number", @card.card_number
    assert_code ".import-preview__variant", @variant.variant_code
  end

  test "resumo do import, inclusive a linha que falhou ao gravar" do
    sign_in
    post collection_imports_path, params: { arquivo: upload(csv) }
    preview = CollectionImport.order(:id).last

    original = CollectionCsv::Commit.instance_method(:upsert)
    CollectionCsv::Commit.define_method(:upsert) { |_linha| raise PG::Error, "conexão perdida" }
    begin
      post confirm_collection_import_path(preview.token)
    ensure
      CollectionCsv::Commit.define_method(:upsert, original)
    end
    follow_redirect! if response.redirect?

    assert_code ".import-summary__falhada code", @card.card_number
    assert_code ".import-summary__falhada code", @variant.variant_code
  end

  test "resumo do import, linha rejeitada" do
    sign_in
    rejeitada = csv.sub(/,3\n\z/, ",nao-e-numero\n")
    post collection_imports_path, params: { arquivo: upload(rejeitada) }
    post confirm_collection_import_path(CollectionImport.order(:id).last.token)
    follow_redirect! if response.redirect?

    assert_code ".import-summary__number-card", @card.card_number
    assert_code ".import-summary__variant", @variant.variant_code
  end
end
