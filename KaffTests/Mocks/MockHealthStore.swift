import Foundation
import KaffCore
@testable import Kaff_Watch_App

/// Tests séquentiels sur le MainActor : pas de synchronisation nécessaire.
final class MockHealthStore: HealthStore, @unchecked Sendable {
    var isAvailable = true
    var stored: [CaffeineDose] = []
    var bodyMassKg: Double? = 72
    var bodyMassDate = Date(timeIntervalSince1970: 1_700_000_000)
    var bodyMassError: Error?
    var saveError: Error?
    var deleteError: Error?
    var authorizationError: Error?
    var savedIDs: [UUID] = []
    var deletedIDs: [UUID] = []
    /// Nombre d'appels à `requestAuthorization` (la feuille Santé ne doit partir que sur action de l'utilisateur).
    private(set) var authorizationRequests = 0

    var sleepSessions: [SleepSession] = []
    var sleepError: Error?
    var sleepAuthorizationError: Error?
    /// Nombre d'appels à `requestSleepAuthorization` (une seule fois, sur activation de l'option).
    private(set) var sleepAuthorizationRequests = 0
    /// Fenêtres demandées à `sleepSessions(from:to:)` ; vide tant que l'option est inactive.
    private(set) var sleepQueries: [(start: Date, end: Date)] = []

    /// Simule le retard de HealthKit : le statut reste `.denied` pendant les N premières lectures après la feuille
    /// (observé en M2.3), puis passe à `.authorized`.
    var authorizedAfterChecks: Int?
    private var authorizationChecks = 0
    private var status: HealthWriteStatus = .authorized

    var writeStatus: HealthWriteStatus {
        get {
            guard let authorizedAfterChecks else { return status }
            authorizationChecks += 1
            return authorizationChecks > authorizedAfterChecks ? .authorized : .denied
        }
        set { status = newValue }
    }

    func requestAuthorization() async throws {
        authorizationRequests += 1
        if let authorizationError { throw authorizationError }
    }

    func doses(from start: Date, to end: Date) async throws -> [CaffeineDose] {
        stored.filter { $0.date >= start && $0.date <= end }
    }

    /// Reflète le contrat réel : l'`id` retourné est celui attribué par HealthKit.
    func save(_ dose: CaffeineDose) async throws -> CaffeineDose {
        if let saveError { throw saveError }
        let saved = CaffeineDose(id: UUID(), date: dose.date, milligrams: dose.milligrams,
                                 drinkID: dose.drinkID, volumeML: dose.volumeML)
        stored.append(saved)
        savedIDs.append(saved.id)
        return saved
    }

    func delete(doseID: UUID) async throws {
        if let deleteError { throw deleteError }
        stored.removeAll { $0.id == doseID }
        deletedIDs.append(doseID)
    }

    func latestBodyMass() async throws -> BodyMassReading? {
        if let bodyMassError { throw bodyMassError }
        return bodyMassKg.map { BodyMassReading(kg: $0, date: bodyMassDate) }
    }

    func requestSleepAuthorization() async throws {
        sleepAuthorizationRequests += 1
        if let sleepAuthorizationError { throw sleepAuthorizationError }
    }

    func sleepSessions(from start: Date, to end: Date) async throws -> [SleepSession] {
        sleepQueries.append((start: start, end: end))
        if let sleepError { throw sleepError }
        return sleepSessions.filter { $0.start >= start && $0.start <= end }
    }
}
