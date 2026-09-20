require "test_helper"
require "ripper"

# T4 — `ProgressController` e rota, com sessão exigida (PRG-08, PRG-09).
#
# O recorte desta task é **autorização e roteamento**, não a apresentação: os
# números já estão provados por unidade em `set_progress_query_test.rb` (T1–T3)
# e a view rica é a T5. Aqui prova-se que a página existe, que ela exige sessão
# e que o usuário do cálculo é o da sessão e de mais ninguém.
#
# SPEC_DEVIATION: a spec (`Assumptions & Open Questions`, "Verificação de
# comportamento visual") prevê verificar comportamento de página por teste de
# **integração sobre HTML renderizado**, e não por system test.
#
# Reason: não há navegador no container (`CLAUDE.md`), logo `assert_select` sobre
# o corpo da resposta é a maior fidelidade disponível. É o precedente já
# estabelecido em `test/integration/collection_ownership_ui_test.rb`. Nenhum
# critério desta task depende de layout ou de interação — só de qual número
# chega ao corpo e de quem é redirecionado.
#
# Três armadilhas ditaram a forma dos testes:
#
# 1. **Um `assert_redirected_to` sozinho não prova filtro.** Ele passaria
#    igualmente se a rota não existisse, se a action não existisse ou se
#    houvesse um redirect por outra razão. Por isso o teste estrutural sobre
#    `_process_action_callbacks`, no mesmo par simétrico de
#    `authentication_test.rb`: `require_authentication` **presente** no
#    controller protegido e **ausente** no `CatalogController`, que é o público.
#    Sem os dois lados, a asserção não distingue "o filtro está instalado aqui"
#    de "o filtro está instalado em tudo, inclusive onde não deveria".
# 2. **`?user_id=` só discrimina se os dois usuários tiverem números
#    diferentes.** Com posses do mesmo tamanho nenhuma asserção separaria
#    "ignorou o parâmetro" de "obedeceu ao parâmetro". `@nami` possui uma
#    variante do set; `@zoro` possui duas — e é a posse **de `@zoro`** que o
#    parâmetro tenta alcançar.
# 3. **O anônimo tem que sair sem dado no corpo, não só com 302.** Um controller
#    que renderizasse a página e depois redirecionasse ainda assim seria 302. A
#    asserção olha o corpo da resposta e exige que nem o código do set nem
#    número de posse apareçam.
class ProgressTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @nami = User.create!(email: "nami-prg4@example.com", password: PASSWORD)
    @zoro = User.create!(email: "zoro-prg4@example.com", password: PASSWORD)

    @set = CardSet.create!(code: "OPp4a", name: "Romance Dawn", kind: "booster",
                           base_set_size: 4, total_set_size: 4)

    @v1 = create_variant("p4a1")
    @v2 = create_variant("p4a2")
    @v3 = create_variant("p4a3")

    # Posses de tamanhos distintos, de propósito: é o que faz o teste do
    # `?user_id=` discriminar. `@nami` tem 1 variante (25%), `@zoro` tem 2 (50%).
    CollectionItem.create!(user: @nami, card_variant: @v1, quantity: 1)
    CollectionItem.create!(user: @zoro, card_variant: @v2, quantity: 1)
    CollectionItem.create!(user: @zoro, card_variant: @v3, quantity: 1)
  end

  # A suíte roda em paralelo e o projeto não usa fixtures YAML: cada teste cria
  # os próprios registros, com chaves naturais distintas por arquivo.
  def create_variant(suffix)
    card = Card.create!(card_set: @set, card_number: "OP01-#{suffix}", name: "Carta #{suffix}",
                        card_type: "character", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: @set, variant_code: suffix,
                        rarity: "C", art_kind: "base")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  # O número que cada usuário deve ver, lido do mesmo query object que a action
  # usa. O teste não reimplementa a agregação — ela já é provada por unidade;
  # aqui ele só verifica **de quem** é o número que chegou ao corpo.
  def linha_do_set(user)
    SetProgressQuery.new(user).call.find { |row| row.set_code == @set.code }
  end

  # --- PRG-09: a página exige sessão ---

  test "anônimo é redirecionado para a autenticação, sem dado de coleção no corpo" do
    get progress_path

    assert_redirected_to new_session_path
    assert_no_match @set.code, response.body
    assert_no_match(/\bOPp4a\b/, response.body)
  end

  # Um 302 sozinho não distingue "filtro presente" de "rota inexistente" nem de
  # "redirect por outra razão". O par simétrico é o que fecha essa lacuna: o
  # filtro **existe** no controller de progresso e **não** existe no catálogo,
  # que é o público do app.
  test "require_authentication está entre os callbacks do ProgressController" do
    assert_includes ProgressController._process_action_callbacks.map(&:filter),
                    :require_authentication,
                    "a página de progresso precisa exigir sessão"

    refute_includes CatalogController._process_action_callbacks.map(&:filter),
                    :require_authentication,
                    "o catálogo precisa continuar público, senão a asserção acima " \
                    "só prova que o filtro está em tudo"
  end

  # A asserção estrutural acima já prova o **efeito** (o filtro está instalado);
  # esta prova a **causa**, e por AST em vez de regex sobre o texto. Um
  # `refute_match(/allow_unauthenticated_access/, fonte)` falharia sobre o
  # comentário deste próprio arquivo que explica por que a declaração não deve
  # existir — e passaria se alguém a escrevesse por outro caminho
  # (`skip_before_action :require_authentication`), que é a forma que o concern
  # expande. Pela árvore, o que se procura é a **chamada**, sob qualquer um dos
  # dois nomes, e comentário nenhum entra.
  test "o controller não declara acesso público por nenhum dos dois nomes" do
    chamadas = identificadores_chamados(arvore_do_controller)

    refute_includes chamadas, "allow_unauthenticated_access",
                    "declarar acesso público removeria o before_action que resolve a sessão, " \
                    "e ler Current.user sem ele responde 200 com tudo zerado, em silêncio"
    refute_includes chamadas, "skip_before_action",
                    "pular o filtro pela forma expandida tem o mesmo efeito"
  end

  test "usuário autenticado recebe 200 na página de progresso" do
    sign_in(@nami)

    get progress_path

    assert_response :success
  end

  # Edge Case da spec: "WHEN a sessão expirar e o usuário recarregar a página,
  # THEN ele é levado à autenticação e retorna à página de progresso depois".
  test "anônimo volta à página de progresso depois de autenticar" do
    get progress_path
    assert_redirected_to new_session_path
    assert_equal progress_url, session[:return_to_after_authenticating]

    sign_in(@nami)

    assert_redirected_to progress_url
    follow_redirect!
    assert_response :success
  end

  # --- PRG-08: o cálculo parte de `Current.user` ---

  test "a action expõe o progresso do usuário da sessão" do
    sign_in(@nami)

    get progress_path

    linha = assigns_progress.find { |row| row.set_code == @set.code }
    assert_equal linha_do_set(@nami).owned_variants, linha.owned_variants
    assert_equal 1, linha.owned_variants
  end

  # A discriminação depende de `@zoro` ter número diferente do de `@nami`: com
  # posses iguais, obedecer ao parâmetro e ignorá-lo dariam o mesmo resultado.
  test "?user_id= de outro usuário é ignorado e vale o usuário da sessão" do
    assert_equal 2, linha_do_set(@zoro).owned_variants,
                 "o cenário precisa de números diferentes, senão nada discrimina"

    sign_in(@nami)

    get progress_path(user_id: @zoro.id)

    assert_response :success
    linha = assigns_progress.find { |row| row.set_code == @set.code }
    assert_equal 1, linha.owned_variants,
                 "o número exibido tem que ser o do usuário da sessão, não o do parâmetro"
  end

  # Prova estrutural, complementar à de comportamento acima: o controller não
  # toca `params` em lugar nenhum. É uma afirmação mais forte que a do
  # `CollectionItemsController` — lá o teste irmão admite `:card_variant_id`,
  # porque a variante é catálogo público e precisa vir da URL; aqui a página
  # inteira é "o progresso de quem está na sessão" e **não tem nenhum parâmetro
  # legítimo** a receber.
  #
  # Por AST (`Ripper.sexp`) e não por regex, pela mesma razão do teste irmão: um
  # regex de `params[:user_id]` é contornado sem intenção por
  # `params.dig(:user_id)`, por `params.to_unsafe_h[:user_id]` ou por
  # `chave = :user_id; params[chave]`, e um regex de `/params/` casaria com esta
  # palavra dentro de um comentário. Na árvore procura-se o **identificador**, o
  # que dispensa manter lista de formas de acesso.
  #
  # Limite conhecido e aceito, herdado do teste irmão: isto prova que nenhum
  # dado de request vira usuário **por esta porta**. Outro caminho
  # (`request.headers`, `cookies` não assinado) é coberto pelos testes de
  # comportamento acima, cada um pelo efeito.
  test "o controller não lê params em lugar nenhum" do
    refute_includes identificadores_chamados(arvore_do_controller), "params",
                    "o usuário do progresso sai de Current.user; nada vindo do request o desloca"
  end

  private
    def arvore_do_controller
      fonte = Rails.root.join("app/controllers/progress_controller.rb").read
      arvore = Ripper.sexp(fonte)
      assert_not_nil arvore, "o controller não é Ruby válido"
      arvore
    end

    # Todo identificador que aparece em **posição de chamada ou de referência**
    # na árvore. `Ripper.sexp` já descarta comentários, então o que sobra é
    # código de verdade. Cobre a chamada sem receptor (`params`,
    # `allow_unauthenticated_access`) e a com receptor (`self.params`) pela mesma
    # regra, porque a busca é pelo nó `@ident` e não por uma forma de invocação
    # que teria de ser mantida à mão.
    def identificadores_chamados(no)
      return [] unless no.is_a?(Array)

      case no
      in [ :@ident, nome, * ] then [ nome ]
      else no.flat_map { |filho| identificadores_chamados(filho) }
      end
    end

    # O progresso que a action montou. Ler a variável de instância da view é o
    # que permite asserir **de quem** é o número sem depender da marcação, que
    # é escopo da T5.
    def assigns_progress
      @controller.view_assigns["rows"]
    end
end
