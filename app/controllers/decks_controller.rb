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
  # O status vem de `Deck#legality`, calculado sobre as entradas carregadas. O
  # `includes` carrega Leader, entradas e cartas de todos os decks em consultas
  # fixas, sem uma por deck (design.md, Tech Decisions).
  def index
    @decks = Current.user.decks.includes(:leader, entries: :card).order(:name, :id)
  end

  def new
    @deck = Current.user.decks.new
  end

  # O deck nasce vazio, sem Leader e sem entradas (DCK-01).
  def create
    @deck = Current.user.decks.new(deck_params)

    if @deck.save
      redirect_to @deck, notice: "Deck criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @deck = Current.user.decks.find(params[:id])
  end

  private
    # Só o nome: Leader e entradas mudam pelas próprias rotas, nunca pelo
    # formulário do deck.
    def deck_params
      params.expect(deck: [ :name ])
    end
end
