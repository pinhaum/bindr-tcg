# `decks` e `deck_entries`, conforme `.specs/features/decks/design.md`
# (Data Models). DCK-02, DCK-39, DCK-40.
#
# O deck referencia `cards`, e não `card_variants`: para jogar, qualquer
# impressão serve, e a escolha de arte é coisa da coleção (design.md §3.1, §10).
class CreateDecks < ActiveRecord::Migration[8.0]
  def change
    create_table :decks do |t|
      # `restrict` pela mesma razão de `collection_items`: o deck é dado do
      # usuário, e apagar a conta não pode levá-lo por efeito colateral.
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.text :name, null: false
      # Leader opcional: o deck nasce vazio (DCK-01). `restrict` porque a
      # ingestão nunca apaga carta (Req. 1.7), e se um dia apagasse, o Leader
      # do usuário não pode sumir calado (DCK-40).
      t.references :leader_card, null: true, foreign_key: { to_table: :cards, on_delete: :restrict }
      t.timestamps
    end
    # DCK-39 — o limite do nome é do banco, não só do formulário.
    add_check_constraint :decks, "char_length(name) BETWEEN 1 AND 60", name: "decks_name_length_check"

    create_table :deck_entries do |t|
      # A única cascata do projeto, e deliberada: a entrada só existe dentro do
      # deck e não é dado de coleção. Excluir o deck leva as entradas dele e
      # nada mais (DCK-09).
      t.references :deck, null: false, index: false, foreign_key: { on_delete: :cascade }
      # Nenhuma FK que parte de `cards` cascateia (DCK-40).
      t.references :card, null: false, foreign_key: { on_delete: :restrict }
      t.integer :quantity, null: false
      t.timestamps
    end
    # DCK-02 — no máximo uma entrada por carta por deck, garantida no banco. O
    # índice também atende a busca por `deck_id`, por isso a referência acima
    # não cria índice próprio.
    add_index :deck_entries, [ :deck_id, :card_id ], unique: true
    # DCK-39 — 50 é o tamanho do deck principal. O piso 1 existe porque zero
    # cópias não é entrada: o decremento que chega a zero apaga a linha (DCK-06).
    add_check_constraint :deck_entries, "quantity BETWEEN 1 AND 50", name: "deck_entries_quantity_check"
  end
end
