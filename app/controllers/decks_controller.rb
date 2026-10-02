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

  # Leader, entradas e cartas vêm pelo `includes`, e "fora da fonte" sai de
  # uma consulta só: o número de consultas da página não cresce com o número
  # de entradas.
  def show
    @deck = Current.user.decks.includes(:leader, entries: :card).find(params[:id])
    @legality = @deck.legality
    @absent_card_ids = absent_card_ids(@deck)
    # DCK-21..23 — pedida, possuída e falta, derivadas da coleção atual numa
    # consulta, sem nada gravado.
    @shortfall = DeckShortfallQuery.new(Current.user, deck: @deck).call.index_by { |row| row.card.id }
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
    # DCK-19 — a carta está "fora da fonte" quando nenhuma variante dela está
    # presente (`CardVariant::PRESENT_SQL`), a mesma regra do catálogo. Ela
    # continua no deck e contando para as regras: só ganha a marca.
    def absent_card_ids(deck)
      ids = [ deck.leader_card_id, *deck.entries.map(&:card_id) ].compact
      ids.to_set - CardVariant.present.where(card_id: ids).distinct.pluck(:card_id)
    end

    # Só o nome: Leader e entradas mudam pelas próprias rotas, nunca pelo
    # formulário do deck.
    def deck_params
      params.expect(deck: [ :name ])
    end
end
