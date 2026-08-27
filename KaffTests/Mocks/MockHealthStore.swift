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
    var savedIDs: [UUID] = []
    var deletedIDs: [UUID] = []

    /// Simule le retard de HealthKit : `isWriteAuthorized` renvoie `false` pendant les N premières lectures.
    var authorizedAfterChecks: Int?
    private var authorizationChecks = 0
    private var writeAuthorized = true

    var isWriteAuthorized: Bool {
        get {
            guard let authorizedAfterChecks else { return writeAuthorized }
            authorizationChecks += 1
            return authorizationChecks > authorizedAfterChecks
        }
        set { writeAuthorized = newValue }
    }

    func requestAuthorization() async throws {}

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
        stored.removeAll { $0.id == doseID }
        deletedIDs.append(doseID)
    }

    func latestBodyMassKg() async throws -> Double? {
        if let bodyMassError { throw bodyMassError }
        return bodyMassKg
    }
}
