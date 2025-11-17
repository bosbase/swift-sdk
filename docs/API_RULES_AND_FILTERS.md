# API Rules and Filters - Swift SDK Documentation

## Overview

API Rules are your collection access controls and data filters. They control who can perform actions on your collections and what data they can access.

Each collection has 5 rules, corresponding to specific API actions:
- `listRule` - Controls who can list records
- `viewRule` - Controls who can view individual records
- `createRule` - Controls who can create records
- `updateRule` - Controls who can update records
- `deleteRule` - Controls who can delete records

Auth collections have an additional `manageRule` that allows one user to fully manage another user's data.

> 📖 **Reference**: This guide mirrors the [JavaScript SDK API Rules documentation](../js-sdk/docs/API_RULES_AND_FILTERS.md) but uses Swift syntax and examples.

## Rule Values

Each rule can be set to:

- **`null` (locked)** - Only authorized superusers can perform the action (default)
- **Empty string `""`** - Anyone can perform the action (superusers, authenticated users, and guests)
- **Non-empty string** - Only users that satisfy the filter expression can perform the action

## Important Notes

1. **Rules act as filters**: API Rules also act as record filters. For example, setting `listRule` to `status = "active"` will only return active records.
2. **HTTP Status Codes**: 
   - `200` with empty items for unsatisfied `listRule`
   - `400` for unsatisfied `createRule`
   - `404` for unsatisfied `viewRule`, `updateRule`, `deleteRule`
   - `403` for locked rules when not a superuser
3. **Superuser bypass**: API Rules are ignored when the action is performed by an authorized superuser.

## Setting Rules via SDK

### Swift SDK

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://localhost:8090")
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Create collection with rules
let collection: JSONRecord = try await client.collections.createBase("articles", overrides: [
    "fields": [
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("status"),
            "type": AnyCodable("select"),
            "options": AnyCodable(["values": AnyCodable(["draft", "published"])]),
            "maxSelect": AnyCodable(1)
        ],
        [
            "name": AnyCodable("author"),
            "type": AnyCodable("relation"),
            "options": AnyCodable(["collectionId": AnyCodable("users")]),
            "maxSelect": AnyCodable(1)
        ]
    ],
    "listRule": AnyCodable("@request.auth.id != \"\" || status = \"published\""),
    "viewRule": AnyCodable("@request.auth.id != \"\" || status = \"published\""),
    "createRule": AnyCodable("@request.auth.id != \"\""),
    "updateRule": AnyCodable("author = @request.auth.id || @request.auth.role = \"admin\""),
    "deleteRule": AnyCodable("author = @request.auth.id || @request.auth.role = \"admin\"")
])

// Update rules
try await client.collections.setListRule(
    "articles",
    rule: "@request.auth.id != \"\" && (status = \"published\" || status = \"draft\")"
)

// Remove rule (set to empty string for public access)
try await client.collections.setListRule("articles", rule: "")

// Lock rule (set to nil for superuser only)
try await client.collections.setListRule("articles", rule: nil)
```

### Setting All Rules at Once

```swift
let rules: JSONRecord = [
    "listRule": AnyCodable("@request.auth.id != \"\""),
    "viewRule": AnyCodable("@request.auth.id != \"\""),
    "createRule": AnyCodable("@request.auth.id != \"\""),
    "updateRule": AnyCodable("author = @request.auth.id"),
    "deleteRule": AnyCodable("author = @request.auth.id")
]

try await client.collections.setRules("articles", rules: rules)
```

### Getting Rules

```swift
let rules: JSONRecord = try await client.collections.getRules("articles")
print("List rule: \(rules["listRule"] ?? "")")
print("View rule: \(rules["viewRule"] ?? "")")
```

## Filter Syntax

The syntax follows: `OPERAND OPERATOR OPERAND`

### Operators

**Comparison Operators:**
- `=` - Equal
- `!=` - NOT equal
- `>` - Greater than
- `>=` - Greater than or equal
- `<` - Less than
- `<=` - Less than or equal

**String Operators:**
- `~` - Like/Contains (auto-wraps right operand in `%` for wildcard match)
- `!~` - NOT Like/Contains

**Array Operators (Any/At least one of):**
- `?=` - Any Equal
- `?!=` - Any NOT equal
- `?>` - Any Greater than
- `?>=` - Any Greater than or equal
- `?<` - Any Less than
- `?<=` - Any Less than or equal
- `?~` - Any Like/Contains
- `?!~` - Any NOT Like/Contains

**Logical Operators:**
- `&&` - AND
- `||` - OR

### Operands

**Field References:**
- `fieldName` - Direct field reference
- `fieldName.subfield` - Nested field (for JSON fields)

**Special Identifiers:**
- `@request.auth.id` - Current authenticated user ID (empty string if not authenticated)
- `@request.auth.role` - Current authenticated user role (if exists)
- `@request.data.fieldName` - Data from the current request
- `@collection.fieldName` - Reference to the current collection field

**Literals:**
- Strings: `"text"` (use double quotes, escape with `\"`)
- Numbers: `123`, `123.45`
- Booleans: `true`, `false`
- Null: `null`
- Dates: `"2023-01-01 10:00:00"` (ISO format)

## Filter Builder

The SDK provides a `filter()` method to safely build filter strings with parameters:

```swift
// Basic usage
let filter = client.filter("title = {:title}", params: ["title": "Hello"])
// Result: title = "Hello"

// Multiple parameters
let filter2 = client.filter(
    "title ~ {:title} && (totalA = {:num} || totalB = {:num})",
    params: [
        "title": "te'st",  // Auto-escaped
        "num": 123
    ]
)
// Result: title ~ "te'st" && (totalA = 123 || totalB = 123)

// With dates
let date = Date()
let filter3 = client.filter(
    "created > {:date}",
    params: ["date": date]
)
// Date is automatically formatted to ISO string

// With null
let filter4 = client.filter(
    "author = {:author}",
    params: ["author": nil as String?]
)
// Result: author = null
```

