# Leitura, criação e renomeação dos decks do usuário da sessão (SDEC-43..46,
# SDEC-47, SDEC-60). Sem
# `allow_unauthenticated_access`: o default do base exige sessão. O deck sai
# sempre de `Current.user.decks`, então o de outro usuário é `RecordNotFound`
# (404, igual ao id inexistente) e `user_id` do request nunca é lido.
class Api::DecksController < Api::BaseController
  include EditingDeck

  # Mesmo `includes` da lista HTML: o status de cada deck sai de `Deck#legality`
  # sobre entradas carregadas, em consultas fixas.
  def index
    @decks = Current.user.decks.includes(:leader, entries: :card).order(:name, :id)
  end

  def show
    render_deck
  end

  # O deck nasce vazio e já em edição, como no HTML (SDEC-44). Só `name` é
  # lido, e só como `String`: `user_id`, Leader e entradas do corpo são ignorados.
  def create
    deck = Current.user.decks.new(name: name_param)
    return render_name_errors(deck) unless deck.save

    start_editing(deck)
    render_deck(deck.id, status: :created)
  end

  # SDEC-45 — muda só o nome; Leader e entradas não passam por aqui.
  def update
    deck = Current.user.decks.find(params[:id])
    return render_name_errors(deck) unless deck.update(name: name_param)

    render_deck(deck.id)
  end

  # SDEC-48 — apaga o deck e as entradas; coleção e wishlist não têm FK para
  # `decks`. Se era o deck em edição, `editing_deck` o descarta da sessão na
  # leitura seguinte (a chave é revalidada por `Current.user.decks`).
  def destroy
    deck = Current.user.decks.find(params[:id])
    deck.destroy!

    render json: { data: { id: deck.id, name: deck.name } }
  end

  # SDEC-49 — grava a mesma chave de sessão que o Hotwire lê; idempotente.
  def select
    deck = Current.user.decks.find(params[:id])
    start_editing(deck)

    render json: { data: { id: deck.id, name: deck.name } }
  end

  # SDEC-59 — o bloco "Faltando para os baralhos" da pasta: o mesmo filtro de
  # `ProgressController#load_deck_shortfall`. Os decks citados vêm numa consulta
  # só, e só quando há linhas.
  def shortfall
    @rows = DeckShortfallQuery.new(Current.user).call.select { |row| row.missing.positive? }
    deck_ids = @rows.flat_map(&:deck_ids).uniq
    @decks = deck_ids.empty? ? {} : Current.user.decks.where(id: deck_ids).pluck(:id, :name).to_h
  end

  private
    # Nome ausente ou que não é texto vale como vazio: a mesma frase de SDEC-46.
    def name_param
      params[:name].is_a?(String) ? params[:name] : ""
    end

    def render_name_errors(deck)
      messages = deck.errors[:name].map { |message| "O nome #{message}." }
      render_error(:unprocessable_entity, "validation_failed", "Dados inválidos.", name: messages)
    end

    def render_deck(deck_id = params[:id], status: :ok)
      detail = DeckDetail.new(user: Current.user, deck_id: deck_id).call
      @deck = detail.deck
      @legality = detail.legality
      @absent_card_ids = detail.absent_card_ids
      @shortfall = detail.shortfall_by_card_id
      @editing = editing_deck&.id == @deck.id
      render :show, status: status
    end
end
