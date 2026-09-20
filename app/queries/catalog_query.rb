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

  # Contrato de `design.md` §4.2: `owned` aceita exatamente estes três valores.
  # `all` é o default e **não é filtro** — é a ausência de recorte, e por isso
  # não vira chip: não há o que remover de "todas". Qualquer outro valor é
  # ignorado como qualquer parâmetro inválido, sem erro (Edge Case da spec).
  OWNERSHIP_VALUES = %w[all owned missing].freeze

  Result = Struct.new(:records, :total_count, :page, :per_page, :active_filters,
                      keyword_init: true) do
    def total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
  end

  # O usuário é **injetado pelo chamador**, como segundo argumento, e nunca sai
  # de `params`. A separação é o que satisfaz o Req. 6.5 por construção:
  # `params` é a URL, e a URL é do atacante. Se o usuário viesse de
  # `@params[:user_id]`, qualquer anônimo leria a coleção alheia com
  # `?owned=owned&user_id=7`. Aqui não há caminho de `params` para `@user` — a
  # única forma de o filtro de posse valer é o chamador passar `Current.user`.
  #
  # **Posicional, não nomeado, e a razão é de compatibilidade.** Um `user:`
  # nomeado competiria com o hash de parâmetros: `CatalogQuery.new(colors: [...])`
  # passa a ser interpretado como lista de keywords e estoura
  # `ArgumentError: unknown keyword: :colors` em todos os chamadores que não
  # usam chaves — medido, 54 erros na suíte. Posicional, a forma antiga
  # continua válida sem tocar em nenhum deles.
  #
  # `nil` é valor legítimo (o anônimo do catálogo público): o filtro é ignorado
  # e o catálogo sai completo, sem erro (COL-11, critério 3). O tipo é validado
  # adiante por `CollectionItem.for_user`, que levanta `ArgumentError` para
  # qualquer coisa que não seja `User` ou `nil` — um id vindo do request não
  # chega a virar consulta.
  def initialize(params = {}, user = nil)
    @params = normalize_keys(params)
    @user = user
    @active_filters = {}
  end

  # A busca inteira roda dentro de uma transação **explícita**. Não é
  # cerimônia: `set_config(..., true)` é `SET LOCAL`, válido só até o fim da
  # transação corrente. Fora de uma, cada statement é a sua própria transação
  # e o limiar já voltou a 0.6 quando a consulta seguinte executa — a busca
  # por typo devolve zero resultado em produção enquanto passa nos testes,
  # porque o Rails envolve cada teste numa transação. Foi exatamente o que
  # aconteceu aqui, e o `assert` que pega isso é o de `q=Zorro` fora do
  # wrapper transacional dos testes.
  def call
    return build_result if search_term.blank?

    Card.transaction { build_result }
  end

  # Filtros sem busca textual. Exposto para o controller montar contagens
  # auxiliares sobre o mesmo recorte.
  def filtered_scope
    scope = base_scope
    scope = apply_array_filters(scope)
    scope = apply_scalar_filters(scope)
    scope = apply_variant_filters(scope)
    scope = apply_range_filters(scope)
    apply_ownership_filter(scope)
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

  def build_result
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

  def base_scope = Card.all

  # O exato vai à frente da página 1 e **só dela**: da página 2 em diante ele
  # já foi consumido, e reprependê-lo repetiria a mesma carta em toda página
  # além de estourar o `per_page`. O offset das páginas seguintes desconta a
  # única vaga que ele ocupou na primeira.
  def page_records(scope, exact, page, per_page)
    return paginate(ordered(scope), page, per_page).to_a unless exact
    return [ exact ] + ordered(scope).limit(per_page - 1).to_a if page == 1

    ordered(scope).limit(per_page).offset((page - 1) * per_page - 1).to_a
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
      # `quote_column_name` em vez de interpolar direto: o nome vem de uma
      # constante congelada, não do request, mas interpolação em SQL é padrão
      # que não se deixa no código — na próxima edição a origem do valor pode
      # já não ser uma constante.
      quoted = Card.connection.quote_column_name(column)
      current.where(Arel.sql("cards.#{quoted} && ARRAY[?]::text[]"), values)
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

  # Filtro de posse (Req. 7.6 / COL-11). Mesmo problema que `sets` e `rarities`
  # resolvem, e por isso a mesma forma: **posse é por variante e este objeto
  # devolve cartas.** `collection_items` referencia `card_variants`, então o
  # predicado tem que atravessar `card_variants` em subconsulta; filtrar
  # `cards` direto é impossível — não há coluna de posse em `cards`.
  #
  # A semântica com várias variantes é a decisão desta task, e ela importa
  # porque **40,1% das cartas do catálogo real têm mais de uma variante**
  # (medido na T8):
  #
  # - `owned`   → a carta tem **ao menos uma** variante possuída;
  # - `missing` → a carta **não tem nenhuma** variante possuída.
  #
  # As duas são complementares e particionam o catálogo: toda carta cai em
  # exatamente uma delas, e `owned ∪ missing == all`. A alternativa ("missing =
  # falta alguma variante") faria as duas se **sobrepor** — uma carta com a base
  # possuída e o parallel faltando apareceria nos dois filtros —, e "o que me
  # falta" deixaria de responder à pergunta que o Req. 7.6 faz. Completude por
  # impressão é o Req. 9 (progresso por set), que tem métrica própria e
  # denominador decidido em AD-003.
  #
  # `NOT EXISTS`, nunca `NOT IN` com subconsulta: `id NOT IN (SELECT card_id
  # ...)` devolve **zero linhas** se um único `card_id` do conjunto for NULL,
  # porque `x <> NULL` é NULL e não falso. Aqui `card_variants.card_id` é `NOT
  # NULL`, então o `NOT IN` funcionaria hoje — e quebraria em silêncio no dia em
  # que a coluna admitisse NULL, sem nenhum teste acusar. `NOT EXISTS` não tem
  # esse comportamento e ainda é a forma que o planejador converte em anti-join.
  #
  # Zero é linha existente, não ausência de linha: o recorte sai de
  # `CollectionItem.owned` (`quantity > 0`), e não da existência do registro.
  # Quem zerou uma quantidade continua com a linha e tem que aparecer em
  # `missing` — é o que distingue "não tem mais" de "nunca teve" (Req. 7.6,
  # decisão registrada na T5).
  #
  # **Índice é T10, não esta task.** O `ecc:database-reviewer` apontou que o
  # `UNIQUE (user_id, card_variant_id)` existente localiza o usuário mas não
  # filtra `quantity`, então a checagem de `quantity >= 1` volta à heap; o
  # candidato é um índice **parcial**
  # `collection_items (user_id, card_variant_id) WHERE quantity >= 1`. Ele
  # também confirmou que reescrever o `IN` interno como `JOIN` **não** muda o
  # plano — o planejador achata os dois em semi-join —, então a forma aqui não
  # é o que a T10 precisa mexer.
  def apply_ownership_filter(scope)
    mode = sanitized_ownership
    return scope if mode.nil? || mode == "all"

    @active_filters[:owned] = mode

    owned = owned_variants_exists
    mode == "owned" ? scope.where(owned.exists) : scope.where(owned.exists.not)
  end

  # `all` não é filtro e por isso não entra em `active_filters`. Sem usuário, o
  # valor inteiro é descartado: o filtro é ignorado **e** não vira chip, porque
  # o chip só representa filtro que está de fato valendo.
  def sanitized_ownership
    return nil if @user.nil?

    value = @params[:owned].to_s.strip
    OWNERSHIP_VALUES.include?(value) ? value : nil
  end

  # Subconsulta correlacionada: `card_variants.card_id = cards.id` é o que liga
  # o `EXISTS` à linha de fora. O `WHERE user_id` sai de
  # `CollectionItem.for_user`, que exige o objeto `User` e levanta
  # `ArgumentError` para um id — a barreira que a T5 desenhou contra a leitura
  # de coleção alheia.
  #
  # A correlação sai de `Card.arel_table`, e **não** da tabela do escopo
  # recebido. Achado do `ecc:database-reviewer`: amarrar a correlação ao escopo
  # funciona hoje, porque `filtered_scope` sempre parte de `cards`, mas o dia em
  # que ele passar por um alias ou uma subconsulta a correlação aponta para a
  # coluna errada **sem erro de sintaxe** — uma consulta que devolve o conjunto
  # errado em silêncio. A raiz é fixa aqui porque é fixa de fato.
  def owned_variants_exists
    variants = CardVariant.arel_table

    CardVariant
      .where(variants[:card_id].eq(Card.arel_table[:id]))
      .where(id: CollectionItem.for_user(@user).owned.select(:card_variant_id))
      .select(1)
      .arel
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
