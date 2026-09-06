import Foundation

/// Une notification locale à planifier (spec §7.6). L'app replace ses notifications en attente par ce plan
/// à chaque publication du snapshot ; `kind.rawValue` sert d'identifiant stable de requête.
public struct PlannedNotification: Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable, CaseIterable {
        /// « Niveau redescendu sous le seuil coucher : OK pour dormir ».
        case sleepReady
        /// « Dernier <boisson> (<mg>) pour dormir à HH:MM ».
        case lastIntake
    }

    public let kind: Kind
    public let fireAt: Date
    /// Dose de référence (mg) pour `.lastIntake`, nil pour `.sleepReady`.
    public let milligrams: Double?

    public init(kind: Kind, fireAt: Date, milligrams: Double?) {
        self.kind = kind
        self.fireAt = fireAt
        self.milligrams = milligrams
    }
}

/// Calcul pur du plan de notifications à partir des doses et des seuils ; aucune dépendance système.
public enum NotificationPlanner {
    /// Source: choix produit — rien à moins d'une minute, la notification arriverait après le fait.
    public static let minimumLeadSeconds: TimeInterval = 60

    /// - `.sleepReady` : à `sleepReadyDate`, seulement si le seuil est (ou sera, au dernier pic) dépassé — sinon
    ///   `sleepReadyDate` renvoie juste le pic à venir, sans rien à annoncer — et avant le prochain 04:00 — la journée caféine suivante repart de zéro, pas de vibration en pleine nuit.
    /// - `.lastIntake` : à `latestIntakeDate` pour `referenceMg`, seulement s'il existe et respecte le délai.
    /// Résultat trié par `fireAt`.
    public static func plan(doses: [CaffeineDose], limits: AssessmentLimits, referenceMg: Double,
                            wantsSleepReady: Bool, wantsLastIntake: Bool,
                            now: Date, calendar: Calendar) -> [PlannedNotification] {
        let assessor = LevelAssessor(limits: limits, calendar: calendar)
        let earliest = now.addingTimeInterval(minimumLeadSeconds)
        let past = doses.filter { $0.date <= now }
        let sleepReady: PlannedNotification? = {
            guard wantsSleepReady, assessor.exceedsBedtimeLimitAfterLastPeak(doses: past, from: now) else { return nil }
            let at = assessor.sleepReadyDate(doses: past, from: now)
            guard at > earliest, at < assessor.day.nextStart(after: now) else { return nil }
            return PlannedNotification(kind: .sleepReady, fireAt: at, milligrams: nil)
        }()
        let lastIntake: PlannedNotification? = {
            guard wantsLastIntake,
                  let at = assessor.latestIntakeDate(milligrams: referenceMg, doses: past, from: now),
                  at > earliest else { return nil }
            return PlannedNotification(kind: .lastIntake, fireAt: at, milligrams: referenceMg)
        }()
        return [sleepReady, lastIntake].compactMap { $0 }.sorted { $0.fireAt < $1.fireAt }
    }
}
