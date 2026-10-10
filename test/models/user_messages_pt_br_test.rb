require "test_helper"

# API-07 — as mensagens de cadastro inválido saem em pt-BR sob o locale da API;
# o locale padrão (`en`) segue intacto para o HTML e para os demais testes.
class UserMessagesPtBrTest < ActiveSupport::TestCase
  def errors_for(**attrs)
    user = User.new(**attrs)
    user.validate
    user.errors
  end

  test "e-mail em branco" do
    I18n.with_locale(:"pt-BR") do
      assert_equal [ "não pode ficar em branco" ],
        errors_for(email: "", password: "senha-correta").messages_for(:email)
    end
  end

  test "e-mail já em uso" do
    User.create!(email: "ace@example.com", password: "senha-correta")
    I18n.with_locale(:"pt-BR") do
      assert_equal [ "já está em uso" ],
        errors_for(email: "ACE@example.com", password: "senha-correta").messages_for(:email)
    end
  end

  test "senha em branco" do
    I18n.with_locale(:"pt-BR") do
      assert_includes errors_for(email: "a@example.com").messages_for(:password),
        "não pode ficar em branco"
    end
  end

  test "senha curta" do
    I18n.with_locale(:"pt-BR") do
      assert_equal [ "é muito curto (mínimo: 8 caracteres)" ],
        errors_for(email: "a@example.com", password: "curta").messages_for(:password)
    end
  end

  test "senha longa demais" do
    I18n.with_locale(:"pt-BR") do
      assert_includes errors_for(email: "a@example.com", password: "a" * 73).messages_for(:password),
        "é muito longa"
    end
  end

  test "confirmação divergente" do
    I18n.with_locale(:"pt-BR") do
      assert_equal [ "não é igual a Senha" ],
        errors_for(email: "a@example.com", password: "senha-correta",
          password_confirmation: "outra-senha").messages_for(:password_confirmation)
    end
  end

  test "nenhum caso emite translation missing" do
    I18n.with_locale(:"pt-BR") do
      errors = errors_for(email: "", password: "a" * 73, password_confirmation: "x")
      assert errors.full_messages.none? { |m| m.include?("translation missing") }, errors.full_messages.inspect
    end
  end

  test "locale padrão continua em inglês" do
    assert_equal :en, I18n.default_locale
    assert_equal [ "can't be blank" ], errors_for(email: "", password: "senha-correta").messages_for(:email)
  end
end
