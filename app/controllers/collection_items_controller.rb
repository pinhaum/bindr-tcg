# Incremento e decremento da posse de uma **variante** (Req. 7.2 / COL-07).
#
# A rota opera por `card_variant_id`, e **não** por id de `collection_item`:
# o botão "+1" nasce na grade do catálogo, onde na imensa maioria das vezes
# ainda não existe registro de coleção nenhum. Exigir um id de item forçaria
# uma leitura prévia só para descobrir que não há o que ler, ou criar linhas
# zeradas para o catálogo inteiro só para ter o que incrementar. O registro é
# encontrado-ou-criado a partir do par (`Current.user`, variante), que é a
# chave natural que o `UNIQUE (user_id, card_variant_id)` já protege.
#
# Consequência para a autorização: não existe id de item na URL, logo não
# existe id de item de outro usuário a recusar. O usuário vem sempre de
# `Current.user` (Req. 6.5), e `params` só contribui com a variante — que é
# catálogo público, igual para todo mundo. `CollectionItem.for_user` continua
# sendo o único caminho de leitura, de modo que uma rota futura por id de item
# cai em `RecordNotFound` sem precisar de checagem própria.
#
# Uma requisição por operação, sem formulário intermediário: `POST` direto,
# sem `new` nem `edit`.
class CollectionItemsController < ApplicationController
  # Nenhuma declaração de acesso público: o default de `ApplicationController`
  # exige sessão, e é ele que atende o Req. 6.4 — o anônimo é redirecionado
  # para a autenticação **antes** da action rodar, então a alteração não chega
  # a ser aplicada.

  before_action :set_card_variant

  # Req. 7.2 — o SQL atômico (e o porquê dele) mora em `CollectionItem`.
  def increment
    quantity = CollectionItem.increment_for!(Current.user, @card_variant)

    respond_with_quantity quantity, notice: "Você tem #{quantity} cópia(s) desta variante."
  end

  # Req. 7.4 / COL-09 — o piso de zero é do `WHERE` em `CollectionItem.decrement_for!`.
  def decrement
    quantity = CollectionItem.decrement_for!(Current.user, @card_variant)

    if quantity.nil?
      # Nenhuma linha afetada: a quantidade corrente é o que já estava lá — zero
      # se a linha existe, zero também se ela não existe. O Stream reafirma o
      # estado em vez de não responder nada, senão o botão desabilitado
      # renderizado com a página velha continuaria contando uma história que o
      # servidor não confirmou.
      respond_with_quantity current_quantity,
        alert: "Você não tem cópias desta variante para remover."
    else
      respond_with_quantity quantity, notice: "Você tem #{quantity} cópia(s) desta variante."
    end
  end

  private
    # A variante é catálogo público: um id inválido é 404, e não vazamento de
    # nada — todo mundo enxerga o mesmo catálogo. O usuário **não** sai daqui.
    def set_card_variant
      @card_variant = CardVariant.find(params[:card_variant_id])
    end

    # Req. 7.5 / COL-10 — a mesma operação responde de duas formas, e as duas
    # são caminho de produção.
    #
    # Com o Turbo carregado, o `POST` do `button_to` chega com
    # `text/vnd.turbo-stream.html` no `Accept` e a resposta troca **só** o
    # contêiner daquela variante: a página não recarrega, a rolagem da grade
    # não volta ao topo e nada além da quantidade muda.
    #
    # **Sem JavaScript, `format.html` responde o mesmo `redirect_back` da T6.**
    # Ele não é resíduo nem provisório: os Edge Cases da spec exigem que
    # incremento e decremento continuem funcionando por submissão normal, com
    # recarga. O Req. 7.5 é melhoria progressiva, não pré-requisito de
    # funcionamento — por isso o `format.html` vem **primeiro** e é o default de
    # quem não pediu Stream.
    #
    # `turbo_stream.update` e não `replace`: `update` troca os filhos e mantém o
    # elemento, que é o que preserva a região `aria-live` do partial. `replace`
    # trocaria o próprio nó, e uma região viva recém-inserida no DOM não
    # anuncia — a mudança de quantidade passaria em silêncio para quem usa
    # leitor de tela.
    def respond_with_quantity(quantity, **flash_options)
      respond_to do |format|
        format.html { redirect_back_with(**flash_options) }
        format.turbo_stream do
          # `flash.now`, não `flash`: a mensagem é renderizada **nesta**
          # resposta. `flash` a guardaria na sessão e ela reapareceria na
          # próxima navegação, fora de contexto.
          flash.now[:notice] = flash_options[:notice] if flash_options[:notice]
          flash.now[:alert] = flash_options[:alert] if flash_options[:alert]

          render turbo_stream: [
            turbo_stream.update(
              helpers.dom_id(@card_variant, :ownership),
              partial: "collection_items/ownership",
              locals: { variant: @card_variant, card: @card_variant.card, quantity: quantity.to_i }
            ),
            # Os dois são atualizados sempre, inclusive para limpar o que
            # sobrou da operação anterior: sem isto, a recusa de um decremento
            # ficaria na tela junto com o sucesso do incremento seguinte.
            turbo_stream.update("flash_notice", partial: "layouts/flash_message",
                                                locals: { message: flash[:notice], kind: "notice" }),
            turbo_stream.update("flash_alert", partial: "layouts/flash_message",
                                               locals: { message: flash[:alert], kind: "alert" })
          ]
        end
      end
    end

    # A quantidade que está no banco agora, para o caso em que o `UPDATE` não
    # afetou linha nenhuma. Parte de `Current.user` como todo o resto (Req. 6.5)
    # e devolve zero quando não há registro — que é o mesmo que o usuário vê.
    def current_quantity
      CollectionItem.for_user(Current.user)
                    .where(card_variant: @card_variant)
                    .pick(:quantity)
                    .to_i
    end

    # O redirect da T6, intocado: é o caminho sem JavaScript.
    #
    # `allow_other_host: false` é explícito de propósito, embora hoje seja
    # redundante: `config.load_defaults 8.0` liga `raise_on_open_redirects`, e
    # é dele que sai o default do parâmetro. A garantia seria **indireta** —
    # igual à do `secure` do cookie de sessão, já registrada como dívida — e o
    # destino aqui vem do header `Referer`, que é do cliente. Fixar localmente
    # custa uma palavra e tira o comportamento da dependência de uma config
    # global que ninguém relaciona com esta linha. Um `Referer` de outro host
    # cai no `fallback_location`; há teste para isso.
    def redirect_back_with(**flash_options)
      redirect_back fallback_location: catalog_path, allow_other_host: false, **flash_options
    end
end
