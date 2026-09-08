import KaffCore
import SwiftUI

/// Feuille courte : raison du statut + les trois vérifications (pic, jour, coucher) avec jauges linéaires.
/// Pic et coucher se lisent aussi en concentration plasmatique estimée (spec §5.3) ; le cumul du jour jamais
/// (quantité ingérée). Les repères de toxicité en note sont informatifs : le statut `high` arrive bien avant.
struct StatusDetailSheet: View {
    let assessment: LevelAssessment
    let profile: UserProfile
    /// Le badge « poids estimé » mène aux Réglages : la feuille n'a pas de destination, Home ferme et pousse la route.
    var openSettings: () -> Void = {}

    // Source: Willson 2018, « The clinical toxicology of caffeine », Toxicol Rep ; revue Frontiers in Toxicology 2026
    // (DOI 10.3389/ftox.2026.1933375) ; docs/science/2026-09-04-fact-check.md « Repères de toxicité ». Symptômes
    // d'intoxication ≥ 15 mg/L, concentrations toxiques > 50 mg/L, létales > 80 mg/L. Repères, pas des seuils.
    private enum Toxicity {
        static let symptomsMgPerLitre = 15.0
        static let toxicMgPerLitre = 50.0
        static let lethalMgPerLitre = 80.0
    }

    private struct Check: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let value: Double
        let limit: Double
        let status: LevelStatus
        /// Lecture en mg/L (valeur, limite) ; absente pour le cumul du jour.
        let concentration: (value: Double, limit: Double)?
    }

    private var checks: [Check] {
        // Volume de distribution : 0,67 L/kg × poids (EFSA 2015), arrondi à 2 L par KaffCore.
        let litres = profile.distributionLitres
        return [
            Check(id: "peak", title: "Pic", symbol: "waveform.path.ecg",
                  value: assessment.currentMg, limit: profile.peakLimitMg, status: assessment.peakStatus,
                  concentration: (assessment.currentMgPerLitre(litres: litres), profile.peakLimitMgPerLitre)),
            Check(id: "daily", title: "Cumul du jour", symbol: "sun.max.fill",
                  value: assessment.dailyTotalMg, limit: profile.dailyLimitMg, status: assessment.dailyStatus,
                  concentration: nil),
            Check(id: "bedtime", title: "Au coucher \(Formatters.time(assessment.bedtime))", symbol: "moon.zzz.fill",
                  value: assessment.projectedBedtimeMg, limit: profile.bedtimeLimitMg, status: assessment.bedtimeStatus,
                  concentration: (assessment.projectedBedtimeMgPerLitre(litres: litres), profile.bedtimeLimitMgPerLitre)),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: assessment.status.symbol)
                    Text(assessment.reason.label(for: assessment.status))
                }
                .font(.headline)
                .foregroundStyle(assessment.status.color)
                ForEach(checks) { check in
                    row(check)
                }
                footnote
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle("Statut")
    }

    private func row(_ check: Check) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Label(check.title, systemImage: check.symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text("\(Formatters.mgValue(check.value)) / \(Formatters.mg(check.limit))")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(check.status.color)
            }
            Gauge(value: min(check.value, check.limit), in: 0...max(check.limit, 1)) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(check.status.color)
            if let concentration = check.concentration {
                concentrationLine(concentration)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(check))
    }

    /// « 3,2 mg/L · limite 4,0 », badge « poids estimé » à côté quand le poids est celui de repli (spec §9) ;
    /// le badge passe dessous quand la ligne ne tient pas (42 mm, tailles d'accessibilité).
    private func concentrationLine(_ concentration: (value: Double, limit: Double)) -> some View {
        let text = Text("\(Formatters.mgPerLitre(concentration.value)) · limite \(Formatters.mgPerLitreValue(concentration.limit))")
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { text; weightBadge }
            VStack(alignment: .leading, spacing: 2) { text; weightBadge }
        }
    }

    @ViewBuilder private var weightBadge: some View {
        if profile.isWeightEstimated {
            Button(action: openSettings) { EstimatedWeightLabel() }
                .buttonStyle(.plain)
                .accessibilityHint("Ouvre les réglages")
        }
    }

    private var footnote: some View {
        Text("Concentration plasmatique estimée · \(Formatters.litresPerKg(PharmacokineticModel.distributionLitresPerKg)) × poids ≈ \(Formatters.litres(profile.distributionLitres)). Repères : symptômes ≥ \(Formatters.mgValue(Toxicity.symptomsMgPerLitre))\u{A0}mg/L, toxique ≥ \(Formatters.mgValue(Toxicity.toxicMgPerLitre)), létal ≥ \(Formatters.mgValue(Toxicity.lethalMgPerLitre)).")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .monospacedDigit()
            .padding(.top, 4)
    }

    private func accessibilityLabel(_ check: Check) -> Text {
        if let concentration = check.concentration {
            return Text("\(check.title) : \(Formatters.mg(check.value)) sur \(Formatters.mg(check.limit)), soit \(Formatters.mgPerLitre(concentration.value)) sur \(Formatters.mgPerLitre(concentration.limit)), \(check.status.accessibilityLabel)")
        }
        return Text("\(check.title) : \(Formatters.mg(check.value)) sur \(Formatters.mg(check.limit)), \(check.status.accessibilityLabel)")
    }
}
