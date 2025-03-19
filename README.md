# GraphQL response fixtures

Testing GraphQL queries using fixture responses runs the risk of false-positive outcomes when a query changes without its response fixture getting updated accordingly. This gem provides a simple utility for loading JSON response fixtures and validating them against the shape of the query to assure they match.

```shell
gem "graphql-response_fixture"
```

## Usage

Build a test query and its response data into a `GraphQL::ResponseFixture`, then assert that the fixture is correct for the query as part of your test:

```ruby
def test_my_stuff
  query = %|{ widget { id title } }|
  result = { 
    "widget" => { 
      "id" => "1", 
      "name" => "My widget", # << incorrect, the query requests `title`
    },
  }
  
  request = GraphQL::Query.new(MySchema, query: query)
  response = GraphQL::ResponseFixture.new(request, result)

  assert response.valid?, response.error_message
  # Results in: "Expected data to provide field `widget.title`"
end
```
