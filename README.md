# GraphQL response validator

Testing GraphQL queries using fixture responses runs the risk of false-positive tests when a query changes without its static response getting updated. This gem provides a simple utility for validating response fixtures against the shape of a query to assure that they match.

```shell
gem "graphql-response_validator"
```

## Usage

Build a test query and its response data into a `GraphQL::ResponseValidator`, then assert that the fixture is correct for the query as part of your test:

```ruby
def test_my_stuff
  request = %|{ widget { id title } }|
  response = {
    "data" => {
      "widget" => { 
        "id" => "1", 
        "name" => "My widget", # << wrong, should be `title`
      },
    },
  }
  
  # check that the query is valid...
  query = GraphQL::Query.new(MySchema, query: request)
  assert query.static_errors.none?, query.static_errors.map(&:message).join("\n")

  # check that the response is valid...
  fixture = GraphQL::ResponseValidator.new(query, response)
  assert fixture.valid?, fixture.errors.map(&:message).join("\n")
  # Results in: "Expected data to provide field `widget.title`"
end
```

### Abstract selections

Abstract selections must include a type identity so that the validator knows what selection path(s) to follow. This can be done by including a `__typename` in abstract selection scopes:

```ruby
def test_my_stuff
  request = %|{ 
    node(id: 1) { 
      ... on Product { title }
      ... on Order { totalCost }
      __typename 
    }
  }|
  response = {
    "data" => {
      "node" => { 
        "title" => "Ethereal wishing well", 
        "__typename" => "Product",
      },
    },
  }
  
  query = GraphQL::Query.new(MySchema, query: request)
  fixture = GraphQL::ResponseValidator.new(query, response)

  assert fixture.valid?, fixture.errors.first&.message
end
```

Alternatively, you can use a system `__typename__` hint that exists only in response data, and this can be pruned from the response data after validating it:

```ruby
def test_my_stuff
  request = %|{ 
    node(id: 1) { 
      ... on Product { title }
      ... on Order { totalCost }
    }
  }|
  response = {
    "data" => {
      "node" => { 
        "totalCost" => 23, 
        "__typename__" => "Order",
      },
    },
  }
  
  query = GraphQL::Query.new(MySchema, query: request)
  fixture = GraphQL::ResponseValidator.new(query, response)

  assert fixture.valid?, fixture.errors.first&.message

  expected_result = { "data" => { "node" => { "totalCost" => 23 } } }
  assert_equal expected_result, fixture.prune!.to_h
end
```
