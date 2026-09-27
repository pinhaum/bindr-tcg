require "test_helper"

class CatalogLayoutStructureTest < ActionDispatch::IntegrationTest
  test "catalog main contains three groups in order: head, filters (in details), body" do
    get catalog_path
    assert_select "main.catalog" do
      assert_select "> div.catalog__head:nth-child(1)" do
        assert_select "h1.catalog__title", text: "Catálogo"
        assert_select "form.catalog__search"
      end
      assert_select "> details.catalog__filters-toggle:nth-child(2) > div.catalog__filters" do
        assert_select ".catalog__filter-group", minimum: 1
      end
      assert_select "> div.catalog__body:nth-child(3)" do
        assert_select "ul.catalog__grid, section.catalog__empty"
      end
    end
  end

  test "head contains title and search form" do
    get catalog_path
    assert_select ".catalog__head" do
      assert_select "h1.catalog__title"
      assert_select "form.catalog__search"
    end
  end

  test "filters contains filter groups with titles" do
    get catalog_path
    assert_select ".catalog__filters" do
      assert_select ".catalog__filter-group", minimum: 1
      assert_select ".catalog__filter-title", minimum: 1
    end
  end

  test "body contains grid or empty section" do
    get catalog_path
    assert_select ".catalog__body" do
      assert_select "ul.catalog__grid, section.catalog__empty"
    end
  end
end
