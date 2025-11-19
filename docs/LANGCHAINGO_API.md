# LangChaingo API - Swift SDK Documentation

## Overview

BosBase exposes the `/api/langchaingo` endpoints so you can run LangChainGo powered workflows without leaving the platform. The Swift SDK wraps these endpoints with the `client.langchaingo` service.

The service exposes four high-level methods:

| Method | HTTP Endpoint | Description |
| --- | --- | --- |
| `client.langchaingo.completions()` | `POST /api/langchaingo/completions` | Runs a chat/completion call using the configured LLM provider. |
| `client.langchaingo.rag()` | `POST /api/langchaingo/rag` | Runs a retrieval-augmented generation pass over an `llmDocuments` collection. |
| `client.langchaingo.queryDocuments()` | `POST /api/langchaingo/documents/query` | Asks an OpenAI-backed chain to answer questions over `llmDocuments` and optionally return matched sources. |
| `client.langchaingo.sql()` | `POST /api/langchaingo/sql` | Lets OpenAI draft and execute SQL against your BosBase database, then returns the results. |

All methods accept an optional `model` configuration:

```swift
struct LangChaingoModelConfig {
    var provider: String?  // "openai" | "ollama" | string
    var model: String?
    var apiKey: String?
    var baseUrl: String?
}
```

If you omit the `model` section, BosBase defaults to `provider: "openai"` and `model: "gpt-4o-mini"` with credentials read from the server environment. Passing an `apiKey` lets you override server defaults on a per-request basis.

## Text + Chat Completions

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://localhost:8090")

let completion: LangChaingoCompletionResponse = try await client.langchaingo.completions(
    LangChaingoCompletionRequest(
        model: LangChaingoModelConfig(
            provider: "openai",
            model: "gpt-4o-mini"
        ),
        messages: [
            LangChaingoMessage(role: "system", content: "Answer in one sentence."),
            LangChaingoMessage(role: "user", content: "Explain Rayleigh scattering.")
        ],
        temperature: 0.2
    )
)

print(completion.content)
```

The completion response mirrors the LangChainGo `ContentResponse` shape, so you can inspect the `functionCall`, `toolCalls`, or `generationInfo` fields when you need more than plain text.

## Retrieval-Augmented Generation (RAG)

Pair the LangChaingo endpoints with the `/api/llm-documents` store to build RAG workflows. The backend automatically uses the chromem-go collection configured for the target LLM collection.

```swift
let answer: LangChaingoRAGResponse = try await client.langchaingo.rag(
    LangChaingoRAGRequest(
        collection: "knowledge-base",
        question: "Why is the sky blue?",
        topK: 4,
        returnSources: true,
        filters: LangChaingoRAGFilters(
            where: ["topic": "physics"]
        )
    )
)

print(answer.answer)
if let sources = answer.sources {
    for source in sources {
        if let score = source.score {
            print("\(String(format: "%.3f", score)) \(source.metadata?["title"] ?? "")")
        }
    }
}
```

Set `promptTemplate` when you want to control how the retrieved context is stuffed into the answer prompt:

```swift
_ = try await client.langchaingo.rag(
    LangChaingoRAGRequest(
        collection: "knowledge-base",
        question: "Summarize the explanation below in 2 sentences.",
        promptTemplate: """
            Context:\n{{.context}}\n\nQuestion: {{.question}}\nSummary:
        """
    )
)
```

## Complete Examples

### Example 1: Simple Chat Completion

```swift
func askQuestion(_ question: String) async throws -> String {
    let completion: LangChaingoCompletionResponse = try await client.langchaingo.completions(
        LangChaingoCompletionRequest(
            messages: [
                LangChaingoMessage(role: "user", content: question)
            ]
        )
    )
    
    return completion.content
}
```

### Example 2: RAG with Knowledge Base

```swift
func askWithContext(_ question: String) async throws -> (answer: String, sources: [JSONRecord]) {
    // First, ensure documents are in the knowledge base
    // (see LLM_DOCUMENTS.md for document insertion)
    
    let answer: LangChaingoRAGResponse = try await client.langchaingo.rag(
        LangChaingoRAGRequest(
            collection: "knowledge-base",
            question: question,
            topK: 5,
            returnSources: true
        )
    )
    
    return (
        answer: answer.answer,
        sources: answer.sources?.map { source in
            [
                "score": AnyCodable(source.score ?? 0.0),
                "metadata": AnyCodable(source.metadata ?? [:])
            ]
        } ?? []
    )
}
```

### LLM Document Queries

> **Note**: This interface is only available to superusers.

When you want to pose a question to a specific `llmDocuments` collection and have LangChaingo+OpenAI synthesize an answer, use `queryDocuments`. It mirrors the RAG arguments but takes a `query` field:

```swift
let response: LangChaingoDocumentQueryResponse = try await client.langchaingo.queryDocuments(
    LangChaingoDocumentQueryRequest(
        collection: "knowledge-base",
        query: "List three bullet points about Rayleigh scattering.",
        topK: 3,
        returnSources: true
    )
)

print(response.answer ?? "")
if let sources = response.sources {
    for source in sources {
        if let score = source.score {
            print("\(String(format: "%.3f", score)) \(source.content ?? "")")
        }
    }
}
```

### SQL Generation + Execution

> **Important Notes**:
> - This interface is only available to superusers. Requests authenticated with regular `users` tokens return a `401 Unauthorized`.
> - It is recommended to execute query statements (SELECT) only.
> - **Do not use this interface for adding or modifying table structures.** Collection interfaces should be used instead for managing database schema.
> - Directly using this interface for initializing table structures and adding or modifying database tables will cause errors that prevent the automatic generation of APIs.

Superuser tokens (`_superusers` records) can ask LangChaingo to have OpenAI propose a SQL statement, execute it, and return both the generated SQL and execution output.

```swift
let result: LangChaingoSQLResponse = try await client.langchaingo.sql(
    LangChaingoSQLRequest(
        query: "Add a demo project row if it doesn't exist, then list the 5 most recent projects.",
        tables: ["projects"], // optional hint to limit which tables the model sees
        topK: 5
    )
)

print(result.sql)    // Generated SQL
print(result.answer) // Model's summary of the execution
print(result.columns ?? [], result.rows ?? [])
```

Use `tables` to restrict which table definitions and sample rows are passed to the model, and `topK` to control how many rows the model should target when building queries. You can also pass the optional `model` block described above to override the default OpenAI model or key for this call.

## Related Documentation

- [LLM Documents](./LLM_DOCUMENTS.md) - Document storage for RAG
- [Vector API](./VECTOR_API.md) - Vector search operations

