import Foundation

/// Une prise de caféine, telle que stockée dans HealthKit (`dietaryCaffeine`).
public struct CaffeineDose: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let date: Date
    public let milligrams: Double
    /// Identifiant du `Drink` d'origine, `nil` pour une saisie manuelle en mg.
    public let drinkID: String?
    public let volumeML: Double?

    public init(id: UUID = UUID(), date: Date, milligrams: Double, drinkID: String? = nil, volumeML: Double? = nil) {
        self.id = id
        self.date = date
        self.milligrams = milligrams
        self.drinkID = drinkID
        self.volumeML = volumeML
    }
}
