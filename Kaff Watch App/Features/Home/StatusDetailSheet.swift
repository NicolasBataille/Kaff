import KaffCore
import SwiftUI

/// Feuille courte : raison du statut + les trois vérifications (pic, jour, coucher) avec jauges linéaires.
struct StatusDetailSheet: View {
    let assessment: LevelAssessment
    let profile: UserProfile

    private struct Check: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let value: Double
        let limit: Double
        let status: LevelStatus
    }

    private var checks: [Check] {
        [
            Check(id: "peak", title: "Pic", symbol: "waveform.path.ecg",
                  value: assessment.currentMg, limit: profile.peakLimitMg, status: assessment.peakStatus),
            Check(id: "daily", title: "Cumul du jour", symbol: "sun.max.fill",
                  value: assessment.dailyTotalMg, limit: profile.dailyLimitMg, status: assessment.dailyStatus),
            Check(id: "bedtime", title: "Au coucher \(Formatters.time(assessment.bedtime))", symbol: "moon.zzz.fill",
                  value: assessment.projectedBedtimeMg, limit: profile.bedtimeLimitMg, status: assessment.bedtimeStatus),
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
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(check.title) : \(Formatters.mg(check.value)) sur \(Formatters.mg(check.limit)), \(check.status.accessibilityLabel)")
    }
}
