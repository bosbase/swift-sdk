import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct RecordSubscription<RecordType: Decodable> {
    public let action: String
    public let record: RecordType
}

public struct RecordSubscriptionOptions {
    public var fields: String?
    public var filter: String?
    public var expand: String?
    public var query: [String: Any?]
    public var headers: [String: String]

    public init(
        fields: String? = nil,
        filter: String? = nil,
        expand: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) {
        self.fields = fields
        self.filter = filter
        self.expand = expand
        self.query = query
        self.headers = headers
    }

    fileprivate func asRealtimeOptions() -> RealtimeSubscriptionOptions {
        var params = query
        if let fields { params["fields"] = fields }
        if let filter { params["filter"] = filter }
        if let expand { params["expand"] = expand }
        return RealtimeSubscriptionOptions(query: params, headers: headers)
    }
}

public typealias OAuth2URLCallback = @Sendable (URL) async throws -> Void

public struct OAuth2AuthConfig {
    public var provider: String
    public var scopes: [String]?
    public var createData: JSONRecord?
    public var urlCallback: OAuth2URLCallback?
    public var expand: String?
    public var fields: String?
    public var query: [String: Any?]
    public var headers: [String: String]
    public var requestKey: String?
    public var autoCancel: Bool?

    public init(
        provider: String,
        scopes: [String]? = nil,
        createData: JSONRecord? = nil,
        urlCallback: OAuth2URLCallback? = nil,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:],
        requestKey: String? = nil,
        autoCancel: Bool? = nil
    ) {
        self.provider = provider
        self.scopes = scopes
        self.createData = createData
        self.urlCallback = urlCallback
        self.expand = expand
        self.fields = fields
        self.query = query
        self.headers = headers
        self.requestKey = requestKey
        self.autoCancel = autoCancel
    }
}

public final class RecordService: BaseService {
    public let collectionIdOrName: String

    public init(client: BosBaseClient, collectionIdOrName: String) {
        self.collectionIdOrName = collectionIdOrName
        super.init(client: client)
    }

    private var baseCollectionPath: String {
        return "/api/collections/" + encodePathSegment(collectionIdOrName)
    }

    private var baseRecordsPath: String {
        return baseCollectionPath + "/records"
    }

    public var isSuperusers: Bool {
        return collectionIdOrName == "_superusers" || collectionIdOrName == "_pbc_2773867675"
    }

    // MARK: - Realtime

    @discardableResult
    public func subscribe<RecordType: Decodable>(
        topic: String,
        options: RecordSubscriptionOptions? = nil,
        callback: @escaping (RecordSubscription<RecordType>) -> Void
    ) async throws -> () -> Void {
        guard !topic.isEmpty else {
            throw ClientResponseError(url: nil, status: 400, response: ["message": AnyCodable("Missing topic.")])
        }

        let topicKey = collectionIdOrName + "/" + topic
        return try await client.realtime.subscribe(topic: topicKey, options: options?.asRealtimeOptions()) { [weak self] message in
            guard let self, let action = message.action, let recordPayload = message.payload["record"] else {
                return
            }
            guard let subscription: RecordSubscription<RecordType> = self.decodeSubscription(action: action, recordPayload: recordPayload) else {
                return
            }
            callback(subscription)
        }
    }

    public func unsubscribe(_ topic: String? = nil) async throws {
        if let topic {
            try await client.realtime.unsubscribe(collectionIdOrName + "/" + topic)
        } else {
            try await client.realtime.unsubscribeByPrefix(collectionIdOrName)
        }
    }

    // MARK: - CRUD

