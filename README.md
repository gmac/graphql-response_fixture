# GraphQL response validator

Testing GraphQL queries using fixture responses runs the risk of false-positive outcomes when a test query changes without its static response getting updated accordingly. This gem provides a simple utility for validating response fixtures against the shape of a query to assure that they match.

```shell
gem "graphql-response_validator"
```

## Usage

Build a test query and its response data into a `GraphQL::ResponseValidator`, then assert that the fixture is correct for the query as part of your test:

```ruby
def test_my_stuff
  query = %|{ widget { id title } }|
  result = {
    "data" => {
      "widget" => { 
        "id" => "1", 
        "name" => "My widget", # << incorrect, the query requests `title`
      },
    },
  }
  
  request = GraphQL::Query.new(MySchema, query: query)
  response = GraphQL::ResponseValidator.new(request, result)

  assert response.valid?, response.errors.first&.message
  # Results in: "Expected data to provide field `widget.title`"
end
```

### Abstract selections

Response data must include a type identity at abstract selections points so that the validator knows what selection paths to follow. This is done by including a `__typename` selection in abstract positions:

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

Alternatively, you can use a system `__typename__` hint that exists only in response data, and can be pruned from the response after validating it:

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

  expected_node = { "totalCost" => 23 }
  assert_equal expected_node, fixture.prune!.to_h
end
```
