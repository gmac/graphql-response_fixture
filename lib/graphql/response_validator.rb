# frozen_string_literal: true

require "graphql"

module GraphQL
  class ResponseValidator
    ValidationError = Struct.new(:message, :path)

    SYSTEM_TYPENAME = "__typename__"
    SCALAR_VALIDATORS = {
      "Boolean" => -> (data) { data.is_a?(TrueClass) || data.is_a?(FalseClass) },
      "Float" => -> (data) { data.is_a?(Numeric) },
      "ID" => -> (data) { data.is_a?(String) || data.is_a?(Integer) },
      "Int" => -> (data) { data.is_a?(Integer) },
      "JSON" => -> (data) { data.is_a?(Hash) },
      "String" => -> (data) { data.is_a?(String) },
    }.freeze
  
    attr_reader :errors
  
    def initialize(
      query,
      data,
      scalar_validators: SCALAR_VALIDATORS,
      system_typename: SYSTEM_TYPENAME
    )
      @query = query
      @data = data
      @errors = []
      @valid = nil
      @scalar_validators = scalar_validators
      @system_typename = system_typename
      @system_typenames = Set.new
    end
  
    def valid?
      return @valid unless @valid.nil?
    
      op = @query.selected_operation
      parent_type = @query.root_type_for_operation(op.operation_type)
      validate_selections(parent_type, op, @data["data"])
      @valid = @errors.none?
    end
  
    def prune!
      valid?
      @system_typenames.each { _1.delete(@system_typename) }
      self
    end
  
    def to_h
      @data
    end
  
    private
  
    def validate_selections(parent_type, parent_node, data_part, path = [])
      if parent_type.non_null?
        if !data_part.nil?
          return validate_selections(parent_type.of_type, parent_node, data_part, path)
        else
          @errors << ValidationError.new("Expected non-null selection to provide value", path.dup)
          return false
        end
    
      elsif data_part.nil?
        # nullable node with a null value is okay
        return true
    
      elsif parent_type.list?
        if data_part.is_a?(Array)
          return data_part.all? { |item| validate_selections(parent_type.of_type, parent_node, item, path) }
        else
          @errors << ValidationError.new("Expected list selection to provide Array", path.dup)
          return false
        end
        
      elsif parent_type.kind.leaf?
        return validate_leaf(parent_type, data_part, path)
    
      elsif !data_part.is_a?(Hash)
        @errors << ValidationError.new("Expected composite selection to provide Hash", path.dup)
        return false
      end
    
      parent_node.selections.all? do |node|
        case node
        when GraphQL::Language::Nodes::Field
          begin
            path << (node.alias || node.name)
            unless data_part.key?(path.last)
              @errors << ValidationError.new("Expected data to provide field", path.dup)
              next false
            end
            
            next_value = data_part[path.last]
            next_type = if node.name == "__typename"
              annotation_type = @query.get_type(data_part[path.last])
              unless annotation_type && @query.possible_types(parent_type).include?(annotation_type)
                @errors << ValidationError.new("Expected selection to provide a possible type name of `#{parent_type.graphql_name}`", path.dup)
                next false
              end

              @query.get_type("String")
            else
              @query.get_field(parent_type, node.name)&.type
            end

            unless next_type
              @errors << ValidationError.new("Invalid selection of `#{parent_type.graphql_name}.#{node.name}`", path.dup)
              next false
            end

            validate_selections(next_type, node, next_value, path)
          ensure
            path.pop
          end
      
        when GraphQL::Language::Nodes::InlineFragment
          resolved_type = resolved_type(parent_type, data_part, path)
          next false if resolved_type.nil?

          fragment_type = node.type.nil? ? parent_type : @query.get_type(node.type.name)
          next true unless @query.possible_types(fragment_type).include?(resolved_type)
      
          validate_selections(fragment_type, node, data_part, path)
      
        when GraphQL::Language::Nodes::FragmentSpread
          resolved_type = resolved_type(parent_type, data_part, path)
          next false if resolved_type.nil?

          fragment_def = @query.fragments[node.name]
          fragment_type = @query.get_type(fragment_def.type.name)
          next true unless @query.possible_types(fragment_type).include?(resolved_type)
      
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
    
      @errors << ValidationError.new("Expected a valid `#{parent_type.graphql_name}` value", path.dup) unless valid
      valid
    end
  
    def resolved_type(parent_type, data_part, path)
      return parent_type unless parent_type.kind.abstract?
    
      typename = data_part[@system_typename] || data_part["__typename"]
      if typename.nil?
        @errors << ValidationError.new("Abstract position expects `__typename` or system typename hint", path.dup)
        return nil
      end
    
      @system_typenames.add(data_part) if data_part.key?(@system_typename)
      annotated_type = @query.get_type(typename)

      if annotated_type.nil?
        @errors << ValidationError.new("Abstract typename `#{typename}` is not a valid type", path.dup)
        nil
      elsif !@query.possible_types(parent_type).include?(annotated_type)
        @errors << ValidationError.new("Abstract type `#{parent_type.graphql_name}` cannot be `#{typename}`", path.dup)
        nil
      else
        annotated_type
      end
    end
  end
end

require_relative "./response_validator/version"