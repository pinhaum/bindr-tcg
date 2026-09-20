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
#
# T2 — percentual com denominador `base_set_size` (PRG-02, PRG-05, PRG-10).
#
# O percentual acrescenta três armadilhas próprias, e os sets `@set_d` a
# `@set_g` existem só para que cada uma delas **discrimine**:
#
# 4. **O denominador é `sets.base_set_size`, nunca uma contagem local de
#    `art_kind = 'base'`.** `@set_d` é o caso medido em 21 dos 62 sets do banco
#    real: `base_set_size = 4` com **uma** variante `base` e três `other` — o
#    retrato de `PRB01` (113 contra 1) em escala de teste. Uma implementação
#    que contasse `art_kind = 'base'` localmente daria denominador 1 e exibiria
#    100% para quem possui uma carta de quatro. Nos sets `@set_a` a `@set_c` as
#    duas fontes coincidem, logo nenhum deles distingue os dois denominadores.
# 5. **O numerador conta `art_kind IN ('base','other')`, e exclui `parallel`.**
#    `@set_d` tem posse em variante `other` e `@set_e` em `parallel`: um
#    numerador restrito a `'base'` erraria o primeiro; um numerador sem filtro
#    nenhum erraria o segundo.
# 6. **Denominador ausente e denominador zero são o mesmo caminho, e esse
#    caminho não é zero por cento.** `@set_f` (`base_set_size` nulo, o
#    `PRB9cd8` do banco real) e `@set_g` (`base_set_size = 0`) têm **posse
#    registrada**: um percentual exibido como `0` seria indistinguível de "não
#    comecei este set" exatamente onde o usuário já tem cartas.
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

    # --- @set_d: base_set_size diverge de count(art_kind = 'base') -------
    # `base_set_size = 4` com uma só variante `base` e três `other`. É o caso
    # medido em 21 dos 62 sets reais, e o único cenário em que o denominador
    # da fonte e a contagem local dão números diferentes.
    @set_d = CardSet.create!(code: "OPp2d", name: "Kingdoms of Intrigue", kind: "booster",
                             base_set_size: 4, total_set_size: 6)
    @v_d_base = create_variant(create_card(@set_d, "OP04-p2a", "Crocodile"), @set_d, "OP04-p2a")
    @v_d_other1 = create_variant(create_card(@set_d, "OP04-p2b", "Nico Robin"), @set_d,
                                 "OP04-p2b", art_kind: "other")
    @v_d_other2 = create_variant(create_card(@set_d, "OP04-p2c", "Smoker"), @set_d,
                                 "OP04-p2c", art_kind: "other")
    @v_d_other3 = create_variant(create_card(@set_d, "OP04-p2d", "Tashigi"), @set_d,
                                 "OP04-p2d", art_kind: "other")
    # Dois parallels, que não podem entrar em numerador nem denominador.
    @v_d_par1 = create_variant(create_card(@set_d, "OP04-p2e", "Sir Crocodile"), @set_d,
                               "OP04-p2e", art_kind: "parallel")
    @v_d_par2 = create_variant(create_card(@set_d, "OP04-p2f", "Mr. 1"), @set_d,
                               "OP04-p2f", art_kind: "parallel")
    own(@user, @v_d_base, 1)
    own(@user, @v_d_other1, 3)

    # --- @set_e: posse apenas de parallel --------------------------------
    @set_e = CardSet.create!(code: "OPp2e", name: "Awakening of the New Era", kind: "booster",
                             base_set_size: 2, total_set_size: 4)
    @v_e_base = create_variant(create_card(@set_e, "OP05-p2a", "Sabo"), @set_e, "OP05-p2a")
    @v_e_par = create_variant(create_card(@set_e, "OP05-p2b", "Koala"), @set_e,
                              "OP05-p2b", art_kind: "parallel")
    own(@user, @v_e_par, 2)

    # --- @set_f: sem base_set_size (o `PRB9cd8` do banco real) -----------
    # Tem posse registrada de propósito: é o que impede "indisponível" de se
    # confundir com "não comecei".
    @set_f = CardSet.create!(code: "OPp2f", name: "X", kind: "promo",
                             base_set_size: nil, total_set_size: nil)
    @v_f = create_variant(create_card(@set_f, "PR-p2f01", "Registro-lixo"), @set_f, "PR-p2f01")
    own(@user, @v_f, 1)

    # --- @set_g: base_set_size zero --------------------------------------
    @set_g = CardSet.create!(code: "OPp2g", name: "Zero Denominator", kind: "promo",
                             base_set_size: 0, total_set_size: 2)
    @v_g = create_variant(create_card(@set_g, "PR-p2g01", "Denominador zero"), @set_g, "PR-p2g01")
    own(@user, @v_g, 1)
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

    # Req. 7.7, mesma coleção, outra pergunta. O total é somatório de cópias e
    # cresce quando o cenário cresce, então a asserção mede a **diferença** que
    # `@v_cinco` faz nas duas métricas, e não um número absoluto que qualquer
    # posse acrescentada pela T2 deslocaria.
    copias = CollectionItem.total_copies_for(@user)
    variantes = CollectionItem.for_user(@user).owned.count
    assert_operator copias, :>, variantes,
                    "somar cópias e contar variantes não podem dar o mesmo número"

    # E a diferença medida é exatamente o excedente de cada variante possuída
    # com mais de uma cópia — `@v_cinco` (5), `@v_d_other1` (3) e `@v_e_par` (2).
    excedente = CollectionItem.for_user(@user).owned.sum("quantity - 1")
    assert_equal 8, excedente
    assert_equal excedente, copias - variantes

    # E a asserção que fecha a distinção: a variante de cinco cópias, sozinha,
    # vale 1 no progresso e 5 no total.
    apenas_cinco = CollectionItem.where(user: @user, card_variant: @v_cinco)
    assert_equal 1, apenas_cinco.owned.count
    assert_equal 5, apenas_cinco.owned.sum(:quantity)
  end

  test "aumentar a quantidade de uma variante possuída não altera o progresso" do
    antes = progress["OPp1a"].owned_variants
    copias_antes = CollectionItem.total_copies_for(@user)

    CollectionItem.find_by!(user: @user, card_variant: @v_cinco).update!(quantity: 99)

    assert_equal antes, progress["OPp1a"].owned_variants,
                 "progresso conta variantes distintas; cópias são o Req. 7.7"
    assert_equal copias_antes + 94, CollectionItem.total_copies_for(@user),
                 "o total de cópias, esse sim, acompanha a quantidade: 5 viraram 99"
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

  # --- PRG-05: o denominador é `sets.base_set_size` ---------------------

  test "o denominador do percentual é base_set_size, e não o total de impressões do set" do
    d = progress["OPp2d"]

    assert_equal 4, d.base_size, "o denominador vem de sets.base_set_size"
    assert_equal 6, d.total_variants, "o set tem 6 impressões, que não são o denominador"
    assert_not_equal d.total_variants, d.base_size,
                     "se as duas coincidissem, nenhuma asserção distinguiria os denominadores"
  end

  # A armadilha medida em 21 dos 62 sets reais: `@set_d` tem `base_set_size = 4`
  # e **uma só** variante `art_kind = 'base'`. Um denominador contado
  # localmente daria 1, e o percentual sairia 200% para duas possuídas.
  test "denominador ignora a contagem local de art_kind base, que diverge da fonte" do
    base_locais = CardVariant.where(set_id: @set_d.id, art_kind: "base").count
    assert_equal 1, base_locais, "o cenário reproduz a divergência medida no banco real"

    d = progress["OPp2d"]

    assert_equal 4, d.base_size
    assert_not_equal base_locais, d.base_size,
                     "contar art_kind = 'base' localmente daria 1 em vez de 4"
  end

  # --- PRG-02: percentual com numerador e denominador conhecidos --------

  test "percentual com denominador e numerador conhecidos" do
    # `@set_d`: possui `@v_d_base` (base) e `@v_d_other1` (other) de 4.
    d = progress["OPp2d"]

    assert_equal 2, d.base_owned_variants
    assert_equal 4, d.base_size
    assert_equal 50.0, d.completion_percent
  end

  test "percentual de set com posse parcial nos sets em que as duas fontes coincidem" do
    # `@set_a`: `base_set_size = 3`, possui `@v_cinco` e `@v_uma`.
    a = progress["OPp1a"]

    assert_equal 2, a.base_owned_variants
    assert_equal 3, a.base_size
    assert_in_delta 66.67, a.completion_percent, 0.01
  end

  test "set sem nenhuma posse tem percentual zero, que é um número e não indisponibilidade" do
    c = progress["OPp1c"]

    assert_equal 0, c.base_owned_variants
    assert_equal 0.0, c.completion_percent
    assert c.completion_percent_known?,
           "zero por cento é informação; indisponível é a ausência dela"
  end

  # --- PRG-02: o numerador conta `base` e `other`, e exclui `parallel` ---

  test "o numerador do percentual conta variantes other além das base" do
    d = progress["OPp2d"]

    # `@v_d_base` é `base` e `@v_d_other1` é `other`: um numerador restrito a
    # `'base'` daria 1 e exibiria 25% para quem tem metade do set.
    assert_equal "base", @v_d_base.art_kind
    assert_equal "other", @v_d_other1.art_kind
    assert_equal 2, d.base_owned_variants,
                 "numerador e denominador precisam contar o mesmo universo"
  end

  test "o numerador do percentual exclui variantes parallel" do
    # `@set_e`: a única posse é `@v_e_par`, que é `parallel`.
    e = progress["OPp2e"]

    assert_equal "parallel", @v_e_par.art_kind
    assert_equal 1, e.owned_variants, "a posse existe e aparece no numerador do Req. 9.1"
    assert_equal 0, e.base_owned_variants, "mas não no numerador do percentual"
    assert_equal 0.0, e.completion_percent
  end

  test "possuir um parallel a mais não altera o percentual de conclusão do set" do
    antes = progress["OPp2d"].completion_percent

    own(@user, @v_d_par2, 1)

    assert_equal antes, progress["OPp2d"].completion_percent,
                 "parallel é métrica separada e nunca entra no percentual (AD-003)"
  end

  test "variantes parallel do set não inflam o denominador" do
    d = progress["OPp2d"]

    # O set tem 2 parallels entre as 6 impressões; o denominador continua 4.
    assert_equal 2, CardVariant.where(set_id: @set_d.id, art_kind: "parallel").count
    assert_equal 4, d.base_size
  end

  # --- PRG-10: denominador ausente é indisponível, nunca 0 nem 100 ------

  test "set sem base_set_size é exibido, com a posse real e percentual indisponível" do
    f = progress["OPp2f"]

    assert_not_nil f, "o set não pode sumir: o usuário tem posse nele"
    assert_equal 1, f.owned_variants, "a posse real é exibida"
    assert_equal 1, f.base_owned_variants

    assert_nil f.base_size, "o set não tem denominador conhecido"
    assert_nil f.completion_percent, "percentual indisponível"
    assert_not f.completion_percent_known?
  end

  # O critério literal da spec: nem `0`, nem `100`. Um `nil` satisfaz os dois
  # por construção, e a asserção existe para travar a representação contra uma
  # implementação futura que "resolvesse" o nulo com um default.
  test "percentual indisponível não é zero nem cem por cento" do
    f = progress["OPp2f"]

    assert_not_equal 0, f.completion_percent
    assert_not_equal 0.0, f.completion_percent
    assert_not_equal 100, f.completion_percent
    assert_not_equal 100.0, f.completion_percent
  end

  # `nil` e `0` têm de ser distinguíveis sem ambiguidade pelo consumidor da
  # API — a view da T5 não pode confundir "indisponível" com "não comecei".
  test "indisponível e zero por cento são distinguíveis pelo chamador" do
    indisponivel = progress["OPp2f"]
    zerado = progress["OPp1c"]

    assert_nil indisponivel.completion_percent
    assert_equal 0.0, zerado.completion_percent
    assert_not_equal indisponivel.completion_percent, zerado.completion_percent

    assert_not indisponivel.completion_percent_known?
    assert zerado.completion_percent_known?
  end

  test "denominador zero cai no mesmo caminho do denominador ausente" do
    g = progress["OPp2g"]
    f = progress["OPp2f"]

    assert_equal 0, @set_g.base_set_size, "o cenário é denominador zero, não nulo"
    assert_equal 1, g.owned_variants, "a posse continua exibida"

    assert_nil g.completion_percent, "nenhuma divisão é executada"
    assert_not g.completion_percent_known?
    assert_equal f.completion_percent_known?, g.completion_percent_known?,
                 "ausente e zero são o mesmo caminho"
  end

  test "denominador zero não levanta erro de divisão nem devolve infinito ou NaN" do
    g = nil
    assert_nothing_raised { g = progress["OPp2g"] }

    assert_nil g.completion_percent
    assert_not_equal Float::INFINITY, g.completion_percent
  end

  # --- Numerador excedente: limitado a cem por cento, sem erro ----------

  # Alcançável hoje: ST16 tem `base_set_size = 7` e 6 variantes não-parallel, e
  # a divergência de classificação pode inverter o sinal em outro set após uma
  # reingestão. `@set_h` reproduz o caso.
  test "numerador maior que o denominador é limitado a cem por cento, sem erro" do
    set_h = CardSet.create!(code: "OPp2h", name: "Excedente", kind: "booster",
                            base_set_size: 1, total_set_size: 3)
    tres = 3.times.map do |i|
      variante = create_variant(create_card(set_h, "OP06-p2#{i}", "Excedente #{i}"),
                                set_h, "OP06-p2#{i}")
      own(@user, variante, 1)
      variante
    end

    h = progress["OPp2h"]

    assert_equal 3, tres.size
    assert_equal 3, h.base_owned_variants, "o numerador real é 3"
    assert_equal 1, h.base_size, "contra um denominador de 1"
    assert_equal 100.0, h.completion_percent,
                 "apresentado limitado a cem por cento, nunca 300%"
    assert h.completion_percent_known?
  end

  test "numerador igual ao denominador dá exatamente cem por cento" do
    own(@user, @v_d_other2, 1)
    own(@user, @v_d_other3, 1)

    d = progress["OPp2d"]

    assert_equal 4, d.base_owned_variants
    assert_equal 4, d.base_size
    assert_equal 100.0, d.completion_percent
  end

  # --- PRG-06: parallels como métrica separada --------------------------

  test "cada set traz a contagem de parallels possuídos e o total de parallels do set" do
    # `@set_d`: 2 parallels impressos, nenhum possuído ainda.
    d = progress["OPp2d"]
    assert_equal 0, d.parallel_owned_variants
    assert_equal 2, d.parallel_variants

    # `@set_e`: 1 parallel impresso e possuído.
    e = progress["OPp2e"]
    assert_equal 1, e.parallel_owned_variants
    assert_equal 1, e.parallel_variants
  end

  # O critério que separa uma implementação correta de uma que soma parallels no
  # numerador. `@set_e` é o cenário montado para discriminar: a **única** posse é
  # `@v_e_par`, um `parallel`. O percentual tem de ser zero e a contagem de
  # parallels **um** — os dois números diferentes, senão nenhuma asserção
  # distinguiria "não somou" de "somou".
  test "posse apenas de parallels mantém o percentual em zero e a contagem refletindo a posse" do
    e = progress["OPp2e"]

    assert_equal "parallel", @v_e_par.art_kind
    assert_equal 1, CollectionItem.for_user(@user).owned
                                  .joins(:card_variant)
                                  .where(card_variants: { set_id: @set_e.id }).count,
                 "a única posse do usuário em OPp2e é o parallel"

    assert_equal 0.0, e.completion_percent,
                 "parallel nunca entra no numerador do percentual (AD-003, Req. 9.6)"
    assert_equal 0, e.base_owned_variants

    assert_equal 1, e.parallel_owned_variants,
                 "e a métrica separada reflete a posse"
    assert_not_equal e.completion_percent, e.parallel_owned_variants,
                     "com os dois números iguais nenhuma asserção discriminaria"
  end

  test "parallels não entram no denominador do percentual" do
    e = progress["OPp2e"]

    # O set tem 2 impressões (1 base, 1 parallel) e `base_set_size = 2`. O
    # denominador vem da fonte e não soma o parallel impresso.
    assert_equal 2, e.total_variants
    assert_equal 1, e.parallel_variants
    assert_equal 2, e.base_size,
                 "o denominador é base_set_size, e o parallel não o infla"
  end

  # O par do teste acima: no **mesmo** cenário, acrescentar uma variante base
  # move só o percentual. Se os parallels vazassem para o numerador, a contagem
  # de parallels e o percentual andariam juntos e este teste não discriminaria.
  test "acrescentar uma variante base altera só o percentual, deixando os parallels intactos" do
    antes = progress["OPp2e"]
    assert_equal 0.0, antes.completion_percent
    assert_equal 1, antes.parallel_owned_variants

    own(@user, @v_e_base, 1)

    depois = progress["OPp2e"]

    assert_equal 50.0, depois.completion_percent,
                 "uma base de duas: o percentual muda"
    assert_equal 1, depois.base_owned_variants

    assert_equal antes.parallel_owned_variants, depois.parallel_owned_variants,
                 "a contagem de parallels fica intacta: a base não é parallel"
    assert_equal antes.parallel_variants, depois.parallel_variants
  end

  test "possuir um parallel a mais altera só a contagem de parallels, não o percentual" do
    antes = progress["OPp2d"]

    own(@user, @v_d_par1, 1)

    depois = progress["OPp2d"]

    assert_equal antes.completion_percent, depois.completion_percent,
                 "o percentual não se mexe (AD-003)"
    assert_equal antes.base_owned_variants, depois.base_owned_variants
    assert_equal antes.parallel_owned_variants + 1, depois.parallel_owned_variants,
                 "só a métrica separada acompanha"
  end

  test "set sem nenhuma variante parallel apresenta a métrica como zero, sem ocultá-la" do
    # `@set_c` tem uma única impressão, `base`. A métrica existe e vale zero.
    c = progress["OPp1c"]

    assert_equal 0, CardVariant.where(set_id: @set_c.id, art_kind: "parallel").count,
                 "o cenário é um set sem parallel nenhum"

    assert_not_nil c, "o set não pode sumir por não ter parallel"
    assert_equal 0, c.parallel_variants
    assert_equal 0, c.parallel_owned_variants
  end

  test "a contagem de parallels conta variantes distintas, nunca cópias" do
    # `@v_e_par` tem 2 cópias e conta **1**, pela mesma regra do Req. 9.4.
    assert_equal 2, CollectionItem.find_by!(user: @user, card_variant: @v_e_par).quantity

    assert_equal 1, progress["OPp2e"].parallel_owned_variants
  end

  test "parallel com quantidade zero não conta como possuído" do
    own(@user, @v_d_par1, 0)

    assert_equal 0, progress["OPp2d"].parallel_owned_variants,
                 "`owned` filtra por quantidade, também na métrica separada"
  end

  test "parallel de outro usuário não entra na contagem do alvo" do
    own(@outro, @v_d_par1, 3)

    assert_equal 0, progress(@user)["OPp2d"].parallel_owned_variants
    assert_equal 1, progress(@outro)["OPp2d"].parallel_owned_variants
    assert_equal 2, progress(@outro)["OPp2d"].parallel_variants,
                   "o total de parallels é do catálogo e não depende de quem olha"
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
