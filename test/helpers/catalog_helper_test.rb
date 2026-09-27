require "test_helper"

class CatalogHelperTest < ActionView::TestCase
  test "filter_toggle_url adds a value to an empty filter" do
    active = {}
    url = filter_toggle_url(active, :colors, "Red")
    assert_includes url, "colors%5B%5D=Red"
  end

  test "filter_toggle_url adds a value to an existing array filter" do
    active = { colors: [ "Red" ] }
    url = filter_toggle_url(active, :colors, "Green")
    assert_includes url, "colors%5B%5D=Red"
    assert_includes url, "colors%5B%5D=Green"
  end

  test "filter_toggle_url removes a value from an array filter" do
    active = { colors: [ "Red", "Green" ] }
    url = filter_toggle_url(active, :colors, "Red")
    assert_includes url, "colors%5B%5D=Green"
    assert_not_includes url, "Red"
  end

  test "filter_toggle_url removes the key when array becomes empty" do
    active = { colors: [ "Red" ] }
    url = filter_toggle_url(active, :colors, "Red")
    assert_not_includes url, "colors"
  end

  test "filter_toggle_url preserves other filters" do
    active = { colors: [ "Red" ], q: "test", sort: "name" }
    url = filter_toggle_url(active, :colors, "Green")
    assert_includes url, "q=test"
    assert_includes url, "sort=name"
  end

  test "filter_toggle_url never includes page parameter" do
    active = { colors: [ "Red" ], page: 3 }
    url = filter_toggle_url(active, :colors, "Green")
    assert_not_includes url, "page"
  end

  test "filter_toggle_url handles owned as scalar: setting a value" do
    active = {}
    url = filter_toggle_url(active, :owned, "owned")
    assert_includes url, "owned=owned"
  end

  test "filter_toggle_url handles owned as scalar: toggling off" do
    active = { owned: "owned" }
    url = filter_toggle_url(active, :owned, "owned")
    assert_not_includes url, "owned"
  end

  test "filter_toggle_url handles owned as scalar: switching value" do
    active = { owned: "owned" }
    url = filter_toggle_url(active, :owned, "missing")
    assert_includes url, "owned=missing"
    assert_not_includes url, "owned=owned"
  end

  test "filter_toggle_url handles owned all: removes the key" do
    active = { owned: "owned" }
    url = filter_toggle_url(active, :owned, "all")
    assert_not_includes url, "owned"
  end

  test "filter_toggle_url preserves range filters and traits" do
    active = { colors: [ "Red" ], cost_min: 2, traits: [ "Straw Hat Crew" ] }
    url = filter_toggle_url(active, :colors, "Green")
    assert_includes url, "cost_min=2"
    assert_includes url, "traits%5B%5D=Straw"
  end

  test "filter_toggle_url adds any value passed, even if later ignored by query" do
    active = { colors: [ "Red" ] }
    url = filter_toggle_url(active, :colors, "InvalidColor")
    assert_includes url, "colors%5B%5D=Red"
    assert_includes url, "colors%5B%5D=InvalidColor"
  end

  test "filter_toggle_url normalizes string key to symbol" do
    active = { colors: [ "Red" ] }
    url = filter_toggle_url(active, "colors", "Red")
    assert_not_includes url, "colors"
  end

  test "filter_toggle_url normalizes string key for owned scalar" do
    active = { owned: "owned" }
    url = filter_toggle_url(active, "owned", "owned")
    assert_not_includes url, "owned"
  end

  test "filter_toggle_url aceita o hash de filtros com chaves string" do
    assert_equal catalog_path, filter_toggle_url({ "colors" => [ "Red" ] }, "colors", "Red")
    assert_equal catalog_path, filter_toggle_url({ "owned" => "owned" }, :owned, "owned")
    assert_includes filter_toggle_url({ "colors" => [ "Red" ] }, :colors, "Green"), "colors%5B%5D=Red&colors%5B%5D=Green"
  end
end
