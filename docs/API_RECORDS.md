# API Records - Swift SDK Documentation

## Overview

The Records API provides comprehensive CRUD (Create, Read, Update, Delete) operations for collection records, along with powerful search, filtering, and authentication capabilities.

**Key Features:**
- Paginated list and search with filtering and sorting
- Single record retrieval with expand support
- Create, update, and delete operations
- Batch operations for multiple records
- Authentication methods (password, OAuth2, OTP)
- Email verification and password reset
- Relation expansion up to 6 levels deep
- Field selection and excerpt modifiers

**Backend Endpoints:**
- `GET /api/collections/{collection}/records` - List records
- `GET /api/collections/{collection}/records/{id}` - View record
- `POST /api/collections/{collection}/records` - Create record
- `PATCH /api/collections/{collection}/records/{id}` - Update record
- `DELETE /api/collections/{collection}/records/{id}` - Delete record
- `POST /api/batch` - Batch operations

## CRUD Operations

### List/Search Records

Returns a paginated records list with support for sorting, filtering, and expansion.

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Basic list with pagination
let result: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(page: 1, perPage: 50)

print(result.page)        // 1
print(result.perPage)     // 50
print(result.totalItems)  // 150
print(result.totalPages)  // 3
print(result.items)       // Array of records
```

#### Advanced List with Filtering and Sorting

```swift
// Filter and sort
let result: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(
        page: 1,
        perPage: 50,
        filter: "created >= \"2022-01-01 00:00:00\" && status = \"published\"",
        sort: "-created,title",  // DESC by created, ASC by title
        expand: "author,categories"
    )

// Filter with operators
let result2: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(
        page: 1,
        perPage: 50,
        filter: "title ~ \"javascript\" && views > 100",
        sort: "-views"
    )
```

#### Get Full List

Fetch all records at once (useful for small collections):

```swift
// Get all records
let allPosts: [JSONRecord] = try await client
    .collection("posts")
    .getFullList(
        filter: "status = \"published\"",
        sort: "-created"
    )

// With batch size for large collections
let allPosts: [JSONRecord] = try await client
    .collection("posts")
    .getFullList(
        batchSize: 200,
        sort: "-created"
    )
```

#### Get First Matching Record

Get only the first record that matches a filter:

```swift
let post: JSONRecord = try await client
    .collection("posts")
    .getFirstListItem(
        filter: "slug = \"my-post-slug\"",
        expand: "author,categories.tags"
    )
```

### View Record

Retrieve a single record by ID:

```swift
// Basic retrieval
let record: JSONRecord = try await client
    .collection("posts")
    .getOne("RECORD_ID")

// With expanded relations
let record: JSONRecord = try await client
    .collection("posts")
    .getOne("RECORD_ID", expand: "author,categories,tags")

// Nested expand
let record: JSONRecord = try await client
    .collection("comments")
    .getOne("COMMENT_ID", expand: "post.author,user")

// Field selection
let record: JSONRecord = try await client
    .collection("posts")
    .getOne("RECORD_ID", fields: "id,title,content,author.name")
```

### Create Record

Create a new record:

```swift
// Simple create
let record: JSONRecord = try await client
    .collection("posts")
    .create(body: [
        "title": AnyCodable("My First Post"),
        "content": AnyCodable("Lorem ipsum..."),
        "status": AnyCodable("draft")
    ])

// Create with relations
let record: JSONRecord = try await client
    .collection("posts")
    .create(body: [
        "title": AnyCodable("My Post"),
        "author": AnyCodable("AUTHOR_ID"),           // Single relation
        "categories": AnyCodable(["cat1", "cat2"])     // Multiple relation
    ])

// Create with file upload (multipart/form-data)
let formData = MultipartFormData()
formData.append(name: "title", value: "My Post")
formData.append(name: "image", fileData: imageData, fileName: "image.jpg", mimeType: "image/jpeg")

let record: JSONRecord = try await client
    .collection("posts")
    .create(body: .multipartData(formData))

// Create with expand to get related data immediately
let record: JSONRecord = try await client
    .collection("posts")
    .create(
        body: [
            "title": AnyCodable("My Post"),
            "author": AnyCodable("AUTHOR_ID")
        ],
        expand: "author"
    )
```

### Update Record

Update an existing record:

```swift
// Simple update
let record: JSONRecord = try await client
    .collection("posts")
    .update("RECORD_ID", body: [
        "title": AnyCodable("Updated Title"),
        "status": AnyCodable("published")
    ])

