# Sessões do usuário (Req. 6.3). A forma vem do gerador de autenticação do
# Rails 8 — `migration CreateSessions user:references ip_address:string
# user_agent:string` (railties-8.0.5.1/.../authentication_generator.rb:54) —
# escrita à mão porque o gerador, rodado inteiro, emite um segundo
# `create_table :users` sobre a tabela existente e sobrescreve o model `User`.
class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions do |t|
      # `cascade` aqui, ao contrário de `collection_items`, que é `restrict`:
      # uma sessão é descartável e derivada — apagar o usuário deve encerrá-la.
      # A coleção é o oposto: insubstituível, e uma cascata a destruiria em
      # silêncio (design.md §5.2).
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
  end
end
