# A pré-visualização de um import, guardada entre o upload (T12) e a
# confirmação (T14). AD-007: o arquivo vive aqui, e não em sessão nem por
# reenvio, porque o Req. 10.5 exige que a confirmação grave **o que a
# pré-visualização mostrou** — e só o staging dá essa garantia.
#
# **Este model não escreve na coleção e não pode passar a escrever.** Ele
# guarda o que *aconteceria*; quem grava é a T14, depois da confirmação
# explícita. A coleção é o único dado insubstituível do sistema — o catálogo é
# regenerável (AD-001) —, e é por isso que esta tabela **não tem FK para
# `collection_items` nem para `card_variants`**: sem aresta não há cascata
# possível na direção do dado que não se recupera. Apagar uma pré-visualização
# não toca na coleção, e há teste no catálogo do Postgres e no comportamento
# para manter assim.
#
# As garantias de integridade não são daqui: o índice único de `token`, o
# `CHECK` de `status`, os `NOT NULL` e a FK `on_delete: :restrict` nasceram na
# migração `20260919120600` e estão provados contra o banco em
# `test/models/collection_import_test.rb`. O que está abaixo é conveniência de
# aplicação — a garantia real continua sendo do schema, que nenhuma corrida
# atravessa e nenhum `UPDATE` direto contorna.
class CollectionImport < ApplicationRecord
  STATUSES = %w[pendente confirmado].freeze

  # A janela legítima entre ver a pré-visualização e clicar em confirmar é de
  # minutos: o usuário lê a tela e decide. Duas horas é folga generosa sobre
  # isso e ainda mantém curto o tempo em que o conteúdo do arquivo de alguém
  # fica no banco sem ter sido pedido para nada. Quem estourar o prazo reenvia
  # o arquivo — o custo do erro é um upload, não um dado perdido.
  VALIDADE = 2.hours

  belongs_to :user

  validates :filename, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :gerar_token, on: :create
  before_validation :definir_prazo, on: :create

  # Req. 6.5 / design.md §7 — toda consulta a dado do usuário parte do usuário
  # da sessão. O argumento é o **objeto** `User`, nunca um id, exatamente como
  # em `CollectionItem.for_user` e `WishlistItem.for_user`: aceitar um id
  # deixaria `CollectionImport.for_user(params[:user_id])` compilar, e a
  # violação de autorização passaria despercebida na revisão.
  #
  # `nil` devolve relação vazia em vez de levantar erro, pela mesma razão das
  # outras duas: quem não tem sessão simplesmente não tem staging. O controller
  # da T12 exige sessão de qualquer forma, então `nil` aqui é o caso do
  # chamador defensivo, não um caminho do produto.
  scope :for_user, ->(user) {
    case user
    when nil then none
    when User then where(user: user)
    else raise ArgumentError, "for_user espera um User ou nil, recebeu #{user.class}"
    end
  }

  scope :vigentes, -> { where(expires_at: Time.current..) }
  scope :expiradas, -> { where(expires_at: ...Time.current) }
  scope :pendentes, -> { where(status: "pendente") }

  # O caminho pelo qual a T12 devolve e a T14 recebe uma pré-visualização.
  #
  # **O filtro por dono vem primeiro e não é opcional**: a busca é
  # `for_user(user).find_by(token:)`, nunca `find_by(token:)` seguido de uma
  # comparação de dono depois. A ordem importa porque a segunda forma carrega o
  # registro alheio para a memória antes de decidir — e um `render` esquecido
  # no meio vira vazamento.
  #
  # **Devolve `nil` tanto para o token alheio quanto para o inexistente**, e a
  # indistinção é o ponto. Responder "existe, mas não é sua" para um e "não
  # existe" para o outro transformaria a tabela num oráculo de tokens válidos,
  # um por requisição. Quem chama trata os dois casos com a mesma resposta.
  def self.find_by_token_for(user, token)
    return nil if token.blank?

    for_user(user).find_by(token: token)
  end

  # Done when: existe caminho de limpeza dos registros expirados.
  #
  # Varredura global, sem dono — a única consulta desta tabela que não parte de
  # `Current.user`. É legítimo porque ela **não lê** dado de ninguém: apaga por
  # prazo e devolve quantas apagou. `delete_all` e não `destroy_all`: não há
  # callback a disparar nem associação dependente a percorrer, e a diferença é
  # uma consulta contra N.
  #
  # Sem agendador ainda: quem chama é um caminho de manutenção
  # (`CollectionImport.limpar_expiradas` no console, ou uma task). Amarrá-lo a
  # um job exigiria adapter de fila configurado, que este projeto não tem, e um
  # agendador quebrado seria pior que uma chamada explícita — daria a impressão
  # de limpeza sem limpar.
  def self.limpar_expiradas
    expiradas.delete_all
  end

  def expirada?
    expires_at.nil? || expires_at <= Time.current
  end

  # A pergunta que a T14 faz antes de gravar. Duas condições, e as duas são
  # necessárias: fora do prazo o arquivo descrito já não é o que o usuário viu,
  # e fora de `pendente` a confirmação já aconteceu — o Edge Case da spec diz
  # que a segunda confirmação não pode duplicar o efeito da primeira.
  def confirmavel?
    !expirada? && status == "pendente"
  end

  # As linhas do resolvedor de volta no tipo em que foram produzidas. Quem
  # consome — a tela da T13 e a escrita da T14 — não precisa saber que o meio
  # de transporte foi `jsonb`, nem lembrar que o `jsonb` devolve chaves como
  # texto e não como símbolo.
  #
  # `classificacao` e `motivo` voltam a ser símbolos porque é assim que o
  # resolvedor os emite e é com eles que `rejeitada?` compara. Deixar a string
  # passar faria `classificacao == :rejeita` ser falso para toda linha
  # rejeitada — defeito **silencioso**: a tela mostraria rejeições como
  # aceitas e a T14 gravaria o que devia recusar.
  def linhas_resolvidas
    Array(linhas).map do |linha|
      atributos = linha.to_h.symbolize_keys
      atributos[:classificacao] = atributos[:classificacao]&.to_sym
      atributos[:motivo] = atributos[:motivo]&.to_sym
      CollectionCsv::Resolver::Linha.new(**atributos)
    end
  end

  # O caminho de ida, simétrico ao de volta: a T12 passa os `Struct` que o
  # resolvedor devolveu e não converte nada à mão. Sem isto, cada chamador
  # faria o seu `map(&:to_h)` e o primeiro que esquecesse gravaria a
  # serialização default de `Struct` — um array posicional, que
  # `linhas_resolvidas` não sabe ler.
  def linhas=(valor)
    super(Array(valor).map { |linha| linha.respond_to?(:to_h) ? linha.to_h : linha })
  end

  private

    # 32 bytes de aleatoriedade urlsafe. Impraticável de adivinhar, e a
    # unicidade real é do índice do banco — este método só evita que a colisão
    # improvável vire erro de usuário em vez de exceção.
    def gerar_token
      self.token ||= SecureRandom.urlsafe_base64(32)
    end

    def definir_prazo
      self.expires_at ||= VALIDADE.from_now
    end
end
