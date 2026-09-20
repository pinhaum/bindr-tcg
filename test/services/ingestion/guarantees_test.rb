require "test_helper"

module Ingestion
  # A task mais importante do projeto (`.specs/features/catalogo/tasks.md` T8).
  #
  # O catálogo é regenerável; a coleção é insubstituível. Todos os testes
  # abaixo existem para provar que a ingestão não pode corromper o segundo ao
  # atualizar o primeiro (Req. 1.4 e 1.7). Se algum deles ficar vermelho, a
  # resposta certa nunca é afrouxar a asserção.
  class GuaranteesTest < ActiveSupport::TestCase
    FIXTURE = Rails.root.join("spec", "fixtures", "optcgjson-subset.json")
    REVISION = "5669eab51096629faf90dbf0dc903128cff80a98".freeze

    def ingest(payload = FIXTURE.read, revision: REVISION, clock: Time)
      Upsert.new(Normalize.call(payload), source: "optcgjson", revision: revision,
                 clock: clock).call
    end

    # Relógio monotônico para os testes que asseveram **ordem** entre marcas de
    # duas execuções. Ver o comentário do teste "a marca de última aparição
    # distingue o presente do ausente": `Time.current` é relógio de parede e
    # pode andar para trás neste ambiente, o que inverte a ordem sem que nada
    # na ingestão esteja errado. Cada leitura aqui é estritamente maior que a
    # anterior, então a asserção passa a medir a regra da ingestão em vez da
    # estabilidade do relógio do host.
    class RelogioCrescente
      def initialize(inicio = Time.current.change(usec: 0), passo: 1.second)
        @proximo = inicio
        @passo = passo
      end

      def current
        instante = @proximo
        @proximo += @passo
        instante
      end
    end

    def contagens
      { sets: CardSet.count, cards: Card.count, variants: CardVariant.count }
    end

    def usuario
      User.create!(email: "colecionador@exemplo.test", password_digest: "x")
    end

    # Done when: ingestão rodada duas vezes sobre a mesma fixture não altera
    # contagem. Req. 1.4 — idempotência.
    test "rodar a ingestão duas vezes não altera a contagem de registros" do
      primeira = ingest
      antes = contagens

      segunda = ingest
      depois = contagens

      assert_equal antes, depois
      assert_equal({ sets: 5, cards: 376, variants: 678 }, depois)

      # Contagem estável sozinha não prova idempotência: uma ingestão que
      # falhasse em todo registro também deixaria a contagem intacta. O que
      # separa os dois casos é a segunda execução ter sido bem-sucedida e ter
      # contado atualizações em vez de criações.
      assert_equal "succeeded", primeira.status
      assert_equal "succeeded", segunda.status
      assert_equal 0, segunda.failed_count
      assert_equal 0, segunda.created_count
      assert_equal antes.values.sum, segunda.updated_count
    end

    test "a segunda execução não recria os registros, apenas atualiza" do
      ingest
      ids_antes = CardVariant.order(:id).pluck(:id, :variant_code)

      segunda = ingest

      assert_equal ids_antes, CardVariant.order(:id).pluck(:id, :variant_code),
                   "os ids mudaram: a coleção do usuário perderia o vínculo"
      assert_equal 0, segunda.failed_count,
                   "a reingestão só é idempotente se nenhum registro tiver falhado"
    end

    # Done when: `collection_item` criado antes da segunda execução continua
    # com a mesma quantidade. Req. 1.7 — o teste mais valioso do projeto.
    test "a coleção do usuário sobrevive intacta a uma nova ingestão" do
      ingest
      dono = usuario
      variante = CardVariant.find_by!(variant_code: "OP01-001_p1")
      item = CollectionItem.create!(user: dono, card_variant: variante, quantity: 3)

      segunda = ingest

      item.reload

      assert_equal 3, item.quantity, "a ingestão alterou a quantidade possuída"
      assert_equal variante.id, item.card_variant_id
      assert_equal 1, CollectionItem.count
      assert_equal "succeeded", segunda.status,
                   "a coleção só está provada intacta se a reingestão tiver de fato rodado"
    end

    # Done when (T12): rodar a ingestão duas vezes com wishlist povoada e
    # nenhum alvo muda. Req. 1.7 / COL-14 — a extensão do teste mais valioso do
    # projeto à segunda tabela de dado insubstituível. A coleção já estava
    # coberta acima; o desejo do usuário tem exatamente o mesmo direito.
    test "a wishlist do usuário sobrevive intacta a uma nova ingestão" do
      ingest
      dono = usuario
      desejadas = %w[OP01-001_p1 OP01-002].map { |code| CardVariant.find_by!(variant_code: code) }
      # Alvos **diferentes entre si e diferentes de 1**: com o mesmo valor em
      # todas as linhas, uma ingestão que sobrescrevesse todos os alvos por um
      # número igual passaria despercebida.
      itens = desejadas.zip([ 3, 5 ]).map do |variante, alvo|
        WishlistItem.create!(user: dono, card_variant: variante, target_quantity: alvo)
      end

      segunda = ingest

      assert_equal [ 3, 5 ], itens.map { |item| item.reload.target_quantity },
                   "a ingestão alterou a quantidade-alvo da wishlist"
      assert_equal desejadas.map(&:id), itens.map(&:card_variant_id),
                   "a wishlist perdeu o vínculo com a variante"
      assert_equal 2, WishlistItem.count
      assert_equal "succeeded", segunda.status,
                   "a wishlist só está provada intacta se a reingestão tiver de fato rodado"
    end

    # Req. 1.7 sob a condição que mais assusta, agora para a wishlist: a
    # variante desejada some da fonte. spec.md, Edge Cases — "o item continua
    # listado, a ingestão não deleta".
    test "variante desejada e ausente da fonte não é removida nem perde o vínculo" do
      ingest
      dono = usuario
      variante = CardVariant.find_by!(variant_code: "OP01-001_p1")
      item = WishlistItem.create!(user: dono, card_variant: variante, target_quantity: 4)

      ingest(fixture_sem_variante("OP01-001_p1"))

      assert CardVariant.exists?(variante.id), "a variante ausente da fonte sumiu do catálogo"
      assert_equal 4, item.reload.target_quantity
      assert_equal variante.id, item.card_variant_id
    end

    # Coleção e wishlist convivem sobre a mesma variante sem interferir uma na
    # outra: são estados independentes (spec.md, "Modelagem da wishlist"). O
    # teste seria verde por acaso se as duas tabelas fossem povoadas em
    # variantes diferentes, então as duas apontam para a **mesma**.
    test "posse e desejo da mesma variante sobrevivem juntos à reingestão" do
      ingest
      dono = usuario
      variante = CardVariant.find_by!(variant_code: "OP01-001_p1")
      posse = CollectionItem.create!(user: dono, card_variant: variante, quantity: 1)
      desejo = WishlistItem.create!(user: dono, card_variant: variante, target_quantity: 3)

      ingest

      assert_equal 1, posse.reload.quantity
      assert_equal 3, desejo.reload.target_quantity
    end

    test "nenhuma foreign key da wishlist usa exclusão em cascata" do
      cascateando = ActiveRecord::Base.connection.select_values(<<~SQL)
        SELECT conname FROM pg_constraint
        WHERE contype = 'f' AND confdeltype <> 'r'
          AND conrelid::regclass::text = 'wishlist_items'
      SQL

      assert_empty cascateando
    end

    test "o banco recusa remover uma variante que alguém deseja" do
      ingest
      dono = usuario
      variante = CardVariant.first
      WishlistItem.create!(user: dono, card_variant: variante, target_quantity: 2)

      assert_raises(ActiveRecord::InvalidForeignKey) do
        remover_variante(variante.id)
      end
    end

    test "a coleção sobrevive a três execuções consecutivas" do
      ingest
      dono = usuario
      item = CollectionItem.create!(user: dono, card_variant: CardVariant.first, quantity: 7)

      3.times { ingest }

      assert_equal 7, item.reload.quantity
    end

    # Req. 1.7 sob a condição que mais assusta: a variante que o usuário possui
    # some da fonte.
    test "variante possuída e ausente da fonte não é removida nem perde o vínculo" do
      ingest
      dono = usuario
      variante = CardVariant.find_by!(variant_code: "OP01-001_p1")
      item = CollectionItem.create!(user: dono, card_variant: variante, quantity: 2)

      ingest(fixture_sem_variante("OP01-001_p1"))

      assert CardVariant.exists?(variante.id), "a variante ausente da fonte sumiu do catálogo"
      assert_equal 2, item.reload.quantity
      assert_equal variante.id, item.card_variant_id
    end

    # Done when: carta ausente da fonte não é removida, apenas marcada.
    test "carta ausente da fonte permanece no catálogo" do
      ingest
      total_antes = Card.count

      ingest(fixture_sem_carta("OP01-001"))

      assert Card.exists?(card_number: "OP01-001"), "a carta ausente da fonte sumiu do catálogo"
      assert_equal total_antes, Card.count
    end

    # A marca é o que permite sinalizar o ausente na interface sem removê-lo:
    # quem entrou na última execução tem `last_seen_at` novo, o ausente
    # mantém o antigo.
    #
    # ## Por que este teste injeta um relógio (T1 da `portabilidade`)
    #
    # A asserção de ordem falhava de forma intermitente na suíte completa — 1
    # falha em 5 execuções —, e **não por empate**: o presente aparecia mais
    # velho que o ausente, uma inversão de segundos. O diagnóstico registrado
    # na spec (truncamento por `to_i`) estava errado: as três colunas são
    # `timestamp(6)`, e truncamento não inverte.
    #
    # A causa é o **relógio de parede do host andar para trás**. A execução
    # que reproduziu o defeito gravou, na mesma ingestão:
    #
    #     run 1083: started_at=19:06:56.243492  finished_at=19:06:50.933776
    #     run 1084: started_at=19:06:50.971246  finished_at=19:07:06.247061
    #
    # A primeira execução terminou ~5,3s **antes** de ter começado, e a
    # segunda começou antes da primeira. Medido diretamente no container: em
    # 2000 leituras, `Time.now` saltou 4 vezes, ±11,25s, enquanto
    # `CLOCK_MONOTONIC` avançou os 0,005s esperados — ressincronização de
    # relógio do WSL2. `Upsert` carimba `last_seen_at` com `@clock.current`,
    # isto é, relógio de parede; logo duas ingestões podem receber marcas
    # fora de ordem sem que nada na ingestão esteja errado.
    #
    # Injetar `RelogioCrescente` ataca essa causa: a ingestão passa a ser
    # medida por uma fonte de tempo monotônica, e a asserção volta a provar a
    # regra — o presente é remarcado, o ausente não — em vez de provar que o
    # relógio do host se comportou. A asserção continua sendo `:>` estrito.
    test "a marca de última aparição distingue o presente do ausente" do
      relogio = RelogioCrescente.new

      ingest(clock: relogio)
      ausente = Card.find_by!(card_number: "OP01-001")
      marca_antiga = ausente.last_seen_at

      segunda = ingest(fixture_sem_carta("OP01-001"), clock: relogio)

      assert_equal marca_antiga.to_i, ausente.reload.last_seen_at.to_i,
                   "a carta ausente não podia ter sido remarcada"
      presente = Card.find_by!(card_number: "OP01-002")
      assert_equal segunda.started_at.to_i, presente.reload.last_seen_at.to_i
      assert_operator presente.last_seen_at, :>, ausente.last_seen_at
    end

    # design.md §5.2 — "a ingestão não tem operação de delete". Uma asserção
    # sobre o código, não sobre o efeito: é o que impede que alguém
    # reintroduza uma exclusão achando que está limpando o catálogo.
    test "o estágio de upsert não contém nenhuma operação de exclusão" do
      codigo = Rails.root.join("app", "services", "ingestion", "upsert.rb").read

      refute_match(/\.destroy\b|\.destroy_all\b|\.delete\b|\.delete_all\b|DELETE\s+FROM/i, codigo)
    end

    # design.md §5.2 — nenhuma FK da coleção pode cascatear, senão remover uma
    # variante apagaria o registro do usuário junto.
    test "nenhuma foreign key da coleção usa exclusão em cascata" do
      cascateando = ActiveRecord::Base.connection.select_values(<<~SQL)
        SELECT conname FROM pg_constraint
        WHERE contype = 'f' AND confdeltype = 'c'
          AND conrelid::regclass::text = 'collection_items'
      SQL

      assert_empty cascateando
    end

    test "o banco recusa remover uma variante que alguém possui" do
      ingest
      dono = usuario
      variante = CardVariant.first
      CollectionItem.create!(user: dono, card_variant: variante, quantity: 1)

      assert_raises(ActiveRecord::InvalidForeignKey) do
        remover_variante(variante.id)
      end
    end

    # Req. 7.8 e 7.4 — garantidos no banco, não só na aplicação.
    test "o banco impede duas linhas de coleção para o mesmo par usuário e variante" do
      ingest
      dono = usuario
      variante = CardVariant.first
      CollectionItem.create!(user: dono, card_variant: variante, quantity: 1)

      assert_raises(ActiveRecord::RecordNotUnique) do
        inserir_item(user_id: dono.id, card_variant_id: variante.id, quantity: 5)
      end
    end

    test "o banco recusa quantidade negativa" do
      ingest
      dono = usuario

      assert_raises(ActiveRecord::StatementInvalid) do
        inserir_item(user_id: dono.id, card_variant_id: CardVariant.first.id, quantity: -1)
      end
    end

    private

    def inserir_item(user_id:, card_variant_id:, quantity:)
      ActiveRecord::Base.connection.execute(<<~SQL)
        INSERT INTO collection_items (user_id, card_variant_id, quantity, created_at, updated_at)
        VALUES (#{user_id}, #{card_variant_id}, #{quantity}, now(), now())
      SQL
    end

    # Exercita a recusa do banco: a FK sem cascata tem de barrar a remoção.
    def remover_variante(id)
      ActiveRecord::Base.connection.execute("DELETE FROM card_variants WHERE id = #{id}")
    end

    def fixture_sem_variante(variant_code)
      payload = JSON.parse(FIXTURE.read)
      payload["data"].each { |s| s["cards"].reject! { |c| c["id"] == variant_code } }
      payload
    end

    def fixture_sem_carta(card_number)
      payload = JSON.parse(FIXTURE.read)
      payload["data"].each { |s| s["cards"].reject! { |c| c["number"] == card_number } }
      payload
    end
  end
end
