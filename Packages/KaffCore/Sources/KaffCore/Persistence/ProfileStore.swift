import Foundation

/// Réglages et boissons personnalisées, dans les `UserDefaults` propres à l'app (jamais dans l'App Group :
/// le profil porte le poids HealthKit, que la complication n'a pas à voir).
public struct ProfileStore: @unchecked Sendable {
    // `UserDefaults` n'est pas déclaré `Sendable` par Foundation mais est documenté thread-safe.
    static let profileKey = "profile.v1"
    static let customDrinksKey = "customDrinks.v1"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func loadProfile() -> UserProfile {
        guard let data = defaults.data(forKey: Self.profileKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else { return .default }
        return profile.clamped()
    }

    public func save(_ profile: UserProfile) throws {
        defaults.set(try JSONEncoder().encode(profile.clamped()), forKey: Self.profileKey)
    }

    public func loadCustomDrinks() -> [Drink] {
        guard let data = defaults.data(forKey: Self.customDrinksKey),
              let drinks = try? JSONDecoder().decode([Drink].self, from: data) else { return [] }
        return drinks
    }

    public func saveCustomDrinks(_ drinks: [Drink]) throws {
        defaults.set(try JSONEncoder().encode(drinks), forKey: Self.customDrinksKey)
    }

    /// Migration unique depuis un ancien emplacement (l'App Group avant v0.1) : chaque clé absente ici est copiée
    /// depuis `legacy`, puis les deux clés sont retirées de `legacy` quoi qu'il arrive (le poids quitte le conteneur
    /// partagé). Idempotent ; sans effet si `legacy` est vide.
    public func migrate(from legacy: UserDefaults) {
        guard legacy !== defaults else { return }
        for key in [Self.profileKey, Self.customDrinksKey] {
            if defaults.object(forKey: key) == nil, let data = legacy.data(forKey: key) {
                defaults.set(data, forKey: key)
            }
            legacy.removeObject(forKey: key)
        }
    }
}
