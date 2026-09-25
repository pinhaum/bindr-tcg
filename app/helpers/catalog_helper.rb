# Tradução dos filtros ativos em chips removíveis (Req. 4.6) e dos links de
# paginação (Req. 4.7). Toda URL gerada aqui parte dos filtros **normalizados**
# do query object, nunca de `params` crus: um parâmetro inválido que foi
# descartado na consulta não pode ressuscitar dentro de um link.
module CatalogHelper
  # Rótulo legível de cada categoria, para o chip dizer o que está removendo.
  FILTER_LABELS = {
    q: "Busca",
    colors: "Cor",
    card_types: "Tipo",
    sets: "Set",
    rarities: "Raridade",
    attributes: "Attribute",
    traits: "Trait",
    cost_min: "Custo mín.",
    cost_max: "Custo máx.",
    power_min: "Power mín.",
    power_max: "Power máx.",
    counter_min: "Counter mín.",
    counter_max: "Counter máx."
  }.freeze

  # Ordenação não é filtro: não vira chip removível, senão o usuário "remove"
  # a ordenação e não sabe o que aconteceu.
  NON_FILTER_KEYS = %i[sort dir page per_page].freeze

  Chip = Struct.new(:label, :value, :url, keyword_init: true)

  # Um chip por **valor**, não por categoria: com "Red" e "Green" ativos, o
  # usuário precisa remover cada cor separadamente (Req. 4.6).
  def catalog_chips(active_filters)
    active_filters.except(*NON_FILTER_KEYS).flat_map do |key, value|
      Array(value).map do |single|
        Chip.new(
          label: FILTER_LABELS.fetch(key, key.to_s.humanize),
          value: single.to_s,
          url: catalog_path(filters_without(active_filters, key, single))
        )
      end
    end
  end

  # Remove um único valor e preserva todo o resto — incluindo a ordenação, que
  # não é filtro mas faz parte do estado da URL.
  def filters_without(active_filters, key, value)
    remaining = active_filters.dup

    if remaining[key].is_a?(Array)
      rest = remaining[key] - [ value ]
      rest.empty? ? remaining.delete(key) : remaining[key] = rest
    else
      remaining.delete(key)
    end

    remaining.except(:page)
  end

  # A paginação carrega o estado inteiro, senão trocar de página perde o filtro.
  def catalog_page_url(active_filters, page)
    catalog_path(active_filters.merge(page: page))
  end

  # Alterna um valor de filtro: acrescenta se inativo, remove se ativo,
  # descartando `page` sempre. Para `owned` (escalar), remove a chave em vez de
  # tentar manter um array. Filtros normalizados preservam a forma já validada.
  def filter_toggle_url(active_filters, key, value)
    filters = active_filters.dup

    if key.to_sym == :owned
      # Posse é escalar: toggling "owned" ou "missing" remove; "all" (default)
      # também remove. Qualquer outro valor é ligado.
      if filters[key].to_s == value.to_s
        filters.delete(key)
      elsif value == "all"
        filters.delete(key)
      else
        filters[key] = value
      end
    elsif filters[key].is_a?(Array)
      # Filtro de array: verifica se já existe
      if filters[key].include?(value)
        # Valor ativo: remover
        rest = filters[key] - [ value ]
        rest.empty? ? filters.delete(key) : filters[key] = rest
      else
        # Valor inativo: adicionar
        filters[key] = filters[key] + [ value ]
      end
    else
      # Filtro não existe ainda: criar array com o valor
      filters[key] = [ value ]
    end

    catalog_path(filters.except(:page))
  end
end
