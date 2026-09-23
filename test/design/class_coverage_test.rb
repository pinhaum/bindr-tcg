require "test_helper"
require_relative "support/stylesheet"

# INT-06, INT-07 (Req. 12.6, 12.8): toda classe que as views usam tem regra em
# `catalog.css`. Classe escrita no HTML e ignorada pela folha foi o que deixou
# `flash--notice` idêntico a `flash--alert`; esta guarda impede a próxima.
#
# A lista de classes é **derivada** das views e helpers, não declarada aqui: uma
# classe nova entra na guarda sem ninguém lembrar de registrá-la.
class ClassCoverageTest < ActiveSupport::TestCase
  SOURCES = %w[app/views app/helpers].freeze

  # `flash--<%= kind %>` em `layouts/_flash_message.html.erb`: o sufixo é o tipo
  # de flash. A lista é conferida contra os controllers no teste abaixo.
  FLASH_KINDS = %w[alert notice].freeze
  INTERPOLATION = "{interpolado}".freeze

  HTML_CLASS = /\bclass="((?:<%.*?%>|[^"])*)"/m
  RUBY_CLASS = /\b(?:form_)?class:\s*"([^"]*)"/
  ERB_TAG = /<%=?(.*?)%>/m

  # Classes de um trecho de template. ERB que só escolhe literais
  # (`<%= "x--y" if cond %>`) contribui com os literais; ERB que interpola um
  # valor vira marcador, expandido por FLASH_KINDS.
  def self.classes_in(source)
    html = source.scan(HTML_CLASS).flatten.flat_map do |value|
      value.gsub(ERB_TAG) do
        literals = Regexp.last_match(1).scan(/"([^"]*)"/).flatten
        literals.any? ? " #{literals.join(' ')} " : INTERPOLATION
      end.split
    end
    ruby = source.scan(RUBY_CLASS).flatten.flat_map(&:split)

    (html + ruby).flat_map do |name|
      name.include?(INTERPOLATION) ? FLASH_KINDS.map { |kind| name.sub(INTERPOLATION, kind) } : [ name ]
    end.uniq
  end

  # Classes com pelo menos uma regra **com declaração**: seletor vazio não conta.
  def self.styled_classes(rules)
    rules.select { |_, body| Stylesheet.declarations(body).any? }
         .flat_map { |selector, _| selector.scan(/\.([a-zA-Z0-9_-]+)/).flatten }
         .uniq
  end

  def self.view_classes
    SOURCES.flat_map { |dir| Dir[Rails.root.join(dir, "**/*.{erb,rb}")] }
           .flat_map { |path| classes_in(File.read(path)) }
           .uniq
  end

  test "toda classe usada nas views tem regra na folha" do
    classes = self.class.view_classes
    assert_operator classes.size, :>, 100, "a extração de classes das views parou de encontrar classes"

    missing = classes - self.class.styled_classes(Stylesheet.rules)

    assert_empty missing.sort, "classes usadas nas views sem regra em catalog.css:\n#{missing.sort.join("\n")}"
  end

  test "o modificador interpolado de flash cobre exatamente os tipos usados nos controllers" do
    kinds = Dir[Rails.root.join("app/controllers/**/*.rb")].flat_map do |path|
      source = File.read(path)
      source.scan(/flash(?:\.now)?\[:(\w+)\]/).flatten + source.scan(/\b(notice|alert):\s/).flatten
    end.uniq.sort

    assert_equal FLASH_KINDS, kinds
  end

  test "a extração lê atributo HTML, ERB condicional, interpolação de flash e opção Ruby" do
    source = <<~ERB
      <p class="a-bloco a-bloco--<%= kind %>">x</p>
      <li class="b-item<%= " b-item--on" if on? %>"></li>
      <%= link_to "x", "/", class: "c-link c-link--x" %>
      <%= button_to "/", form_class: "d-form" do %>y<% end %>
    ERB

    assert_equal %w[a-bloco a-bloco--alert a-bloco--notice b-item b-item--on c-link c-link--x d-form],
                 self.class.classes_in(source).sort
  end

  test "seletor sem declaração não conta como regra" do
    rules = Stylesheet.rules(".com-regra { margin: 0; } .sem-regra { } .composta .tambem { gap: 0; }")

    assert_equal %w[com-regra composta tambem], self.class.styled_classes(rules).sort
  end

  CHROMATIC_PROPERTY = /\A(?:color|background(?:-color)?|border(?:-(?:top|right|bottom|left))?-color|outline-color)\z/

  # Seletores com declaração de cor entre as regras que citam um dos modificadores.
  def self.chromatic_modifier_rules(rules, modifiers)
    rules.select do |selector, body|
      modifiers.any? { |modifier| selector.match?(/\.#{Regexp.escape(modifier)}(?![-\w])/) } &&
        Stylesheet.declarations(body).any? { |property, _| property.match?(CHROMATIC_PROPERTY) }
    end.map(&:first)
  end

  # Incremento e decremento se distinguem pelo rótulo ("+1" / "−1"); o
  # decremento não é ação destrutiva confirmada e não leva `danger` (§11.6).
  test "os botões de posse não se distinguem por cor nem usam danger" do
    modifiers = %w[ownership__button--increment ownership__button--decrement]

    assert_empty self.class.chromatic_modifier_rules(Stylesheet.rules, modifiers)
    danger = Stylesheet.rules.select { |selector, body| selector.include?("ownership__button") && body.include?("var(--danger)") }
    assert_empty danger.map(&:first)
  end

  # O texto "Atendido" / "Faltam N" é o sinal (wishlist_items_test.rb:210, :235);
  # os modificadores reforçam por forma, nunca por cor.
  test "os estados da wishlist não se distinguem por cor" do
    modifiers = %w[wishlist-item__status--pending wishlist-item__status--fulfilled]

    assert_empty self.class.chromatic_modifier_rules(Stylesheet.rules, modifiers)
  end

  test "a guarda de modificador acusa distinção por cor" do
    css = ".x__status--pending { color: var(--ink-muted); } .x__status--pending-y { color: var(--ink); } .x__status--done { border-width: 2px; }"

    assert_equal [ ".x__status--pending" ],
                 self.class.chromatic_modifier_rules(Stylesheet.rules(css), %w[x__status--pending x__status--done])
  end
end