    public func getList<T: Decodable>(
        page: Int = 1,
        perPage: Int = 30,
        skipTotal: Bool = false,
        filter: String? = nil,
        sort: String? = nil,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> ListResult<T> {
        var params = query
        params["page"] = page
        params["perPage"] = perPage
        params["skipTotal"] = skipTotal
        if let filter { params["filter"] = filter }
        if let sort { params["sort"] = sort }
        if let expand { params["expand"] = expand }
        if let fields { params["fields"] = fields }

        let options = RequestOptions(headers: headers, query: params)
        return try await client.send(baseRecordsPath, options: options, decodeTo: ListResult<T>.self)
    }

    public func getFullList<T: Decodable>(
        batchSize: Int = 500,
        filter: String? = nil,
        sort: String? = nil,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> [T] {
        precondition(batchSize > 0, "batchSize must be greater than 0")

        var result: [T] = []
        var page = 1

        while true {
            let list: ListResult<T> = try await getList(
                page: page,
                perPage: batchSize,
                skipTotal: true,
                filter: filter,
                sort: sort,
                expand: expand,
                fields: fields,
                query: query,
                headers: headers
            )
            result.append(contentsOf: list.items)
            if list.items.count < list.perPage {
                break
            }
            page += 1
        }

        return result
    }

    public func getOne<T: Decodable>(
        _ recordId: String,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> T {
        guard !recordId.isEmpty else {
            let errorBody: JSONRecord = [
                "code": 404,
                "message": "Missing required record id.",
                "data": [:]
            ]
            throw ClientResponseError(url: nil, status: 404, response: errorBody)
        }

        var params = query
        if let expand { params["expand"] = expand }
        if let fields { params["fields"] = fields }

        let options = RequestOptions(headers: headers, query: params)
        let path = baseRecordsPath + "/" + encodePathSegment(recordId)
        return try await client.send(path, options: options, decodeTo: T.self)
    }

    public func getFirstListItem<T: Decodable>(
        filter: String,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> T {
        let list: ListResult<T> = try await getList(
            page: 1,
            perPage: 1,
            skipTotal: true,
            filter: filter,
            expand: expand,
            fields: fields,
                query: query,
                headers: headers
            )

        guard let first = list.items.first else {
            let errorBody: JSONRecord = [
                "code": 404,
                "message": "The requested resource wasn't found.",
                "data": [:]
            ]
            throw ClientResponseError(url: nil, status: 404, response: errorBody)
        }

        return first
    }

    public func getCount(
        filter: String? = nil,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Int {
        var params = query
        if let filter { params["filter"] = filter }
        if let expand { params["expand"] = expand }
        if let fields { params["fields"] = fields }

        let options = RequestOptions(headers: headers, query: params)
        struct CountResponse: Decodable { let count: Int }
        let response = try await client.send(baseRecordsPath + "/count", options: options, decodeTo: CountResponse.self)
        return response.count
    }

    @discardableResult
    public func delete(
        _ recordId: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let path = baseRecordsPath + "/" + encodePathSegment(recordId)
        let options = RequestOptions(method: .delete, headers: headers, query: query)
        _ = try await client.send(path, options: options, decodeTo: EmptyResponse.self)
        if isAuthenticatedRecord(recordId: recordId) {
            client.authStore.clear()
        }
        return true
    }

    public func create<Response: Decodable>(
        body: RequestBody,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Response {
        let record: JSONRecord = try await sendMutation(
            path: baseRecordsPath,
            method: .post,
            body: body,
            expand: expand,
            fields: fields,
            query: query,
            headers: headers
        )
        return try client.decodeRecord(record, as: Response.self)
    }

    public func create<Response: Decodable, Payload: Encodable>(
        body: Payload,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Response {
        return try await create(
            body: .encodable(body),
            expand: expand,
            fields: fields,
            query: query,
            headers: headers
        )
    }

    public func update<Response: Decodable>(
        _ recordId: String,
        body: RequestBody,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Response {
        let path = baseRecordsPath + "/" + encodePathSegment(recordId)
        let record: JSONRecord = try await sendMutation(
            path: path,
            method: .patch,
            body: body,
            expand: expand,
            fields: fields,
            query: query,
            headers: headers
        )
        return try client.decodeRecord(record, as: Response.self)
    }

    public func update<Response: Decodable, Payload: Encodable>(
        _ recordId: String,
        body: Payload,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Response {
        return try await update(
            recordId,
            body: .encodable(body),
            expand: expand,
            fields: fields,
            query: query,
            headers: headers
        )
    }

    // MARK: - Auth

    public func listAuthMethods(
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:],
        requestKey: String? = nil,
        autoCancel: Bool? = nil
    ) async throws -> JSONRecord {
        var params = query
        params["fields"] = fields ?? "mfa,otp,password,oauth2"
        let options = RequestOptions(headers: headers, query: params, requestKey: requestKey, autoCancel: autoCancel)
        return try await client.send(baseCollectionPath + "/auth-methods", options: options, decodeTo: JSONRecord.self)
    }

    public func authWithPassword<RecordType: Decodable>(
        identity: String,
        password: String,
        expand: String? = nil,
        fields: String? = nil,
        body: JSONRecord = [:],
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> RecordAuthResponse<RecordType> {
        var payload = body
        payload["identity"] = AnyCodable(identity)
        payload["password"] = AnyCodable(password)
        return try await sendAuthRequest(
            path: baseCollectionPath + "/auth-with-password",
            body: payload,
            expand: expand,
            fields: fields,
            query: query,
            headers: headers
        )
    }

    @discardableResult
    public func bindCustomToken(
        email: String,
        password: String,
        token: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let payload: JSONRecord = [
            "email": AnyCodable(email),
            "password": AnyCodable(password),
            "token": AnyCodable(token)
        ]
        let options = RequestOptions(method: .post, headers: headers, query: query, body: .encodable(payload))
        _ = try await client.send(baseCollectionPath + "/bind-token", options: options, decodeTo: EmptyResponse.self)
        return true
    }

    @discardableResult
    public func unbindCustomToken(
        email: String,
        password: String,
        token: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let payload: JSONRecord = [
            "email": AnyCodable(email),
            "password": AnyCodable(password),
            "token": AnyCodable(token)
        ]
        let options = RequestOptions(method: .post, headers: headers, query: query, body: .encodable(payload))
        _ = try await client.send(baseCollectionPath + "/unbind-token", options: options, decodeTo: EmptyResponse.self)
        return true
    }

    public func authWithToken<RecordType: Decodable>(
        token: String,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:],
        requestKey: String? = nil,
        autoCancel: Bool? = nil
    ) async throws -> RecordAuthResponse<RecordType> {
        let payload: JSONRecord = ["token": AnyCodable(token)]
        return try await sendAuthRequest(
            path: baseCollectionPath + "/auth-with-token",
            body: payload,
            expand: expand,
            fields: fields,
            query: query,
            headers: headers,
            requestKey: requestKey,
            autoCancel: autoCancel
        )
    }

    public func authWithOAuth2Code<RecordType: Decodable>(
        provider: String,
        code: String,
        codeVerifier: String,
        redirectURL: String,
        createData: JSONRecord? = nil,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:],
        requestKey: String? = nil,
        autoCancel: Bool? = nil
    ) async throws -> RecordAuthResponse<RecordType> {
        var payload: JSONRecord = [
            "provider": AnyCodable(provider),
            "code": AnyCodable(code),
            "codeVerifier": AnyCodable(codeVerifier),
            "redirectURL": AnyCodable(redirectURL)
        ]
        if let createData {
            payload["createData"] = AnyCodable(createData)
        }
        return try await sendAuthRequest(
            path: baseCollectionPath + "/auth-with-oauth2",
            body: payload,
            expand: expand,
            fields: fields,
            query: query,
            headers: headers,
            requestKey: requestKey,
            autoCancel: autoCancel
        )
    }

    public func authWithOAuth2<RecordType: Decodable>(
        _ config: OAuth2AuthConfig
    ) async throws -> RecordAuthResponse<RecordType> {
        let realtime = RealtimeService(client: client)
        let state = OAuth2FlowState<RecordType>()

        @Sendable
        func finish(_ result: Result<RecordAuthResponse<RecordType>, Error>) {
            Task {
                await state.resolve(result)
            }
        }

        let cancellationHandler: @Sendable () -> Void = {
            Task {
                await state.cancelIfNeeded()
            }
        }

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                Task { [weak self] in
                    await state.storeContinuation(continuation)

                    guard let self else {
                        finish(.failure(ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("Client no longer available.")])))
                        return
                    }

                    do {
                        let authMethods = try await listAuthMethods(
                            query: config.query,
                            headers: config.headers,
                            requestKey: config.requestKey,
                            autoCancel: config.autoCancel
                        )

                        let provider = try findOAuth2Provider(authMethods: authMethods, name: config.provider)

                        guard let redirectURL = client.buildURL("/api/oauth2-redirect") else {
                            throw ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("Invalid OAuth2 redirect URL.")])
                        }

                        let unsubscribe = try await realtime.subscribe(topic: "@oauth2") { [weak self] message in
                            guard let self else { return }
                            Task {
                                do {
                                    let currentId = await realtime.currentClientIdentifier()
                                    let stateValue = message.payload["state"]?.value as? String
                                    guard let currentId, currentId == stateValue else {
                                        throw ClientResponseError(url: nil, status: 400, response: ["message": AnyCodable("State parameters don't match.")])
                                    }

                                    if let error = message.payload["error"]?.value as? String, !error.isEmpty {
                                        throw ClientResponseError(url: nil, status: 400, response: ["message": AnyCodable(error)])
                                    }

                                    guard let code = message.payload["code"]?.value as? String, !code.isEmpty else {
                                        throw ClientResponseError(url: nil, status: 400, response: ["message": AnyCodable("OAuth2 redirect error or missing code.")])
                                    }

                                    let authData: RecordAuthResponse<RecordType> = try await self.authWithOAuth2Code(
                                        provider: provider.name,
                                        code: code,
                                        codeVerifier: provider.codeVerifier,
                                        redirectURL: redirectURL.absoluteString,
                                        createData: config.createData,
                                        expand: config.expand,
                                        fields: config.fields,
                                        query: config.query,
                                        headers: config.headers,
                                        requestKey: config.requestKey,
                                        autoCancel: config.autoCancel
                                    )

                                    finish(.success(authData))
                                } catch {
                                    finish(.failure(error))
                                }
                            }
                        }

                        await state.storeUnsubscribe(unsubscribe)

                        guard let clientId = await realtime.currentClientIdentifier() else {
                            throw ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("Unable to establish realtime connection.")])
                        }

                        var replacements: [String: Any?] = ["state": clientId]
                        if let scopes = config.scopes, !scopes.isEmpty {
                            replacements["scope"] = scopes.joined(separator: " ")
                        }

                        let authURL = replaceQueryParams(provider.authURL + redirectURL.absoluteString, replacements: replacements)
                        guard let url = URL(string: authURL) else {
                            throw ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("Invalid OAuth2 provider URL.")])
                        }

                        let urlHandler = config.urlCallback ?? defaultOAuthURLHandler
                        try await urlHandler(url)
                    } catch {
                        finish(.failure(error))
                    }
                }
            }
        }, onCancel: cancellationHandler)
    }

    public func authRefresh<RecordType: Decodable>(
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> RecordAuthResponse<RecordType> {
        return try await sendAuthRequest(
            path: baseCollectionPath + "/auth-refresh",
            body: [:],
            query: query,
            headers: headers
        )
    }

    public func requestOTP(
        email: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> OTPResponse {
        let payload: JSONRecord = ["email": AnyCodable(email)]
        let options = RequestOptions(
            method: .post,
            headers: headers,
            query: query,
            body: .encodable(payload)
        )
        return try await client.send(baseCollectionPath + "/request-otp", options: options, decodeTo: OTPResponse.self)
    }

    public func authWithOTP<RecordType: Decodable>(
        otpId: String,
        password: String,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> RecordAuthResponse<RecordType> {
        let payload: JSONRecord = [
            "otpId": AnyCodable(otpId),
            "password": AnyCodable(password)
        ]
        return try await sendAuthRequest(
            path: baseCollectionPath + "/auth-with-otp",
            body: payload,
            expand: expand,
            fields: fields,
            query: query,
            headers: headers
        )
    }

    public func requestPasswordReset(
        email: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let payload: JSONRecord = ["email": AnyCodable(email)]
        let options = RequestOptions(
            method: .post,
            headers: headers,
            query: query,
            body: .encodable(payload)
        )
        _ = try await client.send(baseCollectionPath + "/request-password-reset", options: options, decodeTo: EmptyResponse.self)
        return true
    }

    public func confirmPasswordReset(
        token: String,
        password: String,
        passwordConfirm: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let payload: JSONRecord = [
            "token": AnyCodable(token),
            "password": AnyCodable(password),
            "passwordConfirm": AnyCodable(passwordConfirm)
        ]
        let options = RequestOptions(
            method: .post,
            headers: headers,
            query: query,
            body: .encodable(payload)
        )
        _ = try await client.send(baseCollectionPath + "/confirm-password-reset", options: options, decodeTo: EmptyResponse.self)
        return true
    }

    public func requestVerification(
        email: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let payload: JSONRecord = ["email": AnyCodable(email)]
        let options = RequestOptions(
            method: .post,
            headers: headers,
            query: query,
            body: .encodable(payload)
        )
        _ = try await client.send(baseCollectionPath + "/request-verification", options: options, decodeTo: EmptyResponse.self)
        return true
    }

    public func confirmVerification(
        token: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let payload: JSONRecord = ["token": AnyCodable(token)]
        let options = RequestOptions(
            method: .post,
            headers: headers,
            query: query,
            body: .encodable(payload)
        )
        _ = try await client.send(baseCollectionPath + "/confirm-verification", options: options, decodeTo: EmptyResponse.self)

        if let claims = tokenPayloadClaims(token),
           let current = client.authStore.record,
           recordMatches(claims: claims, record: current) {
            var updated = current
            updated["verified"] = AnyCodable(true)
            client.authStore.save(token: client.authStore.token ?? "", record: updated)
        }
        return true
    }

    public func requestEmailChange(
        newEmail: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let payload: JSONRecord = ["newEmail": AnyCodable(newEmail)]
        let options = RequestOptions(
            method: .post,
            headers: headers,
            query: query,
            body: .encodable(payload)
        )
        _ = try await client.send(baseCollectionPath + "/request-email-change", options: options, decodeTo: EmptyResponse.self)
        return true
    }

    public func confirmEmailChange(
        token: String,
        password: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let payload: JSONRecord = [
            "token": AnyCodable(token),
            "password": AnyCodable(password)
        ]
        let options = RequestOptions(
            method: .post,
            headers: headers,
            query: query,
            body: .encodable(payload)
        )
        _ = try await client.send(baseCollectionPath + "/confirm-email-change", options: options, decodeTo: EmptyResponse.self)

        if let claims = tokenPayloadClaims(token),
           let current = client.authStore.record,
           recordMatches(claims: claims, record: current) {
            client.authStore.clear()
        }
        return true
    }

    public func listExternalAuths<RecordType: Decodable>(
        recordId: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> [RecordType] {
        var params = query
        params["filter"] = client.filter("recordRef = {:id}", params: ["id": recordId])
        return try await client.collection("_externalAuths").getFullList(query: params, headers: headers)
    }

    @discardableResult
    public func unlinkExternalAuth(
        recordId: String,
        provider: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let filter = client.filter("recordRef = {:recordId} && provider = {:provider}", params: ["recordId": recordId, "provider": provider])
        let externalAuth: JSONRecord = try await client.collection("_externalAuths").getFirstListItem(
            filter: filter,
            query: query,
            headers: headers
        )
        guard let authId = recordIdentifier(externalAuth) else {
            let errorBody: JSONRecord = [
                "code": AnyCodable(404),
                "message": AnyCodable("External auth record not found.")
            ]
            throw ClientResponseError(url: nil, status: 404, response: errorBody)
        }
        _ = try await client.collection("_externalAuths").delete(authId, query: query, headers: headers)
        return true
    }

    public func impersonate<RecordType: Decodable>(
        recordId: String,
        duration: Int? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> RecordAuthResponse<RecordType> {
        var params = query
        if let duration { params["duration"] = duration }
        let path = baseCollectionPath + "/impersonate/" + encodePathSegment(recordId)
        return try await sendAuthRequest(
            path: path,
            body: [:],
            query: params,
            headers: headers
        )
    }

    // MARK: - Helpers

    private func sendMutation(
        path: String,
        method: HTTPMethod,
        body: RequestBody,
        expand: String?,
        fields: String?,
        query: [String: Any?],
        headers: [String: String]
    ) async throws -> JSONRecord {
        var params = query
        if let expand { params["expand"] = expand }
        if let fields { params["fields"] = fields }
        let options = RequestOptions(method: method, headers: headers, query: params, body: body)
        let record: JSONRecord = try await client.send(path, options: options, decodeTo: JSONRecord.self)
        maybeUpdateAuthRecord(record)
        return record
    }

    private func sendAuthRequest<RecordType: Decodable>(
        path: String,
        body: JSONRecord,
        expand: String? = nil,
        fields: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:],
        requestKey: String? = nil,
        autoCancel: Bool? = nil
    ) async throws -> RecordAuthResponse<RecordType> {
        var params = query
        if let expand { params["expand"] = expand }
        if let fields { params["fields"] = fields }

        let options = RequestOptions(
            method: .post,
            headers: headers,
            query: params,
            body: .encodable(body),
            requestKey: requestKey,
            autoCancel: autoCancel
        )

        let rawResponse: RecordAuthResponse<JSONRecord> = try await client.send(path, options: options, decodeTo: RecordAuthResponse<JSONRecord>.self)
        client.authStore.save(token: rawResponse.token, record: rawResponse.record)
        return try client.transformAuthResponse(rawResponse, to: RecordType.self)
    }

    private func maybeUpdateAuthRecord(_ updated: JSONRecord) {
        let updatedId = recordIdentifier(updated)
        let currentId = recordIdentifier(client.authStore.record)
        if let updatedId, let currentId, updatedId == currentId {
            client.authStore.update(record: updated)
        }
    }

    private func recordIdentifier(_ record: JSONRecord?) -> String? {
        guard let record,
              let value = record["id"]?.value else { return nil }
        if let string = value as? String {
            return string
        }
        if let convertible = value as? CustomStringConvertible {
            return convertible.description
        }
        return nil
    }

    private func isAuthenticatedRecord(recordId: String) -> Bool {
        guard let current = client.authStore.record else {
            return false
        }
        return recordIdentifier(current) == recordId
    }

    private func decodeSubscription<RecordType: Decodable>(action: String, recordPayload: AnyCodable) -> RecordSubscription<RecordType>? {
        guard let rawRecord = recordPayload.value as? [String: Any] else {
            return nil
        }

        var mapped: JSONRecord = [:]
        for (key, value) in rawRecord {
            mapped[key] = AnyCodable(value)
        }

        guard let decoded = try? client.decodeRecord(mapped, as: RecordType.self) else {
            return nil
        }

        return RecordSubscription(action: action, record: decoded)
    }

    private func findOAuth2Provider(authMethods: JSONRecord, name: String) throws -> OAuth2ProviderInfo {
        guard
            let oauth = authMethods["oauth2"]?.value as? [String: Any],
            let providers = oauth["providers"] as? [[String: Any]]
        else {
            throw ClientResponseError(url: nil, status: 400, response: ["message": AnyCodable("OAuth2 auth methods are not available.")])
        }

        for provider in providers {
            guard let providerName = provider["name"] as? String, providerName == name else { continue }
            guard let authURL = (provider["authURL"] as? String) ?? (provider["authUrl"] as? String), !authURL.isEmpty else {
                break
            }
            guard let verifier = provider["codeVerifier"] as? String, !verifier.isEmpty else {
                break
            }
            return OAuth2ProviderInfo(name: providerName, authURL: authURL, codeVerifier: verifier)
        }

        throw ClientResponseError(url: nil, status: 400, response: ["message": AnyCodable("Missing or invalid provider \"\(name)\".")])
    }

    private func replaceQueryParams(_ url: String, replacements: [String: Any?]) -> String {
        guard var components = URLComponents(string: url) else {
            return url
        }

        var params: [String: String] = [:]
        if let items = components.queryItems {
            for item in items {
                params[item.name] = item.value ?? ""
            }
        }

        for (key, value) in replacements {
            if let value {
                params[key] = String(describing: value)
            } else {
                params.removeValue(forKey: key)
            }
        }

        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.string ?? url
    }

    private func defaultOAuthURLHandler(_ url: URL) async throws {
        #if canImport(UIKit)
        await MainActor.run {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #elseif canImport(AppKit)
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
        #else
        throw ClientResponseError(url: url, status: 0, response: ["message": AnyCodable("Provide a custom urlCallback to open the OAuth2 URL.")])
        #endif
    }

    private func tokenPayloadClaims(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var payload = String(parts[1])
        let remainder = payload.count % 4
        if remainder > 0 {
            payload.append(String(repeating: "=", count: 4 - remainder))
        }
        payload = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: payload) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    private func recordMatches(claims: [String: Any], record: JSONRecord) -> Bool {
        guard let claimId = claims["id"] as? String else { return false }
        guard let currentId = recordIdentifier(record) else { return false }
        if claimId != currentId {
            return false
        }
        if let claimCollection = claims["collectionId"] as? String {
            return (record["collectionId"]?.value as? String) == claimCollection
        }
        return true
    }
}

private actor OAuth2FlowState<RecordType: Decodable> {
    private var finished = false
    private var pendingContinuation: CheckedContinuation<RecordAuthResponse<RecordType>, Error>?
    private var unsubscribe: (() -> Void)?

    func storeContinuation(_ continuation: CheckedContinuation<RecordAuthResponse<RecordType>, Error>) {
        pendingContinuation = continuation
    }

    func storeUnsubscribe(_ handler: @escaping () -> Void) {
        unsubscribe = handler
    }

    func resolve(_ result: Result<RecordAuthResponse<RecordType>, Error>) {
        guard !finished else { return }
        finished = true
        let continuation = pendingContinuation
        let unsubscribe = unsubscribe
        pendingContinuation = nil
        self.unsubscribe = nil
        unsubscribe?()
        continuation?.resume(with: result)
    }

    func cancelIfNeeded() {
        guard !finished else { return }
        finished = true
        let continuation = pendingContinuation
        let unsubscribe = unsubscribe
        pendingContinuation = nil
        self.unsubscribe = nil
        unsubscribe?()
        continuation?.resume(throwing: CancellationError())
    }
}

private struct OAuth2ProviderInfo {
    let name: String
    let authURL: String
    let codeVerifier: String
}
