# Collections - Swift SDK Documentation

This document provides comprehensive documentation for working with Collections and Fields in the BosBase Swift SDK. This documentation is designed to be AI-readable and includes practical examples for all operations.

## Table of Contents

- [Overview](#overview)
- [Collection Types](#collection-types)
- [Collections API](#collections-api)
- [Records API](#records-api)
- [Field Types](#field-types)
- [Examples](#examples)

## Overview

**Collections** represent your application data. Under the hood they are backed by plain SQLite tables that are generated automatically with the collection **name** and **fields** (columns).

A single entry of a collection is called a **record** (a single row in the SQL table).

You can manage your **collections** from the Dashboard, or with the Swift SDK using the `collections` service.

Similarly, you can manage your **records** from the Dashboard, or with the Swift SDK using the `collection(_ name: String)` method which returns a `RecordService` instance.

## Collection Types

Currently there are 3 collection types: **Base**, **View** and **Auth**.

### Base Collection

**Base collection** is the default collection type and it could be used to store any application data (articles, products, posts, etc.).

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Authenticate as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Create a base collection
let collection: JSONRecord = try await client.collections.createBase("articles", body: [
    "fields": AnyCodable([
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true),
            "min": AnyCodable(6),
            "max": AnyCodable(100)
        ],
        [
            "name": AnyCodable("description"),
            "type": AnyCodable("text")
        ]
    ]),
    "listRule": AnyCodable("@request.auth.id != '' || status = 'public'"),
    "viewRule": AnyCodable("@request.auth.id != '' || status = 'public'")
])
```

### View Collection

**View collection** is a read-only collection type where the data is populated from a plain SQL `SELECT` statement, allowing users to perform aggregations or any other custom queries.

For example, the following query will create a read-only collection with 3 _posts_ fields - _id_, _name_ and _totalComments_:

```swift
// Create a view collection
let viewCollection: JSONRecord = try await client.collections.createView("post_stats", body: [
    "query": AnyCodable("""
        SELECT posts.id, posts.name, count(comments.id) as totalComments 
        FROM posts 
        LEFT JOIN comments on comments.postId = posts.id 
        GROUP BY posts.id
    """)
])
```

**Note**: View collections don't receive realtime events because they don't have create/update/delete operations.

### Auth Collection

**Auth collection** has everything from the **Base collection** but with some additional special fields to help you manage your app users and also provide various authentication options.

Each Auth collection has the following special system fields: `email`, `emailVisibility`, `verified`, `password` and `tokenKey`. They cannot be renamed or deleted but can be configured using their specific field options.

```swift
// Create an auth collection
let usersCollection: JSONRecord = try await client.collections.createAuth("users", body: [
    "fields": AnyCodable([
        [
            "name": AnyCodable("name"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("role"),
            "type": AnyCodable("select"),
            "options": AnyCodable([
                "values": AnyCodable(["employee", "staff", "admin"])
            ])
        ]
    ])
])
```

You can have as many Auth collections as you want (users, managers, staffs, members, clients, etc.) each with their own set of fields, separate login and records managing endpoints.

## Collections API

### Initialize Client

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Authenticate as superuser (required for collection management)
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")
```

### List Collections

```swift
// Get paginated list
let result: ListResult<JSONRecord> = try await client.collections.getList(page: 1, perPage: 50)

// Get all collections
let allCollections: [JSONRecord] = try await client.collections.getFullList()
```

### Get Collection

```swift
// By ID or name
let collection: JSONRecord = try await client.collections.getOne("articles")
// or
let collection: JSONRecord = try await client.collections.getOne("COLLECTION_ID")
```

### Create Collection

#### Using Scaffolds (Recommended)

```swift
// Create base collection
let base: JSONRecord = try await client.collections.createBase("articles", body: [
    "fields": AnyCodable([
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ]
    ])
])

// Create auth collection
let auth: JSONRecord = try await client.collections.createAuth("users")

// Create view collection
let view: JSONRecord = try await client.collections.createView("stats", body: [
    "query": AnyCodable("SELECT id, name FROM posts")
])
```

#### Manual Creation

```swift
let collection: JSONRecord = try await client.collections.create(body: [
    "type": AnyCodable("base"),
    "name": AnyCodable("articles"),
    "fields": AnyCodable([
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true),
            "min": AnyCodable(6),
            "max": AnyCodable(100)
        ],
        [
            "name": AnyCodable("description"),
            "type": AnyCodable("text")
        ],
        [
            "name": AnyCodable("published"),
            "type": AnyCodable("bool"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("views"),
            "type": AnyCodable("number"),
            "min": AnyCodable(0)
        ],
        // Note: created and updated fields must be explicitly added if you want to use them
        [
            "name": AnyCodable("created"),
            "type": AnyCodable("autodate"),
            "required": AnyCodable(false),
            "options": AnyCodable([
                "onCreate": AnyCodable(true),
                "onUpdate": AnyCodable(false)
            ])
        ],
        [
            "name": AnyCodable("updated"),
            "type": AnyCodable("autodate"),
            "required": AnyCodable(false),
            "options": AnyCodable([
                "onCreate": AnyCodable(true),
                "onUpdate": AnyCodable(true)
            ])
        ]
    ]),
    "listRule": AnyCodable("@request.auth.id != '' || published = true"),
    "viewRule": AnyCodable("@request.auth.id != '' || published = true"),
    "createRule": AnyCodable("@request.auth.id != ''"),
    "updateRule": AnyCodable("@request.auth.id != ''"),
    "deleteRule": AnyCodable("@request.auth.id != ''")
])
```

### Update Collection

```swift
let collection: JSONRecord = try await client.collections.update("articles", body: [
    "listRule": AnyCodable("@request.auth.id != '' || published = true && status = 'public'")
])
```

### Delete Collection

```swift
// Warning: This will delete the collection and all its records
try await client.collections.delete("articles")
```

### Truncate Collection

Deletes all records but keeps the collection structure:

```swift
try await client.collections.truncate("articles")
```

### Import Collections

```swift
let collectionsToImport: [JSONRecord] = [
    [
        "type": AnyCodable("base"),
        "name": AnyCodable("articles"),
        "fields": AnyCodable([/* ... */])
    ],
    [
        "type": AnyCodable("auth"),
        "name": AnyCodable("users"),
        "fields": AnyCodable([/* ... */])
    ]
]

// Import collections (deleteMissing will delete collections not in the import list)
_ = try await client.collections.importCollections(collectionsToImport)
```

### Get Scaffolds

```swift
let scaffolds: JSONRecord = try await client.collections.getScaffolds()
// Returns: { base: {...}, auth: {...}, view: {...} }
```

## Records API

### Get Record Service

```swift
// Get a RecordService instance for a collection
let articles = client.collection("articles")
```

### List Records

**Important Note:** Bosbase does not initialize `created` and `updated` fields by default. To use these fields, you must explicitly add them when initializing the collection with the proper options:

```swift
// Paginated list 
let result: ListResult<JSONRecord> = try await client
    .collection("articles")
    .getList(
        page: 1,
        perPage: 20,
        filter: "published = true",
        sort: "-created",
        expand: "author",
        fields: "id,title,description"
    )

print("Items: \(result.items?.count ?? 0)")
print("Page: \(result.page)")
print("Per Page: \(result.perPage)")
print("Total Items: \(result.totalItems)")
print("Total Pages: \(result.totalPages)")

// Get all records (automatically paginates)
let allRecords: [JSONRecord] = try await client
    .collection("articles")
    .getFullList(
        filter: "published = true",
        sort: "-created"
    )
```

### Get Single Record

```swift
let record: JSONRecord = try await client
    .collection("articles")
    .getOne("RECORD_ID", expand: "author,category", fields: "id,title,description,author")
```

### Get First Matching Record

```swift
let record: JSONRecord = try await client
    .collection("articles")
    .getFirstListItem(
        filter: "title ~ \"example\" && published = true",
        expand: "author"
    )
```

### Create Record

```swift
// Simple create
let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "title": AnyCodable("My First Article"),
        "description": AnyCodable("This is a test article"),
        "published": AnyCodable(true),
        "views": AnyCodable(0)
    ])

// With file upload
let fileData = try Data(contentsOf: URL(fileURLWithPath: "/path/to/image.jpg"))
let formData = MultipartFormData()
formData.append(name: "title", value: "My Article")
formData.append(name: "cover", fileData: fileData, fileName: "image.jpg", mimeType: "image/jpeg")

let record: JSONRecord = try await client
    .collection("articles")
    .create(body: formData)

// With field modifiers
let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "title": AnyCodable("My Article"),
        "views+": AnyCodable(1),  // Increment views by 1
        "tags+": AnyCodable("new-tag")  // Append to tags array
    ])
```

### Update Record

```swift
// Simple update
let record: JSONRecord = try await client
    .collection("articles")
    .update("RECORD_ID", body: [
        "title": AnyCodable("Updated Title"),
        "published": AnyCodable(true)
    ])

// With field modifiers
let record: JSONRecord = try await client
    .collection("articles")
    .update("RECORD_ID", body: [
        "views+": AnyCodable(1),           // Increment views
        "tags+": AnyCodable("new-tag"),    // Append tag
        "tags-": AnyCodable("old-tag")     // Remove tag
    ])

// With file upload
let formData = MultipartFormData()
formData.append(name: "title", value: "Updated Title")
formData.append(name: "cover", fileData: fileData, fileName: "image.jpg", mimeType: "image/jpeg")

let record: JSONRecord = try await client
    .collection("articles")
    .update("RECORD_ID", body: formData)
```

### Delete Record

```swift
try await client.collection("articles").delete("RECORD_ID")
```

### Batch Operations

```swift
let batch = client.createBatch()

batch.collection("articles").create(body: ["title": AnyCodable("Article 1")])
batch.collection("articles").create(body: ["title": AnyCodable("Article 2")])
batch.collection("articles").update("RECORD_ID", body: ["published": AnyCodable(true)])

let results = try await batch.submit()
// results is an array of responses in the same order as requests
```

## Field Types

All collection fields (with exception of the `JSONField`) are **non-nullable and use a zero-default** for their respective type as fallback value when missing (empty string for `text`, 0 for `number`, etc.).

### BoolField

Stores a single `false` (default) or `true` value.

```swift
// Create field
[
    "name": AnyCodable("published"),
    "type": AnyCodable("bool"),
    "required": AnyCodable(true)
]

// Usage
let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "published": AnyCodable(true)
    ])
```

### NumberField

Stores numeric/float64 value: `0` (default), `2`, `-1`, `1.5`.

**Available modifiers:**
- `fieldName+` - adds number to the existing record value
- `fieldName-` - subtracts number from the existing record value

```swift
// Create field
[
    "name": AnyCodable("views"),
    "type": AnyCodable("number"),
    "min": AnyCodable(0),
    "max": AnyCodable(1000000),
    "onlyInt": AnyCodable(false)  // Allow decimals
]

// Usage
let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "views": AnyCodable(0)
    ])

// Increment
_ = try await client
    .collection("articles")
    .update("RECORD_ID", body: [
        "views+": AnyCodable(1)
    ])

// Decrement
_ = try await client
    .collection("articles")
    .update("RECORD_ID", body: [
        "views-": AnyCodable(5)
    ])
```

### TextField

Stores string values: `""` (default), `"example"`.

**Available modifiers:**
- `fieldName:autogenerate` - autogenerate a field value if the `AutogeneratePattern` field option is set.

```swift
// Create field
[
    "name": AnyCodable("title"),
    "type": AnyCodable("text"),
    "required": AnyCodable(true),
    "min": AnyCodable(6),
    "max": AnyCodable(100),
    "pattern": AnyCodable("^[A-Z]"),  // Must start with uppercase
    "autogeneratePattern": AnyCodable("[a-z0-9]{8}")  // Auto-generate pattern
]

// Usage
let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "title": AnyCodable("My Article")
    ])

// Auto-generate
let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "slug:autogenerate": AnyCodable("article-")
        // Results in: 'article-[random8chars]'
    ])
```

### EmailField

Stores a single email string address: `""` (default), `"john@example.com"`.

```swift
// Create field
[
    "name": AnyCodable("email"),
    "type": AnyCodable("email"),
    "required": AnyCodable(true)
]

// Usage
let record: JSONRecord = try await client
    .collection("users")
    .create(body: [
        "email": AnyCodable("user@example.com")
    ])
```

### URLField

Stores a single URL string value: `""` (default), `"https://example.com"`.

```swift
// Create field
[
    "name": AnyCodable("website"),
    "type": AnyCodable("url"),
    "required": AnyCodable(false)
]

// Usage
let record: JSONRecord = try await client
    .collection("users")
    .create(body: [
        "website": AnyCodable("https://example.com")
    ])
```

### EditorField

Stores HTML formatted text: `""` (default), `<p>example</p>`.

```swift
// Create field
[
    "name": AnyCodable("content"),
    "type": AnyCodable("editor"),
    "required": AnyCodable(true),
    "maxSize": AnyCodable(10485760)  // 10MB
]

// Usage
let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "content": AnyCodable("<p>This is HTML content</p><p>With multiple paragraphs</p>")
    ])
```

### DateField

Stores a single datetime string value: `""` (default), `"2022-01-01 00:00:00.000Z"`.

All BosBase dates follow the RFC3339 format `Y-m-d H:i:s.uZ` (e.g. `2024-11-10 18:45:27.123Z`).

```swift
// Create field
[
    "name": AnyCodable("published_at"),
    "type": AnyCodable("date"),
    "required": AnyCodable(false)
]

// Usage
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "published_at": AnyCodable(formatter.string(from: Date()))
    ])

// Filter by date
let records: ListResult<JSONRecord> = try await client
    .collection("articles")
    .getList(
        page: 1,
        perPage: 20,
        filter: "created >= '2024-11-19 00:00:00.000Z' && created <= '2024-11-19 23:59:59.999Z'"
    )
```

### AutodateField

Similar to DateField but its value is auto set on record create/update. Usually used for timestamp fields like "created" and "updated".

**Important Note:** Bosbase does not initialize `created` and `updated` fields by default. To use these fields, you must explicitly add them when initializing the collection with the proper options:

```swift
// Create field with proper options
[
    "name": AnyCodable("created"),
    "type": AnyCodable("autodate"),
    "required": AnyCodable(false),
    "options": AnyCodable([
        "onCreate": AnyCodable(true),  // Set on record creation
        "onUpdate": AnyCodable(false)  // Don't update on record update
    ])
]

// For updated field
[
    "name": AnyCodable("updated"),
    "type": AnyCodable("autodate"),
    "required": AnyCodable(false),
    "options": AnyCodable([
        "onCreate": AnyCodable(true),  // Set on record creation
        "onUpdate": AnyCodable(true)   // Update on record update
    ])
]

// The value is automatically set by the backend based on the options
```

### SelectField

Stores single or multiple string values from a predefined list.

For **single** `select` (the `MaxSelect` option is <= 1) the field value is a string: `""`, `"optionA"`.

For **multiple** `select` (the `MaxSelect` option is >= 2) the field value is an array: `[]`, `["optionA", "optionB"]`.

**Available modifiers:**
- `fieldName+` - appends one or more values
- `+fieldName` - prepends one or more values
- `fieldName-` - subtracts/removes one or more values

```swift
// Single select
[
    "name": AnyCodable("status"),
    "type": AnyCodable("select"),
    "options": AnyCodable([
        "values": AnyCodable(["draft", "published", "archived"])
    ]),
    "maxSelect": AnyCodable(1)
]

// Multiple select
[
    "name": AnyCodable("tags"),
    "type": AnyCodable("select"),
    "options": AnyCodable([
        "values": AnyCodable(["tech", "design", "business", "marketing"])
    ]),
    "maxSelect": AnyCodable(5)
]

// Usage - Single
let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "status": AnyCodable("published")
    ])

// Usage - Multiple
let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "tags": AnyCodable(["tech", "design"])
    ])

// Modify - Append
_ = try await client
    .collection("articles")
    .update("RECORD_ID", body: [
        "tags+": AnyCodable("marketing")
    ])

// Modify - Remove
_ = try await client
    .collection("articles")
    .update("RECORD_ID", body: [
        "tags-": AnyCodable("tech")
    ])
```

### FileField

Manages record file(s). BosBase stores in the database only the file name. The file itself is stored either on the local disk or in S3.

For **single** `file` (the `MaxSelect` option is <= 1) the stored value is a string: `""`, `"file1_Ab24ZjL.png"`.

For **multiple** `file` (the `MaxSelect` option is >= 2) the stored value is an array: `[]`, `["file1_Ab24ZjL.png", "file2_Frq24ZjL.txt"]`.

**Available modifiers:**
- `fieldName+` - appends one or more files
- `+fieldName` - prepends one or more files
- `fieldName-` - deletes one or more files

```swift
// Single file
[
    "name": AnyCodable("cover"),
    "type": AnyCodable("file"),
    "maxSelect": AnyCodable(1),
    "maxSize": AnyCodable(5242880),  // 5MB
    "mimeTypes": AnyCodable(["image/jpeg", "image/png"])
]

// Multiple files
[
    "name": AnyCodable("documents"),
    "type": AnyCodable("file"),
    "maxSelect": AnyCodable(10),
    "maxSize": AnyCodable(10485760),  // 10MB
    "mimeTypes": AnyCodable(["application/pdf", "application/docx"])
]

// Usage - Upload file
let formData = MultipartFormData()
formData.append(name: "title", value: "My Article")
formData.append(name: "cover", fileData: fileData, fileName: "image.jpg", mimeType: "image/jpeg")

let record: JSONRecord = try await client
    .collection("articles")
    .create(body: formData)

// Modify - Add file
let formData = MultipartFormData()
formData.append(name: "documents", fileData: newFileData, fileName: "document.pdf", mimeType: "application/pdf")

_ = try await client
    .collection("articles")
    .update("RECORD_ID", body: formData)

// Modify - Remove file
_ = try await client
    .collection("articles")
    .update("RECORD_ID", body: [
        "documents-": AnyCodable("old_file_abc123.pdf")
    ])
```

### RelationField

Stores single or multiple collection record references.

For **single** `relation` (the `MaxSelect` option is <= 1) the field value is a string: `""`, `"RECORD_ID"`.

For **multiple** `relation` (the `MaxSelect` option is >= 2) the field value is an array: `[]`, `["RECORD_ID1", "RECORD_ID2"]`.

**Available modifiers:**
- `fieldName+` - appends one or more ids
- `+fieldName` - prepends one or more ids
- `fieldName-` - subtracts/removes one or more ids

```swift
// Single relation
[
    "name": AnyCodable("author"),
    "type": AnyCodable("relation"),
    "options": AnyCodable([
        "collectionId": AnyCodable("users"),
        "cascadeDelete": AnyCodable(false)
    ]),
    "maxSelect": AnyCodable(1)
]

// Multiple relation
[
    "name": AnyCodable("categories"),
    "type": AnyCodable("relation"),
    "options": AnyCodable([
        "collectionId": AnyCodable("categories")
    ]),
    "maxSelect": AnyCodable(5)
]

// Usage - Single
let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "title": AnyCodable("My Article"),
        "author": AnyCodable("USER_RECORD_ID")
    ])

// Usage - Multiple
let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "title": AnyCodable("My Article"),
        "categories": AnyCodable(["CAT_ID1", "CAT_ID2"])
    ])

// Modify - Add relation
_ = try await client
    .collection("articles")
    .update("RECORD_ID", body: [
        "categories+": AnyCodable("CAT_ID3")
    ])

// Modify - Remove relation
_ = try await client
    .collection("articles")
    .update("RECORD_ID", body: [
        "categories-": AnyCodable("CAT_ID1")
    ])

// Expand relations when fetching
let record: JSONRecord = try await client
    .collection("articles")
    .getOne("RECORD_ID", expand: "author,categories")
// record["expand"]?["author"] - full author record
// record["expand"]?["categories"] - array of category records
```

### JSONField

Stores any serialized JSON value, including `null` (default). This is the only nullable field type.

```swift
// Create field
[
    "name": AnyCodable("metadata"),
    "type": AnyCodable("json"),
    "required": AnyCodable(false)
]

// Usage
let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "title": AnyCodable("My Article"),
        "metadata": AnyCodable([
            "seo": [
                "title": AnyCodable("SEO Title"),
                "description": AnyCodable("SEO Description")
            ],
            "custom": [
                "tags": AnyCodable(["tag1", "tag2"]),
                "priority": AnyCodable(10)
            ]
        ])
    ])

// Can also store arrays
let record: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "title": AnyCodable("My Article"),
        "metadata": AnyCodable([1, 2, 3, ["nested": "object"]])
    ])
```

### GeoPointField

Stores geographic coordinates (longitude, latitude) as a serialized json object.

The default/zero value of a `geoPoint` is the "Null Island", aka. `{"lon":0,"lat":0}`.

```swift
// Create field
[
    "name": AnyCodable("location"),
    "type": AnyCodable("geoPoint"),
    "required": AnyCodable(false)
]

// Usage
let record: JSONRecord = try await client
    .collection("places")
    .create(body: [
        "name": AnyCodable("Tokyo Tower"),
        "location": AnyCodable([
            "lon": AnyCodable(139.6917),
            "lat": AnyCodable(35.6586)
        ])
    ])
```

## Examples

### Complete Example: Blog System

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// 1. Create users (auth) collection
let usersCollection: JSONRecord = try await client.collections.createAuth("users", body: [
    "fields": AnyCodable([
        [
            "name": AnyCodable("name"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("avatar"),
            "type": AnyCodable("file"),
            "maxSelect": AnyCodable(1),
            "mimeTypes": AnyCodable(["image/jpeg", "image/png"])
        ]
    ])
])

// 2. Create categories (base) collection
let categoriesCollection: JSONRecord = try await client.collections.createBase("categories", body: [
    "fields": AnyCodable([
        [
            "name": AnyCodable("name"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("slug"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ]
    ])
])

// 3. Create articles (base) collection
let articlesCollection: JSONRecord = try await client.collections.createBase("articles", body: [
    "fields": AnyCodable([
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true),
            "min": AnyCodable(6),
            "max": AnyCodable(200)
        ],
        [
            "name": AnyCodable("slug"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true),
            "autogeneratePattern": AnyCodable("[a-z0-9-]{10,}")
        ],
        [
            "name": AnyCodable("content"),
            "type": AnyCodable("editor"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("excerpt"),
            "type": AnyCodable("text"),
            "max": AnyCodable(500)
        ],
        [
            "name": AnyCodable("cover"),
            "type": AnyCodable("file"),
            "maxSelect": AnyCodable(1),
            "mimeTypes": AnyCodable(["image/jpeg", "image/png"])
        ],
        [
            "name": AnyCodable("author"),
            "type": AnyCodable("relation"),
            "options": AnyCodable([
                "collectionId": AnyCodable(usersCollection["id"]?.value as? String ?? "")
            ]),
            "maxSelect": AnyCodable(1),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("categories"),
            "type": AnyCodable("relation"),
            "options": AnyCodable([
                "collectionId": AnyCodable(categoriesCollection["id"]?.value as? String ?? "")
            ]),
            "maxSelect": AnyCodable(5)
        ],
        [
            "name": AnyCodable("tags"),
            "type": AnyCodable("select"),
            "options": AnyCodable([
                "values": AnyCodable(["tech", "design", "business", "marketing", "lifestyle"])
            ]),
            "maxSelect": AnyCodable(10)
        ],
        [
            "name": AnyCodable("status"),
            "type": AnyCodable("select"),
            "options": AnyCodable([
                "values": AnyCodable(["draft", "published", "archived"])
            ]),
            "maxSelect": AnyCodable(1),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("published"),
            "type": AnyCodable("bool"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("views"),
            "type": AnyCodable("number"),
            "min": AnyCodable(0),
            "onlyInt": AnyCodable(true)
        ],
        [
            "name": AnyCodable("published_at"),
            "type": AnyCodable("date")
        ],
        [
            "name": AnyCodable("metadata"),
            "type": AnyCodable("json")
        ]
    ]),
    "listRule": AnyCodable("@request.auth.id != '' || (published = true && status = 'published')"),
    "viewRule": AnyCodable("@request.auth.id != '' || (published = true && status = 'published')"),
    "createRule": AnyCodable("@request.auth.id != ''"),
    "updateRule": AnyCodable("author = @request.auth.id || @request.auth.role = 'admin'"),
    "deleteRule": AnyCodable("author = @request.auth.id || @request.auth.role = 'admin'")
])

// 4. Create a user
let user: JSONRecord = try await client
    .collection("users")
    .create(body: [
        "email": AnyCodable("author@example.com"),
        "emailVisibility": AnyCodable(true),
        "password": AnyCodable("securepassword123"),
        "passwordConfirm": AnyCodable("securepassword123"),
        "name": AnyCodable("John Doe")
    ])

// 5. Authenticate as the user
let authResult: AuthResult = try await client
    .collection("users")
    .authWithPassword(identity: "author@example.com", password: "securepassword123")

// 6. Create a category
let category: JSONRecord = try await client
    .collection("categories")
    .create(body: [
        "name": AnyCodable("Technology"),
        "slug": AnyCodable("technology")
    ])

// 7. Create an article
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

let article: JSONRecord = try await client
    .collection("articles")
    .create(body: [
        "title": AnyCodable("Getting Started with BosBase"),
        "slug:autogenerate": AnyCodable("getting-started-"),
        "content": AnyCodable("<p>This is my first article about BosBase...</p>"),
        "excerpt": AnyCodable("Learn how to get started with BosBase..."),
        "author": AnyCodable(user["id"]?.value as? String ?? ""),
        "categories": AnyCodable([category["id"]?.value as? String ?? ""]),
        "tags": AnyCodable(["tech", "tutorial"]),
        "status": AnyCodable("published"),
        "published": AnyCodable(true),
        "views": AnyCodable(0),
        "published_at": AnyCodable(formatter.string(from: Date())),
        "metadata": AnyCodable([
            "seo": [
                "title": AnyCodable("Getting Started with BosBase - SEO Title"),
                "description": AnyCodable("SEO description here")
            ]
        ])
    ])

// 8. Update article views
_ = try await client
    .collection("articles")
    .update(article["id"]?.value as? String ?? "", body: [
        "views+": AnyCodable(1)
    ])

// 9. Add a tag to the article
_ = try await client
    .collection("articles")
    .update(article["id"]?.value as? String ?? "", body: [
        "tags+": AnyCodable("beginner")
    ])

// 10. Fetch article with expanded relations
let fullArticle: JSONRecord = try await client
    .collection("articles")
    .getOne(article["id"]?.value as? String ?? "", expand: "author,categories")

if let expand = fullArticle["expand"]?.value as? JSONRecord,
   let author = expand["author"]?.value as? JSONRecord,
   let authorName = author["name"]?.value as? String {
    print("Author: \(authorName)")
}

// 11. List published articles
let publishedArticles: ListResult<JSONRecord> = try await client
    .collection("articles")
    .getList(
        page: 1,
        perPage: 20,
        filter: "published = true && status = \"published\"",
        sort: "-created",
        expand: "author,categories"
    )

// 12. Search articles
let searchResults: ListResult<JSONRecord> = try await client
    .collection("articles")
    .getList(
        page: 1,
        perPage: 20,
        filter: "title ~ \"BosBase\" || content ~ \"BosBase\"",
        sort: "-views"
    )
```

### Authentication with Auth Collections

```swift
// Create an auth collection
let customersCollection: JSONRecord = try await client.collections.createAuth("customers", body: [
    "fields": AnyCodable([
        [
            "name": AnyCodable("name"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("phone"),
            "type": AnyCodable("text")
        ]
    ])
])

// Register a new customer
let customer: JSONRecord = try await client
    .collection("customers")
    .create(body: [
        "email": AnyCodable("customer@example.com"),
        "emailVisibility": AnyCodable(true),
        "password": AnyCodable("password123"),
        "passwordConfirm": AnyCodable("password123"),
        "name": AnyCodable("Jane Doe"),
        "phone": AnyCodable("+1234567890")
    ])

// Authenticate
let auth: AuthResult = try await client
    .collection("customers")
    .authWithPassword(identity: "customer@example.com", password: "password123")

print("Token: \(auth.token)")
print("Record: \(auth.record)")

// Check if authenticated
if let authRecord = client.authStore.record {
    print("Current user: \(authRecord)")
}

// Logout
client.authStore.clear()
```

---

For more information, see:
- [Collections API](./COLLECTION_API.md) - Detailed collection management
- [Records API](./API_RECORDS.md) - Detailed records operations
- [Authentication](./AUTHENTICATION.md) - Authentication guide

