/// Qualification d'un niveau par rapport à un seuil.
public enum LevelStatus: Int, Comparable, Codable, Sendable, CaseIterable {
    case ok = 0
    case elevated = 1
    case high = 2

    /// `ratio` = valeur / seuil. `high` à partir de 1, `elevated` à partir de `elevatedAt`.
    public init(ratio: Double, elevatedAt: Double) {
        if ratio >= 1 { self = .high } else if ratio >= elevatedAt { self = .elevated } else { self = .ok }
    }

    public static func < (lhs: LevelStatus, rhs: LevelStatus) -> Bool { lhs.rawValue < rhs.rawValue }
}
