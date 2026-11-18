import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct Endpoint: Sendable {
    var method: HTTPMethod
    /// Path below `/api/v1`, e.g. `/habits`.
    var path: String
    var query: [URLQueryItem] = []
    var body: (any Encodable & Sendable)?
    var requiresAuth = true
    var headers: [String: String] = [:]
}

enum BundleFetchResult: Sendable {
    case notModified
    case updated(I18nBundle, etag: String?)
}

/// Thread-safe HTTP client. Adds `Authorization`, `Accept-Language`, `X-Timezone` to every request,
/// transparently refreshes an expired access token (single-flight, via `TokenStore`) and retries once.
actor APIClient {
    static let apiPrefix = "/api/v1"

    private let baseURL: URL
    private let session: URLSession
    private let tokens: TokenStore
    private let decoder = JSONCoding.makeDecoder()
    private let encoder = JSONCoding.makeEncoder()
    private var language = "en"
    private var sessionExpiredHandler: (@Sendable () async -> Void)?

    init(baseURL: URL, tokens: TokenStore, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokens = tokens
        self.session = session
    }

    func setLanguage(_ code: String) {
        language = code
    }

    func setSessionExpiredHandler(_ handler: @escaping @Sendable () async -> Void) {
        sessionExpiredHandler = handler
    }

    // MARK: - Core

    func send<Response: Decodable & Sendable>(
        _ endpoint: Endpoint,
        as type: Response.Type = Response.self
    ) async throws -> Response {
        var accessToken: String?
        if endpoint.requiresAuth {
            accessToken = await tokens.accessToken
            guard accessToken != nil else {
                await expireSession()
                throw APIError.sessionExpired
            }
        }

        let (data, http) = try await perform(endpoint, accessToken: accessToken)

        guard http.statusCode == 401, endpoint.requiresAuth else {
            return try decode(data, http)
        }

        // 401 on an authenticated call.
        guard errorBody(from: data)?.code == "TOKEN_EXPIRED" else {
            await expireSession()
            throw APIError.sessionExpired
        }

        let freshToken: String
        do {
            freshToken = try await tokens.refreshAccessToken(failedAccessToken: accessToken) { [self] refreshToken in
                try await self.requestRefresh(refreshToken: refreshToken)
            }
        } catch APIError.network {
            // Offline: keep the session, surface a network error.
            throw APIError.network
        } catch let APIError.server(status, body) where status >= 500 || status == 429 {
            // Backend trouble / rate limit is not a rejected token: keep the session.
            throw APIError.server(status: status, body: body)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            await expireSession()
            throw APIError.sessionExpired
        }

        let (retryData, retryHTTP) = try await perform(endpoint, accessToken: freshToken)
        if retryHTTP.statusCode == 401 {
            await expireSession()
            throw APIError.sessionExpired
        }
        return try decode(retryData, retryHTTP)
    }

    /// i18n bundle with ETag revalidation (`If-None-Match` → 304).
    func fetchBundle(locale: String, etag: String?) async throws -> BundleFetchResult {
        var endpoint = Endpoint(method: .get, path: "/i18n/\(locale)", requiresAuth: false)
        if let etag { endpoint.headers["If-None-Match"] = etag }
        let (data, http) = try await perform(endpoint, accessToken: nil)
        if http.statusCode == 304 { return .notModified }
        let bundle: I18nBundle = try decode(data, http)
        return .updated(bundle, etag: http.value(forHTTPHeaderField: "ETag") ?? bundle.version)
    }

    // MARK: - Internals

    private func requestRefresh(refreshToken: String) async throws -> AuthTokens {
        let endpoint = Endpoint(
            method: .post,
            path: "/auth/refresh",
            body: RefreshInput(refreshToken: refreshToken),
            requiresAuth: false
        )
        let (data, http) = try await perform(endpoint, accessToken: nil)
        let response: AuthResponse = try decode(data, http)
        guard let newRefresh = response.refreshToken else { throw APIError.invalidResponse }
        return AuthTokens(accessToken: response.accessToken, refreshToken: newRefresh)
    }

    private func expireSession() async {
        await tokens.clear()
        await sessionExpiredHandler?()
    }

    private func perform(_ endpoint: Endpoint, accessToken: String?) async throws -> (Data, HTTPURLResponse) {
        let request = try makeRequest(endpoint, accessToken: accessToken)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            return (data, http)
        } catch let error as APIError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIError.network
        }
    }

    private func makeRequest(_ endpoint: Endpoint, accessToken: String?) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidResponse
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = basePath + Self.apiPrefix + endpoint.path
        if !endpoint.query.isEmpty { components.queryItems = endpoint.query }
        guard let url = components.url else { throw APIError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        // We manage caching ourselves (ETag for i18n); never let URLCache answer for us.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios", forHTTPHeaderField: "X-Client")
        request.setValue(language, forHTTPHeaderField: "Accept-Language")
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "X-Timezone")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let body = endpoint.body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (name, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }

    private func decode<Response: Decodable & Sendable>(_ data: Data, _ http: HTTPURLResponse) throws -> Response {
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(status: http.statusCode, body: errorBody(from: data))
        }
        if Response.self == EmptyResponse.self, let empty = EmptyResponse() as? Response {
            return empty
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func errorBody(from data: Data) -> ApiErrorBody? {
        try? decoder.decode(ApiErrorEnvelope.self, from: data).error
    }
}

