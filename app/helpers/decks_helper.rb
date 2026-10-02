module DecksHelper
  # O status em português, do jeito que o spec o escreve (DCK-11). Fica num
  # helper porque a lista de decks e a página do deck mostram o mesmo rótulo.
  DECK_STATUS_LABELS = { valid: "válido", incomplete: "incompleto", invalid: "inválido" }.freeze

  def deck_status_label(status)
    DECK_STATUS_LABELS.fetch(status)
  end

  # Os grupos da página do deck em português (achado L10 da revisão de a11y).
  # `card_type` continua em inglês no banco, como a fonte o traz.
  DECK_GROUP_LABELS = { "character" => "Personagens", "event" => "Eventos", "stage" => "Locais" }.freeze

  def deck_group_label(card_type)
    DECK_GROUP_LABELS.fetch(card_type) { card_type.humanize }
  end
end
