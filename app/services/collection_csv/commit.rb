module CollectionCsv
  # A **única escrita da feature de portabilidade** (POR-08, POR-06, POR-12 /
  # Req. 10.5, 10.3).
  #
  # Treze tasks foram construídas sob uma invariante: nenhuma escrita na
  # coleção sem confirmação explícita do usuário. `Parser`, `Resolver`,
  # `CollectionImportsController#create` e a tela de pré-visualização não
  # gravam nada, e cada um tem teste provando isso. **Aqui a escrita acontece.**
  # A coleção é o único dado insubstituível do sistema — o catálogo é
  # regenerável a partir da fonte externa (AD-001), a coleção não —, e um
  # defeito neste arquivo destrói trabalho que nenhuma reingestão reconstrói.
  #
  # ## A entrada é o staging, e só ele
  #
  # O serviço recebe o **token** da pré-visualização e nunca o arquivo. Isso não
  # é conveniência: o Req. 10.5 é "grava o que a pré-visualização mostrou", e
  # reparsear o CSV na confirmação abriria a possibilidade de gravar algo
  # diferente do que o usuário leu na tela — o catálogo pode ter mudado, o
  # arquivo pode ter sido trocado, a resolução pode dar outro resultado.
  # `Parser` e `Resolver` **não são chamados daqui**, e não podem passar a ser:
  # o dia em que forem, o botão "confirmar" para de ser uma confirmação e vira
  # um segundo upload cego.
  #
  # ## Transação x erro isolado: savepoint por linha
  #
  # Dois critérios do plano parecem se contradizer, e a conciliação é o eixo do
  # desenho deste arquivo:
  #
  # 1. **A transição de status e a escrita ficam na mesma transação**
  #    (requisito vinculante da revisão de banco da T11). Sem isso, duas
  #    confirmações simultâneas gravam a coleção duas vezes.
  # 2. **Uma linha que falha não desfaz as anteriores** (Req. 10.3 / POR-06),
  #    no mesmo espírito do erro isolado da ingestão (design.md §5.2).
  #
  # Não são irreconciliáveis, porque falam de granularidades diferentes: a
  # primeira é sobre o **lote**, a segunda sobre a **linha**. O Postgres resolve
  # as duas com `SAVEPOINT` — em Rails, `transaction(requires_new: true)`. Cada
  # linha grava dentro do seu savepoint: o erro desfaz **aquela** linha e nada
  # mais, o loop continua, e a transação externa — a que contém a transição de
  # status — permanece viva e commita no fim. O que a ingestão obtém com
  # "transação própria por registro" (design.md §5.2) é exatamente isto, com a
  # diferença de que aqui há um envelope externo a preservar.
  #
  # A alternativa — gravar fora de transação, com a transição antes — perderia a
  # atomicidade da reivindicação: um erro depois de marcar `confirmado` deixaria
  # a pré-visualização inconfirmável com a coleção pela metade, e o usuário sem
  # caminho de volta. A outra alternativa — uma transação só, sem savepoints —
  # cumpriria a atomicidade e **perderia o lote inteiro por uma linha ruim**,
  # que é o defeito que o Req. 10.3 nomeia.
  #
  # ## A reivindicação é um `UPDATE` condicional, não um `SELECT` seguido dele
  #
  # A revisão de banco da T11 reproduziu que o `CHECK` de `status` **não impede**
  # a regressão `confirmado → pendente`, e que `confirmavel?` (SELECT) seguido
  # de `update!(status: "confirmado")` (UPDATE) deixa duas requisições
  # simultâneas passarem pela mesma porta: ambas leem `pendente`, ambas passam,
  # e a coleção é gravada duas vezes. `SELECT` seguido de `UPDATE` é defeito
  # aqui **mesmo com teste verde**, porque o teste sequencial não reproduz a
  # corrida.
  #
  # A defesa é uma linha só: `UPDATE ... WHERE id = $1 AND status = 'pendente'
  # AND expires_at > now() RETURNING id`. O `WHERE` é avaliado sobre a linha já
  # travada pelo próprio `UPDATE`, então a segunda requisição não casa e afeta
  # **zero linhas** — a corrida é perdida no banco, que é onde ela existe, e não
  # num `if` em Ruby. O mesmo statement também cobre a expiração, pelo mesmo
  # motivo: um prazo verificado em Ruby e escrito depois tem a mesma janela.
  class Commit
    # O que a confirmação devolve para o controller e para o resumo da T15: o
    # que efetivamente entrou na coleção, separado do que a escrita recusou.
    #
    # `reivindicada` distingue "confirmou agora" de "já estava confirmada, ou
    # venceu": o controller precisa dos dois desfechos, e `gravadas: 0` sozinho
    # não os separa — um lote legítimo de zero linhas aceitas também grava zero.
    #
    # ## As cinco classificações e as três categorias do Req. 10.4 (T15)
    #
    # O `Resolver` (T9) produz cinco classificações e o Req. 10.4 nomeia três.
    # O `Result` carrega as contagens **por classificação**, e não as três
    # categorias já somadas, porque a soma é decisão de apresentação e a perda
    # de informação é irreversível: quem recebe `atualizadas: 2` não tem como
    # descobrir depois que uma delas removeu posse.
    #
    # | Categoria do Req. 10.4 | Classificações |
    # |---|---|
    # | importadas | `:cria` → `criadas` |
    # | atualizadas | `:atualiza` + `:zera` → `atualizadas` + `zeradas` |
    # | rejeitadas | `:rejeita` → `rejeitadas` |
    # | (fora das três) | `:inalterada` → `inalteradas` |
    #
    # **`zeradas` é campo próprio, e tem de continuar sendo.** Dobrá-lo dentro
    # de `atualizadas` cumpriria a letra do Req. 10.4 e falharia no propósito
    # do Req. 10.5: o usuário confirmou um efeito destrutivo, e o resumo que
    # não o nomeia não confirma que ele aconteceu. A tela da T13 mostra o
    # perigo **antes**; este campo é o que permite ao resumo confirmá-lo
    # **depois**.
    #
    # `rejeitadas_detalhadas` traz as linhas recusadas em si — motivo e
    # identificação —, porque o POR-10 pede o motivo **por linha** e um número
    # não o carrega. Elas vêm do staging, que é o que a tela mostrou.
    Result = Struct.new(:reivindicada, :criadas, :atualizadas, :zeradas, :inalteradas,
      :rejeitadas, :rejeitadas_detalhadas, :falhas,
      keyword_init: true) do
      def reivindicada?
        reivindicada
      end

      # O total de linhas que mudaram a coleção, que é o que o controller usa
      # para a mensagem curta. `inalteradas` fica de fora de propósito: elas
      # são gravadas (ver `CLASSIFICACOES_GRAVAVEIS`), mas dizer que N linhas
      # foram gravadas quando nenhuma delas mudou nada seria mentir sobre o
      # efeito.
      def gravadas
        criadas.to_i + atualizadas.to_i + zeradas.to_i
      end
    end

    # As classificações que viram escrita, e a única que não vira por ser
    # rejeição. `:rejeita` **nunca** chega ao banco: é a linha que a tela
    # mostrou com motivo, e gravá-la seria contrariar o que o usuário leu.
    #
    # `:inalterada` **é gravada**, e a escolha é deliberada. Pular a escrita
    # seria uma otimização correta na maior parte das vezes e errada no caso que
    # importa: entre a pré-visualização e a confirmação o usuário pode ter
    # mexido na coleção por outro caminho (a grade do catálogo tem "+1"), e
    # "inalterada" é uma afirmação sobre o estado de **quando a tela foi
    # montada**, não sobre o de agora. Pular deixaria a coleção diferente do que
    # a tela prometeu — que é exatamente o que o Req. 10.5 proíbe. Gravar o
    # mesmo valor é idempotente e custa uma linha num `INSERT` que já está
    # acontecendo.
    CLASSIFICACOES_GRAVAVEIS = %i[cria atualiza zera inalterada].freeze

    # `INSERT ... ON CONFLICT DO UPDATE`, o mesmo padrão do incremento de posse
    # (`CollectionItemsController#increment`), com **uma diferença que é o
    # coração da AD-006**: lá o `DO UPDATE SET` soma
    # (`quantity = collection_items.quantity + 1`), aqui ele **substitui**
    # (`quantity = EXCLUDED.quantity`). Somar dobraria a coleção a cada ciclo de
    # exportar-e-reimportar, e é a única leitura sob a qual o arquivo do export
    # é idempotente na volta (POR-11).
    #
    # Por que `ON CONFLICT` e não `find_or_initialize_by` + `save`: a segunda
    # forma lê em Ruby e escreve depois, e a janela entre as duas é real. Um
    # registro **criado** entre a pré-visualização e a confirmação (o usuário
    # clicou "+1" na grade) faria o `INSERT` cego estourar `RecordNotUnique`; um
    # registro **apagado** no mesmo intervalo faria o `UPDATE` puro afetar zero
    # linhas e a promessa da tela não se cumprir. `ON CONFLICT` absorve os dois
    # com um statement e o lock de linha que o próprio `UPDATE` já toma — é o
    # *lost update* que a T6 da `colecao` resolveu, do lado do import.
    UPSERT_SQL = <<~SQL.freeze
      INSERT INTO collection_items (user_id, card_variant_id, quantity, created_at, updated_at)
      VALUES ($1, $2, $3, now(), now())
      ON CONFLICT (user_id, card_variant_id)
      DO UPDATE SET quantity = EXCLUDED.quantity, updated_at = now()
      RETURNING quantity
    SQL

    # A transição de status, num único statement (requisito vinculante da
    # revisão de banco da T11). `RETURNING id` é o que distingue "tomei" de
    # "outro já tinha tomado": zero linhas devolvidas significa que o `WHERE`
    # não casou — já confirmada, ou vencida — e **nada pode ser gravado**.
    #
    # `expires_at > now()` fica aqui, e não num `if` em Ruby antes, pelo mesmo
    # motivo do `status`: um prazo lido e escrito em dois passos tem a mesma
    # janela que o status lido e escrito em dois passos.
    # Levantada, nunca devolvida como `Result`: um lote acima do teto não é um
    # desfecho que a tela deva explicar ao usuário — é sinal de que algo passou
    # por cima do `Parser`, e o lugar de aparecer é o log, não a interface.
    class LoteGrandeDemais < StandardError; end

    RECLAIM_SQL = <<~SQL.freeze
      UPDATE collection_imports
      SET status = 'confirmado', updated_at = now()
      WHERE id = $1 AND status = 'pendente' AND expires_at > now()
      RETURNING id
    SQL

    # Reivindica a pré-visualização: devolve `true` se **esta** chamada foi a
    # que a tomou, `false` se ela já estava confirmada ou já venceu.
    #
    # Público porque é o que o teste de concorrência exercita: o defeito que a
    # revisão de banco da T11 apontou mora exatamente neste statement, e prová-lo
    # pelo efeito na coleção não distinguiria "a corrida foi perdida no banco"
    # de "a substituição é idempotente por acaso".
    def self.reivindicar(collection_import_id)
      binds = [
        ActiveRecord::Relation::QueryAttribute.new(
          "id", collection_import_id, ActiveRecord::Type::Integer.new
        )
      ]

      CollectionImport.connection
        .exec_query(RECLAIM_SQL, "CollectionImport Reclaim", binds)
        .rows.any?
    end

    # O usuário é o **objeto** da sessão, nunca um id de request (Req. 6.5). O
    # token vem da URL, mas ele não identifica usuário nenhum: é um segredo por
    # upload, e `find_by_token_for` filtra por dono **antes** de carregar o
    # registro (T11).
    def initialize(user, token)
      @user = user
      @token = token
    end

    # `nil` quando não há o que confirmar — token inexistente, ou de outro
    # usuário. Os dois casos devolvem a mesma coisa, pela mesma razão de
    # `find_by_token_for`: responder diferente transformaria a rota num oráculo
    # de tokens válidos, um por requisição.
    def call
      preview = CollectionImport.find_by_token_for(@user, @token)
      return nil if preview.nil?

      gravar(preview)
    end

    private

      def gravar(preview)
        # Contagem **por classificação**, e não por categoria do Req. 10.4: a
        # soma é decisão da tela, e somar aqui apagaria a distinção entre
        # trocar um número e apagar uma posse. O contador é incrementado
        # **dentro** do savepoint, depois do `upsert`, de modo que a linha que
        # falha não entra em contagem nenhuma — é o que faz os números do
        # resumo descreverem o banco, e não a intenção da pré-visualização.
        contagens = Hash.new(0)
        falhas = []

        # Teto redundante com o do `Parser`, e deliberadamente redundante —
        # achado HIGH da revisão de banco. O limite de AD-008 vive em
        # `Parser::MAX_LINHAS`, que atua no **upload**; entre ele e esta escrita
        # está um `jsonb` **sem `CHECK` de tamanho**, então nada no banco impede
        # que um staging maior chegue aqui: um caminho de manutenção, uma
        # migração de dado, ou o próprio limite do parser mudando sem que
        # ninguém olhe para este arquivo.
        #
        # O custo é real e medido pela revisão: 10.000 linhas são 30.004
        # statements e ~7s de transação aberta. Deixar o teto de capacidade
        # morar só numa constante de outro arquivo é confiar demais na distância.
        if linhas_gravaveis(preview).size > Parser::MAX_LINHAS
          raise LoteGrandeDemais,
                "a pré-visualização #{preview.id} tem #{linhas_gravaveis(preview).size} " \
                "linhas graváveis e o teto é #{Parser::MAX_LINHAS}"
        end

        # A transação externa envolve a reivindicação **e** a escrita: é ela que
        # garante que uma confirmação abandonada no meio não deixe a
        # pré-visualização marcada como consumida com a coleção pela metade.
        CollectionImport.transaction do
          unless self.class.reivindicar(preview.id)
            return Result.new(reivindicada: false, criadas: 0, atualizadas: 0, zeradas: 0,
                              inalteradas: 0, rejeitadas: 0, rejeitadas_detalhadas: [],
                              falhas: [])
          end

          linhas_gravaveis(preview).each do |linha|
            # Savepoint por linha. O erro desfaz **esta** linha e nada mais; a
            # transação externa, com a transição de status já aplicada,
            # continua viva. É o erro isolado da ingestão (design.md §5.2) sob
            # um envelope que precisa permanecer atômico.
            CollectionImport.transaction(requires_new: true) do
              upsert(linha)
              contagens[linha.classificacao] += 1
            end
          # `StandardError`, e não `ActiveRecord::ActiveRecordError`: a revisão de
          # banco (autor ≠ revisor) mostrou, com duas conexões reais, que o
          # `rescue` estreito **anulava a garantia que este bloco existe para
          # dar**. `PG::Error` não herda de `ActiveRecordError`
          # (`PG::ConnectionBad.ancestors` = `[PG::ConnectionBad, PG::Error,
          # StandardError, Exception]`), e um `RuntimeError` de aplicação
          # tampouco — reproduzido: com a primeira linha já gravada no savepoint
          # dela, um erro na segunda propagava pelo `each`, a transação externa
          # fazia ROLLBACK e a coleção ficava com **zero** linhas, status de
          # volta a `pendente`. Numa queda de conexão na linha 4.000 de um lote
          # de 10.000, o usuário perderia as 3.999 já gravadas — exatamente o
          # que o Req. 10.3 / POR-06 proíbe.
          #
          # `StandardError` e não `Exception`: `SignalException`, `SystemExit` e
          # `NoMemoryError` precisam continuar derrubando o processo em vez de
          # virar "mais uma linha que falhou".
          rescue StandardError => e
            # A mensagem do banco não vai para a tela: ela carrega nome de
            # tabela, de constraint e às vezes o statement. O que o usuário lê
            # é a identificação da linha, que é o que permite corrigir o
            # arquivo — mesmo espírito do `import_runs.error_log` da ingestão.
            falhas << { indice: linha.indice, card_number: linha.card_number,
                        variant_code: linha.variant_code, erro: e.class.name }
          end
        end

        rejeitadas = preview.linhas_resolvidas.select(&:rejeitada?)

        Result.new(reivindicada: true,
                   criadas: contagens[:cria],
                   atualizadas: contagens[:atualiza],
                   zeradas: contagens[:zera],
                   inalteradas: contagens[:inalterada],
                   rejeitadas: rejeitadas.size,
                   rejeitadas_detalhadas: rejeitadas,
                   falhas: falhas)
      end

      # As linhas que viram escrita, na ordem em que a tela as mostrou.
      # `:rejeita` cai fora aqui, uma vez só, em vez de dentro do loop: a linha
      # rejeitada não tem `card_variant_id` resolvido, e deixá-la chegar ao
      # `INSERT` seria gravar `NULL` numa FK — erro por acaso, onde deveria
      # haver recusa por decisão.
      def linhas_gravaveis(preview)
        preview.linhas_resolvidas.select do |linha|
          CLASSIFICACOES_GRAVAVEIS.include?(linha.classificacao) &&
            linha.card_variant_id.present?
        end
      end

      # Bind params, nunca interpolação: `quantidade_depois` atravessou um
      # `jsonb` e o `card_variant_id` veio de um arquivo do usuário, ainda que
      # já resolvido contra o catálogo.
      def upsert(linha)
        binds = [
          bind("user_id", @user.id),
          bind("card_variant_id", linha.card_variant_id),
          bind("quantity", linha.quantidade_depois)
        ]

        CollectionItem.connection.exec_query(UPSERT_SQL, "CollectionItem Upsert", binds)
      end

      def bind(nome, valor)
        ActiveRecord::Relation::QueryAttribute.new(
          nome, valor, ActiveRecord::Type::Integer.new
        )
      end
  end
end
