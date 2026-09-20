require "test_helper"

# T3 — o concern `Authentication` (Req. 6.3 e 6.4).
#
# Esta task inverte o default do app: antes dela nenhuma action exigia sessão;
# depois dela todas exigem, menos as que declararem `allow_unauthenticated_access`.
# São duas asserções simétricas, e errar qualquer uma é grave em direção oposta:
# proteger o catálogo derruba o produto inteiro, e liberar uma mutação vaza
# dado de usuário.
#
# **Por que a action protegida é definida aqui e não em `app/`:** quando esta
# task roda, nenhuma action protegida existe no app — o `SessionsController` é
# a T4 e o `CollectionItemsController` é a T6. Criar um controller de produção
# só para ter o que testar anteciparia escopo de outra task e viraria código
# morto no commit seguinte. O controller anônimo abaixo exercita exatamente o
# comportamento que a T3 entrega — o default herdado de `ApplicationController`
# — sem inventar nada de produção. É o padrão do próprio Rails para testar
# concerns de controller.
class AuthenticationTest < ActionDispatch::IntegrationTest
  # Um controller que não declara nada. É essa a questão: ele é protegido por
  # **omissão**, porque herda o `before_action` de `ApplicationController`.
  class ProtectedProbeController < ApplicationController
    def show
      render plain: "area restrita de #{Current.user.email}"
    end
  end

  # Estabelece a sessão pelo mesmo `start_new_session_for` que o
  # `SessionsController` da T4 vai chamar. Existe para que o teste não precise
  # reproduzir à mão a assinatura do cookie: quem escreve é o middleware de
  # cookies do Rails, exatamente como em produção. Liberada do filtro porque é
  # o passo que **cria** a sessão.
  class ProbeSignInController < ApplicationController
    allow_unauthenticated_access

    def create
      start_new_session_for(User.find(params[:user_id]))
      head :created
    end
  end

  setup do
    @user = User.create!(email: "nico.robin@example.com", password: "poneglyph-77")

    # A rota da sonda vive só durante o teste. `draw` **substitui** o conjunto
    # de rotas, então o bloco recarrega `config/routes.rb` junto: as rotas reais
    # do app continuam valendo dentro deste arquivo, que é o que permite asserir
    # o redirect para `new_session_path` e o 200 de `/catalog`. `reload_routes!`
    # no teardown devolve o conjunto original.
    Rails.application.routes.draw do
      get "protected_probe" => "authentication_test/protected_probe#show", as: :protected_probe
      post "probe_sign_in" => "authentication_test/probe_sign_in#create", as: :probe_sign_in
      instance_eval(File.read(Rails.root.join("config/routes.rb"))
                        .sub(/\ARails\.application\.routes\.draw do\n/, "").sub(/end\n\z/, ""))
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  def seed_catalog
    set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    card = Card.create!(card_set: set, card_number: "OP01-001", name: "Roronoa Zoro",
                        card_type: "leader", colors: [ "Red" ], cost: 3, power: 5000)
    CardVariant.create!(card: card, card_set: set, variant_code: "OP01-001",
                        rarity: "L", art_kind: "base")
    card
  end

  # Autentica pelo caminho real: uma requisição que chama
  # `start_new_session_for`, deixando o middleware de cookies do Rails assinar o
  # valor. Reproduzir a assinatura à mão no teste acoplaria a suíte ao salt
  # interno do Action Dispatch e provaria menos — não há atalho por `params`
  # em lugar nenhum.
  def sign_in(user)
    post probe_sign_in_path(user_id: user.id)
    assert_response :created
    user.sessions.order(:created_at).last
  end

  # --- Req. 6.3: o catálogo continua público ---

  test "catálogo, detalhe e busca respondem 200 sem sessão" do
    card = seed_catalog

    get catalog_path
    assert_response :success

    get card_path(card.card_number)
    assert_response :success

    get catalog_path(q: "Zoro")
    assert_response :success

    get root_path
    assert_response :success
  end

  # A sonda do teste ficaria protegida mesmo com o concern só parcialmente
  # ligado. Esta asserção é o outro lado: prova que o `allow_unauthenticated_access`
  # do `CatalogController` está de fato surtindo efeito, e não que o
  # `before_action` deixou de ser instalado.
  # O 200 do catálogo, sozinho, também passaria se o concern nunca tivesse sido
  # incluído. Esta asserção separa os dois casos: o filtro **existe** no default
  # do app e o `CatalogController` o pula explicitamente.
  test "catálogo pula um filtro que existe, em vez de não ter filtro nenhum" do
    assert_includes ApplicationController._process_action_callbacks.map(&:filter),
                    :require_authentication,
                    "o default do app precisa exigir sessão"

    refute_includes CatalogController._process_action_callbacks.map(&:filter),
                    :require_authentication,
                    "o catálogo precisa pular o filtro, e não herdá-lo"
  end

  # --- Req. 6.4: o default é exigir sessão ---

  test "action que não declara nada exige sessão e redireciona o anônimo" do
    get protected_probe_path

    assert_redirected_to new_session_path
    assert_nil Current.user
  end

  test "anônimo volta à origem depois de autenticar" do
    get protected_probe_path
    assert_redirected_to new_session_path

    # O concern guarda a origem na sessão do cookie e a devolve em
    # `after_authentication_url`. É o que a T4 vai consumir no `create`.
    assert_equal protected_probe_url, session[:return_to_after_authenticating]

    sign_in(@user)
    get protected_probe_path

    assert_response :success
    assert_match "area restrita de nico.robin@example.com", response.body
  end

  test "sessão válida no cookie assinado libera a action protegida" do
    sign_in(@user)

    get protected_probe_path

    assert_response :success
  end

  # --- A sessão vem do cookie assinado, nunca do request ---

  test "id de sessão em params é ignorado" do
    session_record = @user.sessions.create!(ip_address: "203.0.113.21", user_agent: "rails-test")

    get protected_probe_path(session_id: session_record.id)

    assert_redirected_to new_session_path
  end

  test "cookie não assinado com id de sessão válido é ignorado" do
    session_record = @user.sessions.create!(ip_address: "203.0.113.22", user_agent: "rails-test")
    cookies[:session_id] = session_record.id.to_s

    get protected_probe_path

    assert_redirected_to new_session_path
  end

  test "cookie assinado apontando para sessão encerrada não autentica" do
    session_record = sign_in(@user)
    session_record.destroy

    get protected_probe_path

    assert_redirected_to new_session_path
  end
end
