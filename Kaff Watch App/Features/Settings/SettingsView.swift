import KaffCore
import SwiftUI

/// Réglages : poids, modèle, sommeil, limites, boissons personnalisées, mention non médicale.
/// Les valeurs numériques s'ouvrent sur un cadran couronne (`SettingDialView`) : un `Stepper` inline
/// capture la couronne dès qu'il défile au centre de l'écran et modifie la valeur à l'insu de l'utilisateur.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    private var profile: UserProfile { model.profile }
    private var useManualWeight: Binding<Bool> {
        Binding(get: { profile.manualWeightKg != nil }, set: { on in
            var copy = profile
            copy.manualWeightKg = on ? profile.weightKg : nil
            Task { await model.update(profile: copy) }
        })
    }

    /// « 72 kg · 3 sept. » ou « — » quand la montre n'a aucune pesée.
    private var healthWeightText: String {
        guard let kg = profile.healthKitWeightKg else { return "—" }
        guard let date = profile.healthKitWeightDate else { return Formatters.kg(kg) }
        return "\(Formatters.kg(kg)) · \(Formatters.shortDate(date))"
    }

    var body: some View {
        Form {
            Section("Poids") {
                LabeledContent("Santé") {
                    Text(healthWeightText).foregroundStyle(.secondary)
                }
                Toggle("Saisir manuellement", isOn: useManualWeight)
                    .tint(Theme.accent)
                if profile.manualWeightKg != nil {
                    row(.weight)
                }
                if profile.healthKitWeightKg == nil {
                    // La base Santé de la montre ne reçoit qu'une copie récente des données de l'iPhone :
                    // une pesée ancienne n'y figure pas, HealthKit renvoie alors zéro résultat.
                    footnote("Aucune pesée récente dans Santé sur la montre. Ajoutez votre poids dans Santé sur l'iPhone, ou saisissez-le ici.")
                }
                footnote("Dose unique max \(Formatters.mg(profile.singleDoseLimitMg)) · \(Formatters.count(profile.singleDoseMgPerKg)) mg/kg")
            }
            Section("Modèle") {
                row(.halfLife)
                footnote("≈ \(Formatters.minutes(PharmacokineticModel(halfLifeHours: profile.halfLifeHours).timeToPeakHours * 60)) jusqu'au pic")
            }
            Section("Sommeil") {
                NavigationLink(value: Route.bedtime) {
                    LabeledContent {
                        Text(Formatters.time(profile.bedtime)).monospacedDigit().foregroundStyle(Theme.sleep)
                    } label: {
                        Label("Coucher", systemImage: "moon.zzz.fill")
                    }
                }
                row(.bedtimeLimit)
            }
            Section("Limites") {
                row(.dailyLimit)
            }
            Section {
                NavigationLink(value: Route.customDrinks) {
                    Label("Boissons personnalisées", systemImage: "mug.fill")
                }
            }
            Section {
                footnote("Estimation indicative. Ce n'est pas un avis médical.")
            }
        }
        .navigationTitle("Réglages")
    }

    private func row(_ key: SettingKey) -> some View {
        NavigationLink(value: Route.setting(key)) {
            LabeledContent {
                Text(key.format(key.value(in: profile)))
                    .monospacedDigit()
                    .foregroundStyle(key.tint)
                    .contentTransition(.numericText())
            } label: {
                Label(key.title, systemImage: key.symbol)
            }
        }
        .animation(.default, value: profile)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.default, value: text)
    }
}
