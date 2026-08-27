import Foundation
import KaffCore
@testable import Kaff_Watch_App

/// Tests séquentiels sur le MainActor : pas de synchronisation nécessaire.
final class MockHealthStore: HealthStore, @unchecked Sendable {
    var isAvailable = true
    var isWriteAuthorized = true
    var stored: [CaffeineDose] = []
    var bodyMassKg: Double? = 72
    var saveError: Error?
    var savedIDs: [UUID] = []
    var deletedIDs: [UUID] = []

    func requestAuthorization() async throws {}

    func doses(from start: Date, to end: Date) async throws -> [CaffeineDose] {
        stored.filter { $0.date >= start && $0.date <= end }
    }

    func save(_ dose: CaffeineDose) async throws -> CaffeineDose {
        if let saveError { throw saveError }
        stored.append(dose)
        savedIDs.append(dose.id)
        return dose
    }

    func delete(doseID: UUID) async throws {
        stored.removeAll { $0.id == doseID }
        deletedIDs.append(doseID)
    }

    func latestBodyMassKg() async throws -> Double? { bodyMassKg }
}
