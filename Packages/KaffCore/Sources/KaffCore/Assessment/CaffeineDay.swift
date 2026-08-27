import Foundation

/// Découpage de la journée « caféine » : elle commence à 04:00, pas à minuit.
public struct CaffeineDay: Sendable {
    /// Source: choix produit — une soirée tardive ne remet pas le cumul à zéro à minuit.
    public static let startHour = 4

    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Début (04:00) de la journée caféine contenant `date`.
    public func start(containing date: Date) -> Date {
        let hour = calendar.component(.hour, from: date)
        let base = hour >= Self.startHour ? date : calendar.date(byAdding: .day, value: -1, to: date)!
        return calendar.date(bySettingHour: Self.startHour, minute: 0, second: 0, of: base)!
    }

    /// Prochaine heure de coucher. Si elle est déjà passée dans la journée caféine courante, retourne `now`.
    public func nextBedtime(_ bedtime: ClockTime, after now: Date) -> Date {
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let dayStart = Self.startHour * 60
        let nowRel = (nowMinutes - dayStart + 1440) % 1440
        let bedRel = (bedtime.minutesOfDay - dayStart + 1440) % 1440
        guard nowRel < bedRel else { return now }
        return calendar.nextDate(
            after: now,
            matching: DateComponents(hour: bedtime.hour, minute: bedtime.minute),
            matchingPolicy: .nextTimePreservingSmallerComponents)!
    }
}
