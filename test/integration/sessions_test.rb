require "test_helper"

# T4 — criar conta, entrar, sair (Req. 6.1, 6.5, 6.6).
#
# O teste central é o ciclo inteiro: cadastrar, sair, entrar de novo e alcançar
# uma página protegida. Cada etapa isolada pode passar com o fluxo quebrado —
# cadastro que não autentica, saída que não invalida a sessão no banco, entrada
# que não restaura o acesso. É a sequência que prova o Req. 6.1.
#
# A página protegida é a mesma sonda da T3, pela mesma razão: quando esta task
# roda, `CollectionItemsController` ainda é a T6. Ver o comentário em
# `authentication_test.rb`.
class SessionsTest < ActionDispatch::IntegrationTest
  class ProtectedProbeController < ApplicationController
    def show
      render plain: "coleção de #{Current.user.email}"
    end
  end

  setup do
    Rails.application.routes.draw do
      get "protected_probe" => "sessions_test/protected_probe#show", as: :protected_probe
      instance_eval(File.read(Rails.root.join("config/routes.rb"))
                        .sub(/\ARails\.application\.routes\.draw do\n/, "").sub(/end\n\z/, ""))
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  # --- Req. 6.1: o ciclo completo ---

  test "cadastrar, sair, entrar de novo e alcançar página protegida" do
    assert_difference -> { User.count }, 1 do
      post registration_path, params: {
        email: "nami@example.com", password: "log-pose-77", password_confirmation: "log-pose-77"
      }
    end

    # Cadastrar já autentica: exigir digitar de novo o que acabou de ser
    # escolhido não protegeria nada.
    get protected_probe_path
    assert_response :success
    assert_match "coleção de nami@example.com", response.body

    assert_difference -> { Session.count }, -1 do
      delete session_path
    end

    # A saída invalida de fato, e não só troca a mensagem na tela.
    get protected_probe_path
    assert_redirected_to new_session_path

    post session_path, params: { email: "nami@example.com", password: "log-pose-77" }

    get protected_probe_path
    assert_response :success
    assert_match "coleção de nami@example.com", response.body
  end

  test "as telas de entrar e criar conta são públicas" do
    get new_session_path
    assert_response :success
    assert_select "form[action=?]", session_path

    get new_registration_path
    assert_response :success
    assert_select "form[action=?]", registration_path
  end

  # --- Req. 6.6: a mensagem não revela se o e-mail existe ---

  test "senha errada e e-mail inexistente dão a mesma resposta" do
    User.create!(email: "usopp@example.com", password: "kabuto-99")

    post session_path, params: { email: "usopp@example.com", password: "senha-errada" }
    assert_response :unprocessable_entity
    existente = response.body

    post session_path, params: { email: "ninguem@example.com", password: "senha-errada" }
    assert_response :unprocessable_entity
    inexistente = response.body

    # Comparar o corpo inteiro é o que fecha a porta: qualquer diferença, mesmo
    # uma palavra a mais, seria um oráculo de quais e-mails têm conta. O único
    # trecho neutralizado é o e-mail reapresentado no campo — é o valor que o
    # próprio atacante enviou, e não diz nada que ele já não soubesse.
    neutraliza = ->(body) { body.gsub(/usopp@example\.com|ninguem@example\.com/, "EMAIL") }

    assert_equal neutraliza.call(existente), neutraliza.call(inexistente)
  end

  test "credencial errada reapresenta o formulário com mensagem em português" do
    post session_path, params: { email: "zoro@example.com", password: "errada" }

    assert_response :unprocessable_entity
    assert_select "form[action=?]", session_path
    assert_match "E-mail ou senha inválidos.", response.body
    assert_nil Current.user
  end

  test "credencial errada não cria sessão" do
    User.create!(email: "sanji@example.com", password: "black-leg-88")

    assert_no_difference -> { Session.count } do
      post session_path, params: { email: "sanji@example.com", password: "errada" }
    end
  end

  # --- Caixa do e-mail (achado da T1) ---

  test "entra com o e-mail em qualquer caixa" do
    User.create!(email: "Robin@Example.com", password: "poneglyph-77")

    post session_path, params: { email: "ROBIN@EXAMPLE.COM", password: "poneglyph-77" }

    get protected_probe_path
    assert_response :success
  end

  # --- Req. 6.4: voltar à origem depois de autenticar ---

  test "anônimo barrado numa página protegida volta a ela depois de entrar" do
    User.create!(email: "franky@example.com", password: "super-1234")

    get protected_probe_path
    assert_redirected_to new_session_path

    post session_path, params: { email: "franky@example.com", password: "super-1234" }

    assert_redirected_to protected_probe_url
  end

  test "entrar sem origem guardada leva à raiz" do
    User.create!(email: "brook@example.com", password: "yohohoho-55")

    post session_path, params: { email: "brook@example.com", password: "yohohoho-55" }

    assert_redirected_to root_url
  end

  # --- Cadastro: validação ---

  test "e-mail já cadastrado reapresenta o formulário em vez de estourar" do
    User.create!(email: "chopper@example.com", password: "rumble-42")

    assert_no_difference -> { User.count } do
      post registration_path, params: {
        email: "CHOPPER@example.com", password: "outra-senha-1",
        password_confirmation: "outra-senha-1"
      }
    end

    assert_response :unprocessable_entity
    assert_select ".auth__errors"
  end

  test "confirmação divergente não cria conta" do
    assert_no_difference -> { User.count } do
      post registration_path, params: {
        email: "jinbe@example.com", password: "senha-uma-11", password_confirmation: "senha-duas-22"
      }
    end

    assert_response :unprocessable_entity
  end

  # Senha curta e senha em branco são recusas diferentes: a primeira é política
  # de senha, a segunda é presença. Testar só a vazia provaria piso nenhum —
  # passaria igual com uma senha de um caractere.
  test "senha curta demais não cria conta" do
    assert_no_difference -> { User.count } do
      post registration_path, params: {
        email: "koby@example.com", password: "curta1", password_confirmation: "curta1"
      }
    end

    assert_response :unprocessable_entity
    assert_select ".auth__errors"
  end

  test "senha em branco não cria conta" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { email: "koby@example.com", password: "", password_confirmation: "" }
    end

    assert_response :unprocessable_entity
  end

  # A senha nunca é persistida em claro — o Req. 6.2 é da T1, mas o cadastro é
  # o caminho por onde uma senha entra no sistema pela primeira vez.
  test "cadastro grava digest e nenhuma coluna guarda a senha em claro" do
    post registration_path, params: {
      email: "law@example.com", password: "room-shambles-3", password_confirmation: "room-shambles-3"
    }

    user = User.sole
    assert_not_equal "room-shambles-3", user.password_digest
    assert user.authenticate("room-shambles-3")
    assert_empty User.columns.map(&:name).grep(/\Apassword\z|plain/)
  end

  # --- Layout ---

  test "cabeçalho mostra entrar e criar conta para anônimo, e sair para autenticado" do
    get catalog_path
    assert_select ".site-header__nav a[href=?]", new_session_path
    assert_select ".site-header__nav a[href=?]", new_registration_path

    post registration_path, params: {
      email: "shanks@example.com", password: "akagami-10", password_confirmation: "akagami-10"
    }

    get catalog_path
    assert_select ".site-header__nav form[action=?]", session_path
    assert_select ".site-header__nav a[href=?]", new_session_path, false
  end
end
