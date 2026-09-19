# `users` e `collection_items` mínimos, conforme design.md §3.2.
#
# Por que na Fase 2 e não na Fase 4: a invariante central da ingestão — rodar
# duas vezes não altera a coleção do usuário (Req. 1.7) — não é demonstrável
# sem uma coleção para preservar. Sem estas tabelas, a T8 provaria apenas que
# as contagens do catálogo não mudam, que é a parte fácil e não é a que
# protege dado irrecuperável.
#
# O gerador de autenticação do Rails NÃO foi executado: ele cria `User` e
# `Session` com o fluxo completo de login, que é escopo da Fase 4. Aqui entra
# só o que a asserção precisa.
class CreateCollectionTables < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.text :email, null: false
      t.text :password_digest, null: false
      t.timestamps
    end
    # Req. 6.1 — e-mail é identidade, comparado sem distinção de caixa.
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"

    create_table :collection_items do |t|
      # Sem `on_delete: :cascade`, deliberadamente (design.md §5.2). Se a
      # ingestão apagasse uma variante, a cascata levaria junto o registro do
      # usuário — perda irrecuperável causada por erro de fonte externa.
      # `restrict` transforma isso em erro barulhento em vez de perda calada.
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.references :card_variant, null: false, foreign_key: { on_delete: :restrict }
      t.integer :quantity, null: false, default: 0
      t.timestamps
    end
    # Req. 7.8 — no máximo um registro por (usuário, variante), garantido no
    # banco e não apenas na aplicação.
    add_index :collection_items, [ :user_id, :card_variant_id ], unique: true
    # Req. 7.4 — quantidade nunca negativa.
    add_check_constraint :collection_items, "quantity >= 0", name: "collection_items_quantity_check"
  end
end
