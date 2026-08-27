import Foundation

/// Ce que le widget a besoin de connaître : les doses récentes et le profil.
public struct CacheSnapshot: Hashable, Codable, Sendable {
    public let doses: [CaffeineDose]
    public let profile: UserProfile
    public let updatedAt: Date

    public init(doses: [CaffeineDose], profile: UserProfile, updatedAt: Date) {
        self.doses = doses
        self.profile = profile
        self.updatedAt = updatedAt
    }
}