### Supported Parameter Types

- `String` - Auto-escaped with single quotes
- `Int`, `Double`, `Float` - Converted to numbers
- `Bool` - Converted to `true`/`false`
- `Date` - Converted to ISO 8601 format
- `nil` - Converted to `null`
- Arrays and dictionaries - Converted using `JSON.stringify()` equivalent

## Filter Examples

### Basic Filters

```swift
// Simple equality
let filter1 = client.filter("status = {:status}", params: ["status": "published"])

// Comparison
let filter2 = client.filter("age > {:age}", params: ["age": 18])

// String contains
let filter3 = client.filter("title ~ {:search}", params: ["search": "swift"])

// Multiple conditions
let filter4 = client.filter(
    "status = {:status} && created > {:date}",
    params: [
        "status": "published",
        "date": Date().addingTimeInterval(-86400) // Yesterday
    ]
)
```

### Using Filters in Queries

```swift
// List with filter
let posts: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(
        page: 1,
        perPage: 30,
        filter: client.filter("status = {:status}", params: ["status": "published"])
    )

// Get first matching record
let post: JSONRecord = try await client
    .collection("posts")
    .getFirstListItem(
        filter: client.filter("slug = {:slug}", params: ["slug": "my-post"])
    )

// Count with filter
let count: Int = try await client
    .collection("posts")
    .getCount(
        filter: client.filter("status = {:status}", params: ["status": "draft"])
    )
```

### Complex Filters

```swift
// OR conditions
let filter = client.filter(
    "status = {:status1} || status = {:status2}",
    params: [
        "status1": "published",
        "status2": "archived"
    ]
)

// Nested conditions
let filter2 = client.filter(
    "(status = {:status} && author = {:author}) || @request.auth.role = {:role}",
    params: [
        "status": "published",
        "author": "USER_ID",
        "role": "admin"
    ]
)

// Array operators
let filter3 = client.filter(
    "tags ?= {:tag}",
    params: ["tag": "swift"]
)
```

## API Rule Examples

### Public Collection (Anyone can read, authenticated users can write)

```swift
try await client.collections.setRules("articles", rules: [
    "listRule": AnyCodable(""),
    "viewRule": AnyCodable(""),
    "createRule": AnyCodable("@request.auth.id != \"\""),
    "updateRule": AnyCodable("@request.auth.id != \"\""),
    "deleteRule": AnyCodable("@request.auth.id != \"\"")
])
```

### Private Collection (Only authenticated users)

```swift
try await client.collections.setRules("private_notes", rules: [
    "listRule": AnyCodable("@request.auth.id != \"\""),
    "viewRule": AnyCodable("@request.auth.id != \"\""),
    "createRule": AnyCodable("@request.auth.id != \"\""),
    "updateRule": AnyCodable("@request.auth.id != \"\""),
    "deleteRule": AnyCodable("@request.auth.id != \"\"")
])
```

### Owner-Only Collection (Users can only manage their own records)

```swift
try await client.collections.setRules("user_posts", rules: [
    "listRule": AnyCodable("@request.auth.id != \"\""),
    "viewRule": AnyCodable("@request.auth.id != \"\""),
    "createRule": AnyCodable("@request.auth.id != \"\""),
    "updateRule": AnyCodable("author = @request.auth.id"),
    "deleteRule": AnyCodable("author = @request.auth.id")
])
```

### Published Content (Public read, owner/admin write)

```swift
try await client.collections.setRules("blog_posts", rules: [
    "listRule": AnyCodable("status = \"published\" || author = @request.auth.id"),
    "viewRule": AnyCodable("status = \"published\" || author = @request.auth.id"),
    "createRule": AnyCodable("@request.auth.id != \"\""),
    "updateRule": AnyCodable("author = @request.auth.id || @request.auth.role = \"admin\""),
    "deleteRule": AnyCodable("author = @request.auth.id || @request.auth.role = \"admin\"")
])
```

## Complete Example

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://localhost:8090")

// Authenticate as admin
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Create collection with rules
let collection: JSONRecord = try await client.collections.createBase("articles", overrides: [
    "fields": [
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("status"),
            "type": AnyCodable("select"),
            "options": AnyCodable(["values": AnyCodable(["draft", "published"])]),
            "maxSelect": AnyCodable(1)
        ],
        [
            "name": AnyCodable("author"),
            "type": AnyCodable("relation"),
            "options": AnyCodable(["collectionId": AnyCodable("users")]),
            "maxSelect": AnyCodable(1)
        ]
    ],
    "listRule": AnyCodable("@request.auth.id != \"\" || status = \"published\""),
    "viewRule": AnyCodable("@request.auth.id != \"\" || status = \"published\""),
    "createRule": AnyCodable("@request.auth.id != \"\""),
    "updateRule": AnyCodable("author = @request.auth.id"),
    "deleteRule": AnyCodable("author = @request.auth.id")
])

// Use filters in queries
let publishedPosts: ListResult<JSONRecord> = try await client
    .collection("articles")
    .getList(
        page: 1,
        perPage: 10,
        filter: client.filter("status = {:status}", params: ["status": "published"])
    )

// Authenticate as regular user
try await client
    .collection("users")
    .authWithPassword(identity: "user@example.com", password: "password123")

// User can only see published posts or their own
let myPosts: ListResult<JSONRecord> = try await client
    .collection("articles")
    .getList()
// API rules automatically filter results
```

## Related Documentation

- [Collections](./COLLECTIONS.md)
- [Authentication](./AUTHENTICATION.md)

