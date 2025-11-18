# Collection API - Swift SDK Documentation

## Overview

The Collection API provides endpoints for managing collections (Base, Auth, and View types). All operations require superuser authentication and allow you to create, read, update, and delete collections along with their schemas and configurations.

**Key Features:**
- List and search collections
- View collection details
- Create collections (base, auth, view)
- Update collection schemas and rules
- Delete collections
- Truncate collections (delete all records)
- Import collections in bulk
- Get collection scaffolds (templates)

**Backend Endpoints:**
- `GET /api/collections` - List collections
- `GET /api/collections/{collection}` - View collection
- `POST /api/collections` - Create collection
- `PATCH /api/collections/{collection}` - Update collection
- `DELETE /api/collections/{collection}` - Delete collection
- `DELETE /api/collections/{collection}/truncate` - Truncate collection
- `PUT /api/collections/import` - Import collections
- `GET /api/collections/meta/scaffolds` - Get scaffolds

**Note**: All Collection API operations require superuser authentication.

## Authentication

All Collection API operations require superuser authentication:

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Authenticate as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")
```

## List Collections

Returns a paginated list of collections with support for filtering and sorting.

```swift
// Basic list
let result: ListResult<JSONRecord> = try await client.collections.getList(page: 1, perPage: 30)

print(result.page)        // 1
print(result.perPage)     // 30
print(result.totalItems)  // Total collections count
print(result.items)       // Array of collections
```

### Advanced Filtering and Sorting

```swift
// Filter by type
let authCollections: ListResult<JSONRecord> = try await client.collections.getList(
    page: 1,
    perPage: 100,
    query: ["filter": "type = \"auth\""]
)

// Sort by creation date
let sortedCollections: ListResult<JSONRecord> = try await client.collections.getList(
    page: 1,
    perPage: 100,
    query: ["sort": "-created"]
)
```

### Get Full List

```swift
// Get all collections at once
let allCollections: [JSONRecord] = try await client.collections.getFullList(
    query: ["sort": "name", "filter": "system = false"]
)
```

## View Collection

Retrieve a single collection by ID or name:

```swift
// By name
let collection: JSONRecord = try await client.collections.getOne("posts")

// By ID
let collection: JSONRecord = try await client.collections.getOne("_pbc_2287844090")
```

## Create Collection

Create a new collection with schema fields and configuration.

### Create Base Collection

```swift
let baseCollection: JSONRecord = try await client.collections.create(body: [
    "name": AnyCodable("posts"),
    "type": AnyCodable("base"),
    "fields": AnyCodable([
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true),
            "min": AnyCodable(10),
            "max": AnyCodable(255)
        ],
        [
            "name": AnyCodable("content"),
            "type": AnyCodable("editor"),
            "required": AnyCodable(false)
        ],
        [
            "name": AnyCodable("published"),
            "type": AnyCodable("bool"),
            "required": AnyCodable(false)
        ],
        [
            "name": AnyCodable("author"),
            "type": AnyCodable("relation"),
            "required": AnyCodable(true),
            "collectionId": AnyCodable("_pbc_users_auth_"),
            "maxSelect": AnyCodable(1)
        ]
    ]),
    "listRule": AnyCodable("@request.auth.id != \"\""),
    "viewRule": AnyCodable("@request.auth.id != \"\" || published = true"),
    "createRule": AnyCodable("@request.auth.id != \"\""),
    "updateRule": AnyCodable("author = @request.auth.id"),
    "deleteRule": AnyCodable("author = @request.auth.id")
])
```

### Create Auth Collection

```swift
let authCollection: JSONRecord = try await client.collections.create(body: [
    "name": AnyCodable("users"),
    "type": AnyCodable("auth"),
    "fields": AnyCodable([
        [
            "name": AnyCodable("name"),
            "type": AnyCodable("text"),
            "required": AnyCodable(false)
        ],
        [
            "name": AnyCodable("avatar"),
            "type": AnyCodable("file"),
            "required": AnyCodable(false),
            "maxSelect": AnyCodable(1),
            "maxSize": AnyCodable(2097152), // 2MB
            "mimeTypes": AnyCodable(["image/jpeg", "image/png"])
        ]
    ]),
    "viewRule": AnyCodable("@request.auth.id = id"),
    "updateRule": AnyCodable("@request.auth.id = id"),
    "deleteRule": AnyCodable("@request.auth.id = id")
])
```

### Create View Collection

```swift
let viewCollection: JSONRecord = try await client.collections.create(body: [
    "name": AnyCodable("published_posts"),
    "type": AnyCodable("view"),
    "listRule": AnyCodable("@request.auth.id != \"\""),
    "viewRule": AnyCodable("@request.auth.id != \"\""),
    "viewQuery": AnyCodable("""
        SELECT 
          p.id,
          p.title,
          p.content,
          p.created,
          u.name as author_name,
          u.email as author_email
        FROM posts p
        LEFT JOIN users u ON p.author = u.id
        WHERE p.published = true
    """)
])
```

### Create from Scaffold

Use predefined scaffolds as a starting point:

```swift
// Get available scaffolds
let scaffolds: [String: JSONRecord] = try await client.collections.getScaffolds()

