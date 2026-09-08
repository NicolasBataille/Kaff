import KaffCore
import SwiftUI

/// Réglages : poids, modèle, sommeil, notifications, limites, affichage, boissons personnalisées, mention non médicale.
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

    private var timeToPeakMinutes: Double {
        PharmacokineticModel(halfLifeHours: profile.halfLifeHours).timeToPeakHours * 60
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
                    SettingRowLink(key: .weight)
                }
                if profile.healthKitWeightKg == nil {
                    // La base Santé de la montre ne reçoit qu'une copie récente des données de l'iPhone :
                    // une pesée ancienne n'y figure pas, HealthKit renvoie alors zéro résultat.
                    SettingsFootnote("Aucune pesée récente dans Santé sur la montre. Ajoutez votre poids dans Santé sur l'iPhone, ou saisissez-le ici.")
                }
                SettingsFootnote("Dose unique max \(Formatters.mg(profile.singleDoseLimitMg)) · \(Formatters.count(profile.singleDoseMgPerKg)) mg/kg")
            }
            Section("Modèle") {
                SettingRowLink(key: .halfLife)
                SettingsFootnote("≈ \(Formatters.minutes(timeToPeakMinutes)) jusqu'au pic")
                // Source: docs/science/fact-check-pk.md §5a–5c — tabac t½ 3,5 h vs 6,0 h (Parsons & Neims 1978) ;
                // contraceptifs oraux 7,88 h vs 5,37 h (Abernethy & Todd 1985) ; grossesse T3 11,5–18 h (Knutti 1981,
                // EFSA 2015), hors bornes 2–10 h du réglage. Repris dans docs/science/2026-09-04-fact-check.md
                // (« Indices de demi-vie dans Réglages »).
                SettingsFootnote("Tabac ≈ 3,5 h · contraception œstroprogestative ≈ 8 h · grossesse : hors modèle")
            }
            SleepSettingsSection()
            NotificationSettingsSection()
            Section("Limites") {
                SettingRowLink(key: .dailyLimit)
            }
            DisplaySettingsSection()
            Section {
                NavigationLink(value: Route.customDrinks) {
                    Label("Boissons personnalisées", systemImage: "mug.fill")
                }
            }
            Section {
                SettingsFootnote("Estimation indicative. Ce n'est pas un avis médical.")
            }
        }
        .navigationTitle("Réglages")
    }
}
