# Incremento e decremento de uma carta no deck, acionados pelo detalhe da carta
# (DCK-05, DCK-06). Mesmo desenho de `CollectionItemsController`: SQL atômico
# com bind params e resposta dupla, HTML (`redirect_back`) e Turbo Stream.
#
# Nenhuma declaração de acesso público: sem sessão, o anônimo é redirecionado
# antes da action e nada é gravado (DCK-37). O deck sai de
# `Current.user.decks`, e o de outro usuário cai em `RecordNotFound` e
# responde 404 sem gravar (DCK-36).
#
# Regra de jogo nunca recusa gravação (DCK-18): a 5ª cópia entra, e o status do
# deck é que fica `inválido`. O que recusa é a forma do modelo: carta Leader
# não é entrada (422) e nenhuma entrada passa de 50 (DCK-39).
#
# O deck pode ser apagado entre o `find` e o SQL (outra aba excluindo). O
# `INSERT` do incremento então viola a FK e responde 404, o mesmo de um deck que
# não existe, em vez de 500 (achado DB-M2).
class DeckEntriesController < ApplicationController
  before_action :set_deck, :set_card

  rescue_from ActiveRecord::InvalidForeignKey do
    raise ActiveRecord::RecordNotFound, "Deck excluído durante a operação"
  end

  def increment
    if @card.card_type == "leader"
      return refuse("#{@card.card_number} é um Leader; use “Usar como Leader” em vez de somar cópias.")
    end

    quantity = DeckEntry.increment_for!(@deck, @card)

    if quantity.nil?
      respond_with_quantity current_quantity, alert: "O máximo é #{DeckEntry::MAX_QUANTITY} cópias por carta no deck."
    else
      respond_with_quantity quantity, notice: copies_notice(quantity)
    end
  end

  # O piso e a janela entre o `UPDATE` e o `DELETE` são de
  # `DeckEntry.decrement_for!`: devolve N-1, `0` quando apagou a entrada, ou
  # `nil` quando não havia entrada.
  def decrement
    quantity = DeckEntry.decrement_for!(@deck, @card)

    case quantity
    when nil
      respond_with_quantity current_quantity, alert: "#{@card.card_number} não está no deck “#{@deck.name}”."
    when 0
      respond_with_quantity 0, notice: "#{@card.card_number} saiu do deck “#{@deck.name}”."
    else
      respond_with_quantity quantity, notice: copies_notice(quantity)
    end
  end

  # DCK-04 — grava ou substitui o Leader, sem tocar as entradas. Carta que não
  # é Leader dá 422: é a forma do modelo (`Deck#leader_must_be_a_leader`), não
  # regra de jogo.
  def leader
    unless @card.card_type == "leader"
      return refuse("#{@card.card_number} não é um Leader; use “+” para somar cópias ao deck.")
    end

    @deck.update!(leader: @card)
    respond_with_quantity 0, notice: "#{@card.card_number} é o Leader do deck “#{@deck.name}”."
  end

  private
    def set_deck
      @deck = Current.user.decks.find(params[:deck_id])
    end

    # A carta é catálogo público: um id inválido é 404, sem vazar nada. Um
    # `card_id` que não é escalar (`card_id[]=1&card_id[]=2`) também: sem a
    # guarda, `Card.find` devolveria uma lista e a action daria 500 (achado
    # SEC-L1).
    def set_card
      card_id = params[:card_id]
      raise ActiveRecord::RecordNotFound, "card_id precisa ser um valor só" unless card_id.is_a?(String)

      @card = Card.find(card_id)
    end

    def current_quantity
      @deck.entries.where(card: @card).pick(:quantity).to_i
    end

    def copies_notice(quantity)
      "#{@card.card_number}: #{quantity} #{quantity == 1 ? 'cópia' : 'cópias'} no deck “#{@deck.name}”."
    end

    # Forma do modelo, não regra de jogo (design.md, Error Handling): 422 nos
    # dois formatos, sem gravar nada. No HTML não há `redirect_back`, porque o
    # navegador não segue um redirect com 422; a interface nunca oferece "+"
    # para um Leader, então só chega aqui um POST montado à mão.
    def refuse(message)
      respond_to do |format|
        format.html { render plain: message, status: :unprocessable_entity }
        format.turbo_stream do
          flash.now[:alert] = message
          render turbo_stream: flash_streams, status: :unprocessable_entity
        end
      end
    end

    # A mesma resposta dupla da posse: sem JS, `redirect_back`; com Turbo, o
    # Stream troca só o controle desta carta. `update` com morph, não
    # `replace`: mantém o botão focado e a região `aria-live` do partial, que
    # anuncia a quantidade nova (cabeçalho do partial).
    #
    # Na carta comum, o sucesso já é anunciado pela região viva, então o
    # notice não vai para o flash do Stream: dois canais repetiriam a mesma
    # frase (achado M4). O alerta vai, porque a recusa não muda a quantidade e
    # a região não tem o que anunciar. No Leader não há região, e o notice é o
    # único canal.
    def respond_with_quantity(quantity, **flash_options)
      respond_to do |format|
        format.html { redirect_back_with(**flash_options) }
        format.turbo_stream do
          flash.now[:notice] = flash_options[:notice] if flash_options[:notice] && @card.card_type == "leader"
          flash.now[:alert] = flash_options[:alert] if flash_options[:alert]

          render turbo_stream: [
            turbo_stream.update(helpers.dom_id(@card, :deck_entry), partial: "decks/card_controls", method: :morph,
                                locals: { deck: @deck, card: @card, quantity: quantity.to_i }),
            *flash_streams
          ]
        end
      end
    end

    # Os dois são atualizados sempre, para limpar o que sobrou da operação
    # anterior, como na posse.
    def flash_streams
      [
        turbo_stream.update("flash_notice", partial: "layouts/flash_message",
                                            locals: { message: flash[:notice], kind: "notice" }),
        turbo_stream.update("flash_alert", partial: "layouts/flash_message",
                                           locals: { message: flash[:alert], kind: "alert" })
      ]
    end

    # O destino vem do `Referer`, que é do cliente: `allow_other_host: false`
    # fixa localmente o que `raise_on_open_redirects` já garante.
    def redirect_back_with(**flash_options)
      redirect_back fallback_location: deck_path(@deck), allow_other_host: false, **flash_options
    end
end
