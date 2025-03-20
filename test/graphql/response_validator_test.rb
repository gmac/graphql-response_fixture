# frozen_string_literal: true

require "test_helper"

describe "GraphQL::ResponseValidator" do
  def test_invalid_for_missing_fields
    query = %|{ widget { id } }|

    assert_invalid(query, { "widget" => {} }) do |error|
      assert_equal "Expected data to provide field at `widget.id`", error
    end
  end

  def test_invalid_for_composites_without_hash
    query = %|{ widget { id } }|

    assert_invalid(query, { "widget" => "nope" }) do |error|
      assert_equal "Expected composite selection to provide Hash at `widget`", error
    end
  end

  def test_invalid_for_bad_selections
    query = %|{ widget { nope } }|

    assert_invalid(query, { "widget" => { "nope" => true } }) do |error|
      assert_equal "Invalid selection of `Widget.nope` at `widget.nope`", error
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
    query = %|{ gizmo { ... on Widget { id } } }|

    assert_invalid(query, { "gizmo" => nil }) do |error|
      assert_equal "Expected non-null selection to provide value at `gizmo`", error
    end
  end

  def test_list_returning_valid_value
    query = %|{ widgets { id } }|

    assert_valid(query, { "widgets" => [{ "id" => "1" }] })
  end

  def test_list_returning_non_list_value
    query = %|{ widgets { id } }|

    assert_invalid(query, { "widgets" => {} }) do |error|
      assert_equal "Expected list selection to provide Array at `widgets`", error
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
      assert_equal "Expected a valid `ID` value at `widget.id`", error
    end
  end

  def test_validates_string_scalar
    query = %|{ widget { title } }|

    assert_valid(query, { "widget" => { "title" => "okay" } })
    assert_invalid(query, { "widget" => { "title" => 23 } }) do |error|
      assert_equal "Expected a valid `String` value at `widget.title`", error
    end
  end

  def test_validates_int_scalar
    query = %|{ widget { weight } }|

    assert_valid(query, { "widget" => { "weight" => 23 } })
    assert_invalid(query, { "widget" => { "weight" => "nope" } }) do |error|
      assert_equal "Expected a valid `Int` value at `widget.weight`", error
    end
  end

  def test_validates_float_scalar
    query = %|{ widget { diameter } }|

    assert_valid(query, { "widget" => { "diameter" => 23.5 } })
    assert_invalid(query, { "widget" => { "diameter" => "nope" } }) do |error|
      assert_equal "Expected a valid `Float` value at `widget.diameter`", error
    end
  end

  def test_validates_boolean_scalar
    query = %|{ widget { petFriendly } }|

    assert_valid(query, { "widget" => { "petFriendly" => true } })
    assert_invalid(query, { "widget" => { "petFriendly" => "nope" } }) do |error|
      assert_equal "Expected a valid `Boolean` value at `widget.petFriendly`", error
    end
  end

  def test_validates_json_scalar
    query = %|{ widget { attributes } }|

    assert_valid(query, { "widget" => { "attributes" => {} } })
    assert_invalid(query, { "widget" => { "attributes" => "nope" } }) do |error|
      assert_equal "Expected a valid `JSON` value at `widget.attributes`", error
    end
  end

  def test_validates_enum_value
    query = %|{ widget { heat } }|

    assert_valid(query, { "widget" => { "heat" => "SPICY" } })
    assert_invalid(query, { "widget" => { "heat" => "INVALID" } }) do |error|
      assert_equal "Expected a valid `WidgetHeat` value at `widget.heat`", error
    end
  end

  def test_typename_with_valid_value
    query = %|{ gizmo { __typename } }|

    assert_valid(query, { "gizmo" => { "__typename" => "Widget" } })
  end

  def test_typename_with_null_value
    query = %|{ gizmo { __typename } }|

    assert_invalid(query, { "gizmo" => { "__typename" => nil } }) do |error|
      assert_equal "Expected selection to provide a possible type name of `Gizmo` at `gizmo.__typename`", error
    end
  end

  def test_typename_with_bogus_value
    query = %|{ gizmo { __typename } }|

    assert_invalid(query, { "gizmo" => { "__typename" => "Elephant" } }) do |error|
      assert_equal "Expected selection to provide a possible type name of `Gizmo` at `gizmo.__typename`", error
    end
  end

  def test_direct_interface_selections
    query = %|{ gadget { id } }|

    assert_valid(query, { "gadget" => { "id" => "1" } })
  end

  def test_abstract_fragment_requires_typename_hint
    query = %|{ gizmo { ... on Widget { id } } }|

    assert_invalid(query, { "gizmo" => { "id" => "1" } }) do |error|
      assert_equal "Abstract position expects `__typename` or system typename hint at `gizmo`", error
    end
  end

  def test_abstract_fragment_with_undefined_typename
    query = %|{ gizmo { ... on Widget { id } } }|

    assert_invalid(query, { "gizmo" => { "id" => "1", "__typename" => "Elephant" } }) do |error|
      assert_equal "Abstract typename `Elephant` is not a valid type at `gizmo`", error
    end
  end

  def test_abstract_fragment_with_non_member_typename
    query = %|{ gizmo { ... on Widget { id } } }|

    assert_invalid(query, { "gizmo" => { "id" => "1", "__typename" => "RedHerring" } }) do |error|
      assert_equal "Abstract type `Gizmo` cannot be `RedHerring` at `gizmo`", error
    end
  end

  def test_abstract_fragment_valid_with_typename_hint
    query = %|{ gizmo { ... on Widget { id } __typename } }|

    assert_valid(query, { "gizmo" => { "id" => "1", "__typename" => "Widget" } })
  end

  def test_abstract_fragment_valid_with_system_typename_hint
    query = %|{ gizmo { ... on Widget { id } } }|

    assert_valid(query, { "gizmo" => { "id" => "1", "__typename__" => "Widget" } })
  end

  def test_prunes_system_typename_hints
    query = %|{ gizmo { ... on Widget { id } } }|
    fixture = build_fixture(query, { "gizmo" => { "id" => "1", "__typename__" => "Widget" } })

    expected = { "data" => { "gizmo" => { "id" => "1" } } }
    assert_equal expected, fixture.prune!.to_h
  end

  def test_inline_fragment_selections_use_type_awareness
    query = %|{ 
      gizmo {
        ... on Gadget { id } 
        ... on Widget { diameter } 
        ... on Sprocket { width } 
      }
    }|
    
    assert_valid(query, { "gizmo" => { "id" => "1", "diameter" => 23, "__typename__" => "Widget" } })
    assert_valid(query, { "gizmo" => { "id" => "1", "width" => 23, "__typename__" => "Sprocket" } })

    assert_invalid(query, { "gizmo" => { "id" => "1", "__typename__" => "Widget" } }) do |error|
      assert_equal "Expected data to provide field at `gizmo.diameter`", error
    end
    assert_invalid(query, { "gizmo" => { "diameter" => 23, "__typename__" => "Widget" } }) do |error|
      assert_equal "Expected data to provide field at `gizmo.id`", error
    end
    assert_invalid(query, { "gizmo" => { "id" => "1", "__typename__" => "Sprocket" } }) do |error|
      assert_equal "Expected data to provide field at `gizmo.width`", error
    end
  end

  def test_fragment_spreads_use_type_awareness
    query = %|{ 
      gizmo {
        ... GadgetAttrs
        ... WidgetAttrs
        ... SprocketAttrs
      }
    }
    fragment GadgetAttrs on Gadget { id }
    fragment WidgetAttrs on Widget { diameter }
    fragment SprocketAttrs on Sprocket { width }
    |
    
    assert_valid(query, { "gizmo" => { "id" => "1", "diameter" => 23, "__typename__" => "Widget" } })
    assert_valid(query, { "gizmo" => { "id" => "1", "width" => 23, "__typename__" => "Sprocket" } })

    assert_invalid(query, { "gizmo" => { "id" => "1", "__typename__" => "Widget" } }) do |error|
      assert_equal "Expected data to provide field at `gizmo.diameter`", error
    end
    assert_invalid(query, { "gizmo" => { "diameter" => 23, "__typename__" => "Widget" } }) do |error|
      assert_equal "Expected data to provide field at `gizmo.id`", error
    end
    assert_invalid(query, { "gizmo" => { "id" => "1", "__typename__" => "Sprocket" } }) do |error|
      assert_equal "Expected data to provide field at `gizmo.width`", error
    end
  end

  private

  def build_fixture(query_string, data)
    query = GraphQL::Query.new(TestSchema, query: query_string)
    GraphQL::ResponseValidator.new(query, { "data" => data })
  end

  def assert_valid(query_string, data)
    fixture = build_fixture(query_string, data)
    assert fixture.valid?, format_error_message(fixture.errors.first)
  end

  def assert_invalid(query_string, data)
    fixture = build_fixture(query_string, data)
    assert !fixture.valid?, "Expected fixture to be invalid"
    yield(format_error_message(fixture.errors.first)) if block_given?
  end

  def format_error_message(error)
    return nil if error.nil?

    "#{error.message} at `#{error.path.join(".")}`"
  end
end