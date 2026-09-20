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
class SetProgressQuery
  # Zero é linha existente que significa "não tenho" (Req. 7.3), e não ausência
  # de registro. O recorte sai de `CollectionItem.owned` (`quantity >= 1`) e
  # não da existência da linha: quem zerou a quantidade mantém a linha e tem de
  # dar exatamente o mesmo resultado de quem nunca registrou nada.
  Row = Struct.new(:set_id, :set_code, :set_name, :owned_variants, :total_variants,
                   keyword_init: true)

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
        total_variants: record.total_variants.to_i
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
    COUNT(DISTINCT owned_items.card_variant_id) AS owned_variants
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
