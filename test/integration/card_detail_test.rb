require "test_helper"

# T14 — página de detalhe da carta (Req. 5.1, 5.2, 5.4, 5.5).
#
# O critério mais fácil de errar é o Req. 5.5: campo inaplicável ao tipo é
# **omitido**, não exibido vazio. Um Event não tem power, e mostrar "Power: —"
# é pior que não mostrar nada — sugere um dado que não existe. Por isso há um
# teste por tipo de carta, cada um asserindo tanto o que aparece quanto o que
# **não** pode aparecer.
class CardDetailTest < ActionDispatch::IntegrationTest
  setup do
    @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @st01 = CardSet.create!(code: "ST01", name: "Straw Hat Crew", kind: "starter")
  end

  def create_card(**attrs) = Card.create!(set_id: @op01.id, **attrs)

  def add_variant(card, code, rarity:, card_set: @op01, image: nil)
    CardVariant.create!(card: card, set_id: card_set.id, variant_code: code,
                        rarity: rarity, art_kind: "base", image_url: image,
                        image_url_large: image)
  end

  # --- Req. 5.2: todas as variantes, cada uma com raridade, set e imagem ---

  test "lista todas as variantes da carta com raridade, set e imagem própria" do
    zoro = create_card(card_number: "OP01-001", name: "Roronoa Zoro",
                       card_type: "leader", colors: [ "Red" ], power: 5000, life: 5)
    add_variant(zoro, "OP01-001", rarity: "L", image: "https://example.test/base.png")
    add_variant(zoro, "OP01-001_p1", rarity: "SEC", image: "https://example.test/alt.png")
    # Reimpressão em outro set: a variante mostra o set dela, não o da carta.
    add_variant(zoro, "ST01-001", rarity: "C", card_set: @st01,
                image: "https://example.test/st01.png")

    get card_path("OP01-001")

    assert_response :success
    assert_select ".variant", 3

    assert_select ".variant__rarity", text: "L"
    assert_select ".variant__rarity", text: "SEC"
    assert_select ".variant__rarity", text: "C"

    assert_select ".variant__set", text: /Romance Dawn/
    assert_select ".variant__set", text: /Straw Hat Crew/

    %w[base alt st01].each do |arquivo|
      assert_select "img[src=?]", "https://example.test/#{arquivo}.png"
    end
  end

  test "cada variante exibe o próprio código" do
    zoro = create_card(card_number: "OP01-001", name: "Roronoa Zoro",
                       card_type: "leader", colors: [ "Red" ], power: 5000, life: 5)
    add_variant(zoro, "OP01-001", rarity: "L")
    add_variant(zoro, "OP01-001_p1", rarity: "SEC")

    get card_path("OP01-001")

    assert_select ".variant__code", text: "OP01-001"
    assert_select ".variant__code", text: "OP01-001_p1"
  end

  # Mesma mitigação do AD-004 da grade: a arte é hotlink e pode sumir.
  test "variante sem imagem exibe placeholder com nome e código" do
    nami = create_card(card_number: "OP01-002", name: "Nami", card_type: "character",
                       colors: [ "Green" ], cost: 1, power: 1000)
    add_variant(nami, "OP01-002", rarity: "C", image: nil)

    get card_path("OP01-002")

    assert_select ".variant__placeholder", text: /Nami/
    assert_select ".variant__placeholder", text: /OP01-002/
  end

  # --- Req. 5.5: campos inaplicáveis são omitidos ---

  test "Leader exibe life e power e não exibe cost nem counter" do
    leader = create_card(card_number: "OP01-001", name: "Roronoa Zoro",
                         card_type: "leader", colors: [ "Red" ],
                         power: 5000, life: 5, cost: nil, counter: nil)
    add_variant(leader, "OP01-001", rarity: "L")

    get card_path("OP01-001")

    assert_select ".field--life", text: /5/
    assert_select ".field--power", text: /5000/
    assert_select ".field--cost", 0, "Leader não tem cost — não pode aparecer vazio"
    assert_select ".field--counter", 0, "Leader não tem counter"
  end

  test "Event não exibe power, life nem counter" do
    evento = create_card(card_number: "OP01-004", name: "Gum-Gum Pistol",
                         card_type: "event", colors: [ "Red" ], cost: 1,
                         power: nil, life: nil, counter: nil,
                         effect_text: "Draw one card.")
    add_variant(evento, "OP01-004", rarity: "C")

    get card_path("OP01-004")

    assert_select ".field--cost", text: /1/
    assert_select ".field--power", 0, "Event não tem power (Req. 5.5)"
    assert_select ".field--life", 0, "Event não tem life"
    assert_select ".field--counter", 0, "Event não tem counter"
  end

  test "Stage não exibe power nem life" do
    stage = create_card(card_number: "OP01-030", name: "Thousand Sunny",
                        card_type: "stage", colors: [ "Red" ], cost: 2)
    add_variant(stage, "OP01-030", rarity: "UC")

    get card_path("OP01-030")

    assert_select ".field--cost", text: /2/
    assert_select ".field--power", 0
    assert_select ".field--life", 0
  end

  # `counter` NULL é "não tem counter", não counter 0 — a distinção do schema
  # tem que sobreviver até a tela. Exibir "Counter: 0" seria inventar dado.
  test "Character sem counter omite o campo em vez de exibir zero" do
    sem_counter = create_card(card_number: "OP01-010", name: "Sem Counter",
                              card_type: "character", colors: [ "Blue" ],
                              cost: 3, power: 4000, counter: nil)
    add_variant(sem_counter, "OP01-010", rarity: "C")

    get card_path("OP01-010")

    assert_select ".field--counter", 0,
                  "counter NULL não pode virar 'Counter: 0' na tela"
    assert_select "body", { text: /Counter/, count: 0 },
                  "nem o rótulo de counter deve aparecer"
  end

  test "Character com counter exibe o valor" do
    com_counter = create_card(card_number: "OP01-011", name: "Com Counter",
                              card_type: "character", colors: [ "Blue" ],
                              cost: 3, power: 4000, counter: 2000)
    add_variant(com_counter, "OP01-011", rarity: "C")

    get card_path("OP01-011")

    assert_select ".field--counter", text: /2000/
  end

  # Counter 1000 é valor real; counter 0 não existe no jogo. A asserção existe
  # para que um `if counter.present?` trocado por `if counter&.positive?` não
  # passe despercebido caso a fonte um dia entregue 0.
  test "campo de valor zero legítimo não é confundido com ausente" do
    custo_zero = create_card(card_number: "OP01-012", name: "Custo Zero",
                             card_type: "character", colors: [ "Blue" ],
                             cost: 0, power: 1000)
    add_variant(custo_zero, "OP01-012", rarity: "C")

    get card_path("OP01-012")

    # cost 0 é valor real do jogo e tem que aparecer.
    assert_select ".field--cost", text: /0/
  end

  # --- Req. 5.4: quebras de linha preservadas ---

  test "effect_text preserva quebras de linha" do
    carta = create_card(card_number: "OP01-020", name: "Multilinha",
                        card_type: "character", colors: [ "Red" ], cost: 2, power: 3000,
                        effect_text: "[On Play] Draw one card.\nThen, trash one card.")
    add_variant(carta, "OP01-020", rarity: "R")

    get card_path("OP01-020")

    assert_select ".card-detail__effect" do |elementos|
      html = elementos.first.to_html
      assert_match(/<br/, html,
                   "a quebra de linha do effect_text tem que sobreviver ao HTML (Req. 5.4)")
    end
    assert_select ".card-detail__effect", text: /Draw one card/
    assert_select ".card-detail__effect", text: /trash one card/
  end

  test "trigger_text preserva quebras de linha e só aparece quando existe" do
    com_trigger = create_card(card_number: "OP01-021", name: "Com Trigger",
                              card_type: "event", colors: [ "Red" ], cost: 1,
                              effect_text: "Main effect.",
                              trigger_text: "[Trigger] Play this card.\nThen draw.")
    add_variant(com_trigger, "OP01-021", rarity: "C")

    get card_path("OP01-021")

    assert_select ".card-detail__trigger" do |elementos|
      assert_match(/<br/, elementos.first.to_html)
    end
  end

  test "carta sem trigger não exibe a seção de trigger" do
    sem_trigger = create_card(card_number: "OP01-022", name: "Sem Trigger",
                              card_type: "character", colors: [ "Red" ],
                              cost: 1, power: 1000, effect_text: "Só efeito.",
                              trigger_text: nil)
    add_variant(sem_trigger, "OP01-022", rarity: "C")

    get card_path("OP01-022")

    assert_select ".card-detail__trigger", 0
  end

  test "carta sem texto de efeito não exibe seção de efeito vazia" do
    vanilla = create_card(card_number: "OP01-023", name: "Vanilla",
                          card_type: "character", colors: [ "Red" ],
                          cost: 1, power: 2000, effect_text: nil)
    add_variant(vanilla, "OP01-023", rarity: "C")

    get card_path("OP01-023")

    assert_select ".card-detail__effect", 0
  end

  # O texto vem de fonte externa: HTML nele tem que ser escapado, não renderizado.
  test "HTML no texto de efeito é escapado" do
    perigosa = create_card(card_number: "OP01-024", name: "Perigosa",
                           card_type: "character", colors: [ "Red" ], cost: 1, power: 1000,
                           effect_text: "<script>alert(1)</script>")
    add_variant(perigosa, "OP01-024", rarity: "C")

    get card_path("OP01-024")

    assert_response :success
    assert_no_match(/<script>alert/, response.body)
  end

  # --- Req. 5.1: campos conhecidos e imagem maior ---

  test "exibe os campos conhecidos da carta" do
    carta = create_card(card_number: "OP01-005", name: "Completa",
                        card_type: "character", colors: [ "Red", "Green" ],
                        cost: 4, power: 6000, counter: 1000,
                        traits: [ "Straw Hat Crew", "Supernovas" ],
                        attributes_list: [ "Slash" ], effect_text: "Faz algo.")
    add_variant(carta, "OP01-005", rarity: "SR")

    get card_path("OP01-005")

    assert_select ".card-detail__name", text: "Completa"
    assert_select ".card-detail__number", text: "OP01-005"
    assert_select ".field--colors", text: /Red/
    assert_select ".field--colors", text: /Green/
    assert_select ".field--traits", text: /Straw Hat Crew/
    assert_select ".field--attributes", text: /Slash/
    assert_select ".field--card-type", text: /Character/i
  end

  test "carta inexistente responde 404 em vez de erro" do
    get card_path("NAO-EXISTE")

    assert_response :not_found
  end

  test "a página de detalhe é alcançável a partir da grade" do
    carta = create_card(card_number: "OP01-001", name: "Roronoa Zoro",
                        card_type: "leader", colors: [ "Red" ], power: 5000, life: 5)
    add_variant(carta, "OP01-001", rarity: "L")

    get catalog_path
    assert_select ".card-tile a[href=?]", card_path("OP01-001")

    get card_path("OP01-001")
    assert_response :success
  end
end