// Create base collection from scaffold
let baseCollection: JSONRecord = try await client.collections.createBase(
    name: "my_posts",
    overrides: [
        "fields": AnyCodable([
            [
                "name": AnyCodable("title"),
                "type": AnyCodable("text"),
                "required": AnyCodable(true)
            ]
        ])
    ]
)

// Create auth collection from scaffold
let authCollection: JSONRecord = try await client.collections.createAuth(
    name: "my_users",
    overrides: [:]
)

// Create view collection from scaffold
let viewCollection: JSONRecord = try await client.collections.createView(
    name: "my_view",
    viewQuery: "SELECT id, title FROM posts",
    overrides: [
        "listRule": AnyCodable("@request.auth.id != \"\"")
    ]
)
```

## Update Collection

Update an existing collection's schema, fields, or rules:

```swift
// Update collection name and rules
let updated: JSONRecord = try await client.collections.update("posts", body: [
    "name": AnyCodable("articles"),
    "listRule": AnyCodable("@request.auth.id != \"\" || status = \"public\""),
    "viewRule": AnyCodable("@request.auth.id != \"\" || status = \"public\"")
])

// Add new field - first get the collection
var collection: JSONRecord = try await client.collections.getOne("posts")

// Add field to fields array
if var fields = collection["fields"]?.value as? [JSONRecord] {
    fields.append([
        "name": AnyCodable("tags"),
        "type": AnyCodable("select"),
        "options": AnyCodable([
            "values": AnyCodable(["tech", "science", "art"])
        ])
    ])
    collection["fields"] = AnyCodable(fields)
    _ = try await client.collections.update("posts", body: collection)
}
```

## Delete Collection

Delete a collection (including all records and files):

```swift
// Delete by name
try await client.collections.delete("old_collection")

// Delete by ID
try await client.collections.delete("_pbc_2287844090")
```

**Warning**: This operation is destructive and will:
- Delete the collection schema
- Delete all records in the collection
- Delete all associated files
- Remove all indexes

## Truncate Collection

Delete all records in a collection while keeping the collection schema:

```swift
// Truncate collection (delete all records)
try await client.collections.truncate("posts")
```

**Warning**: This operation is destructive and cannot be undone.

## Import Collections

Bulk import multiple collections at once:

```swift
let collectionsToImport: [JSONRecord] = [
    [
        "name": AnyCodable("posts"),
        "type": AnyCodable("base"),
        "fields": AnyCodable([
            [
                "name": AnyCodable("title"),
                "type": AnyCodable("text"),
                "required": AnyCodable(true)
            ]
        ]),
        "listRule": AnyCodable("@request.auth.id != \"\"")
    ],
    [
        "name": AnyCodable("categories"),
        "type": AnyCodable("base"),
        "fields": AnyCodable([
            [
                "name": AnyCodable("name"),
                "type": AnyCodable("text"),
                "required": AnyCodable(true)
            ]
        ])
    ]
]

