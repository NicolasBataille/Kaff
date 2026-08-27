import Foundation

/// Réglages et boissons personnalisées, dans l'App Group.
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
}
