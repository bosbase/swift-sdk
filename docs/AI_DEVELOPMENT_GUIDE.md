# AI Development Guide - Swift SDK

This guide provides a fast reference for AI systems using the BosBase Swift SDK. It covers the most common operations needed when building AI applications.

## Table of Contents

- [Authentication](#authentication)
- [Initializing and Defining Collections](#initializing-and-defining-collections)
- [Adding Data](#adding-data)
- [Modifying Data](#modifying-data)
- [Deleting Data](#deleting-data)
- [Querying Collection Contents](#querying-collection-contents)
- [Querying Field Information](#querying-field-information)
- [Uploading Files](#uploading-files)
- [Querying Logs](#querying-logs)
- [Sending Emails](#sending-emails)

---

## Authentication

### Initialize Client

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")
```

### Authenticate with Password

```swift
let authResult: AuthResult = try await client
    .collection("users")
    .authWithPassword(identity: "user@example.com", password: "password123")

print("Authenticated user: \(authResult.record["email"]?.value ?? "")")
```

### Authenticate with OAuth2

```swift
// First, get the OAuth2 URL
let authMethods: AuthMethodsList = try await client
    .collection("users")
    .listAuthMethods()

if let oauth2 = authMethods.oauth2?["google"] {
    // Redirect user to oauth2.url
    // After redirect, use the code:
    let authResult: AuthResult = try await client
        .collection("users")
        .authWithOAuth2Code(provider: "google", code: "code-from-redirect")
}
```

### Check Authentication Status

```swift
if let authRecord = client.authStore.record {
    print("Authenticated as: \(authRecord["email"]?.value ?? "")")
} else {
    print("Not authenticated")
}
```

---

## Initializing and Defining Collections

### Create a Base Collection

```swift
let collection: JSONRecord = try await client.collections.create(body: [
    "name": AnyCodable("posts"),
    "type": AnyCodable("base"),
    "schema": AnyCodable([
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("content"),
            "type": AnyCodable("editor"),
            "required": AnyCodable(false)
        ],
        [
            "name": AnyCodable("author"),
            "type": AnyCodable("relation"),
            "options": AnyCodable([
                "collectionId": AnyCodable("users"),
                "cascadeDelete": AnyCodable(true),
                "maxSelect": AnyCodable(1)
            ])
        ]
    ])
])
```

### Create an Auth Collection

```swift
let authCollection: JSONRecord = try await client.collections.create(body: [
    "name": AnyCodable("users"),
    "type": AnyCodable("auth"),
    "schema": AnyCodable([
        [
            "name": AnyCodable("email"),
            "type": AnyCodable("email"),
            "required": AnyCodable(true),
            "unique": AnyCodable(true)
        ],
        [
            "name": AnyCodable("name"),
            "type": AnyCodable("text"),
            "required": AnyCodable(false)
        ]
    ])
])
```

### Get Collection Schema

```swift
let collection: JSONRecord = try await client.collections.getOne("posts")
if let schema = collection["schema"]?.value as? [JSONRecord] {
    for field in schema {
        if let name = field["name"]?.value as? String,
           let type = field["type"]?.value as? String {
            print("Field: \(name), Type: \(type)")
        }
    }
}
```

---

## Adding Data

### Create a Single Record

```swift
let record: JSONRecord = try await client
    .collection("posts")
    .create(body: [
        "title": AnyCodable("My First Post"),
        "content": AnyCodable("This is the content of my post"),
        "author": AnyCodable("user-id-123")
    ])

print("Created record: \(record["id"]?.value ?? "")")
```

### Create Multiple Records (Batch)

```swift
let batch = client.createBatch()

let record1 = batch.collection("posts").create(body: [
    "title": AnyCodable("Post 1"),
    "content": AnyCodable("Content 1")
])

let record2 = batch.collection("posts").create(body: [
    "title": AnyCodable("Post 2"),
    "content": AnyCodable("Content 2")
])

let results = try await batch.submit()
// results is an array of responses in the same order as requests
```

### Create with Relations

```swift
let post: JSONRecord = try await client
    .collection("posts")
    .create(body: [
        "title": AnyCodable("My Post"),
        "content": AnyCodable("Post content"),
        "author": AnyCodable("user-id-123"),
        "tags": AnyCodable(["tag1", "tag2", "tag3"])
    ])
```

---

## Modifying Data

### Update a Record

```swift
let updated: JSONRecord = try await client
    .collection("posts")
    .update("record-id", body: [
        "title": AnyCodable("Updated Title"),
        "content": AnyCodable("Updated content")
    ])
```

### Update Multiple Records

```swift
let batch = client.createBatch()

batch.collection("posts").update("id1", body: ["title": AnyCodable("New Title 1")])
batch.collection("posts").update("id2", body: ["title": AnyCodable("New Title 2")])

let results = try await batch.submit()
```

### Partial Update

```swift
// Only update specific fields
let updated: JSONRecord = try await client
    .collection("posts")
    .update("record-id", body: [
        "title": AnyCodable("New Title")
        // Other fields remain unchanged
    ])
```

---

## Deleting Data

### Delete a Single Record

```swift
try await client
    .collection("posts")
    .delete("record-id")
```

### Delete Multiple Records

```swift
let batch = client.createBatch()

batch.collection("posts").delete("id1")
batch.collection("posts").delete("id2")
batch.collection("posts").delete("id3")

try await batch.submit()
```

### Delete with Filter

```swift
// Delete all records matching a filter
let records: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(filter: "status = 'draft'")

if let items = records.items {
    for record in items {
        if let id = record["id"]?.value as? String {
            try await client.collection("posts").delete(id)
        }
    }
}
```

---

## Querying Collection Contents

### List Records (Paginated)

```swift
let result: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(page: 1, perPage: 20)

if let items = result.items {
    print("Total: \(result.totalItems), Page: \(result.page)")
    for record in items {
        print("Record: \(record)")
    }
}
```

### Get All Records

```swift
let allRecords: [JSONRecord] = try await client
    .collection("posts")
    .getFullList(batch: 100) // Process in batches of 100

print("Total records: \(allRecords.count)")
```

### Get Single Record

```swift
let record: JSONRecord = try await client
    .collection("posts")
    .getOne("record-id")

print("Title: \(record["title"]?.value ?? "")")
```

### Filter Records

```swift
let result: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(
        filter: "status = 'published' && created >= '2024-01-01'",
        sort: "-created",
        expand: "author"
    )
```

### Filter with Relations

```swift
// Get posts by a specific author
let result: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(
        filter: "author.id = 'user-id-123'",
        expand: "author"
    )
```

### Search Records

```swift
// Full-text search (if enabled on text fields)
let result: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(
        filter: "title ~ 'search term'"
    )
```

### Get Record Count

```swift
let count: Int = try await client
    .collection("posts")
    .getCount(filter: "status = 'published'")

print("Published posts: \(count)")
```

---

## Querying Field Information

### Get Collection Schema

```swift
let collection: JSONRecord = try await client.collections.getOne("posts")
if let schema = collection["schema"]?.value as? [JSONRecord] {
    for field in schema {
        if let name = field["name"]?.value as? String,
           let type = field["type"]?.value as? String {
            print("\(name): \(type)")
            
            // Check field options
            if let options = field["options"]?.value as? JSONRecord {
                print("  Options: \(options)")
            }
        }
    }
}
```

### Check Field Type

```swift
let collection: JSONRecord = try await client.collections.getOne("posts")
if let schema = collection["schema"]?.value as? [JSONRecord] {
    if let titleField = schema.first(where: { ($0["name"]?.value as? String) == "title" }) {
        if let type = titleField["type"]?.value as? String {
            print("Title field type: \(type)")
        }
    }
}
```

### Get Relation Information

```swift
let collection: JSONRecord = try await client.collections.getOne("posts")
if let schema = collection["schema"]?.value as? [JSONRecord] {
    if let authorField = schema.first(where: { ($0["name"]?.value as? String) == "author" }) {
        if let options = authorField["options"]?.value as? JSONRecord {
            if let collectionId = options["collectionId"]?.value as? String {
                print("Author relates to collection: \(collectionId)")
            }
        }
    }
}
```

---

## Uploading Files

### Upload a File

```swift
let fileData = try Data(contentsOf: URL(fileURLWithPath: "/path/to/image.jpg"))
let formData = MultipartFormData()
formData.append(name: "file", fileData: fileData, fileName: "image.jpg", mimeType: "image/jpeg")

let record: JSONRecord = try await client
    .collection("posts")
    .update("record-id", body: [
        "image": AnyCodable(formData)
    ])
```

### Upload Multiple Files

```swift
let file1Data = try Data(contentsOf: URL(fileURLWithPath: "/path/to/file1.jpg"))
let file2Data = try Data(contentsOf: URL(fileURLWithPath: "/path/to/file2.jpg"))

let formData = MultipartFormData()
formData.append(name: "file", fileData: file1Data, fileName: "file1.jpg", mimeType: "image/jpeg")
formData.append(name: "file", fileData: file2Data, fileName: "file2.jpg", mimeType: "image/jpeg")

let record: JSONRecord = try await client
    .collection("posts")
    .update("record-id", body: [
        "images": AnyCodable(formData)
    ])
```

### Get File URL

```swift
if let fileId = record["image"]?.value as? String {
    let fileURL = client.files.getURL(
        recordId: "record-id",
        filename: fileId,
        collection: "posts"
    )
    print("File URL: \(fileURL)")
}
```

### Get File URL with Thumbnail

```swift
if let fileId = record["image"]?.value as? String {
    let thumbnailURL = client.files.getURL(
        recordId: "record-id",
        filename: fileId,
        collection: "posts",
        thumb: "100x100"
    )
    print("Thumbnail URL: \(thumbnailURL)")
}
```

---

## Querying Logs

### Get Recent Logs

```swift
// Authenticate as superuser first
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

let logs: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    filter: "level > 0", // Only errors
    sort: "-created"
)

if let items = logs["items"]?.value as? [JSONRecord] {
    for log in items {
        if let message = log["message"]?.value as? String {
            print("Error: \(message)")
        }
    }
}
```

### Get Log Statistics

```swift
let stats: [JSONRecord] = try await client.logs.getStats()

for stat in stats {
    if let total = stat["total"]?.value as? Int,
       let date = stat["date"]?.value as? String {
        print("\(date): \(total) requests")
    }
}
```

---

## Sending Emails

### Configure SMTP Settings

```swift
// Authenticate as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Update SMTP settings
_ = try await client.settings.update(body: [
    "smtp": AnyCodable([
        "enabled": AnyCodable(true),
        "host": AnyCodable("smtp.example.com"),
        "port": AnyCodable(587),
        "username": AnyCodable("user@example.com"),
        "password": AnyCodable("password"),
        "authMethod": AnyCodable("PLAIN"),
        "tls": AnyCodable(true)
    ]),
    "meta": AnyCodable([
        "senderName": AnyCodable("My App"),
        "senderAddress": AnyCodable("noreply@example.com")
    ])
])
```

### Test Email Configuration

```swift
try await client.settings.testEmail(
    toEmail: "test@example.com",
    template: "verification"
)
```

### Trigger Email via Auth Actions

Emails are automatically sent when using auth actions:

```swift
// Request password reset (sends email)
try await client
    .collection("users")
    .requestPasswordReset(email: "user@example.com")

// Request email verification (sends email)
try await client
    .collection("users")
    .requestVerification(email: "user@example.com")
```

---

## Complete Example: AI Content Management System

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Authenticate
try await client
    .collection("users")
    .authWithPassword(identity: "ai@example.com", password: "password")

// Create a post
let post: JSONRecord = try await client
    .collection("posts")
    .create(body: [
        "title": AnyCodable("AI Generated Post"),
        "content": AnyCodable("This post was generated by an AI system"),
        "status": AnyCodable("published"),
        "author": AnyCodable(client.authStore.record?["id"]?.value as? String ?? "")
    ])

print("Created post: \(post["id"]?.value ?? "")")

// Upload an image
if let imagePath = "/path/to/image.jpg" as String?,
   let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)) {
    let formData = MultipartFormData()
    formData.append(name: "file", fileData: imageData, fileName: "image.jpg", mimeType: "image/jpeg")
    
    let updated: JSONRecord = try await client
        .collection("posts")
        .update(post["id"]?.value as? String ?? "", body: [
            "image": AnyCodable(formData)
        ])
    
    print("Image uploaded")
}

// Query posts
let posts: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(
        filter: "status = 'published'",
        sort: "-created",
        page: 1,
        perPage: 10
    )

print("Found \(posts.totalItems) published posts")
```

---

## Best Practices

1. **Error Handling**: Always wrap API calls in `do-catch` blocks:

```swift
do {
    let record = try await client.collection("posts").getOne("id")
} catch let error as ClientResponseError {
    print("API Error: \(error.status) - \(error.response ?? [:])")
} catch {
    print("Unexpected error: \(error)")
}
```

2. **Batch Operations**: Use batch operations for multiple requests to improve performance:

```swift
let batch = client.createBatch()
// Add multiple operations
let results = try await batch.submit()
```

3. **Pagination**: Always use pagination for large datasets:

```swift
let result = try await client.collection("posts").getList(page: 1, perPage: 50)
```

4. **Authentication**: Store auth tokens securely and refresh when needed:

```swift
// Token is automatically stored in authStore
// Refresh when needed:
try await client.collection("users").authRefresh()
```

5. **File Uploads**: Use appropriate MIME types and file sizes:

```swift
// Check file size before uploading
if fileData.count > 10 * 1024 * 1024 { // 10MB
    print("File too large")
    return
}
```

---

For more detailed information, see:
- [Authentication](./AUTHENTICATION.md)
- [Records API](./API_RECORDS.md)
- [Collections API](./COLLECTION_API.md)
- [Files API](./FILE_API.md)