// Update with relations
try await client
    .collection("posts")
    .update("RECORD_ID", body: [
        "categories+": AnyCodable("NEW_CATEGORY_ID"),  // Append
        "tags-": AnyCodable("OLD_TAG_ID")               // Remove
    ])

// Update with file upload
let formData = MultipartFormData()
formData.append(name: "title", value: "Updated Title")
formData.append(name: "image", fileData: newFileData, fileName: "new.jpg", mimeType: "image/jpeg")

let record: JSONRecord = try await client
    .collection("posts")
    .update("RECORD_ID", body: .multipartData(formData))

// Update with expand
let record: JSONRecord = try await client
    .collection("posts")
    .update("RECORD_ID", body: [
        "title": AnyCodable("Updated")
    ], expand: "author,categories")
```

### Delete Record

Delete a record:

```swift
// Simple delete
try await client
    .collection("posts")
    .delete("RECORD_ID")

// Note: Returns true on success
// Throws error if record doesn't exist or permission denied
```

## Filter Syntax

The filter parameter supports a powerful query syntax:

### Comparison Operators

```swift
// Equal
filter: "status = \"published\""

// Not equal
filter: "status != \"draft\""

// Greater than / Less than
filter: "views > 100"
filter: "created < \"2023-01-01\""

// Greater/Less than or equal
filter: "age >= 18"
filter: "price <= 99.99"
```

### String Operators

```swift
// Contains (like)
filter: "title ~ \"javascript\""
// Equivalent to: title LIKE "%javascript%"

// Not contains
filter: "title !~ \"deprecated\""

// Exact match (case-sensitive)
filter: "email = \"user@example.com\""
```

### Array Operators (for multiple relations/files)

```swift
// Any of / At least one
filter: "tags.id ?= \"TAG_ID\""         // Any tag matches
filter: "tags.name ?~ \"important\""    // Any tag name contains "important"

// All must match
filter: "tags.id = \"TAG_ID\" && tags.id = \"TAG_ID2\""
```

### Logical Operators

```swift
// AND
filter: "status = \"published\" && views > 100"

// OR
filter: "status = \"published\" || status = \"featured\""

// Parentheses for grouping
filter: "(status = \"published\" || featured = true) && views > 50"
```

## Sorting

Sort records using the `sort` parameter:

```swift
// Single field (ASC)
sort: "created"

// Single field (DESC)
sort: "-created"

// Multiple fields
sort: "-created,title"  // DESC by created, then ASC by title

// Supported fields
sort: "@random"         // Random order
sort: "@rowid"          // Internal row ID
sort: "id"              // Record ID
sort: "fieldName"       // Any collection field

// Relation field sorting
sort: "author.name"     // Sort by related author's name
```

## Field Selection

Control which fields are returned:

```swift
// Specific fields
fields: "id,title,content"

// All fields at level
fields: "*"

// Nested field selection
fields: "*,author.name,author.email"

// Excerpt modifier for text fields
fields: "*,content:excerpt(200,true)"
// Returns first 200 characters with ellipsis if truncated

// Combined
fields: "*,content:excerpt(200),author.name,author.email"
```

## Expanding Relations

Expand related records without additional API calls:

```swift
// Single relation
expand: "author"

// Multiple relations
expand: "author,categories,tags"

// Nested relations (up to 6 levels)
expand: "author.profile,categories.tags"

// Back-relations
expand: "comments_via_post.user"
```

See [Relations Documentation](./RELATIONS.md) for detailed information.

## Pagination Options

```swift
// Skip total count (faster queries)
let result: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(
        page: 1,
        perPage: 50,
        skipTotal: true,  // totalItems and totalPages will be -1
        filter: "status = \"published\""
    )

// Get Full List with batch processing
let allPosts: [JSONRecord] = try await client
    .collection("posts")
    .getFullList(
        batchSize: 200,
        sort: "-created"
    )
// Processes in batches of 200 to avoid memory issues
```

## Batch Operations

Execute multiple operations in a single transaction:

```swift
// Create a batch
let batch = client.createBatch()

// Add operations
try batch
    .collection("posts")
    .create(body: [
        "title": AnyCodable("Post 1"),
        "author": AnyCodable("AUTHOR_ID")
    ])

try batch
    .collection("posts")
    .create(body: [
        "title": AnyCodable("Post 2"),
        "author": AnyCodable("AUTHOR_ID")
    ])

try batch
    .collection("tags")
    .update("TAG_ID", body: [
        "name": AnyCodable("Updated Tag")
    ])

