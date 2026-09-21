# Upload do CSV de import: produz a pré-visualização e **nada mais**
# (POR-07, POR-12 / Req. 10.5).
#
# **A invariante da feature mora aqui.** Este é o ponto do sistema em que um
# arquivo do usuário descreve mudanças na coleção — o único dado insubstituível
# do sistema, já que o catálogo é regenerável (AD-001). A action recebe o
# arquivo, classifica o que aconteceria e grava **a pré-visualização**. Ela não
# escreve uma linha em `collection_items`, e não pode passar a escrever: quem
# grava é a T14, depois da confirmação explícita. Um upload que altere uma única
# quantidade está errado mesmo com todos os testes verdes, e há
# `assert_no_changes` sobre o retrato inteiro da tabela para manter assim.
#
# **Nenhuma declaração de acesso público.** O default de `ApplicationController`
# exige sessão em toda action (Req. 6.4), e é ele que atende POR-12: o anônimo é
# redirecionado **antes** de a action rodar, então o arquivo dele nem chega a ser
# lido. Isso também fecha por construção a armadilha que apareceu cinco vezes na
# feature `colecao`: `allow_unauthenticated_access` removeria o
# `before_action :require_authentication`, que era quem chamava `resume_session`,
# e `Current.user` seria `nil` na action — aqui isso gravaria staging órfão ou
# estouraria, em silêncio, sobre o arquivo de alguém.
#
# **CSRF continua verificado.** A revisão de segurança da T10 pediu isso em
# letras: nada de `skip_before_action :verify_authenticity_token`. Um POST que
# aceite requisição de outra origem transformaria a etapa de pré-visualização
# num vetor de upload silencioso, e é sobre ela que a confirmação da T14 vai
# agir.
class CollectionImportsController < ApplicationController
  # Teto de bytes **na borda**, como segunda camada ao `Parser::MAX_BYTES`
  # (apontamento da revisão da T10). Os dois medem a mesma grandeza em momentos
  # diferentes, e é essa diferença que justifica os dois: o do parser vê o
  # conteúdo já lido para uma `String` na memória do processo; este vê o
  # `Content-Length` declarado e recusa **antes** de `read` alocar qualquer
  # coisa. Sem ele, o caminho de recusa por tamanho passaria obrigatoriamente
  # por materializar o arquivo inteiro — exatamente o custo que o limite existe
  # para evitar.
  #
  # A folga sobre `MAX_BYTES` é deliberada: o corpo multipart carrega também os
  # limites de parte, os cabeçalhos e o token de CSRF, então medir o envelope
  # pela régua do conteúdo recusaria arquivos legítimos de tamanho quase máximo.
  # O teto exato do **conteúdo** continua sendo do parser, que mede a string de
  # verdade; este aqui é a barreira grosseira que impede o absurdo de entrar.
  #
  # `Content-Length` é dado do cliente e pode mentir — mentir **para menos** não
  # ajuda ninguém, porque o parser mede o conteúdo real logo depois. Esta
  # camada não substitui a outra, e é por isso que as duas existem.
  MAX_CORPO_BYTES = 12 * 1024 * 1024

  MENSAGEM_SEM_ARQUIVO = "Selecione o arquivo CSV da sua coleção para importar.".freeze

  MENSAGEM_CORPO_GRANDE = "O arquivo é grande demais: o limite é de 8 MB. " \
    "Envie o CSV exportado da sua coleção, sem colunas ou textos extras.".freeze

  MENSAGEM_JA_CONFIRMADA = "Esta importação já foi confirmada ou expirou. " \
    "Sua coleção não foi alterada; envie o arquivo de novo se quiser importar.".freeze

  # O formulário de upload. Sem consulta e sem escrita — só o ponto de entrada
  # do fluxo.
  def new
  end

  # O upload. Três passos e nenhum a mais: ler o arquivo, classificar o que
  # aconteceria, guardar a classificação.
  #
  # `Current.user` é o **objeto** que atravessa parser, resolvedor e staging, e
  # nenhum id de request entra em lugar nenhum: `CollectionImport.for_user` e
  # `CollectionItem.for_user` levantam `ArgumentError` para qualquer coisa que
  # não seja `User`, então `?user_id=` não tem por onde entrar (Req. 6.5).
  #
  # A recusa do parser é `422` com a mensagem dele, renderizando o formulário de
  # novo: recusa é desfecho **esperado** aqui (arquivo do usuário é entrada
  # hostil por natureza), e o usuário precisa ler o que fazer com o arquivo dele.
  # **Nenhum registro de staging nasce numa recusa** — guardar o arquivo
  # rejeitado daria à T14 algo para confirmar que o usuário nunca viu.
  def create
    return recusar(MENSAGEM_CORPO_GRANDE) if corpo_grande_demais?

    arquivo = params[:arquivo]
    return recusar(MENSAGEM_SEM_ARQUIVO) unless arquivo.respond_to?(:read)

    resultado = CollectionCsv::Parser.new(conteudo_utf8(arquivo)).call
    return recusar(resultado.erro) unless resultado.aceito?

    preview = CollectionImport.create!(
      user: Current.user,
      filename: nome_para_exibicao(arquivo),
      linhas: CollectionCsv::Resolver.new(Current.user, resultado.linhas).call.linhas
    )

    redirect_to collection_import_path(preview.token)
  end

  # A pré-visualização guardada. A tela de verdade é da T13; aqui ela existe
  # para que o redirect do upload chegue a algum lugar e para que o teste de
  # autorização tenha o que exercitar.
  #
  # **`find_by_token_for` e nunca `find_by(token:)`**: o filtro por dono vem
  # antes de o registro ser carregado (T11). Token alheio e token inexistente
  # devolvem `nil` indistintamente, e os dois viram o mesmo `404` — responder
  # coisas diferentes transformaria a tabela num oráculo de tokens válidos, um
  # por requisição.
  def show
    @collection_import = CollectionImport.find_by_token_for(Current.user, params[:token])

    raise ActiveRecord::RecordNotFound if @collection_import.nil?
  end

  # A confirmação (T14) — a **única escrita** da feature, e a action mais
  # perigosa do sistema. Toda a lógica mora em `CollectionCsv::Commit`; aqui há
  # a chamada e a tradução do desfecho em resposta, e nada mais.
  #
  # **Nenhum parâmetro além do token entra nesta action.** Não se lê `arquivo`,
  # não se chama `Parser` nem `Resolver`: o que é gravado é o que a
  # pré-visualização mostrou, lido do staging (Req. 10.5). Reparsear aqui
  # transformaria o botão "confirmar" num segundo upload cego, e o usuário
  # gravaria algo que nunca leu.
  #
  # `nil` do serviço cobre token inexistente e token alheio com a **mesma**
  # resposta, herdando a indistinção de `find_by_token_for` (T11): responder
  # coisas diferentes faria da rota um oráculo de tokens válidos, um por
  # requisição.
  def confirm
    resultado = CollectionCsv::Commit.new(Current.user, params[:token]).call

    raise ActiveRecord::RecordNotFound if resultado.nil?

    # Não reivindicada: já confirmada antes, ou vencida. Os dois são desfechos
    # **esperados** — o usuário clicou duas vezes, ou deixou a tela aberta —, e
    # nenhum deles é erro: nada foi gravado, e dizer isso é mais útil do que um
    # 500 ou um silêncio que sugere sucesso.
    unless resultado.reivindicada?
      redirect_to collection_import_path(params[:token]), alert: MENSAGEM_JA_CONFIRMADA
      return
    end

    # **O resumo é renderizado aqui, e não depois de um redirect** (T15). Não é
    # preferência de estilo: o `Result` é o único lugar onde as contagens do
    # Req. 10.4 existem, e ele não é persistido (ver o cabeçalho de
    # `_resumo`). Um `redirect_to` obrigaria a atravessá-lo pelo flash — um
    # cookie, com teto de 4 KB, carregando a lista de rejeições — ou a
    # recalculá-lo na outra action a partir do staging já consumido, que
    # descreveria de novo a **intenção** e não o que foi gravado. Renderizar na
    # própria resposta é o que mantém o resumo amarrado à escrita que acabou de
    # acontecer.
    #
    # O preço é o PRG perdido: um F5 reenvia o POST. O desfecho é o do Edge
    # Case da spec — a segunda confirmação não casa o `WHERE status =
    # 'pendente'`, nada é gravado de novo, e o usuário cai no
    # `MENSAGEM_JA_CONFIRMADA`. Barato, e já provado por
    # `collection_import_commit_test`.
    @resultado = resultado
    @collection_import = CollectionImport.find_by_token_for(Current.user, params[:token])

    render :resumo
  end

  private

    # O arquivo do Rack chega em **ASCII-8BIT**: são bytes de rede, e o Rack não
    # tem por que adivinhar a codificação deles. O `Parser` (T8) espera uma
    # string UTF-8 — a primeira coisa que ele faz é perguntar
    # `valid_encoding?`, e essa pergunta só tem sentido contra uma codificação
    # declarada. Entregar os bytes crus fazia o `delete_prefix(BOM)` estourar
    # `Encoding::CompatibilityError` sobre um literal UTF-8, **antes** de o
    # parser chegar à sua própria verificação: o arquivo em Latin-1 virava erro
    # 500 em vez da frase em português que a T8 escreveu para ele.
    #
    # `force_encoding` e não `encode`: reinterpretar os mesmos bytes como UTF-8
    # é exatamente o que se quer, porque é o parser quem decide se eles são
    # válidos. Converter aqui esconderia dele o arquivo mal salvo — e o usuário
    # que salvou a planilha em Latin-1 precisa ler que foi isso que aconteceu.
    def conteudo_utf8(arquivo)
      arquivo.read.to_s.force_encoding(Encoding::UTF_8)
    end

    def corpo_grande_demais?
      request.content_length.to_i > MAX_CORPO_BYTES
    end

    def recusar(mensagem)
      flash.now[:alert] = mensagem
      render :new, status: :unprocessable_entity
    end

    # O `original_filename` é **dado do cliente**, e a coluna `filename` existe
    # para exibição — nunca para compor caminho em disco (apontamento da revisão
    # da T10). Nada neste fluxo abre arquivo por nome: o conteúdo vem do
    # tempfile que o Rack já criou, com nome que o Rack escolheu. Ainda assim o
    # valor é reduzido ao basename e limpo de tudo que não seja nome de arquivo,
    # porque ele vai ser **renderizado** na tela da T13: um valor hostil que não
    # vira caminho ainda pode virar outra coisa na ponta que o exibe, e sanear
    # na entrada é mais barato do que confiar em toda ponta futura.
    def nome_para_exibicao(arquivo)
      bruto = File.basename(arquivo.original_filename.to_s.tr("\\", "/"))
      limpo = bruto.gsub(/[^[:alnum:]._-]/, "_").delete_prefix(".").first(120)

      limpo.presence || "colecao.csv"
    end
end
