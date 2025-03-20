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

  module Gadget
    include GraphQL::Schema::Interface
    field :id, ID, null: false
  end

  class WidgetHeat < GraphQL::Schema::Enum
    value("SPICY")
    value("MILD")
  end

  class Widget < GraphQL::Schema::Object
    implements(Gadget)
    field :title, String, null: false
    field :description, String, null: true
    field :weight, Int, null: true
    field :diameter, Float, null: true
    field :pet_friendly, Boolean, null: true
    field :attributes, JsonType, null: true
    field :heat, WidgetHeat, null: false
  end

  class Sprocket < GraphQL::Schema::Object
    implements(Gadget)
    field :length, Int, null: false
    field :width, Int, null: false
  end

  class RedHerring < GraphQL::Schema::Object
    field :id, ID, null: false
  end

  class Gizmo < GraphQL::Schema::Union
    possible_types(Widget, Sprocket)
  end

  class Query < GraphQL::Schema::Object
    field :widget, Widget, null: true
    field :widgets, [Widget, null: true], null: true

    field :gadget, Gadget, null: false
    field :gadgets, [Gadget, null: false], null: false

    field :gizmo, Gizmo, null: false
    field :gizmos, [Gizmo, null: false], null: false

    field :red_herring, RedHerring, null: false
  end

  query(Query)
end