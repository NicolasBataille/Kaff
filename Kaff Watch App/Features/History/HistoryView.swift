import KaffCore
import SwiftUI

/// Historique 7 jours (page verticale sous Home) : carte du jour, sections par jour, suppression par glissement.
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var deleteCount = 0

    static let days = 7

    private struct DaySection: Identifiable {
        let day: Date
        let doses: [CaffeineDose]
        var id: Date { day }
    }

    private var sections: [DaySection] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -Self.days, to: .now) ?? .now
        let grouped = Dictionary(grouping: model.doses.filter { $0.date >= cutoff }) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            DaySection(day: day, doses: (grouped[day] ?? []).sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        let assessment = model.assessment()
        List {
            Section {
                DailySummaryCard(totalMg: assessment.dailyTotalMg, limitMg: model.profile.dailyLimitMg,
                                 status: assessment.dailyStatus)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            if sections.isEmpty {
                Text("Aucune dose sur 7 jours.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(sections) { section in
                Section(Self.title(for: section.day)) {
                    ForEach(section.doses) { dose in
                        DoseRow(dose: dose, drink: model.drink(for: dose))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteCount += 1
                                    Task { await model.delete(dose) }
                                } label: {
                                    Label("Supprimer", systemImage: "trash.fill")
                                }
                            }
                    }
                }
            }
        }
        .animation(.default, value: model.doses)
        .navigationTitle("Historique")
        .sensoryFeedback(.impact(weight: .light), trigger: deleteCount)
    }

    private static func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Aujourd'hui" }
        if calendar.isDateInYesterday(day) { return "Hier" }
        return Formatters.day(day)
    }
}

/// Ligne : heure, symbole dans un petit disque, nom, mg.
private struct DoseRow: View {
    let dose: CaffeineDose
    let drink: Drink?

    var body: some View {
        HStack(spacing: 8) {
            Text(Formatters.time(dose.date))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
            ZStack {
                Circle().fill(Theme.accent.opacity(0.2))
                Image(systemName: drink.map { $0.isCustom ? "mug.fill" : $0.symbol } ?? "number")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 24, height: 24)
            Text(drink?.name ?? "Manuel")
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            Text(Formatters.mg(dose.milligrams))
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Formatters.time(dose.date)), \(drink?.name ?? "dose manuelle"), \(Formatters.mg(dose.milligrams))")
    }
}
