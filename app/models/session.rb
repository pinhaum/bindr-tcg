# Sessão autenticada, materializada no banco para que encerrar sessão seja um
# delete e não apenas o descarte de um cookie. Portada do template
# `session.rb.tt` de railties-8.0.5.1; o gerador inteiro não roda neste projeto
# (ver comentário em `app/models/user.rb`).
class Session < ApplicationRecord
  belongs_to :user
end
