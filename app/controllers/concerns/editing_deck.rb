# O deck em edição: aquele que recebe as cartas pelo detalhe da carta (DCK-03,
# DCK-04). Mora em `session[:editing_deck_id]`, o cookie de sessão do Rails, já
# assinado (design.md, Tech Decisions).
#
# O valor guardado é só um id, e **nunca é confiado**: toda leitura o revalida
# por `Current.user.decks.find_by`. Um id adulterado, o de um deck excluído ou
# o de um deck de outro usuário dão `nil`, e a chave sai da sessão. Login e
# logout chamam `reset_session`, então a herança entre contas no mesmo
# navegador já não traz id alheio; a revalidação não depende disso. É isso que faz o DCK-41 sair de graça e mantém o DCK-36.
#
# `authenticated?` vem antes de `Current.user`: num controller público, como o
# do catálogo, `allow_unauthenticated_access` tira o `before_action` que
# resolvia a sessão, e sem esta chamada `Current.user` seria `nil` e o controle
# de deck sumiria calado para quem está logado.
module EditingDeck
  extend ActiveSupport::Concern

  included do
    helper_method :editing_deck
  end

  private
    def editing_deck
      return @editing_deck if defined?(@editing_deck)

      @editing_deck = find_editing_deck
    end

    def start_editing(deck)
      session[:editing_deck_id] = deck.id
      @editing_deck = deck
    end

    def find_editing_deck
      return unless authenticated? && session[:editing_deck_id]

      Current.user.decks.find_by(id: session[:editing_deck_id]).tap do |deck|
        session.delete(:editing_deck_id) if deck.nil?
      end
    end
end
