import Foundation

enum APIError: Error, Sendable, Equatable {
    /// Backend returned the error envelope (message already localized via `Accept-Language`).
    case server(status: Int, body: ApiErrorBody?)
    /// Transport failure (offline, timeout, DNS, TLS...). Shown as `errors.network`.
    case network
    /// Session could not be refreshed — user is signed out.
    case sessionExpired
    case decoding
    case invalidResponse

    var code: String? {
        if case .server(_, let body) = self { return body?.code }
        return nil
    }

    var fieldDetails: [ApiErrorDetail] {
        if case .server(_, let body) = self { return body?.details ?? [] }
        return []
    }
}
