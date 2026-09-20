# `collection_imports`, o staging que guarda a pré-visualização entre o upload
# (T12) e a confirmação (T14). Decidido em AD-007: o arquivo não vive em
# sessão (o cookie tem teto de 4KB e mil linhas não cabem) nem é reenviado na
# confirmação (o arquivo poderia mudar entre as duas etapas, e a
# pré-visualização passaria a descrever algo diferente do que seria gravado).
#
# **Uma tabela com as linhas em `jsonb`, e não duas tabelas.** As linhas de uma
# pré-visualização são lidas e escritas **sempre como uma unidade**: a T12
# grava o resultado inteiro do resolvedor, a T13 renderiza o resultado inteiro
# e a T14 grava o resultado inteiro. Nenhum caso do produto consulta uma linha
# isolada, filtra por classificação no banco ou junta linha com outra tabela —
# o `card_variant_id` já vem resolvido dentro do documento, que é justamente o
# ponto de não reparsear na confirmação. Uma tabela filha custaria até 10.000
# INSERTs por upload (AD-008) e 10.000 linhas de volta para montar a tela, para
# comprar uma capacidade de consulta que ninguém exerce. Escrita em `jsonb`
# funciona hoje e há precedente vivo — `import_runs.error_log` —, com a gem
# `json` pinada em `~> 2.7` no `Gemfile` porque a 3.x quebra exatamente isso.
#
# **A tabela não referencia `card_variants` nem `collection_items`, e isso é
# deliberado.** O vínculo com a coleção é o `card_variant_id` **dentro** do
# documento, sem FK: um ponteiro solto não arrasta nada por efeito colateral, e
# sem aresta não existe cascata possível na direção do dado insubstituível
# (design.md §5.2). A T14 resolve esse id no momento da escrita, quando o
# usuário já confirmou. A única FK é para `users`, e é `restrict` como todas as
# outras do projeto.
class CreateCollectionImports < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_imports do |t|
      # `restrict` e não `cascade`, no mesmo padrão de `collection_items` e
      # `wishlist_items`. O staging em si é descartável — quem perde uma
      # pré-visualização reenvia o arquivo —, mas a uniformidade importa mais
      # que a exceção: uma única FK em cascata nesta tabela abriria o
      # precedente que a próxima poderia copiar em direção à coleção. O
      # descarte em massa é feito em SQL explícito por `limpar_expiradas`, não
      # por efeito colateral de um `DELETE` em `users`.
      #
      # `index: false` porque o índice que `t.references` criaria — `(user_id)`
      # sozinho — é **prefixo estrito** do composto `(user_id, token)` que vem
      # abaixo, e o Postgres serve qualquer busca por dono a partir dele. Dois
      # índices onde um basta custam escrita em todo INSERT e UPDATE sem
      # atender nenhuma consulta que o outro não atenda (achado da revisão de
      # banco desta task).
      t.references :user, null: false, index: false, foreign_key: { on_delete: :restrict }

      # O identificador que a T12 devolve e a T14 recebe. Aleatório e não o
      # `id` sequencial: um `id` é adivinhável, e o teto da autorização não
      # pode ser "ninguém tentou o número do vizinho". A consulta por token
      # **também** filtra por `user_id` (`find_by_token_for`), então o token é
      # a segunda barreira, não a única.
      t.string :token, null: false

      # O nome original do arquivo, para que a tela possa dizer de qual arquivo
      # a pré-visualização veio. Nunca compõe caminho em disco — nada é escrito
      # no sistema de arquivos aqui.
      t.string :filename, null: false

      # O resultado do resolvedor (T9), linha a linha, do jeito que a
      # pré-visualização mostrou. É o que torna verdadeira a exigência do
      # Req. 10.5 de que a confirmação grave **o que foi mostrado**: a T14 lê
      # daqui e não do arquivo, logo não há parser no caminho da escrita.
      t.jsonb :linhas, null: false, default: []

      # `pendente` → `confirmado`. O Edge Case da spec — "duas confirmações da
      # mesma pré-visualização não podem duplicar o efeito" — se resolve neste
      # campo: a T14 só grava a partir de `pendente`. `CHECK` e não enum, pelo
      # mesmo motivo de `rarity` em `card_variants` (design.md): enum faz uma
      # migração de dado virar pré-requisito de qualquer estado novo.
      t.string :status, null: false, default: "pendente"

      # `NOT NULL` de propósito: uma pré-visualização sem prazo viveria para
      # sempre guardando o arquivo de alguém. O prazo é curto (ver `VALIDADE`
      # no model) porque a janela legítima entre ver a tela e clicar em
      # confirmar é de minutos.
      t.datetime :expires_at, null: false

      t.timestamps
    end

    # Único: dois registros com o mesmo token fariam a confirmação escolher
    # entre duas pré-visualizações — e uma delas poderia ser de outro usuário.
    # Colisão de `SecureRandom` é improvável, não impossível; o índice
    # transforma o improvável em erro barulhento.
    add_index :collection_imports, :token, unique: true

    # O par que `find_by_token_for` consulta, na ordem em que ele filtra —
    # medido: `Index Scan using index_collection_imports_on_user_id_and_token`
    # com `Index Cond` sobre os dois predicados. Serve também as buscas por
    # dono sozinho, por ser `user_id` a primeira coluna, que é o que dispensa o
    # índice separado de `t.references`.
    add_index :collection_imports, [ :user_id, :token ]

    # A varredura de `limpar_expiradas` é por prazo, sem dono: é a única
    # consulta desta tabela que não parte de `Current.user`, e é legítima
    # porque não lê dado de ninguém — apaga por prazo e devolve contagem.
    #
    # Medido: com a tabela pequena e quase tudo expirado, o planejador escolhe
    # `Seq Scan` e está certo — ler o índice para depois ler quase todas as
    # páginas é mais caro que varrer. O índice paga no regime oposto, que é o
    # normal em produção: muitas pré-visualizações vigentes e poucas vencidas,
    # onde a varredura leria a tabela inteira para apagar meia dúzia de linhas.
    add_index :collection_imports, :expires_at

    add_check_constraint :collection_imports,
      "status IN ('pendente', 'confirmado')",
      name: "collection_imports_status_check"
  end
end
