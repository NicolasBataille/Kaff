import Foundation
import KaffCore

/// Une journée caféine (04:00 → 04:00) de l'historique et ses doses, les plus récentes en tête.
struct HistorySection: Identifiable, Hashable {
    let dayStart: Date
    let doses: [CaffeineDose]
    var id: Date { dayStart }
}
