import KaffCore
import SwiftUI

/// Section Affichage (spec §7 item 5, §5.3) : unité de la complication — mg dans l'organisme, ou concentration
/// plasmatique estimée en mg/L. Home garde les mg en héros ; l'anneau ne change jamais avec l'unité.
/// La ligne suit le style des autres réglages (valeur teintée à droite) et pousse `ComplicationUnitPickerView`.
struct DisplaySettingsSection: View {
    @Environment(AppModel.self) private var model

    private var profile: UserProfile { model.profile }

    var body: some View {
        Section("Affichage") {
            NavigationLink(value: Route.complicationUnit) {
                LabeledContent {
                    Text(verbatim: profile.complicationUnit.label)
                        .foregroundStyle(Theme.accent)
                        .contentTransition(.interpolate)
                        .accessibilityLabel(profile.complicationUnit.accessibilityLabel)
                } label: {
                    Label("Unité de la complication", systemImage: "applewatch.watchface")
                }
            }
            .animation(.default, value: profile.complicationUnit)
            // Haptique sur la ligne persistante (pas sur la liste qui se ferme) : le profil change après le retour.
            .sensoryFeedback(.selection, trigger: profile.complicationUnit)
            // Volume de distribution : 0,67 L/kg × poids (EFSA 2015), arrondi à 2 L par KaffCore (spec §5.3).
            SettingsFootnote("Concentration plasmatique estimée : \(Formatters.litresPerKg(PharmacokineticModel.distributionLitresPerKg)) × poids ≈ \(Formatters.litres(profile.distributionLitres))")
            nowFootnote
            if profile.isWeightEstimated {
                EstimatedWeightLabel(weightKg: profile.weightKg)
            }
        }
    }

    /// Ce que la complication affiche dans chaque unité, en direct (« Maintenant 142 mg · 3,1 mg/L »).
    private var nowFootnote: some View {
        let assessment = model.assessment(at: .now)
        return SettingsFootnote("Maintenant \(Formatters.mg(assessment.currentMg)) · \(Formatters.mgPerLitre(assessment.currentMgPerLitre(litres: profile.distributionLitres)))")
    }
}

/// Deux lignes à coche : « mg » (quantité dans l'organisme) et « mg/L » (concentration plasmatique estimée),
/// chacune avec la valeur du moment en sous-titre. Choisir revient à la section (haptique `.selection` sur la ligne).
struct ComplicationUnitPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var profile: UserProfile { model.profile }

    var body: some View {
        let assessment = model.assessment(at: .now)
        List(DisplayUnit.allCases, id: \.self) { unit in
            Button {
                select(unit)
            } label: {
                LabeledContent {
                    if unit == profile.complicationUnit {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Theme.accent)
                            .fontWeight(.semibold)
                    }
                } label: {
                    Text(verbatim: unit.label)
                    Text(verbatim: example(unit, assessment))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .accessibilityLabel(unit.accessibilityLabel)
            .accessibilityValue(example(unit, assessment))
            .accessibilityAddTraits(unit == profile.complicationUnit ? .isSelected : [])
        }
        .navigationTitle("Unité")
    }

    private func example(_ unit: DisplayUnit, _ assessment: LevelAssessment) -> String {
        switch unit {
        case .milligrams: Formatters.mg(assessment.currentMg)
        case .milligramsPerLitre: Formatters.mgPerLitre(assessment.currentMgPerLitre(litres: profile.distributionLitres))
        }
    }

    private func select(_ unit: DisplayUnit) {
        if unit != profile.complicationUnit {
            var copy = profile
            copy.complicationUnit = unit
            Task { await model.update(profile: copy) }
        }
        dismiss()
    }
}
