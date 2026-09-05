import Foundation
import KaffCore
@testable import Kaff_Watch_App

/// Tests séquentiels sur le MainActor : pas de synchronisation nécessaire.
final class MockHealthStore: HealthStore, @unchecked Sendable {
    var isAvailable = true
    var stored: [CaffeineDose] = []
    var bodyMassKg: Double? = 72
    var bodyMassError: Error?
    var saveError: Error?
    var deleteError: Error?
    var authorizationError: Error?
    var savedIDs: [UUID] = []
    var deletedIDs: [UUID] = []
    /// Nombre d'appels à `requestAuthorization` (la feuille Santé ne doit partir que sur action de l'utilisateur).
    private(set) var authorizationRequests = 0

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

    func latestBodyMassKg() async throws -> Double? {
        if let bodyMassError { throw bodyMassError }
        return bodyMassKg
    }
}
