# Progresso da pasta (SPAS-37..41, SPAS-45). Sem `allow_unauthenticated_access`:
# o default do base exige sessão. O usuário é sempre `Current.user`; `user_id`
# do request nunca é lido. Duas consultas fixas, as mesmas da página HTML.
class Api::ProgressController < Api::BaseController
  def show
    query = SetProgressQuery.new(Current.user, order: params[:order])
    @order = query.order
    @rows = query.call
    @stats = CollectionItem.collection_stats_for(Current.user)
  end
end
