# frozen_string_literal: true

module GraphQL
  class ResponseFixture
    class Repository
      def initialize(base_path: "./", scalar_validators: {}, system_typename: SYSTEM_TYPENAME)
        @base_path = base_path
        @scalar_validators = SCALAR_VALIDATORS.merge(scalar_validators)
        @system_typename = system_typename
      end

      def fetch(fixture_name, query)
        data = File.read(fixture_file_path(fixture_name))
        fixture = ResponseFixture.new(
        query,
        data,
        scalar_validators: @scalar_validators,
        system_typename: @system_typename,
        )
        fixture.valid?
        fixture.prune!
      end

      def write(fixture_name, data)
        File.write(fixture_file_path(fixture_name), JSON.generate(data))
      end

      def fixture_file_path(fixture_name)
        "#{@base_path}/#{fixture_name}.json"
      end
    end
  end
end
