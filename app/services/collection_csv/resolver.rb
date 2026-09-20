module CollectionCsv
  # Resolve a variante de cada linha aceita pelo parser e classifica o efeito
  # que ela teria sobre a coleção do usuário (POR-05, POR-06, POR-13).
  #
  # **Leitura pura, e isso é a invariante da feature, não um detalhe.** Este
  # serviço diz **o que aconteceria**; quem grava é a T14, depois da
  # confirmação explícita do usuário (Req. 10.5). A coleção é o único dado
  # insubstituível do sistema — o catálogo é regenerável (AD-001). Um
  # resolvedor que gravasse antes da confirmação estaria errado mesmo com
  # todos os testes verdes, e há teste com `assert_no_changes` para manter
  # assim.
  #
  # A chave é o **par** `card_number` + `variant_code`, nunca o nome e nunca o
  # `variant_code` sozinho: o índice único do schema é `(card_id,
  # variant_code)`, por carta e não global — o mesmo sufixo `_p1` existe sob
  # centenas de cartas. O nome é informativo e diverge legitimamente do
  # catálogo, que é regenerado sem o usuário fazer nada.
  #
  # **A ausência da fonte não é filtro.** A ingestão não deleta (Req. 1.7): ela
  # deixa `card_variants.last_seen_at` para trás enquanto remarca o presente.
  # Não existe coluna booleana de ausência, e este serviço não consulta
  # `last_seen_at` — filtrar por marca recente apagaria do import justamente as
  # cartas antigas que o usuário mais precisa registrar.
  class Resolver
    # Uma linha classificada, com o suficiente para a pré-visualização da T13
    # (o que era, o que fica, e o motivo quando rejeitada) e para a escrita da
    # T14 (`card_variant_id` e `quantidade_depois`).
    #
    # Objeto de resultado com campos nomeados, no espírito do `Parser::Result`
    # (T8): quem consome ramifica em `aceita?` sem `rescue` e sem lembrar
    # ordem posicional.
    Linha = Struct.new(:indice, :card_number, :variant_code, :card_name,
      :quantidade_bruta, :card_variant_id, :classificacao,
      :quantidade_antes, :quantidade_depois, :motivo, :mensagem,
      keyword_init: true) do
      def rejeitada?
        classificacao == :rejeita
      end

      def aceita?
        !rejeitada?
      end
    end

    Result = Struct.new(:linhas) do
      def aceitas
        linhas.select(&:aceita?)
      end

      def rejeitadas
        linhas.select(&:rejeitada?)
      end
    end

    MENSAGENS = {
      variante_inexistente: "Não existe no catálogo uma variante com este código para esta carta.",
      quantidade_invalida: "A quantidade precisa ser um número inteiro maior ou igual a zero.",
      linha_duplicada: "Esta variante aparece mais de uma vez no arquivo; vale a última ocorrência."
    }.freeze

    def initialize(user, linhas)
      @user = user
      @linhas = Array(linhas)
    end

    def call
      return Result.new([].freeze) if linhas.empty?

      variantes = variantes_por_par
      quantidades = quantidades_atuais(variantes.values)
      ultima = ultima_ocorrencia_por_variante(variantes)

      classificadas = linhas.each_with_index.map do |linha, indice|
        classificar(linha, indice, variantes, quantidades, ultima)
      end

      Result.new(classificadas.freeze)
    end

    private

    attr_reader :user, :linhas

    def classificar(linha, indice, variantes, quantidades, ultima)
      base = base_da_linha(linha, indice)

      variante_id = variantes[par(linha)]
      return rejeitar(base, :variante_inexistente) if variante_id.nil?

      base.card_variant_id = variante_id

      quantidade = quantidade_de(linha)
      return rejeitar(base, :quantidade_invalida) if quantidade.nil?

      # A duplicata é verificada **depois** da variante e da quantidade: uma
      # linha que já seria rejeitada por outro motivo recebe o motivo mais
      # específico, que é o que ajuda o usuário a corrigir o arquivo.
      return rejeitar(base, :linha_duplicada) unless ultima[variante_id] == indice

      base.quantidade_antes = quantidades[variante_id]
      base.quantidade_depois = quantidade
      base.classificacao = classificacao_de(base.quantidade_antes, quantidade)
      base
    end

    def base_da_linha(linha, indice)
      Linha.new(indice: indice,
        card_number: valor(linha, "card_number"),
        variant_code: valor(linha, "variant_code"),
        card_name: valor(linha, "card_name"),
        quantidade_bruta: linha[Format::COLUMNS[3]])
    end

    def rejeitar(base, motivo)
      base.classificacao = :rejeita
      base.motivo = motivo
      base.mensagem = MENSAGENS.fetch(motivo)
      base
    end

    # As quatro classificações e o que cada uma significa para o usuário:
    #
    # - `:cria`     — não havia registro; passa a haver, com a quantidade do
    #                 arquivo (inclusive zero, que é "não possuo" representável
    #                 pelo Req. 7.3).
    # - `:atualiza` — havia registro com outra quantidade; AD-006 manda
    #                 **substituir**, e o antes e o depois viajam juntos para
    #                 que a pré-visualização mostre o que está sendo trocado.
    # - `:zera`     — caso destrutivo, separado de propósito: havia posse
    #                 (quantidade ≥ 1) e o arquivo traz zero, logo a posse
    #                 desaparece. É "atualiza" pela mecânica, mas esconder isso
    #                 dentro dela tiraria do usuário justamente a informação
    #                 que a confirmação do Req. 10.5 existe para dar.
    # - `:inalterada` — a quantidade do arquivo é a que já está lá. É o que
    #                 torna a ida-e-volta do POR-11 legível: reimportar o
    #                 próprio export diz "nada muda" em vez de anunciar N
    #                 atualizações que não alteram nada.
    def classificacao_de(antes, depois)
      return :cria if antes.nil?
      return :inalterada if antes == depois
      return :zera if depois.zero?

      :atualiza
    end

    # Uma consulta para o lote inteiro (POR-13), qualquer que seja o número de
    # linhas. O `joins` é obrigatório porque `card_number` vive em `cards` e
    # não em `card_variants` — sem ele, cada par viraria uma consulta.
    #
    # O filtro é por `card_number` e depois cruzado em memória pelo par, em vez
    # de um `IN` sobre tuplas: o número de cartas distintas de um arquivo é da
    # ordem das linhas (teto de 10.000 por AD-008), e uma lista simples é o que
    # o planejador resolve melhor com o índice de `cards.card_number`. O
    # cruzamento final continua sendo pelo **par**, que é o que impede um
    # `variant_code` de outra carta de casar.
    def variantes_por_par
      numeros = linhas.filter_map { |linha| valor(linha, "card_number") }.uniq
      return {} if numeros.empty?

      CardVariant
        .joins(:card)
        .where(cards: { card_number: numeros })
        .pluck("cards.card_number", "card_variants.variant_code", "card_variants.id")
        .to_h { |numero, codigo, id| [ [ numero, codigo ], id ] }
    end

    # Uma consulta para as posses atuais do lote inteiro, sempre a partir do
    # **objeto** `User` (Req. 6.5): `for_user` levanta `ArgumentError` num id,
    # então não há caminho de parâmetro de request a consulta. O "antes" tem
    # que sair da coleção de quem importa — a posse de outro usuário sobre a
    # mesma variante seria vazamento além de classificação errada.
    def quantidades_atuais(variant_ids)
      return {} if variant_ids.empty?

      CollectionItem
        .for_user(user)
        .where(card_variant_id: variant_ids.uniq)
        .pluck(:card_variant_id, :quantity)
        .to_h
    end

    # Edge Case da spec: a mesma variante em duas linhas não pode deixar "a
    # última vencer em silêncio".
    #
    # O tratamento: a **última** ocorrência vale — AD-006 é substituir, e é ela
    # que reflete a última intenção do usuário — e as anteriores são
    # **rejeitadas com motivo próprio**. Rejeitar a última seria arbitrário;
    # aplicar as duas é impossível sob `UNIQUE (user_id, card_variant_id)`; e
    # descartar as anteriores sem dizer nada é exatamente o que o Edge Case
    # proíbe. Como rejeição, a linha perdedora chega à pré-visualização da T13
    # pelo mesmo caminho de qualquer outra, com o seu motivo visível.
    def ultima_ocorrencia_por_variante(variantes)
      linhas.each_with_index.each_with_object({}) do |(linha, indice), mapa|
        id = variantes[par(linha)]
        mapa[id] = indice if id
      end
    end

    def par(linha)
      [ valor(linha, "card_number"), valor(linha, "variant_code") ]
    end

    # `nil` quando a quantidade não é um inteiro não negativo — negativa,
    # fracionária, texto, vazia. O `CHECK (quantity >= 0)` do schema é a
    # garantia real; aqui o valor é recusado antes de chegar lá para que o
    # usuário leia o motivo em vez de um erro de banco.
    def quantidade_de(linha)
      bruto = linha[Format::COLUMNS[3]].to_s.strip
      return nil unless bruto.match?(/\A\d+\z/)

      Integer(bruto, 10)
    end

    def valor(linha, coluna)
      valor = linha[coluna]
      return nil if valor.nil?

      texto = valor.to_s.strip
      texto.empty? ? nil : texto
    end
  end
end
