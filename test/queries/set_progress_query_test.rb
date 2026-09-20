require "test_helper"

# T1 — agregação de progresso por set (PRG-01, PRG-04, PRG-07, PRG-08).
#
# Os testes derivam dos critérios de aceitação da história P1 da spec, não da
# implementação. Três armadilhas ditaram a forma do cenário, e cada uma delas
# existe para que uma asserção **discrimine** em vez de acompanhar:
#
# 1. **Progresso conta variantes distintas; o Req. 7.7 conta cópias.** Uma
#    variante com `quantity = 5` (`@v_cinco`) existe aqui porque é o único caso
#    que separa `count` de `sum(:quantity)`. As duas métricas são medidas lado
#    a lado no mesmo cenário: uma implementação que somasse quantidade passaria
#    em todo o resto e erraria só aqui.
# 2. **Zero é linha existente, não ausência de linha** (Req. 7.3). `@v_zerada`
#    tem registro de coleção com `quantity = 0`, e o teste exige que o
#    resultado seja **idêntico** ao de `@v_intocada`, que não tem registro
#    nenhum. Uma agregação que usasse existência de registro como critério
#    passaria em tudo menos nisso.
# 3. **A agregação é por `card_variants.set_id`, o set da impressão.**
#    `@v_reimpressao` é variante de uma carta que estreou em `@set_a` mas foi
#    impressa em `@set_b`. Agregar por `cards.set_id` contaria a reimpressão no
#    set errado, e sem essa variante os dois eixos dariam o mesmo número.
#
# Há ainda posse de **outro** usuário (`@outro`) sobre uma variante de um set
# que o alvo também toca: uma agregação que ignorasse o escopo de usuário
# continuaria verde em todos os testes que olham só o próprio usuário.
class SetProgressQueryTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "nami-prg1@example.com", password: "log-pose-77")
    @outro = User.create!(email: "usopp-prg1@example.com", password: "log-pose-77")

    @set_a = CardSet.create!(code: "OPp1a", name: "Romance Dawn", kind: "booster",
                             base_set_size: 3, total_set_size: 5)
    @set_b = CardSet.create!(code: "OPp1b", name: "Paramount War", kind: "booster",
                             base_set_size: 2, total_set_size: 3)
    # Set sem nenhuma posse: tem que aparecer no resultado com numerador zero.
    @set_c = CardSet.create!(code: "OPp1c", name: "Pillars of Strength", kind: "booster",
                             base_set_size: 1, total_set_size: 1)

    # --- @set_a ---------------------------------------------------------
    # Cinco cópias de uma variante: conta **1** no progresso, **5** no total.
    @carta_cinco = create_card(@set_a, "OP01-p1a", "Roronoa Zoro")
    @v_cinco = create_variant(@carta_cinco, @set_a, "OP01-p1a")
    own(@user, @v_cinco, 5)

    # Uma cópia: o caso trivial, para que o numerador de `@set_a` seja 2 e não 1
    # — com um só possuído, "conta variantes" e "conta cópias" coincidiriam.
    @carta_uma = create_card(@set_a, "OP01-p1b", "Nami")
    @v_uma = create_variant(@carta_uma, @set_a, "OP01-p1b")
    own(@user, @v_uma, 1)

    # Registro existente com quantidade zero: não possuída.
    @carta_zerada = create_card(@set_a, "OP01-p1c", "Trafalgar Law")
    @v_zerada = create_variant(@carta_zerada, @set_a, "OP01-p1c")
    own(@user, @v_zerada, 0)

    # Sem registro nenhum: tem que dar o mesmo que a zerada.
    @carta_intocada = create_card(@set_a, "OP01-p1d", "Gum-Gum Pistol")
    @v_intocada = create_variant(@carta_intocada, @set_a, "OP01-p1d")

    # Possuída pelo **outro** usuário, no mesmo set do alvo.
    @carta_alheia = create_card(@set_a, "OP01-p1e", "Bell-mère")
    @v_alheia = create_variant(@carta_alheia, @set_a, "OP01-p1e")
    own(@outro, @v_alheia, 4)

    # --- @set_b ---------------------------------------------------------
    @carta_b = create_card(@set_b, "OP02-p1a", "Portgas D. Ace")
    @v_b = create_variant(@carta_b, @set_b, "OP02-p1a")
    own(@user, @v_b, 2)

    # Carta que **estreou** em `@set_a` e foi **impressa** em `@set_b`: o eixo
    # da agregação decide em qual set ela conta.
    @carta_reimpressa = create_card(@set_a, "OP01-p1f", "Monkey D. Luffy")
    @v_reimpressao = create_variant(@carta_reimpressa, @set_b, "OP01-p1f_p1")
    own(@user, @v_reimpressao, 1)

    # --- @set_c ---------------------------------------------------------
    # Existe, ninguém possui.
    @carta_c = create_card(@set_c, "OP03-p1a", "Shanks")
    @v_c = create_variant(@carta_c, @set_c, "OP03-p1a")
  end

  def create_card(set, number, name)
    Card.create!(card_set: set, card_number: number, name: name,
                 card_type: "character", power: 3000, colors: [ "Red" ])
  end

  def create_variant(card, set, code, art_kind: "base")
    CardVariant.create!(card: card, set_id: set.id, variant_code: code,
                        rarity: "C", art_kind: art_kind)
  end

  def own(user, variant, quantity)
    CollectionItem.create!(user: user, card_variant: variant, quantity: quantity)
  end

  # O resultado é indexado por set para que as asserções falem de um set
  # nomeado, e não de uma posição numa lista.
  def progress(user = @user)
    SetProgressQuery.new(user).call.index_by { |row| row.set_code }
  end

  # --- PRG-01: possuídas e total por set --------------------------------

  test "devolve, por set, as variantes distintas possuídas e o total do set" do
    resultado = progress

    a = resultado["OPp1a"]
    assert_equal 2, a.owned_variants, "possui @v_cinco e @v_uma em OPp1a"
    assert_equal 5, a.total_variants, "OPp1a tem 5 impressões: cinco, uma, zerada, intocada, alheia"

    b = resultado["OPp1b"]
    assert_equal 2, b.owned_variants, "possui @v_b e a reimpressão @v_reimpressao"
    assert_equal 2, b.total_variants
  end

  test "set sem nenhuma posse aparece com numerador zero, e não some" do
    c = progress["OPp1c"]

    assert_not_nil c, "set sem posse continua no resultado"
    assert_equal 0, c.owned_variants
    assert_equal 1, c.total_variants
  end

  test "todo set do catálogo aparece no resultado" do
    codigos = progress.keys

    assert_includes codigos, "OPp1a"
    assert_includes codigos, "OPp1b"
    assert_includes codigos, "OPp1c"
  end

  test "o set é identificado por código e nome, sem consulta extra pelo chamador" do
    a = progress["OPp1a"]

    assert_equal "OPp1a", a.set_code
    assert_equal "Romance Dawn", a.set_name
    assert_equal @set_a.id, a.set_id
  end

  # --- PRG-04: variantes distintas, nunca cópias ------------------------

  # O critério central da task, e a razão de `@v_cinco` existir: as duas
  # métricas são medidas **no mesmo cenário**, lado a lado. Uma agregação que
  # trocasse `count` por `sum(:quantity)` daria 6 aqui e passaria em tudo mais.
  test "uma variante com quantidade 5 conta 1 no progresso e 5 no total de cópias" do
    a = progress["OPp1a"]

    # Progresso: duas variantes distintas possuídas em OPp1a (a de 5 e a de 1).
    assert_equal 2, a.owned_variants

    # Req. 7.7, mesma coleção, outra pergunta: 5 + 1 + 0 no set A, 2 + 1 no B.
    assert_equal 9, CollectionItem.total_copies_for(@user)

    # E a asserção que fecha a distinção: a variante de cinco cópias, sozinha,
    # vale 1 no progresso e 5 no total.
    apenas_cinco = CollectionItem.where(user: @user, card_variant: @v_cinco)
    assert_equal 1, apenas_cinco.owned.count
    assert_equal 5, apenas_cinco.owned.sum(:quantity)
  end

  test "aumentar a quantidade de uma variante possuída não altera o progresso" do
    antes = progress["OPp1a"].owned_variants

    CollectionItem.find_by!(user: @user, card_variant: @v_cinco).update!(quantity: 99)

    assert_equal antes, progress["OPp1a"].owned_variants,
                 "progresso conta variantes distintas; cópias são o Req. 7.7"
    assert_equal 103, CollectionItem.total_copies_for(@user),
                 "o total de cópias, esse sim, acompanha a quantidade"
  end

  # --- PRG-07: quantidade zero não é posse ------------------------------

  test "variante com quantidade zero não entra no numerador" do
    a = progress["OPp1a"]

    assert_equal 2, a.owned_variants,
                 "@v_zerada tem registro com quantity = 0 e não pode contar"
  end

  test "quantidade zero dá o mesmo resultado de não haver registro" do
    com_zerada = progress["OPp1a"].owned_variants

    # Apagar a linha zerada não pode mudar nada: zero e ausência são a mesma
    # não-posse para o progresso.
    CollectionItem.find_by!(user: @user, card_variant: @v_zerada).destroy!

    assert_equal com_zerada, progress["OPp1a"].owned_variants
  end

  test "zerar a quantidade de uma variante possuída diminui o numerador" do
    assert_equal 2, progress["OPp1a"].owned_variants

    CollectionItem.find_by!(user: @user, card_variant: @v_uma).update!(quantity: 0)

    assert_equal 1, progress["OPp1a"].owned_variants,
                 "`owned` filtra por quantidade, não por existência do registro"
  end

  # --- Eixo da agregação: set da impressão, não set de estreia ----------

  # `@carta_reimpressa` estreou em `@set_a` (`cards.set_id`) e foi impressa em
  # `@set_b` (`card_variants.set_id`). O número certo em cada set é o que
  # distingue os dois eixos — e é a mesma razão que `CatalogQuery::VARIANT_FILTERS`
  # documenta.
  test "variante impressa em set diferente do set de estreia conta no set da impressão" do
    resultado = progress

    assert_equal @set_a.id, @carta_reimpressa.set_id, "a carta estreou em OPp1a"
    assert_equal @set_b.id, @v_reimpressao.set_id, "a variante foi impressa em OPp1b"

    assert_equal 2, resultado["OPp1b"].owned_variants,
                 "a reimpressão conta em OPp1b, o set da impressão"
    assert_equal 2, resultado["OPp1a"].owned_variants,
                 "e não em OPp1a, o set de estreia da carta"
  end

  test "o total de variantes do set também sai do set da impressão" do
    resultado = progress

    # OPp1a tem 6 cartas de estreia mas só 5 impressões suas: a sexta foi
    # impressa em OPp1b. Agregar por `cards.set_id` daria 6 e 1.
    assert_equal 5, resultado["OPp1a"].total_variants
    assert_equal 2, resultado["OPp1b"].total_variants
  end

  # --- PRG-08: o progresso parte do usuário da sessão -------------------

  test "posse de outro usuário não entra no progresso do alvo" do
    assert_equal 2, progress["OPp1a"].owned_variants,
                 "@v_alheia é do @outro e está no mesmo set"
  end

  test "cada usuário vê o próprio progresso no mesmo set" do
    assert_equal 2, progress(@user)["OPp1a"].owned_variants
    assert_equal 1, progress(@outro)["OPp1a"].owned_variants
  end

  test "usuário sem posse alguma vê todos os sets com numerador zero" do
    sozinho = User.create!(email: "chopper-prg1@example.com", password: "log-pose-77")

    resultado = progress(sozinho)

    assert_equal 0, resultado["OPp1a"].owned_variants
    assert_equal 0, resultado["OPp1b"].owned_variants
    assert_equal 5, resultado["OPp1a"].total_variants,
                 "o denominador é do catálogo e não depende de quem olha"
  end

  test "nil devolve todos os sets com numerador zero, sem erro" do
    resultado = progress(nil)

    assert_includes resultado.keys, "OPp1a"
    assert_includes resultado.keys, "OPp1b"
    assert_includes resultado.keys, "OPp1c"

    assert_equal 0, resultado["OPp1a"].owned_variants
    assert_equal 0, resultado["OPp1b"].owned_variants
    assert_equal 5, resultado["OPp1a"].total_variants
  end

  # A barreira que a T5 da `colecao` desenhou: um id vindo do request não chega
  # a virar consulta. Sem ela, `SetProgressQuery.new(params[:user_id])`
  # compilaria e a violação de autorização passaria despercebida na revisão.
  test "id numérico no lugar do usuário levanta ArgumentError" do
    erro = assert_raises(ArgumentError) { SetProgressQuery.new(@user.id).call }

    assert_match(/for_user/, erro.message + erro.class.to_s,
                 "a barreira é a de CollectionItem.for_user")
  end

  test "id numérico levanta ArgumentError mesmo antes de chamar call" do
    assert_raises(ArgumentError) { SetProgressQuery.new(@outro.id).call }
  end

  test "string no lugar do usuário levanta ArgumentError" do
    assert_raises(ArgumentError) { SetProgressQuery.new("7").call }
  end

  # --- Forma da agregação -----------------------------------------------

  # PRG-11 é medido na T8, mas a forma nasce aqui: um `count` por set seria
  # N+1, e a asserção abaixo é o que impede a regressão silenciosa para essa
  # forma. Três sets no cenário; se o número de consultas acompanhasse os sets,
  # seriam ao menos três.
  test "o número de consultas não cresce com a quantidade de sets" do
    consultas = capturar_consultas { SetProgressQuery.new(@user).call.to_a }
    antes = consultas.size

    5.times do |i|
      set = CardSet.create!(code: "OPp1x#{i}", name: "Extra #{i}", kind: "booster",
                            base_set_size: 1, total_set_size: 1)
      carta = create_card(set, "OP9#{i}-p1a", "Extra #{i}")
      create_variant(carta, set, "OP9#{i}-p1a")
    end

    depois = capturar_consultas { SetProgressQuery.new(@user).call.to_a }.size

    assert_equal antes, depois,
                 "cinco sets a mais não podem custar consulta a mais"
  end

  def capturar_consultas
    consultas = []
    assinante = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name].to_s.in?([ "SCHEMA", "TRANSACTION" ])
      next if payload[:sql].to_s.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      consultas << payload[:sql]
    end
    yield
    consultas
  ensure
    ActiveSupport::Notifications.unsubscribe(assinante)
  end
end
