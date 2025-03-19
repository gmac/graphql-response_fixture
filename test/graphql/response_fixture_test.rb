# frozen_string_literal: true

require "test_helper"

describe "GraphQL::ResponseFixture" do
  def test_invalid_for_missing_fields
    query = %|{ widget { id } }|

    assert_invalid(query, { "widget" => {} }) do |error|
      assert_equal "Expected data to provide field `widget.id`", error
    end
  end

  def test_invalid_for_composites_without_hash
    query = %|{ widget { id } }|

    assert_invalid(query, { "widget" => "nope" }) do |error|
      assert_equal "Expected composite selection `widget` to provide Hash", error
    end
  end

  def test_invalid_for_bad_selections
    query = %|{ widget { nope } }|

    assert_invalid(query, { "widget" => { "nope" => true } }) do |error|
      assert_equal "Invalid selection for `Widget.nope`", error
    end
  end

  def test_nullable_fields_returning_value
    query = %|{ widget { id } }|

    assert_valid(query, { "widget" => { "id" => "1" } })
  end

  def test_nullable_fields_returning_null
    query = %|{ widget { id } }|

    assert_valid(query, { "widget" => nil })
  end

  def test_non_null_fields_returning_null
    query = %|{ thing { ... on Widget { id } } }|

    assert_invalid(query, { "thing" => nil }) do |error|
      assert_equal "Expected non-null selection `thing` to provide value", error
    end
  end

  def test_list_returning_valid_value
    query = %|{ widgets { id } }|

    assert_valid(query, { "widgets" => [{ "id" => "1" }] })
  end

  def test_list_returning_non_list_value
    query = %|{ widgets { id } }|

    assert_invalid(query, { "widgets" => {} }) do |error|
      assert_equal "Expected list selection `widgets` to provide Array", error
    end
  end

  def test_nullable_list_returning_null
    query = %|{ widgets { id } }|

    assert_valid(query, { "widgets" => nil })
  end

  def test_nullable_list_item_returning_null
    query = %|{ widgets { id } }|

    assert_valid(query, { "widgets" => [nil] })
  end

  def test_validates_id_scalar
    query = %|{ widget { id } }|

    assert_valid(query, { "widget" => { "id" => "1" } })
    assert_valid(query, { "widget" => { "id" => 1 } })
    assert_invalid(query, { "widget" => { "id" => false } }) do |error|
      assert_equal "Expected `widget.id` to provide a valid `ID` value", error
    end
  end

  def test_validates_string_scalar
    query = %|{ widget { title } }|

    assert_valid(query, { "widget" => { "title" => "okay" } })
    assert_invalid(query, { "widget" => { "title" => 23 } }) do |error|
      assert_equal "Expected `widget.title` to provide a valid `String` value", error
    end
  end

  def test_validates_int_scalar
    query = %|{ widget { weight } }|

    assert_valid(query, { "widget" => { "weight" => 23 } })
    assert_invalid(query, { "widget" => { "weight" => "nope" } }) do |error|
      assert_equal "Expected `widget.weight` to provide a valid `Int` value", error
    end
  end

  def test_validates_float_scalar
    query = %|{ widget { diameter } }|

    assert_valid(query, { "widget" => { "diameter" => 23.5 } })
    assert_invalid(query, { "widget" => { "diameter" => "nope" } }) do |error|
      assert_equal "Expected `widget.diameter` to provide a valid `Float` value", error
    end
  end

  def test_validates_boolean_scalar
    query = %|{ widget { petFriendly } }|

    assert_valid(query, { "widget" => { "petFriendly" => true } })
    assert_invalid(query, { "widget" => { "petFriendly" => "nope" } }) do |error|
      assert_equal "Expected `widget.petFriendly` to provide a valid `Boolean` value", error
    end
  end

  def test_validates_json_scalar
    query = %|{ widget { attributes } }|

    assert_valid(query, { "widget" => { "attributes" => {} } })
    assert_invalid(query, { "widget" => { "attributes" => "nope" } }) do |error|
      assert_equal "Expected `widget.attributes` to provide a valid `JSON` value", error
    end
  end

  def test_validates_enum_value
    query = %|{ widget { heat } }|

    assert_valid(query, { "widget" => { "heat" => "SPICY" } })
    assert_invalid(query, { "widget" => { "heat" => "INVALID" } }) do |error|
      assert_equal "Expected `widget.heat` to provide a valid `WidgetHeat` value", error
    end
  end

  def test_typename_with_valid_value
    query = %|{ thing { __typename } }|

    assert_valid(query, { "thing" => { "__typename" => "Widget" } })
  end

  def test_typename_with_null_value
    query = %|{ thing { __typename } }|

    assert_invalid(query, { "thing" => { "__typename" => nil } }) do |error|
      assert_equal "Expected selection `thing.__typename` to provide a possible type name of `Thing`", error
    end
  end

  def test_typename_with_bogus_value
    query = %|{ thing { __typename } }|

    assert_invalid(query, { "thing" => { "__typename" => "Elephant" } }) do |error|
      assert_equal "Expected selection `thing.__typename` to provide a possible type name of `Thing`", error
    end
  end

  private

  def build_fixture(query_string, data)
    query = GraphQL::Query.new(TestSchema, query: query_string)
    GraphQL::ResponseFixture.new(query, data)
  end

  def assert_valid(query_string, data)
    fixture = build_fixture(query_string, data)
    assert fixture.valid?, fixture.error_message
  end

  def assert_invalid(query_string, data)
    fixture = build_fixture(query_string, data)
    assert !fixture.valid?, "Expected fixture to be invalid"
    yield(fixture.error_message) if block_given?
  end
end