import WidgetKit

/// Permet d'espionner le rechargement des complications dans les tests.
protocol WidgetReloader: Sendable {
    func reloadAll()
}

struct WidgetCenterReloader: WidgetReloader {
    func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
