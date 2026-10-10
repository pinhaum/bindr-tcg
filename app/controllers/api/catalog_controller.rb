class Api::CatalogController < Api::BaseController
  allow_unauthenticated_access

  # O usuário do filtro de posse vem só da sessão, em argumento próprio: um
  # `user_id` em `params` nunca chega ao `CatalogQuery` (API-20).
  def index
    @result = CatalogQuery.new(params, Current.user).call
    Card.preload_present_variants(@result.records)
    ActiveRecord::Associations::Preloader.new(records: @result.records, associations: :card_set).call
    variants = @result.records.flat_map(&:card_variants)
    ActiveRecord::Associations::Preloader.new(records: variants, associations: :card_set).call
    @holdings = VariantHoldings.new(Current.user, variants)
  end

  def filters
    @options = CatalogQuery.filter_options
  end
end
