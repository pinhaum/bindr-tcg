# Envio do CSV da coleção (SPOR-36, SPOR-37, SPOR-43). Grava só a
# pré-visualização; `collection_items` nunca é tocada aqui. Sem
# `allow_unauthenticated_access` nem `skip_forgery_protection`: sessão e CSRF
# vêm do base, e o dono é sempre `Current.user` — `user_id` do request não é lido.
class Api::CollectionImportsController < Api::BaseController
  REFUSAL_MESSAGE = "O arquivo não foi importado. Sua coleção não foi alterada.".freeze

  CLASSIFICATIONS = {
    zera: "removes",
    cria: "creates",
    atualiza: "updates",
    rejeita: "rejected",
    inalterada: "unchanged"
  }.freeze

  # Sem filtro de prazo (SPOR-38): reler a pré-visualização não confirma nada.
  # Token alheio, inexistente e malformado caem no mesmo 404 do base (SPOR-39).
  def show
    @collection_import = CollectionImport.find_by_token_for(Current.user, params[:token])
    raise ActiveRecord::RecordNotFound if @collection_import.nil?
  end

  def create
    result = CollectionCsv::Upload.new(Current.user, params[:file], request.content_length).call

    if result.aceito?
      @collection_import = result.preview
      render :create, status: :created
    else
      render_error(:unprocessable_entity, "validation_failed", REFUSAL_MESSAGE, { file: [ result.error ] })
    end
  end
end