try batch
    .collection("categories")
    .delete("CAT_ID")

// Send batch request
let results = try await batch.send()

// Results is an array matching the order of operations
for (index, result) in results.enumerated() {
    if let status = result["status"]?.value as? Int, status >= 400 {
        print("Operation \(index) failed: \(result)")
    } else {
        print("Operation \(index) succeeded: \(result)")
    }
}
```

**Note**: Batch operations must be enabled in Dashboard > Settings > Application.

## Authentication Actions

### List Auth Methods

Get available authentication methods for a collection:

```swift
let methods: JSONRecord = try await client
    .collection("users")
    .listAuthMethods()

print(methods["password"]?["enabled"] ?? false)      // true/false
print(methods["oauth2"]?["enabled"] ?? false)       // true/false
print(methods["oauth2"]?["providers"] ?? [])         // Array of OAuth2 providers
print(methods["otp"]?["enabled"] ?? false)          // true/false
print(methods["mfa"]?["enabled"] ?? false)           // true/false
```

### Auth with Password

```swift
let authData: RecordAuthResponse<JSONRecord> = try await client
    .collection("users")
    .authWithPassword(
        identity: "user@example.com",  // username or email
        password: "password123"
    )

// Auth data is automatically stored in client.authStore
print(client.authStore.isValid())    // true
print(client.authStore.token ?? "")  // JWT token
print(client.authStore.record?["id"] ?? "")  // User ID

// Access the returned data
print(authData.token)
print(authData.record)

// With expand
let authData: RecordAuthResponse<JSONRecord> = try await client
    .collection("users")
    .authWithPassword(
        identity: "user@example.com",
        password: "password123",
        expand: "profile"
    )
```

### Auth with OAuth2

```swift
// Step 1: Get OAuth2 URL (usually done in UI)
let methods: JSONRecord = try await client
    .collection("users")
    .listAuthMethods()

// Step 2: After redirect, exchange code for token
let authData: RecordAuthResponse<JSONRecord> = try await client
    .collection("users")
    .authWithOAuth2Code(
        provider: "google",                    // Provider name
        code: "AUTHORIZATION_CODE",            // From redirect URL
        codeVerifier: "CODE_VERIFIER",         // From step 1
        redirectURL: "https://yourapp.com/callback", // Redirect URL
        createData: [                          // Optional data for new accounts
            "name": AnyCodable("John Doe")
        ]
    )
```

### Auth with OTP (One-Time Password)

```swift
// Step 1: Request OTP
let otpRequest: OTPResponse = try await client
    .collection("users")
    .requestOTP(email: "user@example.com")
// Returns: OTPResponse with otpId

// Step 2: User enters OTP from email
// Step 3: Authenticate with OTP
let authData: RecordAuthResponse<JSONRecord> = try await client
    .collection("users")
    .authWithOTP(
        otpId: otpRequest.otpId,
        password: "123456"  // OTP from email
    )
```

### Auth Refresh

Refresh the current auth token and get updated user data:

```swift
// Refresh auth (useful on app launch)
let authData: RecordAuthResponse<JSONRecord> = try await client
    .collection("users")
    .authRefresh()

// Check if still valid
if client.authStore.isValid() {
    print("User is authenticated")
} else {
    print("Token expired or invalid")
}
```

### Email Verification

```swift
// Request verification email
try await client
    .collection("users")
    .requestVerification(email: "user@example.com")

// Confirm verification (on verification page)
try await client
    .collection("users")
    .confirmVerification(token: "VERIFICATION_TOKEN")
```

### Password Reset

```swift
// Request password reset email
try await client
    .collection("users")
    .requestPasswordReset(email: "user@example.com")

// Confirm password reset (on reset page)
// Note: This invalidates all previous auth tokens
try await client
    .collection("users")
    .confirmPasswordReset(
        token: "RESET_TOKEN",
        password: "newpassword123",
        passwordConfirm: "newpassword123"
    )
```

### Email Change

```swift
// Must be authenticated first
try await client
    .collection("users")
    .authWithPassword(identity: "user@example.com", password: "password")

// Request email change
try await client
    .collection("users")
    .requestEmailChange(newEmail: "newemail@example.com")

// Confirm email change (on confirmation page)
// Note: This invalidates all previous auth tokens
try await client
    .collection("users")
    .confirmEmailChange(
        token: "EMAIL_CHANGE_TOKEN",
        password: "currentpassword"
    )
