# Scripts API - Swift SDK

`client.scripts` exposes superuser-only helpers for storing and executing function code under `/api/scripts`. Versions auto-increment on updates. Execution permissions are managed via `client.scriptPermissions`.

**Table fields**: `id`, `name`, `content`, `description?`, `version`, `created`, `updated`.

## Authenticate as superuser

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")
try await client.collection("_superusers").authWithPassword(identity: "admin@example.com", password: "password")
```

## Create and read scripts

```swift
let script = try await client.scripts.create(
    name: "hello.py",
    content: """
    def main():
        print("Hello from functions!")
    """
)

print(script.id)
print(script.version) // 1

let fetched = try await client.scripts.get("hello.py")
print(fetched.content)

let all = try await client.scripts.list()
print(all.map { ($0.name, $0.version) })
```

## Update (auto-versioned)

```swift
let updated = try await client.scripts.update(
    "hello.py",
    content: """
    def main():
        print("Hi from functions!")
    """
)
print(updated.version) // previous version + 1

// Update description only
_ = try await client.scripts.update("hello.py", description: "Docs-only tweak")
```

## Execute scripts

```swift
let result = try await client.scripts.execute("hello.py")
print(result.output) // stdout/stderr from the script
```

Execution permission defaults to superuser-only unless you create a rule in `scriptPermissions`:

```swift
_ = try await client.scriptPermissions.create(scriptName: "hello.py", content: "user")
let perm = try await client.scriptPermissions.get("hello.py")
print(perm.content) // "user"

_ = try await client.scriptPermissions.update("hello.py", content: "anonymous")
_ = try await client.scriptPermissions.delete("hello.py") // back to superuser-only
```

## Run shell commands in functions directory

```swift
let commandResult = try await client.scripts.command("cat pyproject.toml")
print(commandResult.output)
```

Notes:
- Script CRUD, `command`, and permission management require superuser authentication.
- Permissions accept `anonymous`, `user`, or `superuser` (default when no rule exists).
- Execution runs inside the configured `EXECUTE_PATH` (default `/pb/functions`) and returns combined stdout/stderr.
