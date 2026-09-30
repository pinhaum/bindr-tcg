# Progresso de conclusão por set (Req. 9 / PRG-01, PRG-04, PRG-07, PRG-08).
#
# Responde "quanto falta para eu fechar este set", que é uma pergunta diferente
# da que `CollectionItem.total_copies_for` responde. As duas coexistem e medem
# coisas distintas:
#
# - **aqui**: `COUNT(DISTINCT ...)` de números de carta possuídos — quem tem
#   cinco cópias de uma variante fechou **uma** casa do set;
# - **Req. 7.7**: `SUM(quantity)` de cópias — o mesmo colecionador tem cinco
#   cartas na caixa.
#
# Confundi-las produz dois números errados de uma vez, e é por isso que o teste
# desta task mede as duas lado a lado no mesmo cenário.
#
# ## Uma consulta, não uma por set
#
# A agregação inteira é **um** `GROUP BY sets.id` sobre o join de `sets` com
# as variantes presentes. Não é otimização prematura: um `count` por set é
# N+1 e foi medido — 63 consultas a ~213ms contra ~8ms de uma agregação única,
# ambos com coleção vazia, logo o número mede estrutura e não seletividade
# (spec.md, "Forma da consulta"). O alvo do Req. 11.1 é que o custo **não cresça
# com a quantidade de sets**, e o `GROUP BY` é o que garante isso por
# construção.
#
# Cada métrica é uma coluna agregada com `FILTER` sobre **o mesmo** grupo. Essa
# é a forma que permite acrescentar o percentual (T2) e a contagem de parallels
# (T3) sem nenhuma consulta nova: são mais colunas no mesmo `SELECT`, nunca
# outra passada pelo banco.
#
# ## O eixo é `card_variants.set_id`, o set da **impressão**
#
# Nunca `cards.set_id`, o set de **estreia**. É a mesma razão que
# `CatalogQuery::VARIANT_FILTERS` documenta: uma carta pode ter variantes em
# sets diferentes do seu set de estreia (1402 casos no catálogo real), e
# agregar pelo set de estreia contaria a reimpressão no set errado — numerador e
# denominador ambos deslocados, sem erro nenhum aparecer.
#
# ## O usuário é o objeto, e o `LEFT JOIN` é o que preserva o denominador
#
# O usuário entra como **objeto** `User` (ou `nil`), nunca um id: o tipo é
# validado por `CollectionItem.for_user`, que levanta `ArgumentError` para
# qualquer outra coisa — a barreira desenhada na T5 da `colecao` contra
# `SetProgressQuery.new(params[:user_id])`. Req. 6.5 por construção.
#
# O join com a coleção é `LEFT`, e a condição de posse mora **no `ON`**, não no
# `WHERE`. Com a condição no `WHERE`, o set em que o usuário não possui nada
# perderia todas as linhas e **sumiria do resultado** — a página exibiria só os
# sets já iniciados, que é o oposto do que o Edge Case pede ("todos os sets
# aparecem com numerador zero; a página é informativa, não vazia"). Já o join de
# `sets` com `card_variants` é `INNER`: set sem variante presente na fonte não
# aparece (SRC-16).
#
# ## O percentual: números de carta distintos sobre `sets.base_set_size`
#
# (Req. 9.1, 9.4 e 9.5 emendados; SRC-24..SRC-28, fonte-apitcg.) Na apitcg um
# mesmo número tem mais de uma impressão não-parallel no mesmo set (base e Box
# Topper, por exemplo), então contar variantes passaria de 100%. A unidade é o
# **número de carta distinto**:
#
# - **Denominador = `sets.base_set_size`**, derivado na ingestão (SRC-24).
# - **Universo do numerador**, deduzido do valor gravado em vez de refazer a
#   regra de maioria em SQL: se `base_set_size` é igual ao número de
#   `card_number` distintos presentes no set, a ingestão contou o set inteiro
#   (reimpressão) e o universo é o set inteiro; senão, contou só os números com
#   o prefixo do set (`<código>-`) e o universo é esse. Sem denominador (nulo
#   ou zero), o universo é o set inteiro, só para exibir a posse (PRG-10).
# - **Numerador = números distintos do universo** com ao menos uma variante
#   presente do set, possuída e com `art_kind <> 'parallel'` (SRC-25, SRC-28):
#   `alternate_art`, `manga`, `promo` e `other` entram; duas impressões do
#   mesmo número contam uma vez.
# - **`parallel` fica fora dos dois** — é a métrica separada de AD-003 e do
#   Req. 9.6.
#
# Só entram variantes presentes na fonte (SRC-16); set sem nenhuma variante
# presente não aparece.
#
# ## Parallels: contagem absoluta, fora dos dois lados da divisão
#
# (PRG-06, Req. 9.6, AD-003.) `parallel_owned_variants` e `parallel_variants`
# são **duas colunas a mais no mesmo `SELECT`**, sobre o mesmo `GROUP BY` — não
# há consulta nova por set, como a T1 previu. O total (`parallel_variants`) sai
# do catálogo e não depende de quem olha; o possuído sai do mesmo `LEFT JOIN`
# da coleção que alimenta as demais métricas, logo herda `owned` (quantidade
# zero não conta) e o escopo do usuário sem repetir nenhuma regra.
#
# **Contagem absoluta, e não um segundo percentual.** O Req. 9.6 pede "a
# contagem de parallels possuídos". Um percentual de parallels exigiria um
# `parallelSetSize` que a fonte **não fornece**: seria derivado de `art_kind`,
# que é justamente a classificação cuja confiabilidade a spec mediu como
# divergente em 21 dos 62 sets. Exibir um percentual sobre um denominador que
# sabemos suspeito é o erro que esta feature inteira existe para não cometer.
#
# **Só `parallel` é parallel.** O filtro aqui é `art_kind = 'parallel'` e mais
# nada; todo outro `art_kind` entra no numerador principal. São dois conjuntos
# disjuntos por construção: nenhuma variante conta nas duas métricas, e é isso
# que o Req. 9.6 quer dizer com "nunca somada ao percentual".
#
# ## Indisponível é `nil`, e `nil` nunca é `0`
#
# Set sem `base_set_size` (medido: exatamente um, `PRB9cd8`) e set com
# denominador zero caem no **mesmo** caminho: `completion_percent` é `nil` e
# `completion_percent_known?` é `false`. Nenhuma divisão é executada — o guarda
# é anterior à divisão, não um resgate de `ZeroDivisionError`, e não há como
# sair `Infinity` nem `NaN`.
#
# `nil` foi escolhido justamente porque é **impossível** confundir com `0` em
# Ruby: `nil != 0`, `nil` não responde a comparação numérica e `nil.zero?`
# levanta `NoMethodError`. Um sentinela numérico (`0`, `-1`, `100`) seria
# silenciosamente formatável como percentual pela view da T5, que é exatamente
# o que a spec proíbe ("nunca `0%`, nunca `100%`, nunca omitido"). O predicado
# `completion_percent_known?` existe para que a view pergunte pela
# disponibilidade em vez de testar `nil?`.
#
# O set indisponível **continua no resultado**, com a posse real: omiti-lo
# esconderia cartas que o usuário de fato tem.
class SetProgressQuery
  # Zero é linha existente que significa "não tenho" (Req. 7.3), e não ausência
  # de registro. O recorte sai de `CollectionItem.owned` (`quantity >= 1`) e
  # não da existência da linha: quem zerou a quantidade mantém a linha e tem de
  # dar exatamente o mesmo resultado de quem nunca registrou nada.
  Row = Struct.new(:set_id, :set_code, :set_name, :owned_numbers, :base_size,
                   :parallel_owned_variants, :parallel_variants,
                   keyword_init: true) do
    # `nil` quando não há denominador conhecido — ausente ou zero, o mesmo
    # caminho. O chamador distingue indisponível de zero por cento sem
    # ambiguidade: `nil` contra `0.0`.
    def completion_percent
      return nil unless completion_percent_known?

      [ owned_numbers.to_f / base_size * 100, 100.0 ].min
    end

    # O predicado que a view usa em vez de testar `nil?`, para que
    # "indisponível" seja uma pergunta explícita e não uma checagem de nulo
    # espalhada pela marcação.
    def completion_percent_known?
      !base_size.nil? && base_size.positive?
    end
  end

  # CNF-27/28 — `order` é lista fechada (`ORDERS`), mesmo padrão de
  # `CatalogQuery#ordered` para `sort`/`dir`: qualquer valor fora da lista —
  # ausente, desconhecido, vazio ou um array vindo de `params[:order]` — vira
  # `"recent"` via `.to_s`, nunca um erro. `"code"` é a única outra opção.
  ORDERS = %w[recent code].freeze

  attr_reader :order

  def initialize(user = nil, order: "recent")
    @user = user
    @order = ORDERS.include?(order.to_s) ? order.to_s : "recent"
  end

  def call
    rows.map do |record|
      Row.new(
        set_id: record.id,
        set_code: record.code,
        set_name: record.name,
        owned_numbers: record.owned_numbers.to_i,
        # `to_i` aqui apagaria a distinção entre "sem denominador" e "zero",
        # que é justamente o que PRG-10 exige preservar até o `Row`.
        base_size: record.base_size,
        parallel_owned_variants: record.parallel_owned_variants.to_i,
        parallel_variants: record.parallel_variants.to_i
      )
    end
  end

  private

  # `select_all` em vez de instanciar `CardSet`: o resultado é um relatório, não
  # um conjunto de registros editáveis, e as colunas agregadas não pertencem ao
  # model. `Row` é o contrato que o chamador lê.
  #
  # CNF-27 — a ordem é mais uma coluna e um `ORDER BY` sobre a **mesma**
  # agregação, nunca uma segunda consulta: `last_activity_at` é
  # `MAX(collection_items.updated_at)` do `LEFT JOIN` que já existe
  # (`owned_join`), e por isso o teste de forma (`set_progress_plan_test.rb`,
  # AD-017) continua vendo uma única `CardSet Load`.
  #
  # Nas duas ordens os sets sem posse (nenhuma linha com `quantity > 0`, logo
  # `last_activity_at` NULL) ficam no fim, por código. `recent` ordena os com
  # posse pela atividade, mais nova primeiro; `code`, pelo código.
  def rows
    CardSet
      .select(AGGREGATE_COLUMNS)
      .joins(variants_join)
      .joins(set_numbers_join)
      .joins(owned_join)
      .group("sets.id, set_numbers.distinct_numbers")
      .order(order_clause)
  end

  def order_clause
    return Arel.sql("MAX(owned_items.updated_at) IS NULL, sets.code ASC") if order == "code"

    "last_activity_at DESC NULLS LAST, sets.code ASC"
  end

  # O universo do numerador (ver o cabeçalho): o set inteiro quando não há
  # denominador (nulo ou zero, PRG-10) ou quando ele é igual aos números
  # distintos presentes; senão, só os
  # números com o prefixo `<código>-`. `left(...) =` em vez de `LIKE`, para
  # que `_` e `%` num código de set não virem curinga.
  UNIVERSE_SQL = <<~SQL.squish.freeze
    (COALESCE(sets.base_set_size, 0) = 0
      OR sets.base_set_size = set_numbers.distinct_numbers
      OR left(cards.card_number, length(sets.code) + 1) = sets.code || '-')
  SQL

  AGGREGATE_COLUMNS = <<~SQL.squish.freeze
    sets.id,
    sets.code,
    sets.name,
    COUNT(DISTINCT cards.card_number)
      FILTER (WHERE owned_items.card_variant_id IS NOT NULL
                AND card_variants.art_kind <> 'parallel'
                AND #{UNIVERSE_SQL}) AS owned_numbers,
    sets.base_set_size AS base_size,
    COUNT(DISTINCT owned_items.card_variant_id)
      FILTER (WHERE card_variants.art_kind = 'parallel') AS parallel_owned_variants,
    COUNT(DISTINCT card_variants.id)
      FILTER (WHERE card_variants.art_kind = 'parallel') AS parallel_variants,
    MAX(owned_items.updated_at) AS last_activity_at
  SQL

  # `INNER`: set sem variante presente na fonte sai da lista (SRC-16). A
  # presença entra no `ON` com o mesmo predicado de `CardVariant.present`.
  def variants_join
    "INNER JOIN card_variants ON card_variants.set_id = sets.id AND #{CardVariant::PRESENT_SQL} " \
      "INNER JOIN cards ON cards.id = card_variants.card_id"
  end

  # Números de carta distintos presentes por set: é contra eles que o
  # `base_set_size` gravado diz qual universo a ingestão contou.
  def set_numbers_join
    subquery = CardVariant.present.joins(:card).group(:set_id)
                          .select("card_variants.set_id, COUNT(DISTINCT cards.card_number) AS distinct_numbers")
                          .to_sql

    "INNER JOIN (#{subquery}) set_numbers ON set_numbers.set_id = sets.id"
  end

  # A subconsulta parte de `CollectionItem.for_user(@user).owned`, que já resolve
  # as duas garantias desta task: o escopo do usuário (`ArgumentError` para um
  # id) e a definição de posse (`quantity >= 1`). Para `nil` ela é
  # `CollectionItem.none`, e o `LEFT JOIN` devolve todos os sets com numerador
  # zero — o anônimo não é caso de erro, é numerador vazio.
  def owned_join
    subquery = CollectionItem.for_user(@user).owned
                             .select(:card_variant_id, :updated_at).to_sql

    "LEFT JOIN (#{subquery}) owned_items " \
      "ON owned_items.card_variant_id = card_variants.id"
  end
end
