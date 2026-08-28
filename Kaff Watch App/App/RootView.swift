import SwiftUI

/// Racine : autorisation → pages Home/Historique, pile de navigation pilotée par `AppModel.path`,
/// deep link `kaff://log`, alerte sur `lastError`, reprise au retour au premier plan.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var zoom

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            content
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                        .navigationTransition(.zoom(sourceID: route, in: zoom))
                }
        }
        .environment(\.zoomNamespace, zoom)
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            switch model.authorization {
            case .authorized: Task { await model.refresh() }
            case .denied: Task { await model.start() }
            case .unknown, .unavailable: break
            }
        }
        .onOpenURL { url in
            if url.scheme == "kaff", url.host == "log" { model.path = [.logDrink] }
        }
        .alert("Erreur", isPresented: Binding(get: { model.lastError != nil },
                                              set: { if !$0 { model.clearError() } })) {
            Button("OK") {}
        } message: {
            Text(model.lastError ?? "")
        }
    }

    @ViewBuilder private var content: some View {
        switch model.authorization {
        case .unknown:
            ProgressView()
        case .authorized:
            TabView {
                HomeView()
                HistoryView()
            }
            .tabViewStyle(.verticalPage)
        case .denied, .unavailable:
            AuthorizationView()
        }
    }

    @ViewBuilder private func destination(for route: Route) -> some View {
        switch route {
        case .logDrink: DrinkPickerView()
        case .logManual: ManualDoseView()
        case .settings: SettingsView()
        }
    }
}

extension EnvironmentValues {
    /// Espace de noms partagé pour le morphing bouton → écran (`matchedTransitionSource` / `.zoom`).
    @Entry var zoomNamespace: Namespace.ID?
}