```

### Impersonate (Superuser Only)

Generate a token to authenticate as another user:

```swift
// Must be authenticated as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Impersonate a user
let impersonateAuth: RecordAuthResponse<JSONRecord> = try await client
    .collection("users")
    .impersonate(recordId: "USER_ID", duration: 3600)
// Returns auth data with impersonated user's token

// Use the impersonated token
client.authStore.save(token: impersonateAuth.token, record: impersonateAuth.record)

// Access the token
print(client.authStore.token ?? "")
print(client.authStore.record ?? [:])
```

## Complete Examples

### Example 1: Blog Post Search with Filters

```swift
func searchPosts(query: String, categoryId: String?, minViews: Int?) async throws -> [JSONRecord] {
    var filter = "title ~ \"\(query)\" || content ~ \"\(query)\""
    
    if let categoryId {
        filter += " && categories.id ?= \"\(categoryId)\""
    }
    
    if let minViews {
        filter += " && views >= \(minViews)"
    }
    
    let result: ListResult<JSONRecord> = try await client
        .collection("posts")
        .getList(
            page: 1,
            perPage: 20,
            filter: filter,
            sort: "-created",
            expand: "author,categories"
        )
    
    return result.items
}
```

### Example 2: User Dashboard with Related Content

```swift
func getUserDashboard(userId: String) async throws -> [String: [JSONRecord]] {
    // Get user's posts
    let posts: ListResult<JSONRecord> = try await client
        .collection("posts")
        .getList(
            page: 1,
            perPage: 10,
            filter: "author = \"\(userId)\"",
            sort: "-created",
            expand: "categories"
        )
    
    // Get user's comments
    let comments: ListResult<JSONRecord> = try await client
        .collection("comments")
        .getList(
            page: 1,
            perPage: 10,
            filter: "user = \"\(userId)\"",
            sort: "-created",
            expand: "post"
        )
    
    return [
        "posts": posts.items,
        "comments": comments.items
    ]
}
```

### Example 3: Advanced Filtering

```swift
// Complex filter example
let result: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(
        page: 1,
        perPage: 50,
        filter: """
            (status = "published" || featured = true) &&
            created >= "2023-01-01" &&
            (tags.id ?= "important" || categories.id = "news") &&
            views > 100 &&
            author.email != ""
        """,
        sort: "-views,created",
        expand: "author.profile,tags,categories",
        fields: "*,content:excerpt(300),author.name,author.email"
    )
```

### Example 4: Batch Create Posts

```swift
func createMultiplePosts(postsData: [[String: AnyCodable]]) async throws -> [JSONRecord] {
    let batch = client.createBatch()
    
    for postData in postsData {
        try batch
            .collection("posts")
            .create(body: postData)
    }
    
    let results = try await batch.send()
    
    // Check for failures
    let failures = results.enumerated().compactMap { index, result -> (Int, JSONRecord)? in
        if let status = result["status"]?.value as? Int, status >= 400 {
            return (index, result)
        }
        return nil
    }
    
    if !failures.isEmpty {
        print("Some posts failed to create: \(failures)")
    }
    
    return results.compactMap { $0["body"]?.value as? JSONRecord }
}
```

## Error Handling

```swift
do {
    let record: JSONRecord = try await client
        .collection("posts")
        .create(body: [
            "title": AnyCodable("My Post")
        ])
} catch let error as ClientResponseError {
    if error.status == 400 {
        // Validation error
        print("Validation errors: \(error.response ?? [:])")
    } else if error.status == 403 {
        // Permission denied
        print("Access denied")
    } else if error.status == 404 {
        // Not found
        print("Collection or record not found")
    } else {
        print("Unexpected error: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Best Practices

1. **Use Pagination**: Always use pagination for large datasets
2. **Skip Total When Possible**: Use `skipTotal: true` for better performance when you don't need counts
3. **Batch Operations**: Use batch for multiple operations to reduce round trips
4. **Field Selection**: Only request fields you need to reduce payload size
5. **Expand Wisely**: Only expand relations you actually use
6. **Filter Before Sort**: Apply filters before sorting for better performance
7. **Cache Auth Tokens**: Auth tokens are automatically stored in `authStore`, no need to manually cache
8. **Handle Errors**: Always handle authentication and permission errors gracefully

## Related Documentation

- [Collections](./COLLECTIONS.md) - Collection configuration
- [Relations](./RELATIONS.md) - Working with relations
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Filter syntax details
- [Authentication](./AUTHENTICATION.md) - Detailed authentication guide
- [Files](./FILES.md) - File uploads and handling

