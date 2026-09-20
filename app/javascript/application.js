// Ponto de entrada do JavaScript (config/importmap.rb).
//
// Importar `@hotwired/turbo-rails` é o que liga o Turbo: sem esta linha o
// `<turbo-stream>` devolvido pelo controller de coleção chega ao navegador
// como markup inerte e a página não atualiza.
//
// **Nada aqui é pré-requisito de funcionamento.** Com o JavaScript
// indisponível o mesmo formulário faz submissão normal e o controller responde
// com redirect — o caminho que os Edge Cases da spec exigem manter (o Req. 7.5
// é melhoria progressiva, não requisito de funcionamento).
import "@hotwired/turbo-rails";
