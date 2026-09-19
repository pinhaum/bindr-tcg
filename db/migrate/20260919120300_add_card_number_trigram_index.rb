# Req. 3.1 e 11.3 — a busca textual casa `card_number` por substring, e sem
# este índice essa ramificação é inindexável.
#
# Medido na T11 contra o catálogo real: as três ramificações da busca (nome,
# efeito, `card_number`) unidas por `OR` num único predicado caem em Seq Scan
# **mesmo com os outros dois índices presentes** — uma ramificação sem índice
# derruba o plano indexado do predicado inteiro. Ver `design.md` §4.1.2.
#
# O índice único btree de `card_number` não resolve: criado com a collation
# padrão, não serve nem para `LIKE` ancorado. Ele continua existindo e é o que
# atende o match exato do Req. 3.4 (`card_number = ?`, termo já em maiúsculas).
#
# Este índice é aditivo: não altera nenhuma tabela, coluna ou constraint do
# schema verificado na Fase 2.
class AddCardNumberTrigramIndex < ActiveRecord::Migration[8.0]
  def change
    add_index :cards, :card_number, using: :gin, opclass: :gin_trgm_ops,
              name: "index_cards_on_card_number_trgm"
  end
end
