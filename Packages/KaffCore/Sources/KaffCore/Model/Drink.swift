import Foundation

/// Une boisson du catalogue (prédéfinie ou personnalisée).
public struct Drink: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var name: String
    /// Caféine pour `volumeML`.
    public var milligrams: Double
    public var volumeML: Double
    /// Nom de SF Symbol.
    public var symbol: String
    public var isCustom: Bool

    public init(id: String, name: String, milligrams: Double, volumeML: Double, symbol: String, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.milligrams = milligrams
        self.volumeML = volumeML
        self.symbol = symbol
        self.isCustom = isCustom
    }

    public func milligrams(forVolumeML volume: Double) -> Double {
        guard volumeML > 0 else { return 0 }
        return milligrams * volume / volumeML
    }
}
