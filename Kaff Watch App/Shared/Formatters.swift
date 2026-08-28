import Foundation

/// Mise en forme des valeurs affichées (français, chiffres en `monospacedDigit` côté vue).
enum Formatters {
    static func mg(_ value: Double) -> String { "\(mgValue(value)) mg" }
    static func mgValue(_ value: Double) -> String { "\(Int(value.rounded()))" }
    static func ml(_ value: Double) -> String { "\(Int(value.rounded())) ml" }
    static func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    static func count(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...1))) }
    static func kg(_ value: Double) -> String { "\(Int(value.rounded())) kg" }
    static func hours(_ value: Double) -> String { "\(count(value)) h" }
    static func minutes(_ value: Double) -> String { "\(Int(value.rounded())) min" }

    /// « Jeu 28 » pour les sections d'historique.
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day())
    }

    /// Surtitre du scrubber : « il y a 3 h » / « dans 45 min » / « maintenant ».
    static func relative(minutes: Double) -> String {
        let rounded = Int(minutes.rounded())
        if rounded == 0 { return "maintenant" }
        let magnitude = abs(rounded)
        let text: String
        if magnitude < 60 {
            text = "\(magnitude) min"
        } else if magnitude % 60 == 0 {
            text = "\(magnitude / 60) h"
        } else {
            text = "\(magnitude / 60) h \(String(format: "%02d", magnitude % 60))"
        }
        return rounded < 0 ? "il y a \(text)" : "dans \(text)"
    }
}
