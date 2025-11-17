# Working with Relations - Swift SDK Documentation

## Overview

Relations allow you to link records between collections. BosBase supports both single and multiple relations, and provides powerful features for expanding related records and working with back-relations.

**Key Features:**
- Single and multiple relations
- Expand related records without additional requests
- Nested relation expansion (up to 6 levels)
- Back-relations for reverse lookups
- Field modifiers for append/prepend/remove operations

> 📖 **Reference**: This guide mirrors the [JavaScript SDK Relations documentation](../js-sdk/docs/RELATIONS.md) but uses Swift syntax and examples.

**Relation Field Types:**
- **Single Relation**: Links to one record (MaxSelect <= 1)
- **Multiple Relation**: Links to multiple records (MaxSelect > 1)

**Backend Behavior:**
- Relations are stored as record IDs or arrays of IDs
- Expand only includes relations the client can view (satisfies View API Rule)
- Back-relations use format: `collectionName_via_fieldName`
- Back-relation expand limited to 1000 records per field

## Setting Up Relations

### Creating a Relation Field

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://localhost:8090")
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Get collection
var collection: JSONRecord = try await client.collections.getOne("posts")

// Add single relation field
var fields = collection["fields"] as? [[String: AnyCodable]] ?? []
fields.append([
    "name": AnyCodable("user"),
    "type": AnyCodable("relation"),
    "collectionId": AnyCodable("users"),  // ID of related collection
    "maxSelect": AnyCodable(1),           // Single relation
    "required": AnyCodable(true)
])

// Add multiple relation field
fields.append([
    "name": AnyCodable("tags"),
    "type": AnyCodable("relation"),
    "collectionId": AnyCodable("tags"),
    "maxSelect": AnyCodable(10),          // Multiple relation (max 10)
    "minSelect": AnyCodable(1),            // Minimum 1 required
    "cascadeDelete": AnyCodable(false)    // Don't delete post when tags deleted
])

// Update collection
try await client.collections.update("posts", body: ["fields": AnyCodable(fields)])
```

## Creating Records with Relations

### Single Relation

```swift
// Create a post with a single user relation
let post: JSONRecord = try await client
    .collection("posts")
    .create(body: [
        "title": AnyCodable("My Post"),
        "user": AnyCodable("USER_ID")  // Single relation ID
    ])
```

### Multiple Relations

```swift
// Create a post with multiple tags
let post: JSONRecord = try await client
    .collection("posts")
    .create(body: [
        "title": AnyCodable("My Post"),
        "tags": AnyCodable(["TAG_ID1", "TAG_ID2", "TAG_ID3"])  // Array of IDs
    ])
```

### Mixed Relations

```swift
// Create a comment with both single and multiple relations
let comment: JSONRecord = try await client
    .collection("comments")
    .create(body: [
        "message": AnyCodable("Great post!"),
        "post": AnyCodable("POST_ID"),        // Single relation
        "user": AnyCodable("USER_ID"),        // Single relation
        "tags": AnyCodable(["TAG1", "TAG2"])  // Multiple relation
    ])
```

## Updating Relations

### Replace All Relations

```swift
// Replace all tags
let updated: JSONRecord = try await client
    .collection("posts")
    .update("POST_ID", body: [
        "tags": AnyCodable(["NEW_TAG1", "NEW_TAG2"])
    ])
```

### Append Relations (Using + Modifier)

```swift
// Append tags to existing ones
let updated: JSONRecord = try await client
    .collection("posts")
    .update("POST_ID", body: [
        "tags+": AnyCodable("NEW_TAG_ID")  // Append single tag
    ])

// Append multiple tags
let updated2: JSONRecord = try await client
    .collection("posts")
    .update("POST_ID", body: [
        "tags+": AnyCodable(["TAG_ID1", "TAG_ID2"])  // Append multiple tags
    ])
```

### Prepend Relations (Using + Prefix)

```swift
// Prepend tags (tags will appear first)
let updated: JSONRecord = try await client
    .collection("posts")
    .update("POST_ID", body: [
        "+tags": AnyCodable("PRIORITY_TAG")  // Prepend single tag
    ])

// Prepend multiple tags
let updated2: JSONRecord = try await client
    .collection("posts")
    .update("POST_ID", body: [
        "+tags": AnyCodable(["TAG1", "TAG2"])  // Prepend multiple tags
    ])
```

### Remove Relations (Using - Modifier)

```swift
// Remove single tag
let updated: JSONRecord = try await client
    .collection("posts")
    .update("POST_ID", body: [
        "tags-": AnyCodable("TAG_ID_TO_REMOVE")
    ])

