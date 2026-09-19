# Identidade do usuário. A tabela nasceu na Fase 2 (migração 20260919120200)
# para que a T8 pudesse provar que a ingestão preserva a coleção; a Fase 4
# acrescenta a senha e, nas tasks seguintes, a sessão.
#
# O gerador `bin/rails generate authentication` NÃO foi executado, e não deve
# ser: ele emite um segundo `create_table :users` sobre a tabela existente,
# assume a coluna `email_address` em vez de `email`, e sobrescreve este arquivo
# — apagando em silêncio o `dependent: :restrict_with_exception` abaixo. Os
# artefatos de sessão são portados à mão a partir dos templates de
# railties-8.0.5.1. `authenticate_by` aceita `email:` sem adaptação porque
# particiona os argumentos por `has_attribute?`
# (activerecord-8.0.5.1/lib/active_record/secure_password.rb:41).
class User < ApplicationRecord
  # `restrict_with_exception`, nunca `destroy`: apagar um usuário não pode
  # levar junto a coleção dele por efeito colateral (design.md §5.2). Dado do
  # usuário é insubstituível; o catálogo é regenerável.
  has_many :collection_items, dependent: :restrict_with_exception

  # `destroy`, ao contrário de `collection_items`: a sessão é derivada e
  # descartável, então encerrar a conta encerra as sessões. A assimetria entre
  # as duas linhas é deliberada.
  has_many :sessions, dependent: :destroy

  # Req. 6.2 — a senha é guardada como digest bcrypt, nunca em claro. Também
  # valida presença na criação e confirmação quando `password_confirmation`
  # é informado.
  has_secure_password

  # Req. 6.1 — o e-mail é identidade e é comparado sem distinção de caixa. O
  # índice único `index_users_on_lower_email` impede que duas grafias coexistam,
  # mas não faz a **busca** casar: `authenticate_by` resolve o usuário com
  # `find_by(email:)` (activerecord-8.0.5.1/.../secure_password.rb:52), que é
  # sensível à caixa. Sem esta normalização, quem se cadastrou como `sanji@` não
  # entraria digitando `SANJI@`. `normalizes` fecha os dois lados: normaliza na
  # escrita e também o argumento nomeado das consultas.
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true
end
