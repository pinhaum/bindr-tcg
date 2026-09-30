ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # SRC-16 (fonte-apitcg): o catálogo só mostra variante vista pelo último
    # run `succeeded` da ingestão. Os testes que montam o catálogo à mão
    # chamam isto para pôr sob um run `succeeded` toda variante que nenhum run
    # viu ainda. Variante com `last_seen_at` explícito não é tocada.
    CATALOG_SEEN_AT = Time.utc(2026, 1, 1)

    def mark_catalog_present!
      ImportRun.find_or_create_by!(source: "teste", source_revision: "teste", status: "succeeded",
                                   started_at: CATALOG_SEEN_AT)
      CardVariant.where(last_seen_at: nil).update_all(last_seen_at: CATALOG_SEEN_AT)
    end
  end
end
