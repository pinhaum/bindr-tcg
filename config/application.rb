require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Bindr
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # O schema do catálogo usa recursos que o formato Ruby não sabe
    # representar: a função `immutable_unaccent` (exigida pelo índice trigram
    # do Req. 3.2 — `unaccent` é STABLE e não pode entrar em índice) e os
    # índices de expressão com `gin_trgm_ops` e `to_tsvector`. Com
    # `schema_format = :ruby`, carregar `db/schema.rb` em um banco novo falha
    # ao recriar esses índices. `structure.sql` é gerado por `pg_dump` e
    # preserva tudo.
    config.active_record.schema_format = :sql

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
