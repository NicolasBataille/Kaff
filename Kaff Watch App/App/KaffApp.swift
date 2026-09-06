import KaffCore
import SwiftUI

@main
struct KaffApp: App {
    @State private var model: AppModel = {
        let sharedDefaults = SharedDefaults.resolve()
        // Le profil (poids HealthKit) reste dans les défauts de l'app ; seul le snapshot widget est partagé.
        let profileStore = ProfileStore(defaults: .standard)
        profileStore.migrate(from: sharedDefaults)
        return AppModel(
            health: HealthKitStore(),
            profileStore: profileStore,
            cacheStore: CacheStore(defaults: sharedDefaults),
            widgets: WidgetCenterReloader(),
            notifications: UserNotificationScheduler())
    }()

    var body: some Scene {
        WindowGroup {
            root.environment(model)
        }
    }

    /// Tailles de texte plafonnées à `accessibility5` (les mises en page sont vérifiées jusque-là), jamais planchées.
    @ViewBuilder private var root: some View {
        #if DEBUG
        if ProcessInfo.processInfo.environment["KAFF_WIDGET_GALLERY"] != nil {
            NavigationStack { WidgetGalleryView() }
        } else {
            sizedRoot
        }
        #else
        sizedRoot
        #endif
    }

    @ViewBuilder private var sizedRoot: some View {
        if let forced = Self.forcedDynamicTypeSize {
            RootView().dynamicTypeSize(forced)
        } else {
            RootView().dynamicTypeSize(...DynamicTypeSize.accessibility5)
        }
    }

    /// Debug simulateur uniquement : `SIMCTL_CHILD_KAFF_DYNAMIC_TYPE=AX5 xcrun simctl launch …` force une taille de texte
    /// (le simulateur watchOS n'a ni `simctl ui content_size` ni réglage automatisable).
    private static var forcedDynamicTypeSize: DynamicTypeSize? {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment["KAFF_DYNAMIC_TYPE"] else { return nil }
        let sizes: [String: DynamicTypeSize] = [
            "XS": .xSmall, "S": .small, "M": .medium, "L": .large, "XL": .xLarge, "XXL": .xxLarge, "XXXL": .xxxLarge,
            "AX1": .accessibility1, "AX2": .accessibility2, "AX3": .accessibility3, "AX4": .accessibility4, "AX5": .accessibility5,
        ]
        return sizes[raw]
        #else
        return nil
        #endif
    }
}
