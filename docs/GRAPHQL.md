# GraphQL queries with the Swift SDK

Use `pb.graphql.query()` to call `/api/graphql` with your current auth token. It returns `GraphQLResponse` containing `data`, `errors`, and `extensions`.

> Authentication: the GraphQL endpoint is **superuser-only**. Authenticate as a superuser before calling GraphQL, e.g. `try await pb.collection("_superusers").authWithPassword(identity: email, password: password)`.

## Single-table query

```swift
let query = """
  query ActiveUsers($limit: Int!) {
    records(collection: "users", perPage: $limit, filter: "status = true") {
      items { id data }
    }
  }
"""

let response = try await pb.graphql.query(query, variables: ["limit": AnyCodable(5)])
print(response.data?.asDictionary()?["records"] ?? "no data")
```

## Multi-table join via expands

```swift
let query = """
  query PostsWithAuthors {
    records(
      collection: "posts",
      expand: ["author", "author.profile"],
      sort: "-created"
    ) {
      items {
        id
        data  // expanded relations live under data.expand
      }
    }
  }
"""

let response = try await pb.graphql.query(query)
```

## Conditional query with variables

```swift
let query = """
  query FilteredOrders($minTotal: Float!, $state: String!) {
    records(
      collection: "orders",
      filter: "total >= $minTotal && status = $state",
      sort: "created"
    ) {
      items { id data }
    }
  }
"""

let variables: [String: AnyCodable] = [
  "minTotal": AnyCodable(100),
  "state": AnyCodable("paid")
]

let result = try await pb.graphql.query(query, variables: variables)
```

Use the `filter`, `sort`, `page`, `perPage`, and `expand` arguments to mirror REST list behavior while keeping query logic in GraphQL.

## Create a record

```swift
let mutation = """
  mutation CreatePost($data: JSON!) {
    createRecord(collection: "posts", data: $data, expand: ["author"]) {
      id
      data
    }
  }
"""

let data: [String: AnyCodable] = [
  "title": AnyCodable("Hello"),
  "author": AnyCodable("USER_ID")
]

let created = try await pb.graphql.query(mutation, variables: ["data": AnyCodable(data)])
```

## Update a record

```swift
let mutation = """
  mutation UpdatePost($id: ID!, $data: JSON!) {
    updateRecord(collection: "posts", id: $id, data: $data) {
      id
      data
    }
  }
"""

try await pb.graphql.query(
  mutation,
  variables: [
    "id": AnyCodable("POST_ID"),
    "data": AnyCodable(["title": AnyCodable("Updated title")])
  ]
)
```

## Delete a record

```swift
let mutation = """
  mutation DeletePost($id: ID!) {
    deleteRecord(collection: "posts", id: $id)
  }
"""

try await pb.graphql.query(mutation, variables: ["id": AnyCodable("POST_ID")])
```
