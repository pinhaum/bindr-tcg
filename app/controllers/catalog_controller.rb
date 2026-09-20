# Grade do catálogo (Req. 2). O controller não conhece filtro nenhum: ele
# repassa os parâmetros crus ao `CatalogQuery`, que é o único lugar que traduz
# URL em consulta (design.md §4.2). Acrescentar um filtro novo não deve tocar
# este arquivo.
#
# Catálogo é público (Req. 6.3), e é a única exceção ao default de
# `ApplicationController`, que exige sessão em toda action. A liberação é
# declarada aqui, na classe, e não por rota: um filtro novo ou uma action nova
# deste controller herdam o acesso público sem precisar lembrar de nada. Toda
# mutação continua exigindo sessão porque vive em outro controller.
class CatalogController < ApplicationController
  allow_unauthenticated_access

  def index
    # O usuário do filtro de posse (Req. 7.6 / COL-11) vai por argumento
    # próprio, separado de `params`: o query object não tem caminho de `params`
    # para o usuário, então `?owned=owned&user_id=7` não lê a coleção de
    # ninguém. `authenticated?` antes, pelo mesmo motivo de
    # `#owned_quantities` — `allow_unauthenticated_access` não resolve a sessão,
    # e sem esta chamada `Current.user` seria `nil` aqui e o filtro sairia
    # silenciosamente ignorado para quem está autenticado.
    authenticated?

    @query = CatalogQuery.new(params, Current.user)
    @result = @query.call

    # `preload` e não `includes`: o `CatalogQuery` monta a página em Ruby (o
    # match exato é prependido a um array), então o que chega aqui é um Array
    # de `Card`, não uma relação. `preload` aceita o array e resolve as
    # variantes em **uma** consulta. Sem isto, o tile dispararia uma consulta
    # por carta só para descobrir quantas impressões ela tem.
    ActiveRecord::Associations::Preloader.new(
      records: @result.records, associations: :card_variants
    ).call

    @owned_quantities = owned_quantities(@result.records.flat_map(&:card_variants))
    @owned_total = owned_total
  end

  def show
    @card = Card.includes(card_variants: :card_set).find_by!(card_number: params[:id])
    @variants = @card.card_variants.sort_by { |variant| variant.variant_code }
    @owned_quantities = owned_quantities(@variants)
    @wishlist_targets = wishlist_targets(@variants)
  end

  private
    # Total de **cópias** da coleção inteira (Req. 7.7 / COL-12), em uma consulta
    # agregada por request.
    #
    # **Não é a soma de `@owned_quantities`.** Aquele hash cobre só as variantes
    # da página corrente e existe para exibição por tile: somá-lo daria o total
    # *da página*, um número que mudaria a cada paginação e a cada filtro. O
    # requisito pede o total da coleção, que não depende do recorte na tela.
    #
    # A soma em si mora em `CollectionItem.total_copies_for`, com a justificativa
    # de `sum` contra `count`: o Turbo Stream da posse também a re-renderiza, e
    # duas somas escritas à mão divergiriam na primeira mudança de critério.
    #
    # `authenticated?` antes de ler `Current.user`, pelo mesmo motivo de
    # `#owned_quantities`: `allow_unauthenticated_access` não resolve a sessão, e
    # sem a chamada o total sairia **zero para todo usuário autenticado**, com a
    # página respondendo 200. Para o anônimo, `for_user(nil)` é `none` e a soma é
    # zero — quem decide **não renderizar** nada é a view, não este número.
    def owned_total
      authenticated?

      CollectionItem.total_copies_for(Current.user)
    end

    # Um hash `card_variant_id => quantity` para as variantes desta página, em
    # **uma** consulta (Req. 5.3 / COL-18: o controle aparece por variante, na
    # grade e no detalhe — perguntar a posse variante a variante seria N+1).
    #
    # A consulta parte de `CollectionItem.for_user(Current.user)` e de mais
    # nada: o usuário vem da sessão, nunca do request (Req. 6.5). Para o
    # anônimo, `for_user(nil)` é `none` e o resultado é hash vazio — sem
    # consulta ao banco e sem ramo especial aqui.
    #
    # `authenticated?` **antes** de ler `Current.user`, e isso não é cerimônia.
    # Este controller declara `allow_unauthenticated_access`, que remove o
    # `before_action :require_authentication` — e era ele que resolvia a sessão
    # a partir do cookie assinado. Sem esta chamada, `Current.session` ainda é
    # `nil` aqui e **todo usuário autenticado veria quantidade zero**, porque a
    # sessão só seria resolvida mais tarde, quando a view chamasse
    # `authenticated?` para decidir se mostra os botões. O defeito é silencioso:
    # a página responde 200, os controles aparecem e a posse some.
    #
    # `resume_session` é idempotente (`Current.session ||= ...`), então a
    # chamada da view não repete a consulta.
    def owned_quantities(variants)
      authenticated?

      CollectionItem.for_user(Current.user)
                    .where(card_variant_id: variants.map(&:id))
                    .pluck(:card_variant_id, :quantity)
                    .to_h
    end

    # Um hash `card_variant_id => target_quantity` para as impressões desta
    # carta, em **uma** consulta (Req. 8.1 / COL-14): o formulário de desejo
    # aparece por variante no detalhe, e perguntar item a item dentro do loop
    # seria N+1 — o mesmo problema que `#owned_quantities` resolve para a posse.
    #
    # `authenticated?` **antes** de ler `Current.user`, pela quinta vez nesta
    # feature e pelo mesmo motivo: `allow_unauthenticated_access` remove o
    # `before_action :require_authentication`, que era quem chamava
    # `resume_session`. Sem esta chamada, `Current.user` seria `nil` aqui e
    # **todo usuário autenticado veria "Quero esta" numa impressão que já está
    # na sua lista**, com a página respondendo 200 — defeito silencioso.
    #
    # `for_user(nil)` é `none` para o anônimo: hash vazio, sem consulta e sem
    # ramo especial. Quem decide não renderizar o formulário é a view.
    #
    # **A chamada é redundante hoje e não deve ser removida**, exatamente como a
    # de `#owned_total` (T11). `#show` chama `#owned_quantities` uma linha antes,
    # e ela já resolveu a sessão — o sensor da T13 confirmou que remover **só**
    # esta chamada sobrevive. Removidas as duas, porém, o formulário volta a
    # dizer "Quero esta" para uma impressão que já está na lista do usuário, com
    # a página em 200, e um teste morre. A redundância existe para que uma
    # reordenação futura de `#show` não reintroduza o defeito silencioso.
    def wishlist_targets(variants)
      authenticated?

      WishlistItem.for_user(Current.user)
                  .where(card_variant_id: variants.map(&:id))
                  .pluck(:card_variant_id, :target_quantity)
                  .to_h
    end
end
