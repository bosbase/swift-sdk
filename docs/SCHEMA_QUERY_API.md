# Schema Query API - Swift SDK Documentation

The Schema Query API provides lightweight interfaces to retrieve collection field information without fetching full collection schemas.

## Table of Contents

- [Overview](#overview)
- [Get Collection Schema](#get-collection-schema)
- [Get All Collection Schemas](#get-all-collection-schemas)
- [Type Definitions](#type-definitions)
- [Use Cases](#use-cases)
- [Performance Considerations](#performance-considerations)

---

## Overview

The Schema Query API allows you to query collection field information efficiently. This is particularly useful for:
- AI systems that need to understand data structure
- Code generation tools
- Dynamic form builders
- API documentation generators

Unlike the full Collection API, the Schema Query API returns only essential field information, making it faster and more efficient.

---

## Get Collection Schema

Get the schema for a specific collection:

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Get schema for a specific collection
let schema: JSONRecord = try await client.collections.getSchema("posts")
if let fields = schema["fields"]?.value as? [JSONRecord] {
    for field in fields {
        let name = field["name"]?.value as? String ?? ""
        let type = field["type"]?.value as? String ?? ""
        let required = field["required"]?.value as? Bool ?? false
        print("\(name): \(type) (required: \(required))")
    }
}
```

**Response Structure:**
```swift
// Each field contains:
{
    "id": "field-id",
    "name": "field-name",
    "type": "field-type",
    "required": true,
    "system": false,
    "hidden": false
}
```

**Example:**
```swift
let schema: JSONRecord = try await client.collections.getSchema("posts")

if let fields = schema["fields"]?.value as? [JSONRecord] {
    for field in fields {
        if let name = field["name"]?.value as? String,
           let type = field["type"]?.value as? String,
           let required = field["required"]?.value as? Bool {
            print("Field: \(name)")
            print("  Type: \(type)")
            print("  Required: \(required)")
            
            // Check field options
            if let options = field["options"]?.value as? JSONRecord {
                print("  Options: \(options)")
            }
        }
    }
}
```

---

## Get All Collection Schemas

Get schemas for all collections:

```swift
let schemas = try await client.collections.getAllSchemas()

if let collections = schemas["collections"]?.value as? [JSONRecord] {
    for collection in collections {
        let name = collection["name"]?.value as? String ?? ""
        let type = collection["type"]?.value as? String ?? ""
        let fields = collection["fields"]?.value as? [JSONRecord] ?? []

        print("Collection: \(name) (\(type))")
        print("  Fields: \(fields.count)")

        for field in fields {
            let fieldName = field["name"]?.value as? String ?? ""
            let fieldType = field["type"]?.value as? String ?? ""
            print("    - \(fieldName): \(fieldType)")
        }
    }
}
```

---

## Type Definitions

### Field Types

Common field types and their structure:

#### Text Fields
```swift
{
    "name": "title",
    "type": "text",
    "required": true,
    "options": {
        "min": 0,
        "max": 255,
        "pattern": ""
    }
}
```

#### Number Fields
```swift
{
    "name": "price",
    "type": "number",
    "required": false,
    "options": {
        "min": 0,
        "max": 1000,
        "noDecimal": false
    }
}
```

#### Boolean Fields
```swift
{
    "name": "published",
    "type": "bool",
    "required": false,
    "options": {}
}
```

#### Date Fields
```swift
{
    "name": "created",
    "type": "date",
    "required": false,
    "options": {
        "min": "",
        "max": ""
    }
}
```

#### Select Fields
```swift
{
    "name": "status",
    "type": "select",
    "required": true,
    "options": {
        "maxSelect": 1,
        "values": ["draft", "published", "archived"]
    }
}
```

#### Relation Fields
```swift
{
    "name": "author",
    "type": "relation",
    "required": false,
    "options": {
        "collectionId": "users",
        "cascadeDelete": true,
        "maxSelect": 1,
        "displayFields": ["name", "email"]
    }
}
```

#### File Fields
```swift
{
    "name": "image",
    "type": "file",
    "required": false,
    "options": {
        "maxSelect": 1,
        "maxSize": 5242880,
        "mimeTypes": ["image/jpeg", "image/png"]
    }
}
```

---

## Use Cases

### AI Systems

AI systems can use schema information to understand data structure and generate appropriate queries:

```swift
func getCollectionInfo(collectionName: String) async throws -> [String: Any] {
    let schema: JSONRecord = try await client.collections.getSchema(collectionName)
    
    var info: [String: Any] = [:]
    
    if let name = schema["name"]?.value as? String {
        info["name"] = name
    }
    
    if let type = schema["type"]?.value as? String {
        info["type"] = type
    }
    
    if let fields = schema["fields"]?.value as? [JSONRecord] {
        var fieldInfo: [[String: Any]] = []
        
        for field in fields {
            var fieldData: [String: Any] = [:]
            
            if let name = field["name"]?.value as? String {
                fieldData["name"] = name
            }
            
            if let type = field["type"]?.value as? String {
                fieldData["type"] = type
            }
            
            if let required = field["required"]?.value as? Bool {
                fieldData["required"] = required
            }
            
            fieldInfo.append(fieldData)
        }
        
        info["fields"] = fieldInfo
    }
    
    return info
}

// Use in AI system
let postsInfo = try await getCollectionInfo(collectionName: "posts")
let fieldCount = (postsInfo["fields"] as? [[String: Any]])?.count ?? 0
print("Posts collection has \(fieldCount) fields")
```

### Code Generation

Generate type-safe models from schema:

```swift
func generateSwiftModel(collectionName: String) async throws -> String {
    let schema: JSONRecord = try await client.collections.getSchema(collectionName)
    
    var model = "struct \(collectionName.capitalized): Codable {\n"
    
    if let fields = schema["fields"]?.value as? [JSONRecord] {
        for field in fields {
            if let name = field["name"]?.value as? String,
               let type = field["type"]?.value as? String {
                let swiftType = mapFieldTypeToSwift(type)
                let optional = (field["required"]?.value as? Bool) == false ? "?" : ""
                model += "    let \(name): \(swiftType)\(optional)\n"
            }
        }
    }
    
    model += "}\n"
    return model
}

func mapFieldTypeToSwift(_ type: String) -> String {
    switch type {
    case "text", "email", "url", "editor": return "String"
    case "number": return "Double"
    case "bool": return "Bool"
    case "date": return "Date"
    case "select": return "String"
    case "relation": return "String"
    case "file": return "String"
    default: return "Any"
    }
}
```

### Dynamic Form Builders

Build forms dynamically based on schema:

```swift
func buildFormFields(collectionName: String) async throws -> [[String: Any]] {
    let schema: JSONRecord = try await client.collections.getSchema(collectionName)
    
    var formFields: [[String: Any]] = []
    
    if let fields = schema["fields"]?.value as? [JSONRecord] {
        for field in fields {
            if let name = field["name"]?.value as? String,
               let type = field["type"]?.value as? String,
               let required = field["required"]?.value as? Bool {
                
                var formField: [String: Any] = [
                    "name": name,
                    "type": type,
                    "required": required
                ]
                
                // Add type-specific options
                if let options = field["options"]?.value as? JSONRecord {
                    formField["options"] = options
                }
                
                formFields.append(formField)
            }
        }
    }
    
    return formFields
}
```

### API Documentation

Generate API documentation from schemas:

```swift
func generateAPIDocs() async throws -> String {
    let schemas = try await client.collections.getAllSchemas()
    
    var docs = "# API Documentation\n\n"
    
    if let collections = schemas["collections"]?.value as? [JSONRecord] {
        for collection in collections {
            if let name = collection["name"]?.value as? String,
               let type = collection["type"]?.value as? String {
                docs += "## \(name) Collection (\(type))\n\n"
                
                if let fields = collection["fields"]?.value as? [JSONRecord] {
                    docs += "### Fields\n\n"
                    docs += "| Name | Type | Required |\n"
                    docs += "|------|------|----------|\n"
                    
                    for field in fields {
                        if let fieldName = field["name"]?.value as? String,
                           let fieldType = field["type"]?.value as? String,
                           let required = field["required"]?.value as? Bool {
                            docs += "| \(fieldName) | \(fieldType) | \(required ? "Yes" : "No") |\n"
                        }
                    }
                    
                    docs += "\n"
                }
            }
        }
    }
    
    return docs
}
```

---

## Performance Considerations

### Caching

Cache schema information to avoid repeated API calls:

```swift
class SchemaCache {
    private var cache: [String: JSONRecord] = [:]
    private let client: BosBaseClient
    
    init(client: BosBaseClient) {
        self.client = client
    }
    
    func getSchema(collectionName: String) async throws -> JSONRecord {
        if let cached = cache[collectionName] {
            return cached
        }
        
        let schema: JSONRecord = try await client.collections.getSchema(collectionName)
        cache[collectionName] = schema
        return schema
    }
    
    func invalidate(collectionName: String) {
        cache.removeValue(forKey: collectionName)
    }
    
    func invalidateAll() {
        cache.removeAll()
    }
}

// Usage
let schemaCache = SchemaCache(client: client)
let schema = try await schemaCache.getSchema(collectionName: "posts")
```

### Batch Schema Queries

When querying multiple collections, reuse the `getAllSchemas()` payload instead of issuing one request per collection:

```swift
func getSchemas(collectionNames: [String]) async throws -> [String: JSONRecord] {
    let response = try await client.collections.getAllSchemas()
    let targets = Set(collectionNames.map { $0.lowercased() })

    var result: [String: JSONRecord] = [:]
    if let collections = response["collections"]?.value as? [JSONRecord] {
        for collection in collections {
            if let name = collection["name"]?.value as? String,
               targets.contains(name.lowercased()) {
                result[name] = collection
            }
        }
    }

    return result
}
```

### Selective Field Queries

Only query the fields you need:

```swift
// Get only field names and types
let schema: JSONRecord = try await client.collections.getSchema("posts")
if let fields = schema["fields"]?.value as? [JSONRecord] {
    let fieldInfo = fields.compactMap { field -> (String, String)? in
        guard let name = field["name"]?.value as? String,
              let type = field["type"]?.value as? String else {
            return nil
        }
        return (name, type)
    }
    
    print("Fields: \(fieldInfo)")
}
```

---

## Complete Example: Schema Analyzer

```swift
import BosBase

class SchemaAnalyzer {
    let client: BosBaseClient
    
    init(client: BosBaseClient) {
        self.client = client
    }
    
    func analyzeCollection(_ collectionName: String) async throws -> [String: Any] {
        let schema: JSONRecord = try await client.collections.getSchema(collectionName)
        
        var analysis: [String: Any] = [:]
        
        // Basic info
        if let name = schema["name"]?.value as? String {
            analysis["name"] = name
        }
        
        if let type = schema["type"]?.value as? String {
            analysis["type"] = type
        }
        
        // Field analysis
        if let fields = schema["fields"]?.value as? [JSONRecord] {
            var fieldStats: [String: Int] = [:]
            var requiredCount = 0
            var relationCount = 0
            
            for field in fields {
                if let fieldType = field["type"]?.value as? String {
                    fieldStats[fieldType, default: 0] += 1
                    
                    if fieldType == "relation" {
                        relationCount += 1
                    }
                }
                
                if field["required"]?.value as? Bool == true {
                    requiredCount += 1
                }
            }
            
            analysis["totalFields"] = fields.count
            analysis["requiredFields"] = requiredCount
            analysis["relationFields"] = relationCount
            analysis["fieldTypes"] = fieldStats
        }
        
        return analysis
    }
    
    func compareCollections(_ names: [String]) async throws -> [[String: Any]] {
        var analyses: [[String: Any]] = []
        
        for name in names {
            let analysis = try await analyzeCollection(name)
            analyses.append(analysis)
        }
        
        return analyses
    }
}

// Usage
let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")
let analyzer = SchemaAnalyzer(client: client)

let analysis = try await analyzer.analyzeCollection("posts")
print("Collection analysis: \(analysis)")

let comparisons = try await analyzer.compareCollections(["posts", "users", "comments"])
for comp in comparisons {
    print("\(comp["name"] ?? ""): \(comp["totalFields"] ?? 0) fields")
}
```

---

## Error Handling

Always handle errors when querying schemas:

```swift
do {
    let schema: JSONRecord = try await client.collections.getSchema("posts")
    // Process schema
} catch let error as ClientResponseError {
    if error.status == 404 {
        print("Collection not found")
    } else if error.status == 403 {
        print("Access denied")
    } else {
        print("Error: \(error.response ?? [:])")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

---

For more information, see:
- [Collections API](./COLLECTION_API.md) - Full collection management
- [AI Development Guide](./AI_DEVELOPMENT_GUIDE.md) - Using schemas in AI systems
