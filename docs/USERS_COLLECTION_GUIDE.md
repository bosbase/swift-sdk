# Users Collection Guide - Swift SDK Documentation

This guide explains how to use the built-in `users` collection for authentication, registration, and API rules in the Swift SDK.

## Table of Contents

- [Overview](#overview)
- [Collection Structure](#collection-structure)
- [System Fields](#system-fields)
- [Custom Fields](#custom-fields)
- [Default API Rules](#default-api-rules)
- [User Registration](#user-registration)
- [User Login](#user-login)
- [Using @request.auth in API Rules](#using-requestauth-in-api-rules)
- [Creating Relations to Users](#creating-relations-to-users)
- [Best Practices](#best-practices)

---

## Overview

The `users` collection is a special auth collection that comes pre-configured in BosBase. It provides:
- User authentication (password, OAuth2, OTP)
- User registration
- Email verification
- Password reset
- Built-in API rules for user data access

The `users` collection is automatically created when you set up a new BosBase instance.

---

## Collection Structure

### Get Users Collection Schema

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

let usersCollection: JSONRecord = try await client.collections.getOne("users")

if let name = usersCollection["name"]?.value as? String,
   let type = usersCollection["type"]?.value as? String {
    print("Collection: \(name) (\(type))")
}

if let schema = usersCollection["schema"]?.value as? [JSONRecord] {
    print("Fields: \(schema.count)")
    for field in schema {
        if let fieldName = field["name"]?.value as? String {
            print("  - \(fieldName)")
        }
    }
}
```

---

## System Fields

The `users` collection includes several system fields that are automatically managed:

### id
- **Type**: `text`
- **Description**: Unique record identifier
- **System**: Yes
- **Required**: Yes

### created
- **Type**: `date`
- **Description**: Record creation timestamp
- **System**: Yes
- **Required**: Yes

### updated
- **Type**: `date`
- **Description**: Last update timestamp
- **System**: Yes
- **Required**: Yes

### email
- **Type**: `email`
- **Description**: User's email address (used for authentication)
- **System**: Yes
- **Required**: Yes
- **Unique**: Yes

### verified
- **Type**: `bool`
- **Description**: Email verification status
- **System**: Yes
- **Default**: `false`

### emailVisibility
- **Type**: `bool`
- **Description**: Whether email is visible to other users
- **System**: Yes
- **Default**: `false`

### username
- **Type**: `text`
- **Description**: Unique username (optional)
- **System**: Yes
- **Required**: No
- **Unique**: Yes (if provided)

### name
- **Type**: `text`
- **Description**: User's display name
- **System**: Yes
- **Required**: No

### avatar
- **Type**: `file`
- **Description**: User's profile picture
- **System**: Yes
- **Required**: No

### passwordHash
- **Type**: `text`
- **Description**: Hashed password (never exposed in API responses)
- **System**: Yes
- **Hidden**: Yes

### lastResetSentAt
- **Type**: `date`
- **Description**: Timestamp of last password reset email
- **System**: Yes
- **Hidden**: Yes

### lastVerificationSentAt
- **Type**: `date`
- **Description**: Timestamp of last verification email
- **System**: Yes
- **Hidden**: Yes

---

## Custom Fields

You can add custom fields to the `users` collection:

```swift
// Authenticate as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Get current schema
let usersCollection: JSONRecord = try await client.collections.getOne("users")
var schema = usersCollection["schema"]?.value as? [JSONRecord] ?? []

// Add custom field
schema.append([
    "name": AnyCodable("bio"),
    "type": AnyCodable("text"),
    "required": AnyCodable(false),
    "options": AnyCodable([
        "min": AnyCodable(0),
        "max": AnyCodable(500)
    ])
])

// Update collection
_ = try await client.collections.update("users", body: [
    "schema": AnyCodable(schema)
])
```

**Example Custom Fields:**
```swift
// Add phone number
schema.append([
    "name": AnyCodable("phone"),
    "type": AnyCodable("text"),
    "required": AnyCodable(false)
])

// Add date of birth
schema.append([
    "name": AnyCodable("dateOfBirth"),
    "type": AnyCodable("date"),
    "required": AnyCodable(false)
])

// Add preferences (JSON field)
schema.append([
    "name": AnyCodable("preferences"),
    "type": AnyCodable("json"),
    "required": AnyCodable(false)
])
```

---

## Default API Rules

The `users` collection has default API rules that control access:

### List Rule
- **Default**: `""` (empty - only authenticated users can list)
- **Description**: Controls who can list users

### View Rule
- **Default**: `"id = @request.auth.id"` (users can only view their own record)
- **Description**: Users can only view their own profile

### Create Rule
- **Default**: `""` (empty - anyone can create/register)
- **Description**: Allows public user registration

### Update Rule
- **Default**: `"id = @request.auth.id"` (users can only update their own record)
- **Description**: Users can only update their own profile

### Delete Rule
- **Default**: `"id = @request.auth.id"` (users can only delete their own record)
- **Description**: Users can only delete their own account

### Manage Rule
- **Default**: `""` (empty - only superusers)
- **Description**: Controls who can manage user records (superuser only)

### Auth Rule
- **Default**: `""` (empty - anyone can authenticate)
- **Description**: Controls who can authenticate (public by default)

### Get Current Rules

```swift
let usersCollection: JSONRecord = try await client.collections.getOne("users")

if let options = usersCollection["options"]?.value as? JSONRecord,
   let listRule = options["listRule"]?.value as? String {
    print("List rule: \(listRule)")
}

if let options = usersCollection["options"]?.value as? JSONRecord,
   let viewRule = options["viewRule"]?.value as? String {
    print("View rule: \(viewRule)")
}
```

### Update Rules

```swift
// Authenticate as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Get current options
let usersCollection: JSONRecord = try await client.collections.getOne("users")
var options = usersCollection["options"]?.value as? JSONRecord ?? [:]

// Update rules
options["listRule"] = AnyCodable("verified = true") // Only verified users visible
options["viewRule"] = AnyCodable("id = @request.auth.id || verified = true") // Own record or verified users
options["createRule"] = AnyCodable("") // Public registration
options["updateRule"] = AnyCodable("id = @request.auth.id") // Only own record
options["deleteRule"] = AnyCodable("id = @request.auth.id") // Only own record

// Update collection
_ = try await client.collections.update("users", body: [
    "options": AnyCodable(options)
])
```

---

## User Registration

### Public Registration

Users can register themselves:

```swift
// Register a new user
let record: JSONRecord = try await client
    .collection("users")
    .create(body: [
        "email": AnyCodable("user@example.com"),
        "password": AnyCodable("password123"),
        "passwordConfirm": AnyCodable("password123"),
        "name": AnyCodable("John Doe")
    ])

print("User registered: \(record["id"]?.value ?? "")")
```

### Registration with Email Verification

```swift
// Register user
let record: JSONRecord = try await client
    .collection("users")
    .create(body: [
        "email": AnyCodable("user@example.com"),
        "password": AnyCodable("password123"),
        "passwordConfirm": AnyCodable("password123")
    ])

// Request verification email
try await client
    .collection("users")
    .requestVerification(email: "user@example.com")

// User clicks link in email, then verify
try await client
    .collection("users")
    .confirmVerification(token: "verification-token")
```

### Registration as Superuser

```swift
// Authenticate as superuser first
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Create user (bypasses createRule)
let user: JSONRecord = try await client
    .collection("users")
    .create(body: [
        "email": AnyCodable("user@example.com"),
        "password": AnyCodable("password123"),
        "passwordConfirm": AnyCodable("password123"),
        "verified": AnyCodable(true) // Auto-verify
    ])
```

---

## User Login

### Password Authentication

```swift
let authResult: AuthResult = try await client
    .collection("users")
    .authWithPassword(identity: "user@example.com", password: "password123")

print("Authenticated: \(authResult.record["email"]?.value ?? "")")
print("Token: \(authResult.token)")
```

### OAuth2 Authentication

```swift
// Get OAuth2 providers
let authMethods: AuthMethodsList = try await client
    .collection("users")
    .listAuthMethods()

if let oauth2 = authMethods.oauth2?["google"] {
    // Redirect user to oauth2.url
    // After redirect:
    let authResult: AuthResult = try await client
        .collection("users")
        .authWithOAuth2Code(provider: "google", code: "code-from-redirect")
}
```

### OTP Authentication

```swift
// Request OTP
try await client
    .collection("users")
    .requestOTP(email: "user@example.com")

// Authenticate with OTP
let authResult: AuthResult = try await client
    .collection("users")
    .authWithOTP(email: "user@example.com", otp: "123456")
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

## Using @request.auth in API Rules

The `@request.auth` variable refers to the currently authenticated user record. Use it in API rules to control access based on the authenticated user.

### Example: User-Specific Data

```swift
// Create a collection with user-specific access
let collection: JSONRecord = try await client.collections.create(body: [
    "name": AnyCodable("user_posts"),
    "type": AnyCodable("base"),
    "schema": AnyCodable([
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("user"),
            "type": AnyCodable("relation"),
            "options": AnyCodable([
                "collectionId": AnyCodable("users"),
                "maxSelect": AnyCodable(1)
            ])
        ]
    ]),
    "options": AnyCodable([
        "listRule": AnyCodable("user.id = @request.auth.id"),
        "viewRule": AnyCodable("user.id = @request.auth.id"),
        "createRule": AnyCodable("user.id = @request.auth.id"),
        "updateRule": AnyCodable("user.id = @request.auth.id"),
        "deleteRule": AnyCodable("user.id = @request.auth.id")
    ])
])
```

### Example: Public Read, User Write

```swift
let collection: JSONRecord = try await client.collections.create(body: [
    "name": AnyCodable("posts"),
    "type": AnyCodable("base"),
    "schema": AnyCodable([
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text")
        ],
        [
            "name": AnyCodable("author"),
            "type": AnyCodable("relation"),
            "options": AnyCodable([
                "collectionId": AnyCodable("users"),
                "maxSelect": AnyCodable(1)
            ])
        ]
    ]),
    "options": AnyCodable([
        "listRule": AnyCodable(""), // Public read
        "viewRule": AnyCodable(""), // Public read
        "createRule": AnyCodable("@request.auth.id != ''"), // Authenticated users only
        "updateRule": AnyCodable("author.id = @request.auth.id"), // Only author can update
        "deleteRule": AnyCodable("author.id = @request.auth.id") // Only author can delete
    ])
])
```

### Example: User Profile Access

```swift
// Users can view their own profile and verified users
let usersCollection: JSONRecord = try await client.collections.getOne("users")
var options = usersCollection["options"]?.value as? JSONRecord ?? [:]

options["viewRule"] = AnyCodable("id = @request.auth.id || verified = true")

_ = try await client.collections.update("users", body: [
    "options": AnyCodable(options)
])
```

---

## Creating Relations to Users

### One-to-One Relation

```swift
let collection: JSONRecord = try await client.collections.create(body: [
    "name": AnyCodable("profiles"),
    "type": AnyCodable("base"),
    "schema": AnyCodable([
        [
            "name": AnyCodable("user"),
            "type": AnyCodable("relation"),
            "required": AnyCodable(true),
            "options": AnyCodable([
                "collectionId": AnyCodable("users"),
                "cascadeDelete": AnyCodable(true),
                "maxSelect": AnyCodable(1)
            ])
        ],
        [
            "name": AnyCodable("bio"),
            "type": AnyCodable("text")
        ]
    ])
])
```

### Many-to-Many Relation

```swift
// Create a junction collection for many-to-many
let collection: JSONRecord = try await client.collections.create(body: [
    "name": AnyCodable("user_follows"),
    "type": AnyCodable("base"),
    "schema": AnyCodable([
        [
            "name": AnyCodable("follower"),
            "type": AnyCodable("relation"),
            "required": AnyCodable(true),
            "options": AnyCodable([
                "collectionId": AnyCodable("users"),
                "maxSelect": AnyCodable(1)
            ])
        ],
        [
            "name": AnyCodable("following"),
            "type": AnyCodable("relation"),
            "required": AnyCodable(true),
            "options": AnyCodable([
                "collectionId": AnyCodable("users"),
                "maxSelect": AnyCodable(1)
            ])
        ]
    ]),
    "options": AnyCodable([
        "listRule": AnyCodable("follower.id = @request.auth.id || following.id = @request.auth.id"),
        "createRule": AnyCodable("follower.id = @request.auth.id")
    ])
])
```

### Querying User Relations

```swift
// Get user with related data
let user: JSONRecord = try await client
    .collection("users")
    .getOne("user-id", expand: "profile,posts")

// Get posts by user
let posts: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(
        filter: "author.id = 'user-id'",
        expand: "author"
    )
```

---

## Best Practices

### 1. Email Verification

Always verify user emails for security:

```swift
// After registration
try await client
    .collection("users")
    .requestVerification(email: "user@example.com")

// Check verification status
let user: JSONRecord = try await client
    .collection("users")
    .getOne("user-id")

if let verified = user["verified"]?.value as? Bool, verified {
    print("User is verified")
}
```

### 2. Password Security

Never store passwords in plain text. BosBase handles password hashing automatically:

```swift
// ✅ Correct: Password is hashed automatically
let user: JSONRecord = try await client
    .collection("users")
    .create(body: [
        "email": AnyCodable("user@example.com"),
        "password": AnyCodable("secure-password")
    ])

// ❌ Wrong: Don't try to set passwordHash directly
```

### 3. Access Control

Use API rules to enforce access control:

```swift
// Users can only access their own data
options["listRule"] = AnyCodable("id = @request.auth.id")
options["viewRule"] = AnyCodable("id = @request.auth.id")
options["updateRule"] = AnyCodable("id = @request.auth.id")
```

### 4. Token Management

Tokens are automatically managed by `authStore`:

```swift
// Token is stored automatically after authentication
let authResult: AuthResult = try await client
    .collection("users")
    .authWithPassword(identity: "user@example.com", password: "password")

// Refresh token when needed
try await client.collection("users").authRefresh()

// Clear authentication
client.authStore.clear()
```

### 5. Error Handling

Always handle authentication errors:

```swift
do {
    let authResult = try await client
        .collection("users")
        .authWithPassword(identity: "user@example.com", password: "password")
} catch let error as ClientResponseError {
    if error.status == 400 {
        print("Invalid credentials")
    } else if error.status == 404 {
        print("User not found")
    }
}
```

---

## Complete Example: User Management System

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// 1. Register a new user
let newUser: JSONRecord = try await client
    .collection("users")
    .create(body: [
        "email": AnyCodable("user@example.com"),
        "password": AnyCodable("password123"),
        "passwordConfirm": AnyCodable("password123"),
        "name": AnyCodable("John Doe")
    ])

print("User registered: \(newUser["id"]?.value ?? "")")

// 2. Request email verification
try await client
    .collection("users")
    .requestVerification(email: "user@example.com")

// 3. User logs in
let authResult: AuthResult = try await client
    .collection("users")
    .authWithPassword(identity: "user@example.com", password: "password123")

print("Authenticated: \(authResult.record["email"]?.value ?? "")")

// 4. Update user profile
let updated: JSONRecord = try await client
    .collection("users")
    .update(authResult.record["id"]?.value as? String ?? "", body: [
        "name": AnyCodable("John Updated"),
        "bio": AnyCodable("This is my bio")
    ])

// 5. Get current user
let currentUser: JSONRecord = try await client
    .collection("users")
    .getOne(authResult.record["id"]?.value as? String ?? "")

print("Current user: \(currentUser["name"]?.value ?? "")")

// 6. Create user-specific data
let post: JSONRecord = try await client
    .collection("posts")
    .create(body: [
        "title": AnyCodable("My First Post"),
        "content": AnyCodable("Post content"),
        "author": AnyCodable(authResult.record["id"]?.value as? String ?? "")
    ])

// 7. Get user's posts
let userPosts: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(
        filter: "author.id = '\(authResult.record["id"]?.value as? String ?? "")'",
        expand: "author"
    )

print("User has \(userPosts.totalItems) posts")
```

---

For more information, see:
- [Authentication](./AUTHENTICATION.md) - Detailed authentication guide
- [API Rules](./api-rules.md) - API rules documentation
- [Collections API](./COLLECTION_API.md) - Collection management

