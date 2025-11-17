# Authentication - Swift SDK Documentation

## Overview

Authentication in BosBase is stateless and token-based. A client is considered authenticated as long as it sends a valid `Authorization: YOUR_AUTH_TOKEN` header with requests.

**Key Points:**
- **No sessions**: BosBase APIs are fully stateless (tokens are not stored in the database)
- **No logout endpoint**: To "logout", simply clear the token from your local state (`client.authStore.clear()`)
- **Token generation**: Auth tokens are generated through auth collection Web APIs or programmatically
- **Admin users**: `_superusers` collection works like regular auth collections but with full access (API rules are ignored)
- **OAuth2 limitation**: OAuth2 is not supported for `_superusers` collection

> 📖 **Reference**: This guide mirrors the [JavaScript SDK Authentication documentation](../js-sdk/docs/AUTHENTICATION.md) but uses Swift syntax and examples.

## Authentication Methods

BosBase supports multiple authentication methods that can be configured individually for each auth collection:

1. **Password Authentication** - Email/username + password
2. **OTP Authentication** - One-time password via email
3. **OAuth2 Authentication** - Google, GitHub, Microsoft, etc.
4. **Multi-factor Authentication (MFA)** - Requires 2 different auth methods

## Authentication Store

The SDK maintains an `authStore` that automatically manages the authentication state:

```swift
import BosBase

let client = BosBaseClient(baseURL: URL(string: "http://localhost:8090")!)

// Check authentication status
print(client.authStore.isValid())      // true/false
print(client.authStore.token ?? "")     // current auth token
print(client.authStore.record ?? [:])   // authenticated user record

// Listen for auth changes
client.authStore.onChange = { state in
    print("Auth state changed - Token: \(state.token ?? "nil")")
}

// Clear authentication (logout)
client.authStore.clear()
```

## Password Authentication

Authenticate using email/username and password. The identity field can be configured in the collection options (default is email).

**Backend Endpoint:** `POST /api/collections/{collection}/auth-with-password`

### Basic Usage

```swift
import BosBase

let client = BosBaseClient(baseURL: URL(string: "http://localhost:8090")!)

// Authenticate with email and password
let authData = try await client
    .collection("users")
    .authWithPassword(identity: "test@example.com", password: "password123")

// Auth data is automatically stored in client.authStore
print(client.authStore.isValid())  // true
print(client.authStore.token ?? "") // JWT token
print(client.authStore.record?["id"] ?? "") // user record ID
```

### Response Format

The `authWithPassword` method returns a `RecordAuthResponse` containing:

```swift
struct RecordAuthResponse: Decodable {
    let token: String
    let record: JSONRecord  // Dictionary with user fields
}
```

### Error Handling with MFA

```swift
do {
    let auth = try await client
        .collection("users")
        .authWithPassword(identity: "test@example.com", password: "pass123")
} catch let error as ClientResponseError {
    // Check for MFA requirement
    if let mfaId = error.response?["mfaId"] as? String {
        // Handle MFA flow (see Multi-factor Authentication section)
        print("MFA required: \(mfaId)")
    } else {
        print("Authentication failed: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## OTP Authentication

One-time password authentication via email.

**Backend Endpoints:**
- `POST /api/collections/{collection}/request-otp` - Request OTP
- `POST /api/collections/{collection}/auth-with-otp` - Authenticate with OTP

### Request OTP

```swift
// Request OTP to be sent via email
try await client
    .collection("users")
    .requestOTP(email: "test@example.com")
```

### Authenticate with OTP

```swift
// Authenticate using the OTP ID and password received via email
let auth = try await client
    .collection("users")
    .authWithOTP(otpId: "OTP_ID_FROM_EMAIL", password: "OTP_PASSWORD")
```

## OAuth2 Authentication

OAuth2 authentication supports multiple providers (Google, GitHub, Microsoft, etc.).

**Backend Endpoints:**
- `GET /api/collections/{collection}/auth-with-oauth2` - Get OAuth2 URL
- `POST /api/collections/{collection}/auth-with-oauth2-code` - Complete OAuth2 flow

### OAuth2 with URL Callback

```swift
// Configure OAuth2 authentication
let config = OAuth2AuthConfig(
    provider: "google",
    scopes: ["email", "profile"],
    urlCallback: { url in
        // Open URL in browser or web view
        // On iOS:
        #if canImport(UIKit)
        await UIApplication.shared.open(url)
        #endif
    }
)

// Start OAuth2 flow
let auth = try await client
    .collection("users")
    .authWithOAuth2(config: config)
```

### OAuth2 with Code (Manual Flow)

```swift
// Step 1: Get OAuth2 URL (you handle the redirect manually)
// Step 2: After user authorizes, you receive a code
// Step 3: Complete authentication with the code

