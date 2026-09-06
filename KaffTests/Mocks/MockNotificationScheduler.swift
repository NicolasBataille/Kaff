import KaffCore
@testable import Kaff_Watch_App

/// Tests séquentiels sur le MainActor : pas de synchronisation nécessaire.
final class MockNotificationScheduler: NotificationScheduler, @unchecked Sendable {
    /// Statut lu par `authorization()` ; `requestAuthorization` le remplace par `requestResult`.
    var status: NotificationAuthorization = .notDetermined
    var requestResult: NotificationAuthorization = .authorized
    var requestError: Error?
    /// Nombre d'appels à `requestAuthorization` (la demande système ne doit partir qu'une fois, sur action).
    private(set) var authorizationRequests = 0
    /// Chaque appel à `replace`, dans l'ordre : le dernier est le plan en vigueur.
    private(set) var replacements: [(plan: [PlannedNotification], content: NotificationContent)] = []

    func authorization() async -> NotificationAuthorization { status }

    func requestAuthorization() async throws -> NotificationAuthorization {
        authorizationRequests += 1
        if let requestError { throw requestError }
        status = requestResult
        return requestResult
    }

    func replace(_ plan: [PlannedNotification], content: NotificationContent) async {
        replacements.append((plan: plan, content: content))
    }
}
