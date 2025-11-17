# Collections - Swift SDK Documentation

## Overview

**Collections** represent your application data. Under the hood they are backed by plain SQLite tables that are generated automatically with the collection **name** and **fields** (columns).

A single entry of a collection is called a **record** (a single row in the SQL table).

> 📖 **Reference**: This guide mirrors the [JavaScript SDK Collections documentation](../js-sdk/docs/COLLECTIONS.md) but uses Swift syntax and examples.

## Collection Types

### Base Collection

Default collection type for storing any application data.

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://localhost:8090")

// Authenticate as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Create a base collection
let collection: JSONRecord = try await client.collections.createBase(
    "articles",
    overrides: [
        "fields": [
            [
                "name": "title",
                "type": "text",
                "required": true
            ],
            [
                "name": "description",
                "type": "text"
            ]
        ]
    ]
)
```

### View Collection

Read-only collection populated from a SQL SELECT statement.

```swift
let view: JSONRecord = try await client.collections.createView(
    "post_stats",
    viewQuery: """
        SELECT posts.id, posts.name, count(comments.id) as totalComments 
        FROM posts LEFT JOIN comments on comments.postId = posts.id 
        GROUP BY posts.id
    """
)
```

### Auth Collection

Base collection with authentication fields (email, password, etc.).

```swift
let users: JSONRecord = try await client.collections.createAuth(
    "users",
    overrides: [
        "fields": [
            [
                "name": "name",
                "type": "text",
                "required": true
            ]
        ]
    ]
)
```

## Collections API

### List Collections

```swift
// Get paginated list
let result: ListResult<JSONRecord> = try await client.collections.getList(
    page: 1,
    perPage: 50
)

// Get all collections
let all: [JSONRecord] = try await client.collections.getFullList()
```

### Get Collection

```swift
let collection: JSONRecord = try await client.collections.getOne("articles")
```

### Create Collection

```swift
// Using scaffolds
let base: JSONRecord = try await client.collections.createBase("articles")
let auth: JSONRecord = try await client.collections.createAuth("users")
let view: JSONRecord = try await client.collections.createView(
    "stats",
    viewQuery: "SELECT * FROM posts"
)

// Manual creation
struct CollectionPayload: Encodable {
    let type: String
    let name: String
    let fields: [[String: AnyCodable]]
}

let payload = CollectionPayload(
    type: "base",
    name: "articles",
    fields: [
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("created"),
            "type": AnyCodable("autodate"),
            "required": AnyCodable(false),
            "onCreate": AnyCodable(true),
            "onUpdate": AnyCodable(false)
        ],
        [
            "name": AnyCodable("updated"),
            "type": AnyCodable("autodate"),
            "required": AnyCodable(false),
            "onCreate": AnyCodable(true),
            "onUpdate": AnyCodable(true)
        ]
    ]
)

let collection: JSONRecord = try await client.collections.create(body: payload)
```

### Update Collection

```swift
// Update collection fields
struct UpdatePayload: Encodable {
    let fields: [[String: AnyCodable]]
}

let updatePayload = UpdatePayload(
    fields: [
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("content"),
            "type": AnyCodable("editor")
        ]
    ]
)

let updated: JSONRecord = try await client.collections.update(
    "articles",
    body: updatePayload
)
```

### Delete Collection

```swift
try await client.collections.delete("articles")
```

### Truncate Collection

Delete all records in a collection without deleting the collection itself:

```swift
try await client.collections.truncate("articles")
```

### Import Collections

Import multiple collections at once:

```swift
let collections: [[String: AnyCodable]] = [
    [
        "name": AnyCodable("posts"),
        "type": AnyCodable("base"),
        "fields": AnyCodable([
            ["name": AnyCodable("title"), "type": AnyCodable("text")]
        ])
    ],
    [
        "name": AnyCodable("comments"),
        "type": AnyCodable("base"),
        "fields": AnyCodable([
            ["name": AnyCodable("content"), "type": AnyCodable("text")]
        ])
    ]
]

let imported: [JSONRecord] = try await client.collections.import(
    collections: collections,
    deleteMissing: false
)
```

### Get Scaffolds

Get scaffolded collection models with default field values:

```swift
let scaffolds: JSONRecord = try await client.collections.getScaffolds()
// Returns: { "base": {...}, "auth": {...}, "view": {...} }
```

## Records API

### List Records

```swift
// Paginated list
let posts: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(page: 1, perPage: 30)

