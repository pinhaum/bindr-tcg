module DecksHelper
  # O status em português, do jeito que o spec o escreve (DCK-11). Fica num
  # helper porque a lista de decks e a página do deck mostram o mesmo rótulo.
  DECK_STATUS_LABELS = { valid: "válido", incomplete: "incompleto", invalid: "inválido" }.freeze

  def deck_status_label(status)
    DECK_STATUS_LABELS.fetch(status)
  end
end