// Remove multiple tags
let updated2: JSONRecord = try await client
    .collection("posts")
    .update("POST_ID", body: [
        "tags-": AnyCodable(["TAG1", "TAG2"])
    ])
```

### Complete Example

```swift
// Get existing post
let post: JSONRecord = try await client
    .collection("posts")
    .getOne("POST_ID")

if let tags = post["tags"]?.value as? [String] {
    print("Current tags: \(tags)")  // ['tag1', 'tag2']
}

// Remove one tag, add two new ones
let updated: JSONRecord = try await client
    .collection("posts")
    .update("POST_ID", body: [
        "tags-": AnyCodable("tag1"),           // Remove
        "tags+": AnyCodable(["tag3", "tag4"])   // Append
    ])

let updatedPost: JSONRecord = try await client
    .collection("posts")
    .getOne("POST_ID")

if let newTags = updatedPost["tags"]?.value as? [String] {
    print("Updated tags: \(newTags)")  // ['tag2', 'tag3', 'tag4']
}
```

## Expanding Relations

The `expand` parameter allows you to fetch related records in a single request, eliminating the need for multiple API calls.

### Basic Expand

```swift
// Get comment with expanded user
let comment: JSONRecord = try await client
    .collection("comments")
    .getOne("COMMENT_ID", expand: "user")

if let expand = comment["expand"]?.value as? [String: AnyCodable],
   let user = expand["user"]?.value as? [String: AnyCodable],
   let name = user["name"]?.value as? String {
    print("User name: \(name)")  // "John Doe"
}

// The relation field still contains the ID
if let userId = comment["user"]?.value as? String {
    print("User ID: \(userId)")  // "USER_ID"
}
```

### Expand Multiple Relations

```swift
// Expand multiple relations (comma-separated)
let comment: JSONRecord = try await client
    .collection("comments")
    .getOne("COMMENT_ID", expand: "user,post")

if let expand = comment["expand"]?.value as? [String: AnyCodable] {
    if let user = expand["user"]?.value as? [String: AnyCodable],
       let userName = user["name"]?.value as? String {
        print("User: \(userName)")  // "John Doe"
    }
    
    if let post = expand["post"]?.value as? [String: AnyCodable],
       let postTitle = post["title"]?.value as? String {
        print("Post: \(postTitle)")  // "My Post"
    }
}
```

### Nested Expand (Dot Notation)

You can expand nested relations up to 6 levels deep using dot notation:

```swift
// Expand post and its tags, and user
let comment: JSONRecord = try await client
    .collection("comments")
    .getOne("COMMENT_ID", expand: "user,post.tags")

if let expand = comment["expand"]?.value as? [String: AnyCodable],
   let post = expand["post"]?.value as? [String: AnyCodable],
   let postExpand = post["expand"]?.value as? [String: AnyCodable],
   let tags = postExpand["tags"]?.value as? [[String: AnyCodable]] {
    // Array of tag records
    print("Tags: \(tags.count)")
}

// Expand even deeper
let post: JSONRecord = try await client
    .collection("posts")
    .getOne("POST_ID", expand: "user,comments.user")

// Access: post.expand.comments[0].expand.user
```

### Expand with List Requests

```swift
// List comments with expanded users
let comments: ListResult<JSONRecord> = try await client
    .collection("comments")
    .getList(page: 1, perPage: 20, expand: "user")

for comment in comments.items {
    if let message = comment["message"]?.value as? String {
        print("Message: \(message)")
    }
    
    if let expand = comment["expand"]?.value as? [String: AnyCodable],
       let user = expand["user"]?.value as? [String: AnyCodable],
       let name = user["name"]?.value as? String {
        print("User: \(name)")
    }
}
```

### Expand Single vs Multiple Relations

```swift
// Single relation - expand.user is an object
let post: JSONRecord = try await client
    .collection("posts")
    .getOne("POST_ID", expand: "user")

if let expand = post["expand"]?.value as? [String: AnyCodable],
   let user = expand["user"]?.value as? [String: AnyCodable] {
    print("User is an object: \(user)")
}

// Multiple relation - expand.tags is an array
let postWithTags: JSONRecord = try await client
    .collection("posts")
    .getOne("POST_ID", expand: "tags")

