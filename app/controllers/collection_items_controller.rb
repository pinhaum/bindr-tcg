# Incremento e decremento da posse de uma **variante** (Req. 7.2 / COL-07).
#
# A rota opera por `card_variant_id`, e **não** por id de `collection_item`:
# o botão "+1" nasce na grade do catálogo, onde na imensa maioria das vezes
# ainda não existe registro de coleção nenhum. Exigir um id de item forçaria
# uma leitura prévia só para descobrir que não há o que ler, ou criar linhas
# zeradas para o catálogo inteiro só para ter o que incrementar. O registro é
# encontrado-ou-criado a partir do par (`Current.user`, variante), que é a
# chave natural que o `UNIQUE (user_id, card_variant_id)` já protege.
#
# Consequência para a autorização: não existe id de item na URL, logo não
# existe id de item de outro usuário a recusar. O usuário vem sempre de
# `Current.user` (Req. 6.5), e `params` só contribui com a variante — que é
# catálogo público, igual para todo mundo. `CollectionItem.for_user` continua
# sendo o único caminho de leitura, de modo que uma rota futura por id de item
# cai em `RecordNotFound` sem precisar de checagem própria.
#
# Uma requisição por operação, sem formulário intermediário: `POST` direto,
# sem `new` nem `edit`.
class CollectionItemsController < ApplicationController
  # Nenhuma declaração de acesso público: o default de `ApplicationController`
  # exige sessão, e é ele que atende o Req. 6.4 — o anônimo é redirecionado
  # para a autenticação **antes** da action rodar, então a alteração não chega
  # a ser aplicada.

  before_action :set_card_variant

  # Req. 7.2 — incremento atômico no banco.
  #
  # `INSERT ... ON CONFLICT DO UPDATE SET quantity = <tabela>.quantity + 1`
  # resolve leitura e escrita num único statement. A alternativa ingênua
  # (`item.update!(quantity: item.quantity + 1)`) lê em Ruby e escreve depois:
  # duas abas incrementando de 1 ao mesmo tempo leem 1 as duas, escrevem 2 as
  # duas, e uma das operações do usuário evapora — *lost update* clássico,
  # apontado pelo `ecc:database-reviewer` na T5 como problema desta camada.
  # Um `SELECT ... FOR UPDATE` também resolveria, mas custa uma ida a mais ao
  # banco e uma transação explícita para proteger um contador de inteiro;
  # `ON CONFLICT` faz o mesmo com o lock de linha que o próprio `UPDATE` já
  # toma. E é o `ON CONFLICT` que transforma a corrida de **criação** (duas
  # abas incrementando uma variante ainda não possuída) em atualização em vez
  # de `RecordNotUnique`, como a spec exige nos Edge Cases.
  def increment
    quantity = execute_returning_quantity(<<~SQL, Current.user.id, @card_variant.id)
      INSERT INTO collection_items (user_id, card_variant_id, quantity, created_at, updated_at)
      VALUES ($1, $2, 1, now(), now())
      ON CONFLICT (user_id, card_variant_id)
      DO UPDATE SET quantity = collection_items.quantity + 1, updated_at = now()
      RETURNING quantity
    SQL

    redirect_back_with notice: "Você tem #{quantity} cópia(s) desta variante."
  end

  # Req. 7.4 / COL-09 — o piso de zero mora no `WHERE`, não num `if` em Ruby.
  #
  # `quantity > 0` como condição do próprio `UPDATE` faz o banco decidir, na
  # mesma linha travada que ele vai escrever, se ainda há o que decrementar.
  # Checar antes em Ruby e escrever depois reabriria a janela: duas abas
  # decrementando de 1 leriam 1 as duas e as duas tentariam escrever 0 — aqui a
  # segunda simplesmente não casa o `WHERE` e afeta zero linhas.
  #
  # Zero linha afetada cobre os dois casos de rejeição do "Done when" com o
  # mesmo statement: quantidade já em zero e variante **sem registro nenhum**.
  # O `UPDATE` não cria linha, então decrementar o que não existe não pode
  # produzir registro negativo — não há o que inserir.
  #
  # O `CHECK (quantity >= 0)` do schema continua sendo a garantia real (a T5 o
  # prova por `UPDATE` direto); este `WHERE` é o que transforma a violação em
  # mensagem para o usuário em vez de 500.
  def decrement
    quantity = execute_returning_quantity(<<~SQL, Current.user.id, @card_variant.id)
      UPDATE collection_items
      SET quantity = quantity - 1, updated_at = now()
      WHERE user_id = $1 AND card_variant_id = $2 AND quantity > 0
      RETURNING quantity
    SQL

    if quantity.nil?
      redirect_back_with alert: "Você não tem cópias desta variante para remover."
    else
      redirect_back_with notice: "Você tem #{quantity} cópia(s) desta variante."
    end
  end

  private
    # A variante é catálogo público: um id inválido é 404, e não vazamento de
    # nada — todo mundo enxerga o mesmo catálogo. O usuário **não** sai daqui.
    def set_card_variant
      @card_variant = CardVariant.find(params[:card_variant_id])
    end

    # `exec_query` com bind params, não interpolação: o id vem do request.
    # Devolve a quantidade resultante, ou `nil` quando nenhuma linha foi
    # afetada.
    def execute_returning_quantity(sql, user_id, card_variant_id)
      binds = [
        ActiveRecord::Relation::QueryAttribute.new("user_id", user_id, ActiveRecord::Type::Integer.new),
        ActiveRecord::Relation::QueryAttribute.new("card_variant_id", card_variant_id, ActiveRecord::Type::Integer.new)
      ]
      CollectionItem.connection.exec_query(sql, "CollectionItem Quantity", binds).rows.dig(0, 0)
    end

    # A T8 troca isto por Turbo Stream; até lá, o redirect normal é o que faz o
    # incremento funcionar sem JavaScript (Edge Cases da spec), e continuará
    # sendo o caminho de fallback depois dela.
    #
    # `allow_other_host: false` é explícito de propósito, embora hoje seja
    # redundante: `config.load_defaults 8.0` liga `raise_on_open_redirects`, e
    # é dele que sai o default do parâmetro. A garantia seria **indireta** —
    # igual à do `secure` do cookie de sessão, já registrada como dívida — e o
    # destino aqui vem do header `Referer`, que é do cliente. Fixar localmente
    # custa uma palavra e tira o comportamento da dependência de uma config
    # global que ninguém relaciona com esta linha. Um `Referer` de outro host
    # cai no `fallback_location`; há teste para isso.
    def redirect_back_with(**flash_options)
      redirect_back fallback_location: catalog_path, allow_other_host: false, **flash_options
    end
end
