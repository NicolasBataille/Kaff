import Foundation

/// Conteneur partagé entre l'app et la complication.
public enum AppGroup {
    public static let identifier = "group.fr.nikou.kaff"

    /// `nil` si l'entitlement App Groups manque (erreur de configuration, pas d'état normal).
    public static var defaults: UserDefaults? { UserDefaults(suiteName: identifier) }
}
