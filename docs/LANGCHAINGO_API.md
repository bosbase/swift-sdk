# LangChaingo API - Swift SDK Documentation

## Overview

BosBase exposes the `/api/langchaingo` endpoints so you can run LangChainGo powered workflows without leaving the platform. The Swift SDK wraps these endpoints with the `client.langchaingo` service.

The service exposes two high-level methods:

| Method | HTTP Endpoint | Description |
| --- | --- | --- |
| `client.langchaingo.completions()` | `POST /api/langchaingo/completions` | Runs a chat/completion call using the configured LLM provider. |
| `client.langchaingo.rag()` | `POST /api/langchaingo/rag` | Runs a retrieval-augmented generation pass over an `llmDocuments` collection. |

Both methods accept an optional `model` configuration:

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

## Related Documentation

- [LLM Documents](./LLM_DOCUMENTS.md) - Document storage for RAG
- [Vector API](./VECTOR_API.md) - Vector search operations

