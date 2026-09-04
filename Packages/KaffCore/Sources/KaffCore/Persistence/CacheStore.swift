import Foundation

/// Snapshot JSON dans les `UserDefaults` de l'App Group. Écrit par l'app, lu par le widget.
public struct CacheStore: @unchecked Sendable {
    // `UserDefaults` n'est pas déclaré `Sendable` par Foundation mais est documenté thread-safe.
    /// v2 (M5.4) : `limits` remplace `profile`. v3 (M5.6) : `peakLimitMg` remplace `singleDoseLimitMg`.
    /// Un blob d'une version antérieure n'est jamais relu (clé différente → placeholder) et est effacé à la
    /// première écriture pour ne pas laisser un poids (v1) ni un seuil périmé (v2) dans l'App Group.
    public static let key = "cache.snapshot.v3"
    static let legacyKeys = ["cache.snapshot.v1", "cache.snapshot.v2"]

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
        Self.legacyKeys.forEach(defaults.removeObject(forKey:))
    }

    public func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
