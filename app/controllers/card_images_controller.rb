# Endpoint público para servir arte das cartas em cache.
#
# **Segurança (AD-012):**
# - Autorização: público, sem autenticação (`allow_unauthenticated_access`).
# - A URL de saída vem do banco, nunca do request — parâmetro `url` é ignorado.
# - `variant_code` é validado contra padrão esperado antes de qualquer consulta.
# - `variant_code` inválido, variante inexistente ou sem `image_url` → 404.
# - URL recusada (host/esquema/porta/extensão), falha de rede, timeout ou corpo
#   grande demais da fonte → 502.
#
# **Cache HTTP:**
# - Cacheável por um ano (o arquivo só muda se a arte mudar sob o mesmo código).
class CardImagesController < ApplicationController
  allow_unauthenticated_access

  def show
    # Valida formato de `variant_code` antes de qualquer consulta;
    # inválido → 404 sem consultar o banco ou a fonte.
    unless params[:variant_code].match?(CardImageCache::VARIANT_CODE_FORMAT)
      return head :not_found
    end

    variant = CardVariant.find_by(variant_code: params[:variant_code])

    # Variante inexistente ou sem `image_url` → 404 sem corpo.
    return head :not_found if variant.nil? || variant.image_url.blank?

    # Busca e serve (primeira vez baixa, próximas vezes servem do disco).
    result = CardImageCache.new.fetch(variant)

    # Cache HTTP de um ano (31536000 segundos).
    expires_in 1.year, public: true
    send_file result.path, type: result.content_type, disposition: "inline"
  rescue CardImageCache::NotFound
    # Path traversal, formato inválido ou sem image_url.
    head :not_found
  rescue CardImageCache::Unavailable
    # URL recusada, timeout, falha de rede, ou corpo grande demais.
    head :bad_gateway
  end
end
