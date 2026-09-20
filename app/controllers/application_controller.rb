class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Inverte o default do app: a partir daqui toda action exige sessão (Req.
  # 6.4) e o acesso público é exceção declarada com `allow_unauthenticated_access`
  # — hoje só o `CatalogController` (Req. 6.3).
  include Authentication
end
