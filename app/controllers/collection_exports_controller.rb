# Download da coleção do usuário em CSV (Req. 10 / POR-03).
#
# **Nenhuma declaração de acesso público, e isso é a decisão desta task.** O
# default de `ApplicationController` exige sessão em toda action (Req. 6.4), e é
# ele que atende POR-03: o anônimo é redirecionado para a autenticação **antes**
# de a action rodar, então nenhuma linha de coleção chega ao corpo da resposta.
# Diferente do catálogo, aqui não há nada de público a servir — o arquivo é, por
# definição, o dado privado de uma pessoa.
#
# Exigir sessão também fecha, por construção, a armadilha que apareceu cinco
# vezes na feature `colecao`: em controller público `allow_unauthenticated_access`
# remove o `before_action :require_authentication`, que era quem chamava
# `resume_session` — e ler `Current.user` sem antes chamar `authenticated?`
# responde **200 com um arquivo vazio, em silêncio**, que para o colecionador é
# indistinguível de "minha coleção sumiu". Aqui o filtro resolve a sessão antes
# da action e o defeito não tem como existir. Por isso
# `allow_unauthenticated_access` não deve ser acrescentado a este controller, e
# `authenticated?` não precisa ser chamado por reflexo como no
# `CatalogController#owned_quantities`.
#
# **Leitura pura.** A invariante da feature é que nada é gravado na coleção sem
# confirmação explícita do usuário (Req. 10.5); o export é a metade sem risco de
# perda e não escreve nada — nem um registro de auditoria, nem uma marca de
# "último export".
class CollectionExportsController < ApplicationController
  # O nome é fixo e em português porque é o que o usuário lê na pasta de
  # downloads. **Sem e-mail, sem id e sem data**: o arquivo circula em anexo e
  # em print de tela, e o identificador do usuário não tem por que viajar junto
  # — a coleção já é identificada por quem baixou. Fixo também significa que
  # baixar duas vezes produz o mesmo nome, e o sistema operacional resolve a
  # colisão como resolve qualquer outra.
  FILENAME = "colecao.csv".freeze

  # `CollectionCsv::Export.new(Current.user)` é o único ponto de entrada, e ele
  # aceita o **objeto** `User` — nunca um id. A barreira é de tipo e mora em
  # `CollectionItem.for_user`, que levanta `ArgumentError` para qualquer outra
  # coisa. Consequência: `?user_id=7` não tem por onde entrar na consulta, e o
  # Req. 6.5 fica satisfeito por construção em vez de por verificação.
  #
  # A action não lê `params` em lugar nenhum: não há filtro, recorte nem formato
  # a receber do request. O arquivo inteiro é uma consulta só, montada a partir
  # de quem está na sessão.
  #
  # `disposition: "attachment"` porque o CSV é para ser salvo, não exibido; o
  # `charset` explícito no `type` é o que diz à planilha como ler os acentos —
  # sem ele, `Bell-mère` chega corrompido a quem abre o arquivo em Latin-1.
  def show
    send_data CollectionCsv::Export.new(Current.user).to_csv,
      type: "text/csv; charset=#{CollectionCsv::Format::ENCODING.downcase}",
      disposition: "attachment",
      filename: FILENAME
  end
end
