# Ponto de entrada único que traduz parâmetros de URL em consulta ao catálogo
# (`design.md` §4.2). Serve HTML e JSON, e é o único lugar que precisa de teste
# de filtro.
#
# Duas regras estruturam tudo aqui:
#
# 1. **`OU` dentro da categoria, `E` entre categorias** (Req. 4.3 e 4.4). Cada
#    categoria vira um predicado; os predicados se encadeiam por `where`, que é
#    `E`. O `OU` mora dentro de cada predicado — sobreposição de arrays para
#    `colors`/`traits`/`attributes_list`, `IN` para colunas escalares.
# 2. **Parâmetro desconhecido ou inválido é ignorado, nunca levanta erro.** Uma
#    URL compartilhada não pode dar 500 porque um filtro foi renomeado. Toda
#    entrada passa por um saneador que devolve `nil` no lugar de explodir, e o
#    que for descartado também não aparece nos filtros ativos — o chip só
#    representa filtro que está de fato valendo.
#
# A busca por consulta (`q`) é acrescentada pela T11 em `CatalogSearch`; aqui só
# entram filtros, ordenação e paginação.
class CatalogQuery
  DEFAULT_PER_PAGE = 24
  MAX_PER_PAGE = 100

  # Colunas de array no Postgres. `&&` ("tem elemento em comum") é o que faz o
  # filtro de cor incluir multicoloridas (Req. 4.5): `['Red','Blue'] && ['Red']`
  # é verdadeiro. Igualdade de array perderia exatamente esse caso.
  ARRAY_FILTERS = {
    colors: :colors,
    traits: :traits,
    attributes: :attributes_list
  }.freeze

  # Colunas escalares de `cards`: `OU` dentro da categoria é o próprio `IN`.
  SCALAR_FILTERS = { card_types: :card_type }.freeze

  # Estes dois não são colunas de `cards`: uma carta pode ter variantes em sets
  # diferentes do seu set de estreia (1402 casos no catálogo real), então o
  # filtro tem que passar por `card_variants` via EXISTS. Filtrar por
  # `cards.set_id` daria falso negativo em toda reimpressão.
  VARIANT_FILTERS = { sets: :code, rarities: :rarity }.freeze

  RANGE_FILTERS = %i[cost power counter].freeze

  SORTABLE = %w[card_number name cost power].freeze
  DIRECTIONS = %w[asc desc].freeze

  Result = Struct.new(:records, :total_count, :page, :per_page, :active_filters,
                      keyword_init: true) do
    def total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
  end

  def initialize(params = {})
    @params = normalize_keys(params)
    @active_filters = {}
  end

  def call
    scope = filtered_scope
    total = scope.count
    page = sanitized_page
    per_page = sanitized_per_page

    Result.new(
      records: paginate(ordered(scope), page, per_page).to_a,
      total_count: total,
      page: page,
      per_page: per_page,
      active_filters: @active_filters.freeze
    )
  end

  # Exposto para a T11 encadear a busca textual sobre os mesmos filtros, e para
  # a contagem de página do controller.
  def filtered_scope
    scope = base_scope
    scope = apply_array_filters(scope)
    scope = apply_scalar_filters(scope)
    scope = apply_variant_filters(scope)
    apply_range_filters(scope)
  end

  def active_filters = @active_filters

  private

  def base_scope = Card.all

  # Aceita tanto `ActionController::Parameters` quanto Hash de símbolo ou
  # string, sem exigir que o chamador saiba qual é qual.
  def normalize_keys(params)
    raw = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params
    raw.to_h.transform_keys(&:to_sym)
  end

  def apply_array_filters(scope)
    ARRAY_FILTERS.reduce(scope) do |current, (param, column)|
      values = sanitized_list(param)
      next current if values.blank?

      @active_filters[param] = values
      current.where("#{column} && ARRAY[?]::text[]", values)
    end
  end

  def apply_scalar_filters(scope)
    SCALAR_FILTERS.reduce(scope) do |current, (param, column)|
      values = sanitized_list(param)
      next current if values.blank?

      @active_filters[param] = values
      current.where(column => values)
    end
  end

  def apply_variant_filters(scope)
    VARIANT_FILTERS.reduce(scope) do |current, (param, column)|
      values = sanitized_list(param)
      next current if values.blank?

      @active_filters[param] = values
      current.where(id: variant_card_ids(column, values))
    end
  end

  def variant_card_ids(column, values)
    relation = CardVariant.select(:card_id)
    column == :code ? relation.joins(:card_set).where(sets: { code: values }) : relation.where(column => values)
  end

  # `counter` NULL significa "não tem counter", nunca counter 0. Comparação com
  # NULL já devolve NULL em SQL, então a carta sem counter cai fora da faixa
  # por construção — o cuidado aqui é não introduzir um `COALESCE(counter, 0)`
  # que a transformaria em counter 0.
  def apply_range_filters(scope)
    RANGE_FILTERS.reduce(scope) do |current, column|
      min = sanitized_integer(:"#{column}_min")
      max = sanitized_integer(:"#{column}_max")
      next current if min.nil? && max.nil?

      @active_filters[:"#{column}_min"] = min unless min.nil?
      @active_filters[:"#{column}_max"] = max unless max.nil?

      current = current.where(current.arel_table[column].gteq(min)) unless min.nil?
      max.nil? ? current : current.where(current.arel_table[column].lteq(max))
    end
  end

  def ordered(scope)
    column = SORTABLE.include?(@params[:sort].to_s) ? @params[:sort].to_s : "card_number"
    direction = DIRECTIONS.include?(@params[:dir].to_s) ? @params[:dir].to_s : "asc"

    @active_filters[:sort] = column unless column == "card_number" && direction == "asc"
    @active_filters[:dir] = direction unless column == "card_number" && direction == "asc"

    # `card_number` como desempate deixa a paginação determinística: sem ele,
    # ordenar por uma coluna com repetição (ou anulável) pode devolver a mesma
    # carta em duas páginas.
    scope.order(Arel.sql("#{column} #{direction} NULLS LAST"), card_number: :asc)
  end

  def paginate(scope, page, per_page)
    scope.limit(per_page).offset((page - 1) * per_page)
  end

  def sanitized_page
    value = sanitized_integer(:page)
    value.nil? || value < 1 ? 1 : value
  end

  def sanitized_per_page
    value = sanitized_integer(:per_page)
    return DEFAULT_PER_PAGE if value.nil? || value < 1

    value.clamp(1, MAX_PER_PAGE)
  end

  # Valor vazio, em branco ou duplicado não vira filtro — é ruído de formulário,
  # não intenção do usuário.
  def sanitized_list(param)
    Array(@params[param]).filter_map do |value|
      text = value.to_s.strip
      text.presence
    end.uniq
  end

  # Devolve `nil` para qualquer coisa que não seja inteiro. `Integer(..., 10)`
  # em vez de `to_i` porque `"abacaxi".to_i` é 0 — um filtro silenciosamente
  # errado é pior que um filtro ignorado.
  def sanitized_integer(param)
    value = @params[param]
    return nil if value.nil? || value.to_s.strip.empty?

    Integer(value.to_s.strip, 10)
  rescue ArgumentError, TypeError
    nil
  end
end
