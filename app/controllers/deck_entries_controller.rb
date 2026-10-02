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
class DeckEntriesController < ApplicationController
  MAX_QUANTITY = DeckEntry::QUANTITY_RANGE.max

  before_action :set_deck, :set_card

  # `ON CONFLICT DO UPDATE` lê e escreve num statement só: dois incrementos
  # simultâneos somam os dois em vez de um sobrescrever o outro (DCK-38), e a
  # corrida de criação vira atualização em vez de `RecordNotUnique`. O teto de
  # 50 mora no `WHERE` do `DO UPDATE`, na mesma linha travada: em 50, nada casa,
  # o `RETURNING` volta vazio e a quantidade fica como está. O
  # `CHECK (quantity BETWEEN 1 AND 50)` do banco continua sendo a garantia; o
  # `WHERE` só transforma a violação em mensagem.
  def increment
    if @card.card_type == "leader"
      return refuse("#{@card.card_number} é um Leader; use “Usar como Leader” em vez de somar cópias.")
    end

    quantity = execute_returning_quantity(<<~SQL)
      -- incrementDeckEntry
      INSERT INTO deck_entries (deck_id, card_id, quantity, created_at, updated_at)
      VALUES ($1, $2, 1, now(), now())
      ON CONFLICT (deck_id, card_id)
      DO UPDATE SET quantity = deck_entries.quantity + 1, updated_at = now()
      WHERE deck_entries.quantity < #{MAX_QUANTITY}
      RETURNING quantity
    SQL

    if quantity.nil?
      respond_with_quantity current_quantity, alert: "O máximo é #{MAX_QUANTITY} cópias por carta no deck."
    else
      respond_with_quantity quantity, notice: copies_notice(quantity)
    end
  end

  # O piso mora no `WHERE`: acima de 1, o `UPDATE` tira uma cópia; em 1, nada
  # casa e o `DELETE ... WHERE quantity = 1` apaga a entrada (DCK-06). Com dois
  # decrementos simultâneos sobre 2, o primeiro baixa para 1 e o segundo apaga
  # a linha. Sem entrada, nenhum dos dois casa e nada é criado.
  def decrement
    quantity = execute_returning_quantity(<<~SQL)
      -- decrementDeckEntry
      UPDATE deck_entries
      SET quantity = quantity - 1, updated_at = now()
      WHERE deck_id = $1 AND card_id = $2 AND quantity > 1
      RETURNING quantity
    SQL
    return respond_with_quantity(quantity, notice: copies_notice(quantity)) if quantity

    removed = execute_returning_quantity(<<~SQL)
      -- deleteLastDeckEntryCopy
      DELETE FROM deck_entries
      WHERE deck_id = $1 AND card_id = $2 AND quantity = 1
      RETURNING quantity
    SQL

    if removed
      respond_with_quantity 0, notice: "#{@card.card_number} saiu do deck “#{@deck.name}”."
    else
      respond_with_quantity current_quantity, alert: "#{@card.card_number} não está no deck “#{@deck.name}”."
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

    # A carta é catálogo público: um id inválido é 404, sem vazar nada.
    def set_card
      @card = Card.find(params[:card_id])
    end

    # `exec_query` com bind params, não interpolação: os ids vêm do request.
    # Devolve a quantidade resultante, ou `nil` quando nenhuma linha foi
    # afetada.
    def execute_returning_quantity(sql)
      binds = [
        ActiveRecord::Relation::QueryAttribute.new("deck_id", @deck.id, ActiveRecord::Type::Integer.new),
        ActiveRecord::Relation::QueryAttribute.new("card_id", @card.id, ActiveRecord::Type::Integer.new)
      ]
      DeckEntry.connection.exec_query(sql, "DeckEntry Quantity", binds).rows.dig(0, 0)
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
    # Stream troca só o controle desta carta. `update`, não `replace`, para
    # manter a região `aria-live` do partial e o anúncio da quantidade nova.
    def respond_with_quantity(quantity, **flash_options)
      respond_to do |format|
        format.html { redirect_back_with(**flash_options) }
        format.turbo_stream do
          flash.now[:notice] = flash_options[:notice] if flash_options[:notice]
          flash.now[:alert] = flash_options[:alert] if flash_options[:alert]

          render turbo_stream: [
            turbo_stream.update(helpers.dom_id(@card, :deck_entry), partial: "decks/card_controls",
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
