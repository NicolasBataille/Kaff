import KaffCore
import SwiftUI

/// Historique 7 journées caféine (page verticale sous Home) : carte du jour, sections par journée (04:00 → 04:00,
/// `AppModel.historySections`), suppression par glissement.
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var deleteCount = 0

    static let days = 7

    var body: some View {
        // `.everyMinute` : les titres « Aujourd'hui » / « Hier » basculent à 04:00 sans relancer la page.
        TimelineView(.everyMinute) { context in
            content(now: context.date)
        }
        .navigationTitle("Historique")
        .sensoryFeedback(.impact(weight: .light), trigger: deleteCount)
    }

    private func content(now: Date) -> some View {
        let assessment = model.assessment()
        let sections = model.historySections(days: Self.days)
        return List {
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
                Section(title(for: section, now: now)) {
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
    }

    /// « Aujourd'hui » / « Hier » selon la journée caféine courante, sinon « jeudi 28 ».
    private func title(for section: HistorySection, now: Date) -> String {
        let day = model.assessor.day
        let todayStart = day.start(containing: now)
        if section.dayStart == todayStart { return "Aujourd'hui" }
        if section.dayStart == day.start(containing: todayStart.addingTimeInterval(-1)) { return "Hier" }
        return Formatters.day(section.dayStart)
    }
}

/// Ligne : symbole dans un petit disque, nom sur l'heure, mg à droite (tient sur 42 mm sans troncature).
private struct DoseRow: View {
    let dose: CaffeineDose
    let drink: Drink?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 8) {
            DrinkSymbolDisc(drink: drink, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(drink?.name ?? "Manuel")
                    .font(.footnote)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.8)
                Text(Formatters.time(dose.date))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
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
