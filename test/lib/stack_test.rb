require "test_helper"

# A T1 não tem comportamento de domínio para testar — o que ela precisa provar é
# que a stack decidida em AD-002 está de fato ativa, e não apenas declarada no
# Gemfile. PostgreSQL não é preferência aqui: `pg_trgm`, `unaccent` e GIN sobre
# arrays sustentam os Req. 3 e 4 inteiros. Se este teste falhar, toda a Fase 2
# está construída sobre um banco que não suporta o design.
class StackTest < ActiveSupport::TestCase
  test "a aplicação está conectada a um PostgreSQL" do
    assert_equal "PostgreSQL", ActiveRecord::Base.connection.adapter_name
  end

  test "o PostgreSQL responde a uma consulta" do
    assert_equal 1, ActiveRecord::Base.connection.select_value("SELECT 1")
  end

  test "o banco de teste é distinto do banco de desenvolvimento" do
    test_db = ActiveRecord::Base.connection_db_config.database
    development_db = ActiveRecord::Base
      .configurations
      .configs_for(env_name: "development", name: "primary")
      .database

    refute_equal development_db, test_db
  end
end
