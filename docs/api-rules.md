# API Rules Documentation - Swift SDK

## Overview

API Rules are collection access controls and data filters that determine who can perform actions on your collections and what data they can access.

## Overview

Each collection has 5 standard API rules, corresponding to specific API actions:

- **`listRule`** - Controls read/list access
- **`viewRule`** - Controls read/view access  
- **`createRule`** - Controls create access
- **`updateRule`** - Controls update access
- **`deleteRule`** - Controls delete access

Auth collections have two additional rules:

- **`manageRule`** - Admin-like permissions for managing auth records
- **`authRule`** - Additional constraints applied during authentication

## Rule Values

Each rule can be set to one of three values:

### 1. `null` (Locked)
Only authorized superusers can perform the action.

```swift
// In Swift, use nil or empty dictionary
let collection: JSONRecord = try await client.collections.getOne("products")
var updated = collection
updated["listRule"] = nil
_ = try await client.collections.update("products", body: updated)
```

### 2. `""` (Empty String - Public)
Anyone (superusers, authorized users, and guests) can perform the action.

```swift
var collection: JSONRecord = try await client.collections.getOne("products")
collection["listRule"] = AnyCodable("")
_ = try await client.collections.update("products", body: collection)
```

### 3. Non-empty String (Filter Expression)
Only users satisfying the filter expression can perform the action.

```swift
var collection: JSONRecord = try await client.collections.getOne("products")
collection["listRule"] = AnyCodable("@request.auth.id != \"\"")
_ = try await client.collections.update("products", body: collection)
```

## Default Permissions

When you create a base collection without specifying rules, BosBase applies opinionated defaults:

- `listRule` and `viewRule` default to an empty string (`""`), so guests and authenticated users can query records.
- `createRule` defaults to `@request.auth.id != ""`, restricting writes to authenticated users or superusers.
- `updateRule` and `deleteRule` default to `@request.auth.id != "" && createdBy = @request.auth.id`, which limits mutations to the record creator (superusers still bypass rules).

## Setting Rules

### Individual Rules

Set individual rules by updating the collection:

```swift
// Get collection
var collection: JSONRecord = try await client.collections.getOne("products")

// Set list rule
collection["listRule"] = AnyCodable("@request.auth.id != \"\"")

// Set view rule
collection["viewRule"] = AnyCodable("@request.auth.id != \"\"")

// Set create rule
collection["createRule"] = AnyCodable("@request.auth.id != \"\"")

// Set update rule
collection["updateRule"] = AnyCodable("@request.auth.id != \"\" && author.id ?= @request.auth.id")

// Set delete rule
collection["deleteRule"] = nil  // Only superusers

// Save changes
_ = try await client.collections.update("products", body: collection)
```

### Bulk Rule Updates

Set multiple rules at once:

```swift
var collection: JSONRecord = try await client.collections.getOne("products")
collection["listRule"] = AnyCodable("@request.auth.id != \"\"")
collection["viewRule"] = AnyCodable("@request.auth.id != \"\"")
collection["createRule"] = AnyCodable("@request.auth.id != \"\"")
collection["updateRule"] = AnyCodable("@request.auth.id != \"\" && author.id ?= @request.auth.id")
collection["deleteRule"] = nil  // Only superusers

_ = try await client.collections.update("products", body: collection)
```

### Getting Rules

Retrieve all rules for a collection:

```swift
let collection: JSONRecord = try await client.collections.getOne("products")
print(collection["listRule"]?.value as? String ?? "")
print(collection["viewRule"]?.value as? String ?? "")
```

## Filter Syntax

Rules use the same filter syntax as API queries. The syntax follows: `OPERAND OPERATOR OPERAND`

### Operators

- `=` - Equal
- `!=` - NOT equal
- `>` - Greater than
- `>=` - Greater than or equal
- `<` - Less than
- `<=` - Less than or equal
- `~` - Like/Contains (auto-wraps string in `%` for wildcard)
- `!~` - NOT Like/Contains
- `?=` - Any/At least one of Equal
- `?!=` - Any/At least one of NOT equal
- `?>` - Any/At least one of Greater than
- `?>=` - Any/At least one of Greater than or equal
- `?<` - Any/At least one of Less than
- `?<=` - Any/At least one of Less than or equal
- `?~` - Any/At least one of Like/Contains
- `?!~` - Any/At least one of NOT Like/Contains

### Logical Operators

- `&&` - AND
- `||` - OR
- `(...)` - Grouping parentheses

### Field Access

#### Collection Schema Fields

Access fields from your collection schema:

```swift
// Filter by status field
"status = \"active\""

// Access nested relation fields
"author.status != \"banned\""

// Access relation IDs
"author.id ?= @request.auth.id"
```

#### Request Context (`@request.*`)

Access current request data:

```swift
// Authentication state
"@request.auth.id != \"\""  // User is authenticated
"@request.auth.id = \"\""  // User is guest

// Request context
"@request.context != \"oauth2\""  // Not an OAuth2 request

// HTTP method
"@request.method = \"GET\""

// Request headers (normalized: lowercase, "-" replaced with "_")
"@request.headers.x_token = \"test\""

// Query parameters
"@request.query.page = \"1\""

// Body parameters
"@request.body.title != \"\""
```

