require "test_helper"

# INT-06 (Req. 12.8): cada tipo de mensagem sai com o modificador do seu tipo,
# que é o que a folha usa para distingui-los por forma (test/design/flash_test.rb).
class FlashUiTest < ActionDispatch::IntegrationTest
  test "login inválido renderiza a mensagem como alert, na região assertiva" do
    post session_path, params: { email: "zoro@example.com", password: "errada" }

    assert_response :unprocessable_entity
    assert_select "[role=alert] p.flash.flash--alert", text: "E-mail ou senha inválidos."
    assert_select "p.flash--notice", count: 0
  end

  test "sair renderiza a mensagem como notice, na região polida" do
    User.create!(email: "nami@example.com", password: "log-pose-77")
    post session_path, params: { email: "nami@example.com", password: "log-pose-77" }

    delete session_path
    follow_redirect!

    assert_select "[role=status] p.flash.flash--notice", text: "Sessão encerrada."
    assert_select "p.flash--alert", count: 0
  end
end