let auth = try await client
    .collection("users")
    .authWithOAuth2Code(
        provider: "google",
        code: "AUTHORIZATION_CODE",
        codeVerifier: "CODE_VERIFIER",  // From PKCE flow
        redirectUrl: "https://yourapp.com/callback"
    )
```

## Refresh Authentication

Refresh the current authenticated record and auth token.

```swift
// Refresh the auth token
let auth = try await client
    .collection("users")
    .authRefresh()
```

## Password Reset

### Request Password Reset

```swift
// Send password reset email
try await client
    .collection("users")
    .requestPasswordReset(email: "test@example.com")
```

### Confirm Password Reset

```swift
// Reset password using token from email
try await client
    .collection("users")
    .confirmPasswordReset(
        resetToken: "TOKEN_FROM_EMAIL",
        newPassword: "newpassword123",
        newPasswordConfirm: "newpassword123"
    )
```

## Email Verification

### Request Verification

```swift
// Send verification email
try await client
    .collection("users")
    .requestVerification(email: "test@example.com")
```

### Confirm Verification

```swift
// Verify email using token from email
try await client
    .collection("users")
    .confirmVerification(verificationToken: "TOKEN_FROM_EMAIL")
```

## Email Change

### Request Email Change

```swift
// Request email change (requires authentication)
let auth = try await client
    .collection("users")
    .authWithPassword(identity: "old@example.com", password: "password")

try await client
    .collection("users")
    .requestEmailChange(newEmail: "new@example.com")
```

### Confirm Email Change

```swift
// Confirm email change using token from email
try await client
    .collection("users")
    .confirmEmailChange(
        emailChangeToken: "TOKEN_FROM_EMAIL",
        userPassword: "currentpassword"
    )
```

## List Auth Methods

Get all available authentication methods for a collection:

```swift
let methods = try await client
    .collection("users")
    .listAuthMethods()

// methods contains available auth providers and methods
```

## Impersonation

Impersonate another user (superuser only):

```swift
// Authenticate as superuser first
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "adminpass")

// Impersonate a user
let impersonatedAuth = try await client
    .collection("users")
    .impersonate(recordId: "USER_ID_TO_IMPERSONATE")
```

## Multi-factor Authentication (MFA)

When MFA is enabled, the initial authentication may return an error with `mfaId`:

```swift
do {
    let auth = try await client
        .collection("users")
        .authWithPassword(identity: "test@example.com", password: "pass123")
} catch let error as ClientResponseError {
    if let mfaId = error.response?["mfaId"] as? String {
        // First factor passed, now request OTP for second factor
        try await client
            .collection("users")
            .requestOTP(email: "test@example.com")
        
        // Then authenticate with OTP
        let auth = try await client
            .collection("users")
            .authWithOTP(otpId: mfaId, password: "OTP_PASSWORD")
    }
}
```

## External Auth Providers

### List External Auths

List all linked external auth providers for a record:

```swift
let externalAuths = try await client
    .collection("users")
    .listExternalAuths(recordId: "USER_ID")
```

### Unlink External Auth

Unlink an external auth provider:

```swift
try await client
    .collection("users")
    .unlinkExternalAuth(recordId: "USER_ID", provider: "google")
```

## Complete Example

```swift
import BosBase

// Initialize client
let client = try BosBaseClient(baseURLString: "http://localhost:8090")

// Authenticate user
do {
    let auth = try await client
        .collection("users")
        .authWithPassword(identity: "user@example.com", password: "password123")
    
    print("Authenticated: \(auth.record?["email"] ?? "")")
    
    // Use authenticated client
    let posts: ListResult<JSONRecord> = try await client
        .collection("posts")
        .getList()
    
    print("Fetched \(posts.items.count) posts")
    
    // Refresh token if needed
    let refreshed = try await client
        .collection("users")
        .authRefresh()
    
    // Logout
    client.authStore.clear()
    
} catch let error as ClientResponseError {
    print("Error: \(error.status) - \(error.response ?? [:])")
} catch {
    print("Unexpected error: \(error)")
}
```

## Best Practices

1. **Store tokens securely**: The `AuthStore` keeps tokens in memory by default. For persistence, implement a custom `AuthStore` that saves to Keychain (iOS) or UserDefaults.

2. **Handle token expiration**: Implement automatic token refresh using the `authRefresh()` method.

3. **Error handling**: Always handle `ClientResponseError` for authentication failures.

4. **MFA support**: Check for `mfaId` in error responses when MFA is enabled.

5. **OAuth2 redirects**: Handle OAuth2 redirects properly in your app's URL scheme or universal links.