// MARK: - Endpoints

extension APIClient {
    // Auth
    func register(_ input: RegisterInput) async throws -> AuthResponse {
        try await send(Endpoint(method: .post, path: "/auth/register", body: input, requiresAuth: false))
    }

    func login(_ input: LoginInput) async throws -> AuthResponse {
        try await send(Endpoint(method: .post, path: "/auth/login", body: input, requiresAuth: false))
    }

    func logout(refreshToken: String) async throws {
        let _: EmptyResponse = try await send(
            Endpoint(method: .post, path: "/auth/logout", body: RefreshInput(refreshToken: refreshToken), requiresAuth: false)
        )
    }

    // Me
    func me() async throws -> User {
        try await send(Endpoint(method: .get, path: "/me"))
    }

    func updateMe(_ input: UpdateMeInput) async throws -> User {
        try await send(Endpoint(method: .patch, path: "/me", body: input))
    }

    // Habits
    func habits() async throws -> [HabitWithProgress] {
        let response: ItemsResponse<HabitWithProgress> = try await send(Endpoint(method: .get, path: "/habits"))
        return response.items
    }

    func habit(id: String) async throws -> HabitWithProgress {
        try await send(Endpoint(method: .get, path: "/habits/\(id)"))
    }

    func createHabit(_ input: CreateHabitInput) async throws -> HabitWithProgress {
        try await send(Endpoint(method: .post, path: "/habits", body: input))
    }

    func updateHabit(id: String, _ input: UpdateHabitInput) async throws -> HabitWithProgress {
        try await send(Endpoint(method: .patch, path: "/habits/\(id)", body: input))
    }

    func deleteHabit(id: String) async throws {
        let _: EmptyResponse = try await send(Endpoint(method: .delete, path: "/habits/\(id)"))
    }

    func checkIn(habitId: String, date: String) async throws -> CheckIn {
        try await send(Endpoint(method: .post, path: "/habits/\(habitId)/checkins", body: CheckInInput(date: date)))
    }

    func undoCheckIn(habitId: String, date: String) async throws {
        let _: EmptyResponse = try await send(Endpoint(method: .delete, path: "/habits/\(habitId)/checkins/\(date)"))
    }

    func checkIns(habitId: String, from: String, to: String) async throws -> [CheckIn] {
        let response: ItemsResponse<CheckIn> = try await send(
            Endpoint(
                method: .get,
                path: "/habits/\(habitId)/checkins",
                query: [URLQueryItem(name: "from", value: from), URLQueryItem(name: "to", value: to)]
            )
        )
        return response.items
    }

    // Stats
    func statsSummary() async throws -> StatsSummary {
        try await send(Endpoint(method: .get, path: "/stats/summary"))
    }

    // i18n
    func locales() async throws -> LocalesResponse {
        try await send(Endpoint(method: .get, path: "/i18n/locales", requiresAuth: false))
    }
}