// Import collections
_ = try await client.collections.importCollections(collectionsToImport)
```

## Get Scaffolds

Get collection templates for creating new collections:

```swift
let scaffolds: [String: JSONRecord] = try await client.collections.getScaffolds()

// Available scaffold types
print(scaffolds["base"] ?? [:])   // Base collection template
print(scaffolds["auth"] ?? [:])   // Auth collection template
print(scaffolds["view"] ?? [:])   // View collection template
```

## Complete Examples

### Example 1: Setup Blog Collections

```swift
func setupBlog() async throws -> [String: String] {
    // Create posts collection
    let posts: JSONRecord = try await client.collections.create(body: [
        "name": AnyCodable("posts"),
        "type": AnyCodable("base"),
        "fields": AnyCodable([
            [
                "name": AnyCodable("title"),
                "type": AnyCodable("text"),
                "required": AnyCodable(true),
                "min": AnyCodable(10),
                "max": AnyCodable(255)
            ],
            [
                "name": AnyCodable("content"),
                "type": AnyCodable("editor"),
                "required": AnyCodable(true)
            ],
            [
                "name": AnyCodable("published"),
                "type": AnyCodable("bool"),
                "required": AnyCodable(false)
            ]
        ]),
        "listRule": AnyCodable("@request.auth.id != \"\" || published = true"),
        "viewRule": AnyCodable("@request.auth.id != \"\" || published = true"),
        "createRule": AnyCodable("@request.auth.id != \"\""),
        "updateRule": AnyCodable("author = @request.auth.id"),
        "deleteRule": AnyCodable("author = @request.auth.id")
    ])
    
    // Create categories collection
    let categories: JSONRecord = try await client.collections.create(body: [
        "name": AnyCodable("categories"),
        "type": AnyCodable("base"),
        "fields": AnyCodable([
            [
                "name": AnyCodable("name"),
                "type": AnyCodable("text"),
                "required": AnyCodable(true),
                "unique": AnyCodable(true)
            ]
        ]),
        "listRule": AnyCodable("@request.auth.id != \"\""),
        "viewRule": AnyCodable("@request.auth.id != \"\"")
    ])
    
    // Access collection IDs immediately after creation
    let postsId = posts["id"]?.value as? String ?? ""
    let categoriesId = categories["id"]?.value as? String ?? ""
    
    print("Posts collection ID: \(postsId)")
    print("Categories collection ID: \(categoriesId)")
    
    return [
        "postsId": postsId,
        "categoriesId": categoriesId
    ]
}
```

## Error Handling

```swift
do {
    _ = try await client.collections.create(body: [
        "name": AnyCodable("test"),
        "type": AnyCodable("base"),
        "fields": AnyCodable([])
    ])
} catch let error as ClientResponseError {
    if error.status == 401 {
        print("Not authenticated")
    } else if error.status == 403 {
        print("Not a superuser")
    } else if error.status == 400 {
        print("Validation error: \(error.response ?? [:])")
    } else {
        print("Unexpected error: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Best Practices

1. **Always Authenticate**: Ensure you're authenticated as a superuser before making requests
2. **Backup Before Import**: Always backup existing collections before using `import` with `deleteMissing: true`
3. **Validate Schema**: Validate collection schemas before creating/updating
4. **Use Scaffolds**: Use scaffolds as starting points for consistency
5. **Test Rules**: Test API rules thoroughly before deploying to production
6. **Document Schemas**: Keep documentation of your collection schemas
7. **Version Control**: Store collection schemas in version control for migration tracking

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **System Collections**: System collections cannot be deleted or renamed
- **View Collections**: Cannot be truncated (they don't store records)
- **Relations**: Collections referenced by others cannot be deleted
- **Field Modifications**: Some field type changes may require data migration

## Related Documentation

- [Collections Guide](./COLLECTIONS.md) - Working with collections and records
- [API Records](./API_RECORDS.md) - Record CRUD operations
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Understanding API rules

