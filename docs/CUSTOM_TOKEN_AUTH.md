# Custom Token Binding and Login (Swift SDK)

Bind your own application token to an auth record (users or `_superusers`) and authenticate with it later. Tokens are stored hashed on the server and enforced per collection.

**Endpoints**
- `POST /api/collections/{collection}/bind-token`
- `POST /api/collections/{collection}/unbind-token`
- `POST /api/collections/{collection}/auth-with-token`

## Bind a token

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// regular user
try await client
    .collection("users")
    .bindCustomToken(email: "user@example.com", password: "hunter2", token: "my-device-token")

// superuser
try await client
    .collection("_superusers")
    .bindCustomToken(email: "admin@example.com", password: "admin123", token: "admin-device-token")
```

## Unbind a token

```swift
// stop accepting the token for the user
try await client
    .collection("users")
    .unbindCustomToken(email: "user@example.com", password: "hunter2", token: "my-device-token")

// stop accepting a superuser token
try await client
    .collection("_superusers")
    .unbindCustomToken(email: "admin@example.com", password: "admin123", token: "admin-device-token")
```

## Authenticate with a token

```swift
// login using the previously bound token
let auth: RecordAuthResponse<JSONRecord> = try await client
    .collection("users")
    .authWithToken(token: "my-device-token")

print(auth.token)   // BosBase auth token
print(auth.record)  // Authenticated record payload

// superuser login via token
let adminAuth: RecordAuthResponse<JSONRecord> = try await client
    .collection("_superusers")
    .authWithToken(token: "admin-device-token")
```

Notes:
- Binding and unbinding require verifying the account email and password.
- The same token value can be used for either collection, but authentication is restricted to the collection you call.
- MFA and collection rules still apply when logging in with a token.
