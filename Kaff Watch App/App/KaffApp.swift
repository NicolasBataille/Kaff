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
            RootView().environment(model)
        }
    }
}
