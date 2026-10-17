require "test_helper"

# STRO-31 — custo de `GET /api/progress` (PRG-11, AD-021). Migra a medição por
# requisição que `queries/set_progress_plan_test.rb` fazia sobre o HTML.
#
# O teste é sobre custo e forma, nunca sobre o número exibido. A asserção
# principal é a **diferença** entre dois cenários com quantidades de sets
# diferentes: sessão e demais consultas constantes se cancelam na subtração, e
# só uma consulta por set a quebraria. A auxiliar desconta nominalmente as
# consultas de sessão e prova que restam exatamente duas (sets e indicadores);
# a `listDeckShortfall` (AD-021) é medida em `/api/decks/shortfall`. Tudo com e
# sem decks.
class Api::ProgressPlanTest < ActionDispatch::IntegrationTest
  PASSWORD = "grand-line-t6".freeze
  CONSULTAS_DE_SESSAO = [ "Session Load", "User Load" ].freeze
  SETS_PEQUENO = 1
  SETS_GRANDE = 40

  setup do
    @user = User.create!(email: "plano-api-t6@example.com", password: PASSWORD)
    mark_catalog_present!
    entrar
  end

  test "o número de consultas da requisição não cresce com a quantidade de sets" do
    semear_sets(SETS_PEQUENO, prefixo: "P")
    pequeno = consultas_da_pagina

    semear_sets(SETS_GRANDE, prefixo: "G")
    grande = consultas_da_pagina

    assert_equal SETS_PEQUENO + SETS_GRANDE, CardSet.count,
                 "o segundo cenário precisa ter mais sets que o primeiro, senão nada é comparado"
    assert_equal pequeno.size, grande.size,
                 "#{SETS_GRANDE} sets a mais custaram #{grande.size - pequeno.size} consulta(s) a mais — " \
                 "a API está N+1 na quantidade de sets (PRG-11).\n" \
                 "Cenário pequeno:\n#{formatar(pequeno)}\nCenário grande:\n#{formatar(grande)}"
  end

  test "sem decks, descontadas as consultas de sessão, /api/progress resolve em duas agregações" do
    semear_sets(SETS_GRANDE, prefixo: "U")

    assert_agregacoes_de_progresso(consultas_da_pagina)
  end

  test "com decks, descontadas as consultas de sessão, /api/progress resolve em duas agregações" do
    semear_sets(SETS_GRANDE, prefixo: "D")
    criar_decks

    assert_agregacoes_de_progresso(consultas_da_pagina)
  end

  test "sem decks, /api/decks/shortfall resolve em uma listDeckShortfall (AD-021)" do
    semear_sets(SETS_GRANDE, prefixo: "S")

    assert_uma_list_deck_shortfall(consultas_do_shortfall)
  end

  test "com decks, /api/decks/shortfall resolve em uma listDeckShortfall (AD-021)" do
    semear_sets(SETS_GRANDE, prefixo: "F")
    criar_decks

    assert_uma_list_deck_shortfall(consultas_do_shortfall)
  end

  test "a requisição devolve os sets, senão a contagem mediria uma resposta vazia" do
    semear_sets(SETS_PEQUENO, prefixo: "R")

    get "/api/progress"

    assert_response :ok
    assert_equal SETS_PEQUENO, response.parsed_body.dig("data", "sets").size
  end

  private

  # AD-021 previa a `listDeckShortfall` na página HTML da pasta; na API ela é
  # um endpoint à parte (`/api/decks/shortfall`), então `/api/progress` fica
  # com a agregação por set e a dos indicadores.
  def assert_agregacoes_de_progresso(consultas)
    restantes = sem_consultas_de_sessao(consultas)

    assert_equal 2, restantes.size,
                 "a API deveria resolver em **duas** consultas além da sessão " \
                 "(sets + indicadores), e emitiu #{restantes.size}.\n#{formatar(restantes)}"
    assert_equal 0, restantes.count { |_, sql| sql.include?("-- listDeckShortfall") },
                 "a listDeckShortfall voltou para /api/progress; o contrato da AD-021 mudou.\n" \
                 "#{formatar(restantes)}"
    assert restantes.any? { |_, sql| sql.match?(/GROUP BY/i) },
           "nenhuma consulta restante é a agregação por set; a API pode ter trocado de forma.\n" \
           "#{formatar(restantes)}"
  end

  def assert_uma_list_deck_shortfall(consultas)
    restantes = sem_consultas_de_sessao(consultas)

    assert_equal 1, restantes.count { |_, sql| sql.include?("-- listDeckShortfall") },
                 "a falta dos decks deveria sair de uma única listDeckShortfall.\n#{formatar(restantes)}"
    outras = restantes.reject { |_, sql| sql.include?("-- listDeckShortfall") }
    assert_empty outras.select { |_, sql| sql.match?(/GROUP BY|array_agg|SUM\(/i) },
                 "o shortfall emitiu outra agregação além da listDeckShortfall (AD-021).\n#{formatar(restantes)}"
  end

  def sem_consultas_de_sessao(consultas)
    de_sessao, restantes = consultas.partition { |nome, _| CONSULTAS_DE_SESSAO.include?(nome) }

    assert_equal CONSULTAS_DE_SESSAO.size, de_sessao.size,
                 "as consultas de sessão descontadas mudaram de forma; a conta precisa ser refeita à mão.\n" \
                 "#{formatar(consultas)}"
    restantes
  end

  def criar_decks
    cartas = Card.where("card_number LIKE 'T6D%' OR card_number LIKE 'T6F%'").order(:card_number).limit(2).to_a
    cartas.each_with_index do |carta, i|
      Deck.create!(user: @user, name: "Deck #{i}").entries.create!(card: carta, quantity: 3)
    end
    assert_equal 2, @user.decks.count
  end

  def entrar
    get "/api/session"
    token = response.parsed_body.dig("data", "csrf_token")
    post "/api/session", params: { email: @user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => token }
    assert_response :ok, "a sessão não foi estabelecida; a medição seria a do login"
  end

  def consultas_da_pagina
    consultas = capturar_consultas { get "/api/progress" }
    assert_response :ok, "a API não respondeu 200; a contagem mediria a resposta errada"
    consultas
  end

  def consultas_do_shortfall
    consultas = capturar_consultas { get "/api/decks/shortfall" }
    assert_response :ok, "o shortfall não respondeu 200; a contagem mediria a resposta errada"
    consultas
  end

  def capturar_consultas
    consultas = []
    assinante = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name].to_s.in?([ "SCHEMA", "TRANSACTION" ])
      next if payload[:sql].to_s.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      consultas << [ payload[:name].to_s, payload[:sql].to_s ]
    end
    yield
    consultas
  ensure
    ActiveSupport::Notifications.unsubscribe(assinante)
  end

  def formatar(consultas)
    consultas.map.with_index { |(nome, sql), i| "  #{i + 1}. [#{nome}] #{sql.squish[0, 160]}" }.join("\n")
  end

  def semear_sets(quantidade, prefixo:)
    quantidade.times do |i|
      set = CardSet.create!(code: "T6#{prefixo}#{i}", name: "Set #{prefixo}#{i}", kind: "booster",
                            base_set_size: 2, total_set_size: 3)
      base = criar_variante(set, "#{prefixo}#{i}a", "base")
      criar_variante(set, "#{prefixo}#{i}b", "parallel")
      CollectionItem.create!(user: @user, card_variant: base, quantity: 1 + (i % 3))
    end
  end

  def criar_variante(set, sufixo, art_kind)
    card = Card.create!(card_set: set, card_number: "T6#{sufixo}", name: "Carta #{sufixo}",
                        card_type: "character", colors: [ "Red" ])
    CardVariant.create!(last_seen_at: CATALOG_SEEN_AT, card: card, card_set: set, variant_code: "t6#{sufixo}",
                        rarity: "C", art_kind: art_kind)
  end
end
