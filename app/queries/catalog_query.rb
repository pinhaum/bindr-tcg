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
# A busca textual (`q`) entra por três caminhos independentes unidos por `OU`
# — nome por trigram, efeito por full-text, `card_number` por substring — e o
# match **exato** de `card_number` é uma consulta separada cujo resultado é
# prependido (Req. 3.4). Ver `#search_scope` e `#call`.
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

  # `word_similarity` (`<%`), não `similarity` (`%`), e limiar 0.5 em vez do
  # default 0.6 — medido contra o catálogo real (2815 cartas) na T11:
  #
  #   similarity('Zorro', 'Roronoa Zoro')      = 0.286  → abaixo do default 0.3
  #   word_similarity('Zorro', 'Roronoa Zoro') = 0.571  → abaixo do default 0.6
  #
  # Com o par default (`%` a 0.3) o Req. 3.3 **falha**: um typo de um caractere
  # em "Zoro" não acha a carta, porque a similaridade da string inteira é
  # diluída pelo sobrenome que o termo não tem. `word_similarity` compara o
  # termo contra a melhor extensão do nome e resolve isso; 0.5 é o limiar que
  # aceita os typos reais testados (Zorro, Namy, Luffi, Belmere) sem inundar o
  # resultado. O operador `<%` continua usando o índice GIN trigram
  # (`Bitmap Index Scan on index_cards_on_unaccent_name_trgm`, verificado por
  # EXPLAIN) — `immutable_unaccent(name)` é obrigatório aqui: com `unaccent`
  # direto o índice não é usado (design.md §4.1.1).
  WORD_SIMILARITY_THRESHOLD = "0.5".freeze

  # Dicionário de dois argumentos: só essa forma de `to_tsvector` é IMMUTABLE,
  # e é a que o índice `index_cards_on_effect_text_tsvector` usa.
  TEXT_SEARCH_CONFIG = "english".freeze

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
    apply_search_threshold

    scope = searchable_scope
    exact = exact_card_number_match(scope)
    # O exato sai do conjunto paginado para não aparecer duas vezes: ele é
    # prependido à página 1 e continua contado uma única vez no total.
    scope = scope.where.not(id: exact.id) if exact

    total = scope.count + (exact ? 1 : 0)
    page = sanitized_page
    per_page = sanitized_per_page

    Result.new(
      records: page_records(scope, exact, page, per_page),
      total_count: total,
      page: page,
      per_page: per_page,
      active_filters: @active_filters.freeze
    )
  end

  # Filtros sem busca textual. Exposto para o controller montar contagens
  # auxiliares sobre o mesmo recorte.
  def filtered_scope
    scope = base_scope
    scope = apply_array_filters(scope)
    scope = apply_scalar_filters(scope)
    scope = apply_variant_filters(scope)
    apply_range_filters(scope)
  end

  # Filtros + busca textual. É sobre este escopo que o match exato de
  # `card_number` é procurado, e é por isso que prepender não passa por cima de
  # um filtro ativo (Req. 3.6).
  def searchable_scope = apply_search(filtered_scope)

  def active_filters = @active_filters

  # Exposto para o teste de plano de execução (Req. 11.3): a asserção é sobre
  # o SQL das ramificações da busca, que é onde os índices são escolhidos.
  def search_match_sql
    apply_search_threshold
    Card.sanitize_sql_array([ SEARCH_MATCH_SQL,
                              search_term,
                              TEXT_SEARCH_CONFIG, TEXT_SEARCH_CONFIG, search_term,
                              "%#{sanitize_like(search_term.upcase)}%" ])
  end

  # Exposto para o teste de plano (Req. 11.3), pelo mesmo motivo de
  # `search_match_sql`.
  def exact_match_sql
    exact_match_scope(searchable_scope).select(:id).to_sql
  end

  private

  def base_scope = Card.all

  # O exato vai à frente da página 1; nas demais páginas ele já foi consumido,
  # então o offset desconta a vaga que ele ocupou.
  def page_records(scope, exact, page, per_page)
    return paginate(ordered(scope), page, per_page).to_a unless exact
    return [ exact ] + ordered(scope).limit(per_page - 1).to_a if page == 1

    [ exact ] + ordered(scope).limit(per_page).offset((page - 1) * per_page - 1).to_a.last(per_page)
  end

  # `SET LOCAL` via `set_config(..., true)`: vale só até o fim da transação
  # corrente e não vaza para outra consulta nem para outra conexão do pool.
  def apply_search_threshold
    return if search_term.blank?

    Card.connection.select_value(
      Card.sanitize_sql_array(
        [ "SELECT set_config('pg_trgm.word_similarity_threshold', ?, true)",
          WORD_SIMILARITY_THRESHOLD ]
      )
    )
  end

  def search_term
    @search_term ||= @params[:q].to_s.strip
  end

  # Os três caminhos são formas alternativas de o mesmo termo casar a mesma
  # carta, e o conjunto entra por `E` com os filtros, porque `filtered_scope`
  # já os aplicou.
  #
  # Eles se unem por **`UNION`, não por `OR`** — e isso não é estilo. Medido
  # contra o catálogo real na T11 (design.md §4.1.2): um único
  # `WHERE a OR b OR c` produz Seq Scan mesmo com os três índices presentes,
  # porque uma ramificação inindexável derruba o plano indexado do predicado
  # inteiro. Em `UNION`, cada ramificação é planejada isolada e usa o seu
  # índice.
  def apply_search(scope)
    return scope if search_term.blank?

    @active_filters[:q] = search_term
    scope.where(id: search_match_ids)
  end

  def search_match_ids
    Card.connection.select_values(
      Card.sanitize_sql_array([ SEARCH_MATCH_SQL,
                                search_term,
                                TEXT_SEARCH_CONFIG, TEXT_SEARCH_CONFIG, search_term,
                                "%#{sanitize_like(search_term.upcase)}%" ])
    )
  end

  SEARCH_MATCH_SQL = <<~SQL.freeze
    SELECT id FROM cards WHERE immutable_unaccent(?) <% immutable_unaccent(name)
    UNION
    SELECT id FROM cards WHERE to_tsvector(?, coalesce(effect_text, '')) @@ plainto_tsquery(?, ?)
    UNION
    SELECT id FROM cards WHERE card_number LIKE ?
  SQL

  # Consulta separada, deliberadamente (design.md §4.1): resolver ranking exato
  # dentro do full-text é mais frágil e menos previsível que duas consultas.
  # Ela parte do escopo já filtrado, então um filtro ativo que exclua a carta
  # exata continua valendo.
  #
  # Comparação contra a coluna crua, com o termo em maiúsculas pelo Ruby:
  # `upper(card_number) = upper(?)` descartaria o índice único e viraria
  # varredura completa. Os 2815 `card_number` do catálogo são maiúsculos.
  def exact_card_number_match(scope)
    return nil if search_term.blank?

    exact_match_scope(scope).first
  end

  def exact_match_scope(scope) = scope.where(card_number: search_term.upcase)

  def sanitize_like(term)
    ActiveRecord::Base.sanitize_sql_like(term)
  end

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