if let expand = postWithTags["expand"]?.value as? [String: AnyCodable],
   let tags = expand["tags"]?.value as? [[String: AnyCodable]] {
    print("Tags is an array: \(tags.count) items")
}
```

### Expand Permissions

**Important**: Only relations that satisfy the related collection's `viewRule` will be expanded. If you don't have permission to view a related record, it won't appear in the expand.

```swift
// If you don't have view permission for user, expand.user will be undefined
let comment: JSONRecord = try await client
    .collection("comments")
    .getOne("COMMENT_ID", expand: "user")

if let expand = comment["expand"]?.value as? [String: AnyCodable],
   let user = expand["user"]?.value as? [String: AnyCodable] {
    if let name = user["name"]?.value as? String {
        print("User name: \(name)")
    }
} else {
    print("User not accessible or not found")
}
```

## Back-Relations

Back-relations allow you to query and expand records that reference the current record through a relation field.

### Back-Relation Syntax

The format is: `collectionName_via_fieldName`

- `collectionName`: The collection that contains the relation field
- `fieldName`: The name of the relation field that points to your record

### Example: Posts with Comments

```swift
// Get a post and expand all comments that reference it
let post: JSONRecord = try await client
    .collection("posts")
    .getOne("POST_ID", expand: "comments_via_post")

// comments_via_post is always an array (even if original field is single)
if let expand = post["expand"]?.value as? [String: AnyCodable],
   let comments = expand["comments_via_post"]?.value as? [[String: AnyCodable]] {
    // Array of comment records
    print("Comments: \(comments.count)")
}
```

### Back-Relation with Nested Expand

```swift
// Get post with comments, and expand each comment's user
let post: JSONRecord = try await client
    .collection("posts")
    .getOne("POST_ID", expand: "comments_via_post.user")

// Access nested expands
if let expand = post["expand"]?.value as? [String: AnyCodable],
   let comments = expand["comments_via_post"]?.value as? [[String: AnyCodable]] {
    for comment in comments {
        if let message = comment["message"]?.value as? String {
            print("Comment: \(message)")
        }
        
        if let commentExpand = comment["expand"]?.value as? [String: AnyCodable],
           let user = commentExpand["user"]?.value as? [String: AnyCodable],
           let userName = user["name"]?.value as? String {
            print("User: \(userName)")
        }
    }
}
```

### Filtering with Back-Relations

```swift
// List posts that have at least one comment containing "hello"
let posts: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(
        page: 1,
        perPage: 20,
        filter: "comments_via_post.message ?~ 'hello'",
        expand: "comments_via_post.user"
    )
```

## Complete Example

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://localhost:8090")

// Authenticate
try await client
    .collection("users")
    .authWithPassword(identity: "user@example.com", password: "password123")

// Create post with relations
let post: JSONRecord = try await client
    .collection("posts")
    .create(body: [
        "title": AnyCodable("My First Post"),
        "content": AnyCodable("This is the content"),
        "user": AnyCodable("USER_ID"),  // Single relation
        "tags": AnyCodable(["TAG1", "TAG2"])  // Multiple relations
    ])

// Get post with expanded relations
let postWithRelations: JSONRecord = try await client
    .collection("posts")
    .getOne(post["id"] as! String, expand: "user,tags,comments_via_post.user")

// Access expanded data
if let expand = postWithRelations["expand"]?.value as? [String: AnyCodable] {
    // Single relation - object
    if let user = expand["user"]?.value as? [String: AnyCodable],
       let userName = user["name"]?.value as? String {
        print("Author: \(userName)")
    }
    
    // Multiple relation - array
    if let tags = expand["tags"]?.value as? [[String: AnyCodable]] {
        print("Tags: \(tags.count)")
        for tag in tags {
            if let tagName = tag["name"]?.value as? String {
                print("  - \(tagName)")
            }
        }
    }
    
    // Back-relation - array
    if let comments = expand["comments_via_post"]?.value as? [[String: AnyCodable]] {
        print("Comments: \(comments.count)")
        for comment in comments {
            if let message = comment["message"]?.value as? String {
                print("  Comment: \(message)")
            }
            
            // Nested expand
            if let commentExpand = comment["expand"]?.value as? [String: AnyCodable],
               let user = commentExpand["user"]?.value as? [String: AnyCodable],
               let userName = user["name"]?.value as? String {
                print("    By: \(userName)")
            }
        }
    }
}

// Update relations
let updated: JSONRecord = try await client
    .collection("posts")
    .update(post["id"] as! String, body: [
        "tags+": AnyCodable("NEW_TAG"),  // Append
        "tags-": AnyCodable("OLD_TAG")    // Remove
    ])
```

## Related Documentation

- [Collections](./COLLECTIONS.md)
- [API Rules and Filters](./API_RULES_AND_FILTERS.md)

