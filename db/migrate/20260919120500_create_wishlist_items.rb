# `wishlist_items`, conforme design.md §3.2. Req. 8.1/8.4 — COL-14 e COL-17.
#
# Tabela própria, e não uma coluna em `collection_items`: desejo e posse são
# estados independentes. Querer três cópias e ter zero precisa ser
# representável, e uma coluna na coleção forçaria criar registro de posse para
# exprimir desejo (spec.md, "Modelagem da wishlist").
#
# Referencia `card_variants`, nunca `cards`: desejo é por impressão específica,
# como a posse. Querer a arte alternativa do Luffy não é querer a base
# (design.md §3.1).
class CreateWishlistItems < ActiveRecord::Migration[8.0]
  def change
    create_table :wishlist_items do |t|
      # Sem `on_delete: :cascade`, deliberadamente e pela mesma razão de
      # `collection_items` (design.md §5.2): a ingestão não tem operação de
      # delete, mas se um dia tivesse, a cascata apagaria o desejo do usuário
      # em silêncio ao remover uma variante do catálogo. O catálogo é
      # regenerável; o dado do usuário não é. `restrict` transforma a perda
      # calada em erro barulhento.
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.references :card_variant, null: false, foreign_key: { on_delete: :restrict }
      t.integer :target_quantity, null: false
      t.timestamps
    end
    # Req. 8.5 / COL-14 — no máximo um item de wishlist por par (usuário,
    # variante), garantido no banco e não apenas na aplicação: marcar a mesma
    # variante em duas abas não pode gerar duas linhas.
    add_index :wishlist_items, [ :user_id, :card_variant_id ], unique: true
    # Req. 8.1 — o alvo é inteiro **maior que zero**.
    #
    # Assimetria deliberada com `collection_items`, que usa `quantity >= 0`, e
    # que parece inconsistência sem esta nota. Posse zero é estado legítimo:
    # "tenho a linha, não tenho a carta" é o que distingue quem nunca teve de
    # quem não tem mais, e é o que o filtro do Req. 7.6 lê. Desejar zero cópias,
    # porém, não é desejo nenhum — a forma de não querer mais é **remover** o
    # item (Req. 8.4), não zerar o alvo. Sem este piso, um alvo 0 ficaria
    # permanentemente "atendido" (Req. 8.3 compara posse com alvo) e poluiria a
    # lista com linhas que não pedem nada.
    add_check_constraint :wishlist_items, "target_quantity >= 1", name: "wishlist_items_target_quantity_check"
  end
end
