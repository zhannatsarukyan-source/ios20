import Foundation

enum AppConfig {
    /// Read from Info.plist key `API_BASE_URL` (set per configuration in Config/*.xcconfig).
    static let apiBaseURL: URL = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: raw), url.scheme != nil, url.host() != nil {
            return url
        }
        #if DEBUG
        // Developer fallback only (simulator → host machine).
        assertionFailure("API_BASE_URL missing/invalid in Info.plist — check Config/Debug.xcconfig")
        return URL(string: "http://localhost:8080")!
        #else
        // A Release build without a valid backend URL is a packaging bug: fail loudly, never silently hit localhost.
        fatalError("API_BASE_URL missing/invalid in Info.plist — check Config/Release.xcconfig")
        #endif
    }()

    static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// "1.0.0 (1)" — numeric build metadata, not translatable copy.
    static var versionDisplay: String {
        "\(marketingVersion) (\(buildNumber))"
    }
}
