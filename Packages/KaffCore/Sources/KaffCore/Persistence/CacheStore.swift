import Foundation

/// Snapshot JSON dans les `UserDefaults` de l'App Group. Écrit par l'app, lu par le widget.
public struct CacheStore: @unchecked Sendable {
    // `UserDefaults` n'est pas déclaré `Sendable` par Foundation mais est documenté thread-safe.
    public static let key = "cache.snapshot.v1"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func read() -> CacheSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(CacheSnapshot.self, from: data)
    }

    public func write(_ snapshot: CacheSnapshot) throws {
        defaults.set(try JSONEncoder().encode(snapshot), forKey: Self.key)
    }

    public func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
