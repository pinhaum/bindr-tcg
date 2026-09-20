# Progresso de conclusão por set (Req. 9 / PRG-01, PRG-04, PRG-07, PRG-08).
#
# Responde "quanto falta para eu fechar este set", que é uma pergunta diferente
# da que `CollectionItem.total_copies_for` responde. As duas coexistem e medem
# coisas distintas:
#
# - **aqui**: `COUNT(DISTINCT ...)` de variantes possuídas — quem tem cinco
#   cópias de uma variante fechou **uma** casa do set;
# - **Req. 7.7**: `SUM(quantity)` de cópias — o mesmo colecionador tem cinco
#   cartas na caixa.
#
# Confundi-las produz dois números errados de uma vez, e é por isso que o teste
# desta task mede as duas lado a lado no mesmo cenário.
#
# ## Uma consulta, não uma por set
#
# A agregação inteira é **um** `GROUP BY sets.id` sobre um `LEFT JOIN` de
# `sets` para `card_variants`. Não é otimização prematura: um `count` por set é
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
# aparecem com numerador zero; a página é informativa, não vazia"). O mesmo vale
# para o `LEFT JOIN` de `sets` para `card_variants`: set sem nenhuma variante
# continua listado, com total zero.
#
# ## O percentual: denominador `sets.base_set_size`, numerador `base` + `other`
#
# (PRG-02, PRG-05, PRG-10.) A escolha **não é arbitrária** e não é a leitura
# ingênua do Req. 9.5; ela é uma decisão do dono do produto, registrada na spec
# (`.specs/features/progresso/spec.md`, "Conflito com `.context/requirements.md`")
# e medida no banco de desenvolvimento antes de virar código:
#
# | Comparação | Divergências |
# |---|---|
# | `base_set_size` vs. `count(art_kind = 'base')`            | **21 de 62 sets** |
# | `base_set_size` vs. `count(art_kind IN ('base','other'))` | **1 de 62 sets** (ST16: 7 contra 6) |
#
# O Req. 9.5 trata "variantes base do set" e `baseSetSize` da fonte como
# sinônimos. **No banco real não são**, porque a ingestão classifica como
# `other` reimpressões que a fonte conta dentro de `baseSetSize`. Por isso:
#
# - **Denominador = `sets.base_set_size`**, o campo da fonte externa, nunca uma
#   contagem local de `art_kind = 'base'` e nunca o total de impressões do set.
#   Contar localmente seria catastrófico em dois casos medidos: `FamilyDeckSet`
#   daria denominador **0** (49 variantes, todas `other`) — divisão por zero e
#   set invisível; `PRB01` daria **1** em vez de 113, exibindo 100% para quem
#   possui uma única carta de 113.
# - **Numerador = variantes possuídas com `art_kind IN ('base','other')`**, o
#   **mesmo universo** do denominador. Com numerador só `'base'`, o percentual
#   seria aritmeticamente incoerente com o seu próprio denominador, e
#   `FamilyDeckSet` exibiria 0/49 para quem possui o set inteiro.
# - **`parallel` fica fora dos dois** — é a métrica separada de AD-003 e do
#   Req. 9.6, e entra na T3.
#
# Corrigir a classificação de `art_kind` na ingestão está em Out of Scope: é
# defeito do subsistema de ingestão, e misturá-lo aqui violaria a separação que
# é o eixo do `design.md`.
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
  Row = Struct.new(:set_id, :set_code, :set_name, :owned_variants, :total_variants,
                   :base_owned_variants, :base_size,
                   keyword_init: true) do
    # `nil` quando não há denominador conhecido — ausente ou zero, o mesmo
    # caminho. O chamador distingue indisponível de zero por cento sem
    # ambiguidade: `nil` contra `0.0`.
    def completion_percent
      return nil unless completion_percent_known?

      [ base_owned_variants.to_f / base_size * 100, 100.0 ].min
    end

    # O predicado que a view usa em vez de testar `nil?`, para que
    # "indisponível" seja uma pergunta explícita e não uma checagem de nulo
    # espalhada pela marcação.
    def completion_percent_known?
      !base_size.nil? && base_size.positive?
    end
  end

  def initialize(user = nil)
    @user = user
  end

  def call
    rows.map do |record|
      Row.new(
        set_id: record.id,
        set_code: record.code,
        set_name: record.name,
        owned_variants: record.owned_variants.to_i,
        total_variants: record.total_variants.to_i,
        base_owned_variants: record.base_owned_variants.to_i,
        # `to_i` aqui apagaria a distinção entre "sem denominador" e "zero",
        # que é justamente o que PRG-10 exige preservar até o `Row`.
        base_size: record.base_size
      )
    end
  end

  private

  # `select_all` em vez de instanciar `CardSet`: o resultado é um relatório, não
  # um conjunto de registros editáveis, e as colunas agregadas não pertencem ao
  # model. `Row` é o contrato que o chamador lê.
  def rows
    CardSet
      .select(AGGREGATE_COLUMNS)
      .joins(variants_join)
      .joins(owned_join)
      .group("sets.id")
      .order("sets.code ASC")
  end

  AGGREGATE_COLUMNS = <<~SQL.squish.freeze
    sets.id,
    sets.code,
    sets.name,
    COUNT(DISTINCT card_variants.id) AS total_variants,
    COUNT(DISTINCT owned_items.card_variant_id) AS owned_variants,
    COUNT(DISTINCT owned_items.card_variant_id)
      FILTER (WHERE card_variants.art_kind IN ('base', 'other')) AS base_owned_variants,
    sets.base_set_size AS base_size
  SQL

  def variants_join
    "LEFT JOIN card_variants ON card_variants.set_id = sets.id"
  end

  # A subconsulta parte de `CollectionItem.for_user(@user).owned`, que já resolve
  # as duas garantias desta task: o escopo do usuário (`ArgumentError` para um
  # id) e a definição de posse (`quantity >= 1`). Para `nil` ela é
  # `CollectionItem.none`, e o `LEFT JOIN` devolve todos os sets com numerador
  # zero — o anônimo não é caso de erro, é numerador vazio.
  def owned_join
    subquery = CollectionItem.for_user(@user).owned.select(:card_variant_id).to_sql

    "LEFT JOIN (#{subquery}) owned_items " \
      "ON owned_items.card_variant_id = card_variants.id"
  end
end
