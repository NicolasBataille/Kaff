import SwiftUI

/// Racine : autorisation → pages Home/Historique, pile de navigation pilotée par `AppModel.path`,
/// deep links `kaff://home` (complication → écran principal) et `kaff://log` (choix de boisson), alerte sur
/// `lastError`, reprise au retour au premier plan.
struct RootView: View {
    /// Pages verticales de la racine.
    enum Page: Hashable { case home, history }

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var zoom
    @State private var page: Page = .home

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
            case .denied: Task { await model.start() }   // relit le statut au retour de Réglages › Santé
            case .unknown, .notDetermined, .unavailable: break
            }
        }
        .onOpenURL { url in
            guard url.scheme == "kaff", model.authorization == .authorized else { return }
            switch url.host {
            case "home":
                // Tap sur la complication : retour à l'écran principal, quel que soit l'écran laissé ouvert.
                model.path = []
                page = .home
            case "log":
                model.path = [.logDrink]
            default:
                break
            }
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
            TabView(selection: $page) {
                HomeView().tag(Page.home)
                HistoryView().tag(Page.history)
            }
            .tabViewStyle(.verticalPage)
        case .notDetermined, .denied, .unavailable:
            AuthorizationView()
        }
    }

    @ViewBuilder private func destination(for route: Route) -> some View {
        switch route {
        case .logDrink: DrinkPickerView()
        case .amount(let drink): DrinkAmountView(drink: drink)
        case .logManual: ManualDoseView()
        case .settings: SettingsView()
        case .customDrinks: CustomDrinkEditorView()
        case .bedtime: BedtimePickerView()
        case .setting(let key): SettingDialView(key: key)
        case .complicationUnit: ComplicationUnitPickerView()
        }
    }
}

extension EnvironmentValues {
    /// Espace de noms partagé pour le morphing bouton → écran (`matchedTransitionSource` / `.zoom`).
    @Entry var zoomNamespace: Namespace.ID?
}