// With filter
let filtered: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(
        page: 1,
        perPage: 30,
        filter: client.filter("status = {:status}", params: ["status": "published"]),
        expand: "author"
    )

// Get all records (auto-paginated)
let all: [JSONRecord] = try await client
    .collection("posts")
    .getFullList()
```

### Get Single Record

```swift
// Get by ID
let post: JSONRecord = try await client
    .collection("posts")
    .getOne("RECORD_ID", expand: "author")

// Get first matching record
let first: JSONRecord = try await client
    .collection("posts")
    .getFirstListItem(
        filter: client.filter("slug = {:slug}", params: ["slug": "my-post"])
    )
```

### Create Record

```swift
// Simple create
struct PostPayload: Encodable {
    let title: String
    let content: String
    let status: String
}

let created: JSONRecord = try await client
    .collection("posts")
    .create(body: PostPayload(
        title: "Hello World",
        content: "This is my first post",
        status: "published"
    ))

// Create with relation
let postWithAuthor: JSONRecord = try await client
    .collection("posts")
    .create(body: [
        "title": AnyCodable("My Post"),
        "author": AnyCodable("USER_ID")
    ])
```

### Update Record

```swift
// Update by ID
let updated: JSONRecord = try await client
    .collection("posts")
    .update("RECORD_ID", body: [
        "title": AnyCodable("Updated Title"),
        "status": AnyCodable("draft")
    ])

// Using Encodable type
struct UpdatePayload: Encodable {
    let title: String
}

let updated2: JSONRecord = try await client
    .collection("posts")
    .update("RECORD_ID", body: UpdatePayload(title: "New Title"))
```

### Delete Record

```swift
try await client
    .collection("posts")
    .delete("RECORD_ID")
```

### Get Record Count

```swift
let count: Int = try await client
    .collection("posts")
    .getCount(
        filter: client.filter("status = {:status}", params: ["status": "published"])
    )
```

## Field Management

### Add Field

```swift
let field: JSONRecord = [
    "name": AnyCodable("description"),
    "type": AnyCodable("text"),
    "required": AnyCodable(false)
]

let updated: JSONRecord = try await client.collections.addField(
    "articles",
    field: field
)
```

### Update Field

```swift
let updates: JSONRecord = [
    "required": AnyCodable(true),
    "max": AnyCodable(500)
]

let updated: JSONRecord = try await client.collections.updateField(
    "articles",
    fieldName: "description",
    updates: updates
)
```

### Remove Field

```swift
try await client.collections.removeField("articles", fieldName: "description")
```

### Get Field

```swift
let field: JSONRecord = try await client.collections.getField(
    "articles",
    fieldName: "title"
)
```

## Index Management

### Add Index

```swift
try await client.collections.addIndex(
    "articles",
    columns: ["title", "created"],
    unique: false,
    indexName: "idx_title_created"
)
```

### Remove Index

```swift
try await client.collections.removeIndex(
    "articles",
    columns: ["title", "created"]
)
```

### Get Indexes

```swift
let indexes: [JSONRecord] = try await client.collections.getIndexes("articles")
```

## Complete Example

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://localhost:8090")

// Authenticate
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Create collection
let collection: JSONRecord = try await client.collections.createBase("blog_posts", overrides: [
    "fields": [
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("content"),
            "type": AnyCodable("editor")
        ],
        [
            "name": AnyCodable("status"),
            "type": AnyCodable("select"),
            "options": AnyCodable([
                "values": AnyCodable(["draft", "published"])
            ]),
            "maxSelect": AnyCodable(1)
        ]
    ]
])

// Create record
let post: JSONRecord = try await client
    .collection("blog_posts")
    .create(body: [
        "title": AnyCodable("My First Post"),
        "content": AnyCodable("This is the content"),
        "status": AnyCodable("published")
    ])

// List records
let posts: ListResult<JSONRecord> = try await client
    .collection("blog_posts")
    .getList(page: 1, perPage: 10)

print("Total posts: \(posts.totalItems)")
for post in posts.items {
    print("Post: \(post["title"] ?? "")")
}

// Update record
let updated: JSONRecord = try await client
    .collection("blog_posts")
    .update(post["id"] as! String, body: [
        "status": AnyCodable("draft")
    ])

// Delete record
try await client
    .collection("blog_posts")
    .delete(post["id"] as! String)
```

## Related Documentation

- [Authentication](./AUTHENTICATION.md)
- [API Rules and Filters](./API_RULES_AND_FILTERS.md)
- [Relations](./RELATIONS.md)
- [Files](./FILES.md)

