# Pin npm packages by running ./bin/importmap

# Turbo é a única dependência de JavaScript do app (T8 / Req. 7.5). O arquivo
# `turbo.js` vem do próprio `turbo-rails` e é servido pelo Propshaft — não há
# download nem `vendor/javascript` a versionar, e a versão do JS acompanha a da
# gem por construção.
#
# **Stimulus não é pinado, de propósito.** A gem está no Gemfile desde o
# esqueleto, mas esta task não tem um único controller Stimulus: a atualização
# da quantidade é Turbo Stream, que é declarativo e chega pronto do servidor.
# Pinar o que não se usa carregaria JS em toda página para nada. Entra quando
# houver comportamento de cliente que o Turbo não resolva.
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.js"
