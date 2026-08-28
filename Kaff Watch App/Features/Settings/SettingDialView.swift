import KaffCore
import SwiftUI

/// Réglages numériques du profil, chacun réglé sur un cadran couronne dédié.
/// (Les `Stepper` inline capturent la couronne dès qu'ils défilent au centre : voir SettingsView.)
enum SettingKey: Hashable, CaseIterable {
    case weight, halfLife, bedtimeLimit, dailyLimit

    var title: String {
        switch self {
        case .weight: "Poids"
        case .halfLife: "Demi-vie"
        case .bedtimeLimit: "Max au coucher"
        case .dailyLimit: "Par jour"
        }
    }

    var symbol: String {
        switch self {
        case .weight: "scalemass.fill"
        case .halfLife: "hourglass"
        case .bedtimeLimit: "moon.zzz.fill"
        case .dailyLimit: "sun.max.fill"
        }
    }

    var tint: Color {
        switch self {
        case .bedtimeLimit: Theme.sleep
        default: Theme.accent
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .weight: UserProfile.Bounds.weightKg
        case .halfLife: UserProfile.Bounds.halfLifeHours
        case .bedtimeLimit: UserProfile.Bounds.bedtimeLimitMg
        case .dailyLimit: UserProfile.Bounds.dailyLimitMg
        }
    }

    /// Un cran de couronne.
    var step: Double {
        switch self {
        case .weight: 1
        case .halfLife: 0.5
        case .bedtimeLimit: 5
        case .dailyLimit: 25
        }
    }

    func value(in profile: UserProfile) -> Double {
        switch self {
        case .weight: profile.weightKg
        case .halfLife: profile.halfLifeHours
        case .bedtimeLimit: profile.bedtimeLimitMg
        case .dailyLimit: profile.dailyLimitMg
        }
    }

    func apply(_ value: Double, to profile: UserProfile) -> UserProfile {
        var copy = profile
        switch self {
        case .weight: copy.manualWeightKg = value
        case .halfLife: copy.halfLifeHours = value
        case .bedtimeLimit: copy.bedtimeLimitMg = value
        case .dailyLimit: copy.dailyLimitMg = value
        }
        return copy
    }

    func format(_ value: Double) -> String {
        switch self {
        case .weight: Formatters.kg(value)
        case .halfLife: Formatters.hours(value)
        case .bedtimeLimit, .dailyLimit: Formatters.mg(value)
        }
    }

    /// Ligne explicative sous le cadran, recalculée en direct.
    func footnote(for profile: UserProfile) -> String {
        switch self {
        case .weight: "Dose unique max \(Formatters.mg(profile.singleDoseLimitMg)) · \(Formatters.count(profile.singleDoseMgPerKg)) mg/kg"
        case .halfLife: "≈ \(Formatters.minutes(PharmacokineticModel(halfLifeHours: profile.halfLifeHours).timeToPeakHours * 60)) jusqu'au pic"
        case .bedtimeLimit: "Niveau toléré à \(Formatters.time(profile.bedtime)) pour bien dormir."
        case .dailyLimit: "Cumul depuis 04:00 · repère EFSA 400 mg."
        }
    }
}

/// Cadran d'un réglage du profil : `ValueDialView` + sauvegarde immédiate (debounce) dans `AppModel`.
struct SettingDialView: View {
    let key: SettingKey

    @Environment(AppModel.self) private var model
    @State private var value = 0.0
    @State private var isLoaded = false
    @State private var saveTask: Task<Void, Never>?

    private static let saveDelay: Duration = .milliseconds(250)

    var body: some View {
        ValueDialView(title: key.title, symbol: key.symbol, tint: key.tint, value: $value,
                      range: key.range, step: key.step, format: key.format) { value in
            key.footnote(for: key.apply(value, to: model.profile))
        }
        .onAppear {
            value = key.value(in: model.profile)
            isLoaded = true
        }
        .onDisappear(perform: flush)
        .onChange(of: value) { _, _ in scheduleSave() }
    }

    private func scheduleSave() {
        guard isLoaded else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            await save()
        }
    }

    private func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard isLoaded else { return }
        Task { await save() }
    }

    private func save() async {
        guard key.value(in: model.profile) != value else { return }
        await model.update(profile: key.apply(value, to: model.profile))
    }
}
