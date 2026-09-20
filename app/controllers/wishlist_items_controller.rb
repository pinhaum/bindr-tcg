# Wishlist do usuário da sessão: marcar, listar e remover (Req. 8.1/8.2/8.4 —
# COL-14, COL-15, COL-17), com "atendido" (Req. 8.3 / COL-16) derivado na
# consulta.
#
# **Nenhuma declaração de acesso público.** O default de `ApplicationController`
# exige sessão em toda action, e é ele que atende o Req. 6.4: o anônimo é
# redirecionado para a autenticação **antes** da action rodar, então nem a
# listagem nem a escrita chegam a acontecer. Consequência: a armadilha do
# `allow_unauthenticated_access` — que fez `Current.user` ser `nil` dentro de
# actions públicas quatro vezes nesta feature — não existe aqui, e
# `authenticated?` não deve ser acrescentado por reflexo. O
# `require_authentication` já resolveu a sessão quando a action começa.
#
# **A rota de remoção opera por id de `wishlist_items`**, ao contrário do
# `CollectionItemsController`, que opera por `card_variant_id`. A diferença é
# de desenho e não de gosto: o "+1" da posse nasce na grade do catálogo, onde o
# registro de coleção normalmente ainda não existe; remover da wishlist parte
# da própria lista, onde o item existe por definição e tem id. É essa rota que
# torna real o critério 4 da história "P1: Isolamento entre usuários" — o 404
# por id alheio —, que a T7 registrou como `SPEC_DEVIATION` por não ter, no
# desenho da posse, nenhuma URL onde um id coubesse.
class WishlistItemsController < ApplicationController
  # Req. 8.2 / COL-15 — **apenas** os itens do usuário da sessão.
  #
  # `WishlistItem.for_user(Current.user)` é o único ponto de entrada, e ele
  # aceita um `User` (nunca um id), de modo que `?user_id=7` não tem por onde
  # entrar na consulta. O Req. 6.5 fica satisfeito por construção.
  def index
    @items = WishlistItem.for_user(Current.user).with_fulfillment
  end

  # Req. 8.1 / COL-14 — marcar uma variante como desejada com alvo inteiro
  # maior que zero.
  #
  # A variante vem do request porque ela é catálogo público, igual para todo
  # mundo; o usuário **não** vem — sai de `Current.user`. Um id de variante
  # inexistente é 404 pelo `find`, e isso não vaza nada de ninguém.
  #
  # O alvo inválido (zero, negativo, texto) vira mensagem em português em vez
  # de 500: a validação do model existe exatamente para isso. A garantia real
  # continua sendo o `CHECK (target_quantity >= 1)` do banco, que nenhuma
  # corrida atravessa — a validação só a antecipa para poder falar com o
  # usuário.
  def create
    variant = CardVariant.find(params[:card_variant_id])
    item = WishlistItem.for_user(Current.user).find_or_initialize_by(card_variant: variant)
    item.target_quantity = params[:target_quantity]

    if item.save
      redirect_back_to_origin notice: "#{variant.card.name} #{variant.variant_code} " \
                                      "na lista de desejos: #{item.target_quantity} cópia(s)."
    else
      redirect_back_to_origin alert: "Não foi possível salvar o desejo: " \
                                     "#{item.errors.full_messages.to_sentence}."
    end
  end

  # Req. 8.4 / COL-17 — remover um item.
  #
  # **`for_user(Current.user).find(params[:id])`, e nunca `find_by` seguido de
  # `if nil`.** A diferença é o critério 4 da história de isolamento inteiro:
  # `find` dentro do escopo do usuário levanta `RecordNotFound` quando o id é
  # de outro usuário, e o Rails traduz isso em **404** — a mesma resposta que
  # um id inexistente. Um `find_by` com checagem de dono responderia 403 (ou
  # 200 com mensagem), e aí a diferença entre "não existe" e "existe mas não é
  # seu" viraria um oráculo de quais itens outras pessoas desejam.
  #
  # Não há checagem de dono espalhada porque não há o que checar: o escopo é o
  # usuário, e fora dele o registro simplesmente não é encontrável.
  def destroy
    item = WishlistItem.for_user(Current.user).find(params[:id])
    item.destroy!

    redirect_to wishlist_items_path, notice: "Item removido da lista de desejos."
  end

  private
    # O "marcar como desejada" nasce na página de detalhe da carta, e devolver
    # o usuário para lá é o que permite marcar várias impressões em sequência.
    # `allow_other_host: false` explícito pela mesma razão do
    # `CollectionItemsController`: o destino vem do header `Referer`, que é do
    # cliente, e a garantia não deve depender de uma config global que ninguém
    # relaciona com esta linha.
    def redirect_back_to_origin(**flash_options)
      redirect_back fallback_location: wishlist_items_path, allow_other_host: false, **flash_options
    end
end
