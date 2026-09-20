require "test_helper"

# T9 — filtro de posse no `CatalogQuery` (Req. 7.6 / COL-11).
#
# Os testes derivam do critério de aceitação, não da implementação. O cenário
# foi montado para que cada um deles **discrimine**, e três armadilhas ditaram
# a forma dele:
#
# 1. **Posse é por variante; o filtro devolve cartas.** Uma carta de três
#    variantes com só uma possuída existe aqui (`@multipla`) porque é o caso
#    que separa "tem ao menos uma" de "tem todas". Sem ela, `owned` e um
#    hipotético "completa" dariam o mesmo resultado e o teste não escolheria
#    entre as duas semânticas.
# 2. **Zero é linha existente, não ausência de linha.** `@zerada` tem registro
#    de coleção com `quantity = 0`. Um filtro que usasse existência de registro
#    como critério passaria em todo o resto e erraria só aqui.
# 3. **O usuário é injetado, nunca lido da URL.** Há carta possuída por
#    **outro** usuário (`@alheia`): um filtro que ignorasse o escopo de usuário
#    continuaria verde em todos os testes que olham só o próprio usuário.
class CatalogOwnershipTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "nami-t9@example.com", password: "log-pose-77")
    @outro = User.create!(email: "usopp-t9@example.com", password: "log-pose-77")
    @set = CardSet.create!(code: "OPt9", name: "Romance Dawn", kind: "booster")

    # Uma variante, possuída.
    @unica = create_card("OP01-t9a", "Roronoa Zoro", colors: [ "Red" ], cost: 3)
    @v_unica = create_variant(@unica, "OP01-t9a")
    own(@user, @v_unica, 2)

    # Três variantes, **uma** possuída: o caso que define a semântica.
    @multipla = create_card("OP01-t9b", "Nami", colors: [ "Green" ], cost: 1)
    @v_multipla = [ "OP01-t9b", "OP01-t9b_p1", "OP01-t9b_p2" ].map { create_variant(@multipla, _1) }
    own(@user, @v_multipla.first, 1)

    # Registro existente com quantidade zero: não possuída (Req. 7.3).
    @zerada = create_card("OP01-t9c", "Trafalgar Law", colors: [ "Red" ], cost: 4)
    @v_zerada = create_variant(@zerada, "OP01-t9c")
    own(@user, @v_zerada, 0)

    # Sem registro nenhum.
    @intocada = create_card("OP01-t9d", "Gum-Gum Pistol", colors: [ "Red" ], cost: 1)
    create_variant(@intocada, "OP01-t9d")

    # Possuída por outro usuário — nunca pode entrar no `owned` de `@user`.
    @alheia = create_card("OP01-t9e", "Bell-mère", colors: [ "Green" ], cost: 2)
    @v_alheia = create_variant(@alheia, "OP01-t9e")
    own(@outro, @v_alheia, 5)
  end

  def create_card(number, name, **attrs)
    Card.create!(card_set: @set, card_number: number, name: name,
                 card_type: "character", power: 3000, **attrs)
  end

  def create_variant(card, code)
    CardVariant.create!(card: card, set_id: @set.id, variant_code: code,
                        rarity: "C", art_kind: "base")
  end

  def own(user, variant, quantity)
    CollectionItem.create!(user: user, card_variant: variant, quantity: quantity)
  end

  def numbers(result) = result.records.map(&:card_number).sort

  # `user:` fica fora do hash de parâmetros de propósito: aqui, como na
  # produção, a URL e o usuário são duas vias de entrada separadas.
  def query(params = {}, user: :default)
    usuario = user == :default ? @user : user
    CatalogQuery.new(params, usuario).call
  end

  TODAS = %w[OP01-t9a OP01-t9b OP01-t9c OP01-t9d OP01-t9e].freeze

  # --- COL-11, critério 1: o contrato de `design.md` §4.2 ---

  test "owned devolve as cartas com ao menos uma variante possuída" do
    assert_equal %w[OP01-t9a OP01-t9b], numbers(query({ owned: "owned" }))
  end

  test "missing devolve as cartas sem nenhuma variante possuída" do
    assert_equal %w[OP01-t9c OP01-t9d OP01-t9e], numbers(query({ owned: "missing" }))
  end

  test "all não recorta nada e devolve o catálogo completo" do
    assert_equal TODAS, numbers(query({ owned: "all" }))
  end

  # `owned` e `missing` **particionam** o catálogo: toda carta cai em
  # exatamente uma das duas. É a asserção que distingue a semântica escolhida
  # ("não tem nenhuma") da alternativa ("falta alguma"), sob a qual `@multipla`
  # apareceria nos dois conjuntos e a soma passaria do total.
  test "owned e missing são complementares e não se sobrepõem" do
    possuidas = numbers(query({ owned: "owned" }))
    faltantes = numbers(query({ owned: "missing" }))

    assert_empty possuidas & faltantes, "nenhuma carta pode estar nos dois filtros"
    assert_equal TODAS, (possuidas + faltantes).sort
  end

  # O caso que decide a semântica: a carta tem três impressões e o usuário tem
  # uma. Ela é "possuída" e **não** é "faltante" — completude por impressão é o
  # Req. 9, com métrica própria.
  test "carta com uma de três variantes possuídas conta como possuída" do
    assert_includes numbers(query({ owned: "owned" })), "OP01-t9b"
    refute_includes numbers(query({ owned: "missing" })), "OP01-t9b"
  end

  # --- COL-11, critério 5: quantidade zero é não possuída ---

  test "variante com quantidade zero não conta como possuída" do
    refute_includes numbers(query({ owned: "owned" })), "OP01-t9c",
                    "zero é linha existente, não posse"
    assert_includes numbers(query({ owned: "missing" })), "OP01-t9c",
                    "quem zerou a quantidade volta a ser 'me falta'"
  end

  # A diferença entre "nunca teve" e "não tem mais" não pode aparecer no
  # filtro: as duas são não-posse.
  test "quantidade zero e ausência de registro dão o mesmo resultado no filtro" do
    faltantes = numbers(query({ owned: "missing" }))

    assert_includes faltantes, "OP01-t9c", "registro com zero"
    assert_includes faltantes, "OP01-t9d", "sem registro nenhum"
  end

  # --- Req. 6.5: a posse é sempre a do usuário injetado ---

  test "posse de outro usuário não entra no filtro" do
    refute_includes numbers(query({ owned: "owned" })), "OP01-t9e"
    assert_includes numbers(query({ owned: "missing" })), "OP01-t9e"
  end

  test "o mesmo catálogo filtrado para outro usuário devolve a posse dele" do
    assert_equal [ "OP01-t9e" ], numbers(query({ owned: "owned" }, user: @outro))
  end

  # O usuário **não** sai de `params`. Se saísse, este teste veria a coleção do
  # `@outro`; como ele é injetado, o parâmetro é ruído ignorado.
  test "user_id na URL não escolhe de quem é a posse" do
    resultado = query({ owned: "owned", user_id: @outro.id })

    assert_equal %w[OP01-t9a OP01-t9b], numbers(resultado)
  end

  test "user_id na URL não faz o filtro valer para o anônimo" do
    resultado = query({ owned: "owned", user_id: @user.id }, user: nil)

    assert_equal TODAS, numbers(resultado)
  end

  # --- COL-11, critério 3: sem usuário, o filtro é ignorado ---

  test "sem usuário o filtro é ignorado e o catálogo sai completo" do
    assert_equal TODAS, numbers(query({ owned: "owned" }, user: nil))
    assert_equal TODAS, numbers(query({ owned: "missing" }, user: nil))
  end

  test "sem usuário o filtro descartado não vira chip" do
    resultado = query({ owned: "owned" }, user: nil)

    refute resultado.active_filters.key?(:owned),
           "chip só representa filtro que está de fato valendo"
  end

  # --- COL-11, critério 2 e Edge Case: valor inválido é ignorado ---

  test "valor fora do contrato é ignorado sem levantar erro" do
    assert_equal TODAS, numbers(query({ owned: "banana" }))
    assert_equal TODAS, numbers(query({ owned: "" }))
    assert_equal TODAS, numbers(query({ owned: [ "owned" ] }))
  end

  test "valor fora do contrato não vira chip" do
    refute query({ owned: "banana" }).active_filters.key?(:owned)
  end

  # `all` é o default e não é filtro: não há o que remover num chip "todas".
  test "all não vira chip" do
    refute query({ owned: "all" }).active_filters.key?(:owned)
  end

  test "owned e missing viram chip quando valem" do
    assert_equal "owned", query({ owned: "owned" }).active_filters[:owned]
    assert_equal "missing", query({ owned: "missing" }).active_filters[:owned]
  end

  test "ausência do parâmetro devolve o catálogo completo" do
    assert_equal TODAS, numbers(query)
  end

  # --- COL-11, critério 4: E entre categorias, OU dentro da categoria ---

  test "posse combina com filtro de categoria por E" do
    # `@unica` é Red e possuída; `@multipla` é Green e possuída. Se a
    # combinação fosse OU, a Green entraria pelo lado da posse.
    assert_equal [ "OP01-t9a" ], numbers(query({ owned: "owned", colors: [ "Red" ] }))
  end

  test "missing combina com filtro de categoria por E" do
    # Red e faltantes: `@zerada` e `@intocada`. `@alheia` é Green e fica fora.
    assert_equal %w[OP01-t9c OP01-t9d], numbers(query({ owned: "missing", colors: [ "Red" ] }))
  end

  test "posse combina com faixa numérica por E" do
    assert_equal [ "OP01-t9a" ], numbers(query({ owned: "owned", cost_min: 3 }))
  end

  test "OU dentro da categoria de cor continua valendo sob o filtro de posse" do
    assert_equal %w[OP01-t9a OP01-t9b],
                 numbers(query({ owned: "owned", colors: [ "Red", "Green" ] }))
  end

  test "posse combina com busca textual por E" do
    assert_equal [ "OP01-t9b" ], numbers(query({ owned: "owned", q: "Nami" }))
    assert_empty numbers(query({ owned: "missing", q: "Nami" }))
  end

  # --- Req. 4.8: o total acompanha o recorte ---

  test "total_count conta o conjunto filtrado por posse, não a página" do
    resultado = query({ owned: "missing", per_page: 1 })

    assert_equal 1, resultado.records.size
    assert_equal 3, resultado.total_count
  end
end
