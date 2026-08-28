import KaffCore
import SwiftUI

@main
struct KaffApp: App {
    @State private var model: AppModel = {
        let defaults = SharedDefaults.resolve()
        return AppModel(
            health: HealthKitStore(),
            profileStore: ProfileStore(defaults: defaults),
            cacheStore: CacheStore(defaults: defaults),
            widgets: WidgetCenterReloader())
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .dynamicTypeSize(Self.forcedDynamicTypeSize ?? .large ... .accessibility5)
        }
    }

    /// Debug simulateur uniquement : `SIMCTL_CHILD_KAFF_DYNAMIC_TYPE=AX5 xcrun simctl launch …` force une taille de texte
    /// (le simulateur watchOS n'a ni `simctl ui content_size` ni réglage automatisable).
    private static var forcedDynamicTypeSize: ClosedRange<DynamicTypeSize>? {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment["KAFF_DYNAMIC_TYPE"] else { return nil }
        let sizes: [String: DynamicTypeSize] = [
            "XS": .xSmall, "S": .small, "M": .medium, "L": .large, "XL": .xLarge, "XXL": .xxLarge, "XXXL": .xxxLarge,
            "AX1": .accessibility1, "AX2": .accessibility2, "AX3": .accessibility3, "AX4": .accessibility4, "AX5": .accessibility5,
        ]
        return sizes[raw].map { $0...$0 }
        #else
        return nil
        #endif
    }
}