#### Other Collections (`@collection.*`)

Target other collections that share common field values:

```swift
// Check if user has access in related collection
"@collection.permissions.user ?= @request.auth.id && @collection.permissions.resource = id"
```

### Field Modifiers

#### `:isset` Modifier

Check if a request field was submitted:

```swift
// Prevent changing role field
"@request.body.role:isset = false"
```

#### `:length` Modifier

Check the number of items in an array field:

```swift
// At least 2 items in select field
"@request.body.tags:length > 1"

// Check existing relation field length
"someRelationField:length = 2"
```

#### `:each` Modifier

Apply condition to each item in a multiple field:

```swift
// All select options contain "create"
"@request.body.someSelectField:each ~ \"create\""

// All fields have "pb_" prefix
"someSelectField:each ~ \"pb_%\""
```

#### `:lower` Modifier

Perform case-insensitive string comparisons:

```swift
// Case-insensitive title check
"@request.body.title:lower = \"test\""

// Case-insensitive existing field match
"title:lower ~ \"test\""
```

### DateTime Macros

All macros are UTC-based:

```swift
// Current datetime
"@now"

// Date components
"@second"    // 0-59
"@minute"    // 0-59
"@hour"      // 0-23
"@weekday"   // 0-6
"@day"       // Day number
"@month"     // Month number
"@year"      // Year number

// Relative dates
"@yesterday"
"@tomorrow"
"@todayStart"  // Beginning of current day
"@todayEnd"    // End of current day
"@monthStart"  // Beginning of current month
"@monthEnd"    // End of current month
"@yearStart"   // Beginning of current year
"@yearEnd"     // End of current year
```

Example:

```swift
"@request.body.publicDate >= @now"
"created >= @todayStart && created <= @todayEnd"
```

### Functions

#### `geoDistance(lonA, latA, lonB, latB)`

Calculate Haversine distance between two geographic points in kilometres:

```swift
// Offices within 25km
"geoDistance(address.lon, address.lat, 23.32, 42.69) < 25"
```

## Common Examples

### Allow Only Registered Users

```swift
var collection: JSONRecord = try await client.collections.getOne("products")
collection["listRule"] = AnyCodable("@request.auth.id != \"\"")
collection["viewRule"] = AnyCodable("@request.auth.id != \"\"")
collection["createRule"] = AnyCodable("@request.auth.id != \"\"")
_ = try await client.collections.update("products", body: collection)
```

### Filter by Status

```swift
var collection: JSONRecord = try await client.collections.getOne("products")
collection["listRule"] = AnyCodable("status = \"active\"")
_ = try await client.collections.update("products", body: collection)
```

### Combine Conditions

```swift
var collection: JSONRecord = try await client.collections.getOne("products")
collection["listRule"] = AnyCodable("@request.auth.id != \"\" && (status = \"active\" || status = \"pending\")")
_ = try await client.collections.update("products", body: collection)
```

### Filter by Relation

```swift
// Only show records where user is the author
var collection: JSONRecord = try await client.collections.getOne("posts")
collection["listRule"] = AnyCodable("@request.auth.id != \"\" && author.id ?= @request.auth.id")
_ = try await client.collections.update("posts", body: collection)
```

### Owner-Based Update/Delete

```swift
// Users can only update/delete their own records
var collection: JSONRecord = try await client.collections.getOne("posts")
collection["updateRule"] = AnyCodable("@request.auth.id != \"\" && author.id = @request.auth.id")
collection["deleteRule"] = AnyCodable("@request.auth.id != \"\" && author.id = @request.auth.id")
_ = try await client.collections.update("posts", body: collection)
```

## Best Practices

1. **Start with locked rules** (nil) for security, then gradually open access as needed
2. **Use relation checks** for owner-based access patterns
3. **Combine multiple conditions** using `&&` and `||` for complex scenarios
4. **Test rules thoroughly** before deploying to production
5. **Document your rules** in code comments explaining the business logic
6. **Use empty string (`""`)** only when you truly want public access
7. **Leverage modifiers** (`:isset`, `:length`, `:each`) for validation

## Error Responses

API Rules also act as data filters. When a request doesn't satisfy a rule:

- **listRule** - Returns `200` with empty items (filters out records)
- **createRule** - Returns `400` Bad Request
- **viewRule** - Returns `404` Not Found
- **updateRule** - Returns `404` Not Found
- **deleteRule** - Returns `404` Not Found
- **All rules** - Return `403` Forbidden if locked (nil) and user is not superuser

## Notes

- **Superusers bypass all rules** - Rules are ignored when the action is performed by an authorized superuser
- **Rules are evaluated server-side** - Client-side validation is not enough
- **Comments are supported** - Use `//` for single-line comments in rules
- **System fields protection** - Some fields may be protected regardless of rules

## Related Documentation

- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Detailed filter syntax
- [Collection API](./COLLECTION_API.md) - Collection management
- [Authentication](./AUTHENTICATION.md) - User authentication

