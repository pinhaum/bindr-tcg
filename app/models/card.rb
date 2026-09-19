# A carta do jogo, identificada por `card_number` (design.md §3.1). É sobre ela
# que as regras e os textos falam. Uma impressão física é `CardVariant` — não
# colapsar as duas.
class Card < ApplicationRecord
  belongs_to :card_set, foreign_key: :set_id, inverse_of: :cards
  has_many :card_variants, dependent: :restrict_with_exception

  validates :card_number, presence: true, uniqueness: true
  validates :name, presence: true

  # Req. 5.5 — qual campo se aplica a qual tipo de carta. A regra é do jogo,
  # não da presença do dado: um Event **nunca** tem power, e exibir "Power: —"
  # inventa um dado que não existe.
  #
  # Isto é deliberadamente separado de "o valor está preenchido". Um Character
  # sem counter (`counter` NULL, 1094 no catálogo) tem counter *aplicável* e
  # *ausente* — nos dois casos o campo some da tela, mas pelos motivos certos,
  # e `cost` 0 continua sendo valor real que aparece.
  APPLICABLE_FIELDS = {
    "leader" => %i[colors power life attributes_list traits block_icon],
    "character" => %i[colors cost power counter attributes_list traits block_icon],
    "event" => %i[colors cost attributes_list traits block_icon],
    "stage" => %i[colors cost attributes_list traits block_icon]
  }.freeze

  def field_applicable?(field)
    APPLICABLE_FIELDS.fetch(card_type, APPLICABLE_FIELDS["character"]).include?(field)
  end

  # O campo aparece quando se aplica ao tipo **e** tem valor.
  #
  # `!value.nil?` em vez de `value.present?` para o caso escalar. Para os
  # inteiros do catálogo os dois concordam hoje (`0.present?` é `true` em
  # Rails, então cost 0 aparece nos dois), mas a pergunta aqui é
  # "existe valor?", não "é preenchido?": `present?` descarta `false` e
  # string vazia, e o dia em que um campo booleano ou textual entrar nesta
  # lista a distinção deixa de ser acadêmica.
  def display_field?(field)
    return false unless field_applicable?(field)

    value = public_send(field)
    value.is_a?(Array) ? value.any? : !value.nil?
  end
end
