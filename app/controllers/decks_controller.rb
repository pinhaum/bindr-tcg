# Os decks do usuário da sessão (Req. 14 / DCK-01, DCK-08).
#
# Nenhuma declaração de acesso público: o default de `ApplicationController`
# exige sessão, e o anônimo é redirecionado para o login antes da action rodar,
# sem aplicar nada (DCK-37).
#
# Todo acesso parte de `Current.user.decks`, nunca de um `user_id` do request
# (Req. 6.5). Um id de deck de outro usuário cai em `RecordNotFound` e responde
# 404, o mesmo de um id que não existe: a resposta não revela que o deck existe
# (DCK-36).
class DecksController < ApplicationController
  include EditingDeck

  # O status vem de `Deck#legality`, calculado sobre as entradas carregadas. O
  # `includes` carrega Leader, entradas e cartas de todos os decks em consultas
  # fixas, sem uma por deck (design.md, Tech Decisions).
  def index
    @decks = Current.user.decks.includes(:leader, entries: :card).order(:name, :id)
  end

  def new
    @deck = Current.user.decks.new
  end

  # O deck nasce vazio, sem Leader e sem entradas (DCK-01), e já em edição:
  # o fluxo do Independent Test (criar, abrir o detalhe, usar o Leader) não
  # precisa de um passo a mais (design.md, Tech Decisions).
  def create
    @deck = Current.user.decks.new(deck_params)

    if @deck.save
      start_editing(@deck)
      redirect_to @deck, notice: "Deck criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Leitura, retrato único e "fora da fonte" vêm de `DeckDetail`: o número de
  # consultas da página não cresce com o número de entradas.
  def show
    detail = DeckDetail.new(user: Current.user, deck_id: params[:id]).call
    @deck = detail.deck
    @legality = detail.legality
    @absent_card_ids = detail.absent_card_ids
    @shortfall = detail.shortfall_by_card_id
  end

  def edit
    @deck = Current.user.decks.find(params[:id])
  end

  # DCK-10 — renomear muda só o nome; Leader e entradas não passam por aqui.
  def update
    @deck = Current.user.decks.find(params[:id])

    if @deck.update(deck_params)
      redirect_to @deck, notice: "Deck renomeado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Troca o deck em edição. O deck sai de `Current.user.decks`, então o de
  # outro usuário é 404 e a sessão não muda (DCK-36).
  def select
    deck = Current.user.decks.find(params[:id])
    start_editing(deck)

    redirect_to deck, notice: "Agora as cartas vão para o deck “#{deck.name}”."
  end

  # DCK-09 — a confirmação. Só lê: nada é apagado num `GET`.
  def delete
    @deck = Current.user.decks.find(params[:id])
  end

  # DCK-09 — apaga o deck e as entradas dele, e nada mais: coleção e wishlist
  # não têm FK para `decks`.
  def destroy
    deck = Current.user.decks.find(params[:id])
    deck.destroy!

    redirect_to decks_path, notice: "Deck “#{deck.name}” excluído."
  end

  private
    # Só o nome: Leader e entradas mudam pelas próprias rotas, nunca pelo
    # formulário do deck.
    def deck_params
      params.expect(deck: [ :name ])
    end
end
