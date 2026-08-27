import KaffCore
import SwiftUI

@main
struct KaffApp: App {
    @State private var model = AppModel(
        health: HealthKitStore(),
        profileStore: ProfileStore(defaults: AppGroup.defaults ?? .standard),
        cacheStore: CacheStore(defaults: AppGroup.defaults ?? .standard),
        widgets: WidgetCenterReloader())

    var body: some Scene {
        WindowGroup {
            VStack {
                Text("Auth: \(String(describing: model.authorization))")
                Text("Doses: \(model.doses.count)")
                Text("\(Int(model.assessment().currentMg)) mg")
                Button("+63 mg") { Task { await model.log(milligrams: 63, drink: nil, volumeML: nil) } }
            }
            .task { await model.start() }
            .environment(model)
        }
    }
}
