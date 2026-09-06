import Foundation
import KaffCore
import os
import UserNotifications

/// Autorisation des notifications telle que l'app la voit (`UNAuthorizationStatus` réduit à trois cas).
enum NotificationAuthorization: Equatable, Sendable {
    /// La demande système n'a pas encore été présentée : on peut la faire (sur action de l'utilisateur).
    case notDetermined
    case authorized
    /// Refusée : aucune re-demande automatique, seul Réglages › Notifications reste (spec §9).
    case denied
}

/// Contexte d'affichage : le planificateur (KaffCore) ne connaît que des mg et des dates.
struct NotificationContent: Equatable, Sendable {
    /// « Espresso » — boisson de référence du rappel « dernier ».
    let referenceDrinkName: String
    /// Pour « … pour dormir à 23:00 » (coucher effectif, spec §5.1).
    let bedtime: ClockTime
    /// Pour « redescendu sous 35 mg ».
    let bedtimeLimitMg: Double
}

/// Abstraction de `UNUserNotificationCenter` (spec §3.1) : mock dans les tests de `AppModel`.
protocol NotificationScheduler: Sendable {
    func authorization() async -> NotificationAuthorization
    /// Présente la demande système ; retourne l'état résultant. À appeler sur action de l'utilisateur.
    func requestAuthorization() async throws -> NotificationAuthorization
    /// Remplace toutes les notifications en attente de Kaff par `plan` (vide = tout retirer).
    func replace(_ plan: [PlannedNotification], content: NotificationContent) async
}

/// Implémentation `UserNotifications`. Sans état : le centre est relu à chaque appel (`UNUserNotificationCenter`
/// n'est pas `Sendable`).
final class UserNotificationScheduler: NotificationScheduler {
    /// Préfixe des identifiants de requête : seules celles-ci sont retirées par `replace`.
    static let identifierPrefix = "fr.nikou.kaff.notification."

    private let logger = Logger(subsystem: "fr.nikou.kaff", category: "Notifications")

    func authorization() async -> NotificationAuthorization {
        Self.authorization(from: await UNUserNotificationCenter.current().notificationSettings().authorizationStatus)
    }

    func requestAuthorization() async throws -> NotificationAuthorization {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        return granted ? .authorized : .denied
    }

    func replace(_ plan: [PlannedNotification], content: NotificationContent) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        for item in plan {
            do {
                try await center.add(Self.request(for: item, content: content))
            } catch {
                logger.error("Planification impossible (\(item.kind.rawValue, privacy: .public)): \(error.localizedDescription)")
            }
        }
    }

    static func authorization(from status: UNAuthorizationStatus) -> NotificationAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized, .provisional, .ephemeral: .authorized
        case .denied: .denied
        @unknown default: .notDetermined
        }
    }

    /// Déclencheur calendaire non répétitif à la seconde près ; identifiant stable par genre (une seule requête par genre).
    private static func request(for item: PlannedNotification, content: NotificationContent) -> UNNotificationRequest {
        let body = UNMutableNotificationContent()
        body.title = title(for: item, content: content)
        body.body = text(for: item, content: content)
        body.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: identifierPrefix + item.kind.rawValue, content: body, trigger: trigger)
    }

    private static func title(for item: PlannedNotification, content: NotificationContent) -> String {
        switch item.kind {
        case .sleepReady: String(localized: "OK pour dormir")
        case .lastIntake: String(localized: "Dernier \(content.referenceDrinkName)")
        }
    }

    private static func text(for item: PlannedNotification, content: NotificationContent) -> String {
        switch item.kind {
        case .sleepReady:
            return String(localized: "Niveau redescendu sous \(Formatters.mg(content.bedtimeLimitMg)).")
        case .lastIntake:
            let mg = Formatters.mg(item.milligrams ?? 0)
            let time = Formatters.time(content.bedtime)
            return String(localized: "Dernier \(content.referenceDrinkName) (\(mg)) pour dormir à \(time).")
        }
    }
}
