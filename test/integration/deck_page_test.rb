require "test_helper"

# T9 (decks) — a página do deck: composição, status, avisos e "fora da fonte"
# (DCK-07, DCK-15, DCK-17, DCK-19, DCK-44).
#
# Integração sobre o HTML renderizado: não há navegador no container
# (SPEC_DEVIATION do projeto).
class DeckPageTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  BAN_NOTICE = "A lista de banidas não é verificada".freeze
  OWN_RULE_NOTICE = "Este Leader tem regra de montagem própria, não verificada".freeze
  # Texto real da OP12-001 (Silvers Rayleigh), como em `legality_test.rb`.
  RAYLEIGH_RULE = "Under the rules of this game, you cannot include cards with a cost of 5 or more in your deck.".freeze

  setup do
    @user = User.create!(email: "deck-t9@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "DT09", name: "Decks T9", kind: "booster")
    @leader = create_card("DT09-001", name: "Leader Preto", card_type: "leader")
  end

  def create_card(number, name: "Carta #{number}", card_type: "character", cost: nil, colors: [ "Black" ],
                  effect_text: nil, present: true)
    Card.create!(card_set: @set, card_number: number, name: name, card_type: card_type, cost: cost,
                 colors: colors, effect_text: effect_text).tap do |card|
      CardVariant.create!(card: card, card_set: @set, variant_code: "tcgplayer:#{number}", art_kind: "base",
                          last_seen_at: present ? nil : CATALOG_SEEN_AT - 1.day)
    end
  end

  def create_deck(name: "Deck", leader: nil, entries: {})
    mark_catalog_present!
    Deck.create!(user: @user, name: name, leader: leader).tap do |deck|
      entries.each { |card, quantity| deck.entries.create!(card: card, quantity: quantity) }
    end
  end

  # 12 × 4 + 1 × 2 = 50 cartas pretas, para um deck válido com o Leader preto.
  def full_entries(prefix)
    cards = (2..14).map { |n| create_card(format("#{prefix}-%03d", n), cost: 1) }
    cards.first(12).to_h { |card| [ card, 4 ] }.merge(cards.last => 2)
  end

  def sign_in
    post session_path, params: { email: @user.email, password: PASSWORD }
  end

  def status_section
    css_select("section[aria-labelledby='deck-status-title']").first
  end

  def capture_queries
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      # Consulta servida pelo cache também conta: o que se mede é quantas a
      # página pede, não quantas o cache deixou passar.
      next if payload[:name].to_s.in?([ "SCHEMA", "TRANSACTION" ])

      queries << payload[:sql]
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # --- Composição (DCK-07) ---

  test "as entradas aparecem em Character, Event e Stage, por custo e depois card_number" do
    stage = create_card("DT09-050", card_type: "stage", cost: 1)
    event_cost2 = create_card("DT09-040", card_type: "event", cost: 2)
    event_cost1 = create_card("DT09-041", card_type: "event", cost: 1)
    char_no_cost = create_card("DT09-030", cost: nil)
    char_b = create_card("DT09-022", cost: 3)
    char_a = create_card("DT09-021", cost: 3)
    char_cost1 = create_card("DT09-029", cost: 1)
    deck = create_deck(leader: @leader, entries: {
      stage => 1, event_cost2 => 2, event_cost1 => 3, char_no_cost => 1, char_b => 4, char_a => 2, char_cost1 => 1
    })
    sign_in

    get deck_path(deck)

    assert_response :success
    groups = css_select("section[aria-labelledby='deck-main-title'] section")
    assert_equal [ "Character", "Event", "Stage" ], groups.map { |group| group.at_css("h3").text.strip }
    assert_equal [
      [ "DT09-029", "DT09-021", "DT09-022", "DT09-030" ],
      [ "DT09-041", "DT09-040" ],
      [ "DT09-050" ]
    ], groups.map { |group| group.css("li a").map { |a| a.text[/DT09-\d+/] } }
    assert_equal [ "1×", "2×", "4×", "1×" ], groups.first.css("li > span:first-child").map { |span| span.text.strip }
  end

  test "o Leader aparece com nome e card_number" do
    deck = create_deck(leader: @leader)
    sign_in

    get deck_path(deck)

    assert_select "section[aria-labelledby='deck-leader-title'] a[href='#{card_path('DT09-001')}']",
                  text: "Leader Preto (DT09-001)"
  end

  test "sem Leader, a página diz Sem Leader" do
    deck = create_deck
    sign_in

    get deck_path(deck)

    assert_select "section[aria-labelledby='deck-leader-title'] p", text: "Sem Leader"
  end

  # --- "N / 50" e status (DCK-07, DCK-11) ---

  test "N / 50 segue main_total e o status válido não mostra motivo" do
    deck = create_deck(leader: @leader, entries: full_entries("DT09V"))
    sign_in

    get deck_path(deck)

    assert_select "h2#deck-main-title", text: "Deck principal: 50 / 50"
    assert_select "h2#deck-status-title", text: "Status: válido"
    assert_empty status_section.css("ul li")
  end

  test "status incompleto mostra cada motivo" do
    card = create_card("DT09-002", cost: 1)
    deck = create_deck(entries: { card => 3 })
    sign_in

    get deck_path(deck)

    assert_select "h2#deck-main-title", text: "Deck principal: 3 / 50"
    assert_select "h2#deck-status-title", text: "Status: incompleto"
    assert_equal [ "O deck não tem Leader", "Faltam 47 cartas para 50" ],
                 status_section.css("ul li").map { |li| li.text.strip }
  end

  test "status inválido mostra cada motivo, nomeando as cartas" do
    five = create_card("DT09-002", cost: 1)
    red = create_card("DT09-003", cost: 1, colors: [ "Red" ])
    deck = create_deck(leader: @leader, entries: { five => 5, red => 1 })
    sign_in

    get deck_path(deck)

    assert_select "h2#deck-status-title", text: "Status: inválido"
    assert_equal [ "Faltam 44 cartas para 50", "DT09-002 tem 5 cópias; o máximo é 4",
                   "DT09-003 é vermelha e o Leader é preto" ],
                 status_section.css("ul li").map { |li| li.text.strip }
  end

  # --- Avisos (DCK-17, DCK-44) ---

  test "o aviso de banidas aparece com deck válido e com deck vazio" do
    valid = create_deck(name: "Válido", leader: @leader, entries: full_entries("DT09B"))
    empty = create_deck(name: "Vazio")
    sign_in

    [ valid, empty ].each do |deck|
      get deck_path(deck)
      assert_select "section[aria-labelledby='deck-status-title'] p", text: BAN_NOTICE
    end
  end

  test "Leader com regra própria mostra o aviso e o texto da regra, sem mudar o status" do
    rayleigh = create_card("DT09-100", name: "Silvers Rayleigh", card_type: "leader",
                                       effect_text: "#{RAYLEIGH_RULE}\n\n[Activate: Main] Faz algo.")
    deck = create_deck(leader: rayleigh, entries: full_entries("DT09R"))
    sign_in

    get deck_path(deck)

    assert_select "h2#deck-status-title", text: "Status: válido"
    assert_select "section[aria-labelledby='deck-status-title'] strong", text: OWN_RULE_NOTICE
    assert_select "section[aria-labelledby='deck-status-title'] blockquote", text: RAYLEIGH_RULE
  end

  test "Leader sem regra própria não mostra o aviso" do
    deck = create_deck(leader: @leader)
    sign_in

    get deck_path(deck)

    assert_no_match(/#{OWN_RULE_NOTICE}/, response.body)
    assert_select "blockquote", count: 0
  end

  # --- Fora da fonte (DCK-19) ---

  test "carta sem variante presente aparece marcada fora da fonte e continua contando no total" do
    gone = create_card("DT09-060", name: "Sumida", cost: 2, present: false)
    kept = create_card("DT09-061", name: "Presente", cost: 2)
    deck = create_deck(leader: @leader, entries: { gone => 3, kept => 1 })
    sign_in

    get deck_path(deck)

    items = css_select("section[aria-labelledby='deck-main-title'] li")
    marks = items.to_h { |li| [ li.at_css("a").text[/DT09-\d+/], li.text.include?("fora da fonte") ] }
    assert_equal({ "DT09-060" => true, "DT09-061" => false }, marks)
    assert_select "h2#deck-main-title", text: "Deck principal: 4 / 50"
  end

  test "Leader sem variante presente aparece marcado fora da fonte" do
    leader = create_card("DT09-070", card_type: "leader", present: false)
    deck = create_deck(leader: leader)
    sign_in

    get deck_path(deck)

    assert_select "section[aria-labelledby='deck-leader-title'] span", text: "fora da fonte"
  end

  # --- Consultas ---

  test "o número de consultas da página não cresce com o número de entradas" do
    small = create_deck(name: "Pequeno", leader: @leader, entries: { create_card("DT09-200", cost: 1) => 1 })
    big = create_deck(name: "Grande", leader: @leader, entries: full_entries("DT09Q"))
    sign_in

    small_count = capture_queries { get deck_path(small) }.size
    big_count = capture_queries { get deck_path(big) }.size

    assert_equal small_count, big_count
  end
end
