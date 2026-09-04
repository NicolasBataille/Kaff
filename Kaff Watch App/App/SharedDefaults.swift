import Foundation
import KaffCore
import os

/// `UserDefaults` partagés avec la complication (App Group), avec repli journalisé sur `.standard`.
enum SharedDefaults {
    /// À appeler une seule fois au démarrage : le repli est signalé par un `fault` unique.
    static func resolve() -> UserDefaults {
        if let defaults = AppGroup.defaults { return defaults }
        Logger(subsystem: "fr.nikou.kaff", category: "AppGroup")
            .fault("App Group indisponible : cache widget local uniquement")
        return .standard
    }
}
