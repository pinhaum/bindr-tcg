# Importar uma lista no formato do OPTCG Simulator num deck novo (DCK-24..30).
#
# Nenhuma declaração de acesso público: sem sessão, o anônimo é redirecionado
# antes da action e nada é criado (DCK-37). O deck nasce em
# `Current.user.decks`, nunca de um `user_id` do request (Req. 6.5).
#
# Importar **sempre cria** um deck: substituir um existente por colagem o
# destruiria sem volta (DCK-24). Por isso não há staging nem pré-visualização,
# como no import da coleção (AD-007): nada que existe é alterado, e a página
# do deck criado já mostra status e motivos.
#
# Tudo ou nada (DCK-28): `Deck::ListText.parse` recusa a lista inteira se uma
# linha estiver ruim, e o deck e as entradas são gravados num `save` só, que
# roda numa transação. Se o deck não puder ser gravado, nenhuma entrada fica.
class DeckImportsController < ApplicationController
  include EditingDeck

  def new
    @deck = Current.user.decks.new
  end

  def create
    @deck = Current.user.decks.new
    @import = import_params
    result = Deck::ListText.parse(@import[:list])
    @list_errors = result.errors
    return render(:new, status: :unprocessable_entity) if @list_errors.any?

    # DCK-24 — sem nome, o deck leva o nome do Leader importado. Sem nome e sem
    # Leader, a validação do nome recusa e o formulário pede um.
    @deck.assign_attributes(name: @import[:name].presence || result.leader&.name.to_s, leader: result.leader)
    result.entries.each { |card, quantity| @deck.entries.build(card: card, quantity: quantity) }

    if @deck.save
      start_editing(@deck)
      redirect_to @deck, notice: "Deck importado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    # `permit`, não `expect`: um formulário enviado sem o campo da lista cai
    # na recusa "A lista não tem nenhuma carta", em vez de um 400 sem
    # mensagem. Um valor que não é texto (`list[]=`) é descartado do mesmo
    # jeito.
    def import_params
      params.fetch(:deck_import, {}).permit(:name, :list)
    end
end
