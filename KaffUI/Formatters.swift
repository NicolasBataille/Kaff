import Foundation
import KaffCore

/// Mise en forme des valeurs affichées (français, chiffres en `monospacedDigit` côté vue).
enum Formatters {
    static func mg(_ value: Double) -> String { "\(mgValue(value)) mg" }
    static func mgValue(_ value: Double) -> String { "\(Int(value.rounded()))" }
    static func ml(_ value: Double) -> String { "\(Int(value.rounded())) ml" }
    /// « 3,9 mg/L » — concentration plasmatique estimée (spec §5.3), une décimale, séparateur de la locale.
    static func mgPerLitre(_ value: Double) -> String { "\(mgPerLitreValue(value)) mg/L" }
    static func mgPerLitreValue(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(1))) }
    /// « 08:53 » (toujours deux chiffres, comme la barre d'état).
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
    static func count(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...1))) }
    /// Pluriel basé sur la valeur affichée par `count` (1,98 s'affiche « 2 » → pluriel).
    static func isPlural(_ value: Double) -> Bool { (value * 10).rounded() / 10 >= 2 }
    static func kg(_ value: Double) -> String { "\(Int(value.rounded())) kg" }
    static func hours(_ value: Double) -> String { "\(count(value)) h" }
    static func minutes(_ value: Double) -> String { "\(Int(value.rounded())) min" }

    /// « 23:00 » pour une heure de la journée.
    static func time(_ clock: ClockTime) -> String {
        String(format: "%02d:%02d", clock.hour, clock.minute)
    }

    /// « 3 sept. » pour dater la dernière pesée.
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// « jeudi 28 » pour les sections d'historique.
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day())
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
