# frozen_string_literal: true

require "graphql"

module GraphQL
  class ResponseFixture
    SYSTEM_TYPENAME = "__typename__"
    SCALAR_VALIDATORS = {
      "Boolean" => -> (data) { data.is_a?(TrueClass) || data.is_a?(FalseClass) },
      "Float" => -> (data) { data.is_a?(Numeric) },
      "ID" => -> (data) { data.is_a?(String) || data.is_a?(Integer) },
      "Int" => -> (data) { data.is_a?(Integer) },
      "JSON" => -> (data) { data.is_a?(Hash) },
      "String" => -> (data) { data.is_a?(String) },
    }.freeze
  
    class ResponseFixtureError < StandardError; end
  
    attr_reader :error_message
  
    def initialize(
      query,
      data,
      scalar_validators: SCALAR_VALIDATORS,
      system_typename: SYSTEM_TYPENAME
    )
      @query = query
      @data = data
      @valid = nil
      @error_message = nil
      @scalar_validators = scalar_validators
      @system_typename = system_typename
      @system_typenames = Set.new
    end
  
    def valid?
      return @valid unless @valid.nil?
    
      op = @query.selected_operation
      parent_type = @query.root_type_for_operation(op.operation_type)
      validate_selections(parent_type, op, @data)
      @valid = true
    rescue ResponseFixtureError => e
      @error_message = e.message
      @valid = false
    end
  
    def prune!
      @system_typenames.each { _1.delete(@system_typename) }
      self
    end
  
    def to_h
      @data
    end
  
    private
  
    def validate_selections(parent_type, parent_node, data_part, path = [])
      if parent_type.non_null?
        raise ResponseFixtureError, "Expected non-null selection `#{path.join(".")}` to provide value" if data_part.nil?
        return validate_selections(parent_type.of_type, parent_node, data_part, path)
    
      elsif data_part.nil?
        # nullable node with a null value is okay
        return true
    
      elsif parent_type.list?
        raise ResponseFixtureError, "Expected list selection `#{path.join(".")}` to provide Array" unless data_part.is_a?(Array)
        return data_part.all? { |item| validate_selections(parent_type.of_type, parent_node, item, path) }
        
      elsif parent_type.kind.leaf?
        return validate_leaf(parent_type, data_part, path)
    
      elsif !data_part.is_a?(Hash)
        raise ResponseFixtureError, "Expected composite selection `#{path.join(".")}` to provide Hash"
      end
    
      parent_node.selections.all? do |node|
        case node
        when GraphQL::Language::Nodes::Field
          field_name = node.alias || node.name
          path << field_name
          raise ResponseFixtureError, "Expected data to provide field `#{path.join(".")}`" unless data_part.key?(path.last)
          
          next_value = data_part[path.last]
          next_type = if node.name == "__typename"
            annotation_type = @query.get_type(data_part[field_name])
            unless annotation_type && @query.possible_types(parent_type).include?(annotation_type)
              raise ResponseFixtureError, "Expected selection `#{path.join(".")}` to provide a possible type name of `#{parent_type.graphql_name}`"
            end

            @query.get_type("String")
          else
            @query.get_field(parent_type, node.name)&.type
          end
          raise ResponseFixtureError, "Invalid selection for `#{parent_type.graphql_name}.#{node.name}`" unless next_type

          result = validate_selections(next_type, node, next_value, path)
          path.pop
          result
      
        when GraphQL::Language::Nodes::InlineFragment
          resolved_type = resolved_type(parent_type, data_part, path)
          fragment_type = node.type.nil? ? parent_type : @query.get_type(node.type.name)
          return true unless @query.possible_types(fragment_type).include?(resolved_type)
      
          validate_selections(fragment_type, node, data_part, path)
      
        when GraphQL::Language::Nodes::FragmentSpread
          resolved_type = resolved_type(parent_type, data_part, path)
          fragment_def = @query.fragments[node.name]
          fragment_type = @query.get_type(fragment_def.type.name)
          return true unless @query.possible_types(fragment_type).include?(resolved_type)
      
          validate_selections(fragment_type, fragment_def, data_part, path)
        end
      end
    end
  
    def validate_leaf(parent_type, value, path)
      valid = if parent_type.kind.enum?
        parent_type.values.key?(value)
      elsif parent_type.kind.scalar?
        validator = @scalar_validators[parent_type.graphql_name]
        validator.nil? || validator.call(value)
      end
    
      unless valid
        raise ResponseFixtureError, "Expected `#{path.join(".")}` to provide a valid `#{parent_type.graphql_name}` value"
      end
      true
    end
  
    def resolved_type(parent_type, data_part, path)
      return parent_type unless parent_type.kind.abstract?
    
      typename = data_part["__typename"] || data_part[@system_typename]
      if typename.nil?
        raise ResponseFixtureError, "Abstract position at `#{path.join(".")}` expects `__typename` or system typename hint"
      end
    
      @system_typenames.add(data_part) if data_part.key?(@system_typename)
      annotated_type = @query.get_type(typename)

      if annotated_type.nil?
        raise ResponseFixtureError, "Abstract typename `#{typename}` is not a valid type"
      elsif !@query.possible_types(parent_type).include?(annotated_type)
        raise ResponseFixtureError, "Abstract type `#{typename}` does not belong to `#{parent_type.graphql_name}`"
      else
        annotated_type
      end
    end
  end
end

require_relative "./response_fixture/repository"
require_relative "./response_fixture/version"