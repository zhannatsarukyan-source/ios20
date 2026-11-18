import Foundation

struct CachedBundle: Codable, Sendable {
    let etag: String?
    let bundle: I18nBundle
}

/// Disk cache for locale bundles and the locales list (Application Support/Habitly/i18n).
actor I18nCache {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL? = nil) {
        self.directory = directory
            ?? URL.applicationSupportDirectory.appending(path: "Habitly/i18n", directoryHint: .isDirectory)
    }

    /// Bundles are keyed by the REQUESTED locale code (normalized), not `bundle.locale`: the backend may
    /// answer an unknown locale with the default bundle, and the read must hit the same file as the write.
    func loadBundle(requestedLocale: String) -> CachedBundle? {
        read(CachedBundle.self, file: Self.bundleFile(for: requestedLocale))
    }

    func saveBundle(_ cached: CachedBundle, requestedLocale: String) {
        write(cached, file: Self.bundleFile(for: requestedLocale))
    }

    static func bundleFile(for locale: String) -> String {
        "bundle-\(sanitize(normalize(locale))).json"
    }

    static func normalize(_ locale: String) -> String {
        locale.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
    }

    func loadLocales() -> LocalesResponse? {
        read(LocalesResponse.self, file: "locales.json")
    }

    func saveLocales(_ locales: LocalesResponse) {
        write(locales, file: "locales.json")
    }

    private func read<T: Decodable>(_ type: T.Type, file: String) -> T? {
        let url = directory.appending(path: file)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, file: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(value)
            try data.write(to: directory.appending(path: file), options: .atomic)
        } catch {
            // Cache is best-effort.
        }
    }

    static func sanitize(_ locale: String) -> String {
        String(locale.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" })
    }
}
