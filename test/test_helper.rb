# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "bundler/setup"
Bundler.require(:default, :test)

require "minitest/pride"
require "minitest/autorun"

class TestSchema < GraphQL::Schema
  class JsonType < GraphQL::Schema::Scalar
    graphql_name("JSON")
  end

  class WidgetHeat < GraphQL::Schema::Enum
    value("SPICY")
    value("MILD")
  end

  class Widget < GraphQL::Schema::Object
    field :id, ID, null: false
    field :title, String, null: false
    field :description, String, null: true
    field :weight, Int, null: true
    field :diameter, Float, null: true
    field :pet_friendly, Boolean, null: true
    field :attributes, JsonType, null: true
    field :heat, WidgetHeat, null: false
  end

  class Sprocket < GraphQL::Schema::Object
    field :id, ID, null: false
    field :length, Int, null: false
    field :width, Int, null: false
  end

  class Thing < GraphQL::Schema::Union
    possible_types(Widget, Sprocket)
  end

  class Query < GraphQL::Schema::Object
    field :widget, Widget, null: true
    field :widgets, [Widget, null: true], null: true

    field :thing, Thing, null: false
    field :things, [Thing, null: false], null: false
  end

  query(Query)
end