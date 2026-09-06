import Foundation

/// Heure de coucher déduite des nuits Santé, avec le nombre de nuits qui la soutiennent.
public struct BedtimeEstimate: Hashable, Sendable {
    public let time: ClockTime
    public let nights: Int

    public init(time: ClockTime, nights: Int) {
        self.time = time
        self.nights = nights
    }
}

/// Déduit l'heure de coucher habituelle des sessions de sommeil (spec §5.1).
public enum BedtimeInference {
    /// Source: fact-check §5 « médiane des 7–14 dernières nuits » ; assez court pour suivre un changement d'habitude.
    public static let lookbackDays = 14
    /// Source: choix produit — une médiane sur 1–2 nuits n'est pas une habitude.
    public static let minimumNights = 3
    /// Source: choix produit, sans base littéraire.
    public static let napMaxHours = 3.0
    /// Source: choix produit (affichage HH:MM stable).
    public static let roundingMinutes = 5
    /// Source: choix produit — une session qui commence entre 05:00 et 18:59 et dure ≤ `napMaxHours` est une sieste.
    public static let napWindowStartHour = 5
    /// Fin exclue de la fenêtre de sieste (19:00) ; c'est aussi le premier coucher accepté.
    /// Source: choix produit — un coucher entre `CaffeineDay.startHour` et 19:00 tombe dans la journée caféine suivante.
    public static let napWindowEndHour = 19
    /// HealthKit écrit une nuit en plusieurs échantillons (phases, réveils) : deux fragments séparés d'au plus cet
    /// écart forment la même nuit. Source: choix produit — un réveil nocturne dure des minutes, pas des heures ;
    /// deux nuits consécutives sont espacées d'une journée.
    public static let mergeGapHours = 2.0

    /// Source: définition — secondes par heure.
    private static let secondsPerHour = 3600.0
    /// Source: définition — minutes par jour.
    private static let minutesPerDay = 1440
    /// Source: définition — 12:00 en minutes, origine de la médiane circulaire (23:30 → 690, 00:30 → 750).
    private static let noonMinutes = 720

    /// Les fragments d'une même nuit sont d'abord fusionnés (`mergeGapHours`), puis les siestes écartées : une
    /// session qui commence entre 05:00 et 18:59 et dure ≤ `napMaxHours`.
    /// `nil` si moins de `minimumNights` nuits dans la fenêtre ou si la médiane tombe entre 04:00 et 18:59.
    public static func estimate(sessions: [SleepSession], now: Date, calendar: Calendar) -> BedtimeEstimate? {
        guard let windowStart = calendar.date(byAdding: .day, value: -lookbackDays, to: now) else { return nil }
        let inWindow = sessions.filter { $0.start >= windowStart && $0.start <= now }
        let candidates = merged(inWindow).filter { !isNap($0, calendar: calendar) }
        let bedtimes = nightlyBedtimes(candidates, calendar: calendar)
        guard bedtimes.count >= minimumNights else { return nil }

        let time = circularMedian(minutesOfDay: bedtimes.map { minutesOfDay($0, calendar: calendar) })
        guard isAcceptableBedtime(time) else { return nil }
        return BedtimeEstimate(time: time, nights: bedtimes.count)
    }

    /// Fusionne les sessions qui se chevauchent ou se suivent à moins de `mergeGapHours` (tri par début, balayage) ;
    /// la session fusionnée garde le début du premier fragment et la fin la plus tardive, kind du premier fragment.
    static func merged(_ sessions: [SleepSession]) -> [SleepSession] {
        let gap = mergeGapHours * secondsPerHour
        return sessions.sorted { $0.start < $1.start }.reduce(into: [SleepSession]()) { result, next in
            guard let last = result.last, next.start.timeIntervalSince(last.end) <= gap else {
                result.append(next)
                return
            }
            result[result.count - 1] = SleepSession(start: last.start, end: max(last.end, next.end), kind: last.kind)
        }
    }

    static func isNap(_ session: SleepSession, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: session.start)
        let startsInDaytime = (napWindowStartHour..<napWindowEndHour).contains(hour)
        return startsInDaytime && session.duration <= napMaxHours * secondsPerHour
    }

    /// Début le plus tôt de chaque groupe de sessions partageant la même journée caféine.
    static func nightlyBedtimes(_ sessions: [SleepSession], calendar: Calendar) -> [Date] {
        let day = CaffeineDay(calendar: calendar)
        let byNight = Dictionary(grouping: sessions) { day.start(containing: $0.start) }
        return byNight.values.compactMap { $0.map(\.start).min() }
    }

    /// Médiane des heures mesurées depuis 12:00 (pour que 23:30 et 00:30 donnent 00:00), arrondie à `roundingMinutes`.
    static func circularMedian(minutesOfDay: [Int]) -> ClockTime {
        let sinceNoon = minutesOfDay
            .map { ($0 - noonMinutes + minutesPerDay) % minutesPerDay }
            .sorted()
        let count = sinceNoon.count
        let median: Double = count.isMultiple(of: 2)
            ? Double(sinceNoon[count / 2 - 1] + sinceNoon[count / 2]) / 2
            : Double(sinceNoon[count / 2])
        let step = Double(roundingMinutes)
        let rounded = Int((median / step).rounded() * step)
        let minutes = (rounded + noonMinutes) % minutesPerDay
        return ClockTime(hour: minutes / 60, minute: minutes % 60)
    }

    /// Un coucher entre `CaffeineDay.startHour` (04:00) et 18:59 appartiendrait à la journée caféine suivante.
    static func isAcceptableBedtime(_ time: ClockTime) -> Bool {
        !(CaffeineDay.startHour..<napWindowEndHour).contains(time.hour)
    }

    private static func minutesOfDay(_ date: Date, calendar: Calendar) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }
}
