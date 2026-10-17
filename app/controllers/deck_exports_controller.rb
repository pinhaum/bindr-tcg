# A lista do deck no formato do OPTCG Simulator (DCK-31), em
# `text/plain; charset=utf-8` exibido no navegador: o usuário copia ou salva.
#
# Sem declaração de acesso público: o default de `ApplicationController` exige
# sessão. O deck sai de `Current.user.decks`, então o de outro usuário é 404,
# igual ao que não existe (DCK-36).
class DeckExportsController < ApplicationController
  def show
    deck = Current.user.decks.find(params[:id])

    render plain: Deck::ListText.format(deck)
  end
end
