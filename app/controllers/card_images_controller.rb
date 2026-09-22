# Endpoint público para servir arte das cartas em cache.
#
# **Segurança (AD-012):**
# - Autorização: público, sem autenticação (`allow_unauthenticated_access`).
# - A URL de saída vem do banco, nunca do request — parâmetro `url` é ignorado.
# - `variant_code` é validado contra padrão esperado antes de qualquer consulta.
# - Falha de SSRF ou path traversal → 404; falha da fonte → 502.
#
# **Cache HTTP:**
# - Cacheável por um ano (o arquivo só muda se a arte mudar sob o mesmo código).
class CardImagesController < ApplicationController
  allow_unauthenticated_access

  def show
    # Valida formato de `variant_code` antes de qualquer consulta.
    # IMG-09: invalido → 404 sem consultar a fonte.
    pattern = /\A[A-Za-z0-9]+(-[A-Za-z0-9]+)*(_[a-z0-9]+)?\z/
    unless params[:variant_code].match?(pattern)
      return head :not_found
    end

    variant = CardVariant.find_by(variant_code: params[:variant_code])

    # IMG-11: variante inexistente ou sem `image_url` → 404 sem corpo.
    return head :not_found if variant.nil? || variant.image_url.blank?

    # IMG-05, IMG-06: baixa (primeira vez) ou serve do disco.
    result = CardImageCache.new.fetch(variant)

    # IMG-07: cache HTTP de um ano (31536000 segundos).
    expires_in 1.year, public: true
    send_file result.path, type: result.content_type, disposition: "inline"
  rescue CardImageCache::NotFound
    # IMG-11: variante sem `image_url`, sem corpo.
    head :not_found
  rescue CardImageCache::Unavailable
    # IMG-12: falha de rede ou fonte → 502, sem corpo.
    head :bad_gateway
  end
end
