require "test_helper"

# T1 — `params[:order]` na página de progresso, com sessão exigida
# (CNF-27, CNF-28, CNF-38).
#
# O recorte é HTTP: a agregação e o desempate já estão provados por unidade em
# `set_progress_query_test.rb`. Aqui prova-se o que só a resposta pode provar —
# que `?order=code` e `?order=recent` chegam ao `ProgressController` e mudam a
# ordem em que os `<li class="progress-set">` aparecem no HTML, que um valor
# desconhecido não derruba a página, e que a atividade de um segundo usuário
# não vaza para a ordem do primeiro através da mesma rota.
#
# T10 acrescenta os chips "Recentes" / "Por código" (CNF-29) junto do `<h2>`.
# Os testes de chip ficam neste arquivo, e não em `progress_ui_test.rb`, porque
# a cobertura de ordem já mora aqui — mesma fixture, mesmo par de sets.
class ProgressOrderTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "nami-cnf27@example.com", password: PASSWORD)
    @outro = User.create!(email: "usopp-cnf27@example.com", password: PASSWORD)

    @set_recente = CardSet.create!(code: "OPo2", name: "Recente", kind: "booster",
                                   base_set_size: 1, total_set_size: 1)
    @set_antigo = CardSet.create!(code: "OPo1", name: "Antigo", kind: "booster",
                                  base_set_size: 1, total_set_size: 1)
    @set_sem_posse = CardSet.create!(code: "OPo0", name: "Sem posse", kind: "booster",
                                     base_set_size: 1, total_set_size: 1)

    v_antigo = create_variant(@set_antigo, "o1")
    v_recente = create_variant(@set_recente, "o2")
    create_variant(@set_sem_posse, "o3")

    travel_to 2.days.ago do
      CollectionItem.create!(user: @user, card_variant: v_antigo, quantity: 1)
    end
    travel_to 1.day.ago do
      CollectionItem.create!(user: @user, card_variant: v_recente, quantity: 1)
    end
  end

  def create_variant(set, suffix)
    card = Card.create!(card_set: set, card_number: "OP01-#{suffix}", name: "Carta #{suffix}",
                        card_type: "character", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: set, variant_code: suffix,
                        rarity: "C", art_kind: "base")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  def posicoes_dos_sets
    css_select("li.progress-set").map { |node| node["id"].delete_prefix("progress_set_") }
                                  .each_with_index.to_h
  end

  test "sem parâmetro de ordem, os sets aparecem por atividade mais recente primeiro" do
    sign_in(@user)
    get progress_path

    assert_response :success
    posicao = posicoes_dos_sets

    assert_operator posicao[@set_recente.code], :<, posicao[@set_antigo.code]
    assert_operator posicao[@set_antigo.code], :<, posicao[@set_sem_posse.code]
  end

  test "?order=recent devolve a mesma ordem do padrão" do
    sign_in(@user)
    get progress_path(order: "recent")

    assert_response :success
    posicao = posicoes_dos_sets

    assert_operator posicao[@set_recente.code], :<, posicao[@set_antigo.code]
  end

  test "?order=code ordena os sets com posse pelo código e os sem posse no fim" do
    sign_in(@user)
    get progress_path(order: "code")

    assert_response :success
    posicao = posicoes_dos_sets

    assert_operator posicao[@set_antigo.code], :<, posicao[@set_recente.code],
                    "OPo1 vem antes de OPo2 por código, mesmo tendo posse mais antiga"
    assert_operator posicao[@set_recente.code], :<, posicao[@set_sem_posse.code],
                    "OPo0 tem o menor código, mas não tem posse: fica no fim (CNF-27)"
  end

  test "?order=xyz (desconhecido) responde 200 e cai na ordem recent" do
    sign_in(@user)
    get progress_path(order: "xyz")

    assert_response :success
    posicao = posicoes_dos_sets

    assert_operator posicao[@set_recente.code], :<, posicao[@set_antigo.code]
  end

  test "?order= vazio responde 200 e cai na ordem recent" do
    sign_in(@user)
    get progress_path(order: "")

    assert_response :success
    posicao = posicoes_dos_sets

    assert_operator posicao[@set_recente.code], :<, posicao[@set_antigo.code]
  end

  test "?order[]=recent (array) responde 200 e cai na ordem recent" do
    sign_in(@user)
    get progress_path, params: { order: [ "recent" ] }

    assert_response :success
    posicao = posicoes_dos_sets

    assert_operator posicao[@set_recente.code], :<, posicao[@set_antigo.code]
  end

  test "coleção vazia: todos os sets por código, mesmo sem parâmetro de ordem" do
    vazio = User.create!(email: "chopper-cnf27@example.com", password: PASSWORD)
    sign_in(vazio)
    get progress_path

    assert_response :success
    posicao = posicoes_dos_sets

    assert_operator posicao[@set_sem_posse.code], :<, posicao[@set_antigo.code],
                    "ninguém tem posse: OPo0 vem primeiro por código (CNF-38)"
    assert_operator posicao[@set_antigo.code], :<, posicao[@set_recente.code]
  end

  test "a atividade de um segundo usuário não muda a ordem do primeiro" do
    v_recente_outro = create_variant(@set_antigo, "o4")
    travel_to 1.minute.ago do
      CollectionItem.create!(user: @outro, card_variant: v_recente_outro, quantity: 1)
    end

    sign_in(@user)
    get progress_path

    assert_response :success
    posicao = posicoes_dos_sets

    assert_operator posicao[@set_recente.code], :<, posicao[@set_antigo.code],
                    "a posse recentíssima é do @outro; a ordem do @user não muda"
  end

  # --- CNF-29: chips "Recentes" / "Por código" ---

  def chip(texto)
    css_select(".progress__order-link").find { |node| node.text.squish == texto }
  end

  test "os dois chips existem junto do h2, cada um com o href da sua ordem" do
    sign_in(@user)
    get progress_path

    assert_response :success
    recentes = chip("Recentes")
    por_codigo = chip("Por código")

    assert recentes, "falta o chip 'Recentes'"
    assert por_codigo, "falta o chip 'Por código'"
    assert_equal progress_path(order: "recent"), recentes["href"]
    assert_equal progress_path(order: "code"), por_codigo["href"]
  end

  test "sem parâmetro de ordem, o chip Recentes tem aria-current" do
    sign_in(@user)
    get progress_path

    assert_equal "page", chip("Recentes")["aria-current"]
    assert_nil chip("Por código")["aria-current"]
  end

  test "?order=code marca o chip Por código com aria-current" do
    sign_in(@user)
    get progress_path(order: "code")

    assert_equal "page", chip("Por código")["aria-current"]
    assert_nil chip("Recentes")["aria-current"]
  end

  # CNF-28/CNF-29 juntos: um valor desconhecido cai em "recent" na consulta
  # (T1) e o chip precisa refletir a ordem **aplicada**, não o parâmetro bruto
  # — é por isso que a view lê `@order`, nunca `params[:order]` diretamente.
  test "?order=xyz (desconhecido) marca o chip Recentes, não nenhum chip" do
    sign_in(@user)
    get progress_path(order: "xyz")

    assert_response :success
    assert_equal "page", chip("Recentes")["aria-current"]
    assert_nil chip("Por código")["aria-current"]
  end
end
