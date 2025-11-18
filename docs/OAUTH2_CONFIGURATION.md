# OAuth2 Configuration - Swift SDK Documentation

This document explains how to configure OAuth2 authentication providers for auth collections using the Swift SDK.

## Table of Contents

- [Overview](#overview)
- [Enabling OAuth2](#enabling-oauth2)
- [Adding Providers](#adding-providers)
- [Configuring Field Mapping](#configuring-field-mapping)
- [Updating Providers](#updating-providers)
- [Removing Providers](#removing-providers)
- [Disabling OAuth2](#disabling-oauth2)
- [Supported Providers](#supported-providers)
- [Important Notes](#important-notes)

---

## Overview

OAuth2 allows users to authenticate using third-party providers (Google, GitHub, etc.) instead of passwords. This guide covers configuring OAuth2 providers for auth collections.

> **Note**: OAuth2 configuration requires superuser authentication (🔐).

---

## Enabling OAuth2

Before adding providers, OAuth2 must be enabled for the auth collection.

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Authenticate as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Enable OAuth2 for the users collection
let collection: JSONRecord = try await client.collections.getOne("users")
var authOptions = collection["options"]?.value as? JSONRecord ?? [:]

var auth = authOptions["auth"]?.value as? JSONRecord ?? [:]
auth["enableOAuth2"] = AnyCodable(true)
authOptions["auth"] = AnyCodable(auth)
collection["options"] = AnyCodable(authOptions)

_ = try await client.collections.update("users", body: [
    "options": AnyCodable(authOptions)
])
```

---

## Adding Providers

### Add Google OAuth2 Provider

```swift
let collection: JSONRecord = try await client.collections.getOne("users")
var authOptions = collection["options"]?.value as? JSONRecord ?? [:]

var auth = authOptions["auth"]?.value as? JSONRecord ?? [:]
var oauth2 = auth["oauth2"]?.value as? JSONRecord ?? [:]

oauth2["google"] = AnyCodable([
    "enabled": AnyCodable(true),
    "clientId": AnyCodable("YOUR_GOOGLE_CLIENT_ID"),
    "clientSecret": AnyCodable("YOUR_GOOGLE_CLIENT_SECRET"),
    "redirectUrl": AnyCodable("http://127.0.0.1:8090/api/collections/users/auth-with-oauth2?provider=google")
])

auth["oauth2"] = AnyCodable(oauth2)
authOptions["auth"] = AnyCodable(auth)

_ = try await client.collections.update("users", body: [
    "options": AnyCodable(authOptions)
])
```

### Add GitHub OAuth2 Provider

```swift
let collection: JSONRecord = try await client.collections.getOne("users")
var authOptions = collection["options"]?.value as? JSONRecord ?? [:]

var auth = authOptions["auth"]?.value as? JSONRecord ?? [:]
var oauth2 = auth["oauth2"]?.value as? JSONRecord ?? [:]

oauth2["github"] = AnyCodable([
    "enabled": AnyCodable(true),
    "clientId": AnyCodable("YOUR_GITHUB_CLIENT_ID"),
    "clientSecret": AnyCodable("YOUR_GITHUB_CLIENT_SECRET"),
    "redirectUrl": AnyCodable("http://127.0.0.1:8090/api/collections/users/auth-with-oauth2?provider=github")
])

auth["oauth2"] = AnyCodable(oauth2)
authOptions["auth"] = AnyCodable(auth)

_ = try await client.collections.update("users", body: [
    "options": AnyCodable(authOptions)
])
```

### Add Facebook OAuth2 Provider

```swift
let collection: JSONRecord = try await client.collections.getOne("users")
var authOptions = collection["options"]?.value as? JSONRecord ?? [:]

var auth = authOptions["auth"]?.value as? JSONRecord ?? [:]
var oauth2 = auth["oauth2"]?.value as? JSONRecord ?? [:]

oauth2["facebook"] = AnyCodable([
    "enabled": AnyCodable(true),
    "clientId": AnyCodable("YOUR_FACEBOOK_APP_ID"),
    "clientSecret": AnyCodable("YOUR_FACEBOOK_APP_SECRET"),
    "redirectUrl": AnyCodable("http://127.0.0.1:8090/api/collections/users/auth-with-oauth2?provider=facebook")
])

auth["oauth2"] = AnyCodable(oauth2)
authOptions["auth"] = AnyCodable(auth)

_ = try await client.collections.update("users", body: [
    "options": AnyCodable(authOptions)
])
```

### Add Discord OAuth2 Provider

```swift
let collection: JSONRecord = try await client.collections.getOne("users")
var authOptions = collection["options"]?.value as? JSONRecord ?? [:]

var auth = authOptions["auth"]?.value as? JSONRecord ?? [:]
var oauth2 = auth["oauth2"]?.value as? JSONRecord ?? [:]

oauth2["discord"] = AnyCodable([
    "enabled": AnyCodable(true),
    "clientId": AnyCodable("YOUR_DISCORD_CLIENT_ID"),
    "clientSecret": AnyCodable("YOUR_DISCORD_CLIENT_SECRET"),
    "redirectUrl": AnyCodable("http://127.0.0.1:8090/api/collections/users/auth-with-oauth2?provider=discord")
])

auth["oauth2"] = AnyCodable(oauth2)
authOptions["auth"] = AnyCodable(auth)

_ = try await client.collections.update("users", body: [
    "options": AnyCodable(authOptions)
])
```

### Add Microsoft OAuth2 Provider

```swift
let collection: JSONRecord = try await client.collections.getOne("users")
var authOptions = collection["options"]?.value as? JSONRecord ?? [:]

var auth = authOptions["auth"]?.value as? JSONRecord ?? [:]
var oauth2 = auth["oauth2"]?.value as? JSONRecord ?? [:]

oauth2["microsoft"] = AnyCodable([
    "enabled": AnyCodable(true),
    "clientId": AnyCodable("YOUR_MICROSOFT_CLIENT_ID"),
    "clientSecret": AnyCodable("YOUR_MICROSOFT_CLIENT_SECRET"),
    "redirectUrl": AnyCodable("http://127.0.0.1:8090/api/collections/users/auth-with-oauth2?provider=microsoft")
])

auth["oauth2"] = AnyCodable(oauth2)
authOptions["auth"] = AnyCodable(auth)

_ = try await client.collections.update("users", body: [
    "options": AnyCodable(authOptions)
])
```

### Add Apple OAuth2 Provider

Apple OAuth2 requires generating a client secret using JWT:

```swift
// First, generate the Apple client secret
let appleSecret = try await client.settings.generateAppleClientSecret(
    clientId: "YOUR_APPLE_CLIENT_ID",
    teamId: "YOUR_APPLE_TEAM_ID",
    keyId: "YOUR_APPLE_KEY_ID",
    privateKey: "YOUR_APPLE_PRIVATE_KEY"
)

// Then configure Apple OAuth2
let collection: JSONRecord = try await client.collections.getOne("users")
var authOptions = collection["options"]?.value as? JSONRecord ?? [:]

var auth = authOptions["auth"]?.value as? JSONRecord ?? [:]
var oauth2 = auth["oauth2"]?.value as? JSONRecord ?? [:]

oauth2["apple"] = AnyCodable([
    "enabled": AnyCodable(true),
    "clientId": AnyCodable("YOUR_APPLE_CLIENT_ID"),
    "clientSecret": AnyCodable(appleSecret),
    "redirectUrl": AnyCodable("http://127.0.0.1:8090/api/collections/users/auth-with-oauth2?provider=apple")
])

auth["oauth2"] = AnyCodable(oauth2)
authOptions["auth"] = AnyCodable(auth)

_ = try await client.collections.update("users", body: [
    "options": AnyCodable(authOptions)
])
```

---

## Configuring Field Mapping

OAuth2 providers return user information that needs to be mapped to collection fields. Configure field mapping when adding or updating providers.

### Example: Map Google Profile Fields

```swift
let collection: JSONRecord = try await client.collections.getOne("users")
var authOptions = collection["options"]?.value as? JSONRecord ?? [:]

var auth = authOptions["auth"]?.value as? JSONRecord ?? [:]
var oauth2 = auth["oauth2"]?.value as? JSONRecord ?? [:]

oauth2["google"] = AnyCodable([
    "enabled": AnyCodable(true),
    "clientId": AnyCodable("YOUR_GOOGLE_CLIENT_ID"),
    "clientSecret": AnyCodable("YOUR_GOOGLE_CLIENT_SECRET"),
    "redirectUrl": AnyCodable("http://127.0.0.1:8090/api/collections/users/auth-with-oauth2?provider=google"),
    "fieldMapping": AnyCodable([
        "email": AnyCodable("email"),
        "name": AnyCodable("name"),
        "avatarUrl": AnyCodable("avatar")
    ])
])

auth["oauth2"] = AnyCodable(oauth2)
authOptions["auth"] = AnyCodable(auth)

_ = try await client.collections.update("users", body: [
    "options": AnyCodable(authOptions)
])
```

### Available OAuth2 Profile Fields

Common fields available from OAuth2 providers:
- `email` - User's email address
- `name` - User's full name
- `username` - Username
- `avatarUrl` - Profile picture URL
- `id` - Provider user ID

Map these to your collection fields as needed.

---

## Updating Providers

Update an existing provider's configuration:

```swift
let collection: JSONRecord = try await client.collections.getOne("users")
var authOptions = collection["options"]?.value as? JSONRecord ?? [:]

var auth = authOptions["auth"]?.value as? JSONRecord ?? [:]
var oauth2 = auth["oauth2"]?.value as? JSONRecord ?? [:]

// Update Google provider
if var google = oauth2["google"]?.value as? JSONRecord {
    google["clientId"] = AnyCodable("NEW_CLIENT_ID")
    google["clientSecret"] = AnyCodable("NEW_CLIENT_SECRET")
    oauth2["google"] = AnyCodable(google)
}

auth["oauth2"] = AnyCodable(oauth2)
authOptions["auth"] = AnyCodable(auth)

_ = try await client.collections.update("users", body: [
    "options": AnyCodable(authOptions)
])
```

---

## Removing Providers

Remove a provider from the OAuth2 configuration:

```swift
let collection: JSONRecord = try await client.collections.getOne("users")
var authOptions = collection["options"]?.value as? JSONRecord ?? [:]

var auth = authOptions["auth"]?.value as? JSONRecord ?? [:]
var oauth2 = auth["oauth2"]?.value as? JSONRecord ?? [:]

// Remove Google provider
oauth2.removeValue(forKey: "google")

auth["oauth2"] = AnyCodable(oauth2)
authOptions["auth"] = AnyCodable(auth)

_ = try await client.collections.update("users", body: [
    "options": AnyCodable(authOptions)
])
```

---

## Disabling OAuth2

Disable OAuth2 for the collection:

```swift
let collection: JSONRecord = try await client.collections.getOne("users")
var authOptions = collection["options"]?.value as? JSONRecord ?? [:]

var auth = authOptions["auth"]?.value as? JSONRecord ?? [:]
auth["enableOAuth2"] = AnyCodable(false)
authOptions["auth"] = AnyCodable(auth)

_ = try await client.collections.update("users", body: [
    "options": AnyCodable(authOptions)
])
```

---

## Supported Providers

The following OAuth2 providers are supported:

- **Google** (`google`)
- **GitHub** (`github`)
- **Facebook** (`facebook`)
- **Discord** (`discord`)
- **Microsoft** (`microsoft`)
- **Apple** (`apple`)
- **Twitter** (`twitter`)
- **Spotify** (`spotify`)
- **Twitch** (`twitch`)
- **Custom** (`custom`) - For custom OAuth2 providers

### Custom Provider Configuration

For custom providers, additional configuration may be required:

```swift
oauth2["custom"] = AnyCodable([
    "enabled": AnyCodable(true),
    "clientId": AnyCodable("YOUR_CLIENT_ID"),
    "clientSecret": AnyCodable("YOUR_CLIENT_SECRET"),
    "redirectUrl": AnyCodable("http://127.0.0.1:8090/api/collections/users/auth-with-oauth2?provider=custom"),
    "authUrl": AnyCodable("https://custom-provider.com/oauth/authorize"),
    "tokenUrl": AnyCodable("https://custom-provider.com/oauth/token"),
    "userApiUrl": AnyCodable("https://custom-provider.com/api/user")
])
```

---

## Important Notes

### Redirect URLs

1. **Exact Match Required**: Redirect URLs must exactly match what's configured in the OAuth2 provider's settings.

2. **Format**: The redirect URL format is:
   ```
   {baseURL}/api/collections/{collectionName}/auth-with-oauth2?provider={providerName}
   ```

3. **HTTPS in Production**: Always use HTTPS redirect URLs in production environments.

### Security

1. **Client Secrets**: Never expose client secrets in client-side code. OAuth2 configuration should only be done server-side with superuser authentication.

2. **HTTPS**: Always use HTTPS in production to protect OAuth2 tokens and user data.

3. **Token Storage**: OAuth2 tokens are automatically stored securely in the `authStore`.

### Testing

1. **Local Development**: Use `http://127.0.0.1:8090` for local development.

2. **Provider Settings**: Ensure your OAuth2 provider application settings include the correct redirect URLs.

3. **Error Handling**: Always handle OAuth2 errors appropriately:

```swift
do {
    let authResult = try await client
        .collection("users")
        .authWithOAuth2Code(provider: "google", code: code)
} catch let error as ClientResponseError {
    if error.status == 400 {
        print("Invalid OAuth2 code or configuration")
    } else if error.status == 401 {
        print("OAuth2 authentication failed")
    }
}
```

---

## Complete Example: Full OAuth2 Setup

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Authenticate as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Get current collection configuration
let collection: JSONRecord = try await client.collections.getOne("users")
var authOptions = collection["options"]?.value as? JSONRecord ?? [:]

// Enable OAuth2
var auth = authOptions["auth"]?.value as? JSONRecord ?? [:]
auth["enableOAuth2"] = AnyCodable(true)

// Configure Google OAuth2
var oauth2 = auth["oauth2"]?.value as? JSONRecord ?? [:]
oauth2["google"] = AnyCodable([
    "enabled": AnyCodable(true),
    "clientId": AnyCodable("YOUR_GOOGLE_CLIENT_ID"),
    "clientSecret": AnyCodable("YOUR_GOOGLE_CLIENT_SECRET"),
    "redirectUrl": AnyCodable("http://127.0.0.1:8090/api/collections/users/auth-with-oauth2?provider=google"),
    "fieldMapping": AnyCodable([
        "email": AnyCodable("email"),
        "name": AnyCodable("name"),
        "avatarUrl": AnyCodable("avatar")
    ])
])

// Configure GitHub OAuth2
oauth2["github"] = AnyCodable([
    "enabled": AnyCodable(true),
    "clientId": AnyCodable("YOUR_GITHUB_CLIENT_ID"),
    "clientSecret": AnyCodable("YOUR_GITHUB_CLIENT_SECRET"),
    "redirectUrl": AnyCodable("http://127.0.0.1:8090/api/collections/users/auth-with-oauth2?provider=github")
])

auth["oauth2"] = AnyCodable(oauth2)
authOptions["auth"] = AnyCodable(auth)

// Update collection
_ = try await client.collections.update("users", body: [
    "options": AnyCodable(authOptions)
])

print("OAuth2 configuration updated successfully")

// Verify configuration
let updated: JSONRecord = try await client.collections.getOne("users")
if let options = updated["options"]?.value as? JSONRecord,
   let auth = options["auth"]?.value as? JSONRecord,
   let oauth2 = auth["oauth2"]?.value as? JSONRecord {
    print("Enabled providers:")
    for (key, value) in oauth2 {
        if let provider = value.value as? JSONRecord,
           provider["enabled"]?.value as? Bool == true {
            print("  - \(key)")
        }
    }
}
```

---

## Using OAuth2 Authentication

After configuration, users can authenticate using OAuth2:

```swift
// 1. Get available OAuth2 providers
let authMethods: AuthMethodsList = try await client
    .collection("users")
    .listAuthMethods()

if let oauth2 = authMethods.oauth2 {
    // 2. Redirect user to OAuth2 URL
    for (provider, config) in oauth2 {
        if let url = config["url"]?.value as? String {
            print("\(provider) OAuth2 URL: \(url)")
            // Open this URL in a browser
        }
    }
    
    // 3. After redirect, authenticate with the code
    let authResult: AuthResult = try await client
        .collection("users")
        .authWithOAuth2Code(provider: "google", code: "code-from-redirect")
    
    print("Authenticated user: \(authResult.record["email"]?.value ?? "")")
}
```

---

For more information, see:
- [Authentication](./AUTHENTICATION.md) - General authentication guide
- [Collections API](./COLLECTION_API.md) - Collection management
- [Management API](./MANAGEMENT_API.md) - Settings management

