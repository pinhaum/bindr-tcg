# Lista de desejos (SPAS-42, SPAS-45). Sem `allow_unauthenticated_access`: o
# default do base exige sessão. O usuário é sempre `Current.user`; `user_id` do
# request nunca é lido. Três consultas fixas, as mesmas da página HTML.
class Api::WishlistController < Api::BaseController
  def index
    @items = WishlistItem.for_user(Current.user).with_fulfillment
  end
end
