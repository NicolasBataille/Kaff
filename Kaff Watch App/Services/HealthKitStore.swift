import Foundation
import HealthKit
import KaffCore

/// Implémentation HealthKit. `HKHealthStore` est thread-safe (documentation Apple) mais pas annoté `Sendable`.
final class HealthKitStore: HealthStore, @unchecked Sendable {
    enum MetadataKey {
        static let drinkID = "fr.batum.kaff.drinkID"
        static let volumeML = "fr.batum.kaff.volumeML"
        static let source = "fr.batum.kaff.source"
    }

    private let store = HKHealthStore()
    private let caffeineType = HKQuantityType(.dietaryCaffeine)
    private let bodyMassType = HKQuantityType(.bodyMass)
    private let milligram = HKUnit.gramUnit(with: .milli)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    var isWriteAuthorized: Bool { store.authorizationStatus(for: caffeineType) == .sharingAuthorized }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [caffeineType], read: [caffeineType, bodyMassType])
    }

    func doses(from start: Date, to end: Date) async throws -> [CaffeineDose] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: caffeineType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)])
        return try await descriptor.result(for: store).map(dose(from:))
    }

    func save(_ dose: CaffeineDose) async throws -> CaffeineDose {
        var metadata: [String: Any] = [MetadataKey.source: dose.drinkID == nil ? "manual" : "drink"]
        if let drinkID = dose.drinkID { metadata[MetadataKey.drinkID] = drinkID }
        if let volume = dose.volumeML { metadata[MetadataKey.volumeML] = volume }
        let sample = HKQuantitySample(
            type: caffeineType,
            quantity: HKQuantity(unit: milligram, doubleValue: dose.milligrams),
            start: dose.date, end: dose.date, metadata: metadata)
        try await store.save(sample)
        return self.dose(from: sample)
    }

    func delete(doseID: UUID) async throws {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: caffeineType, predicate: HKQuery.predicateForObject(with: doseID))],
            sortDescriptors: [])
        guard let sample = try await descriptor.result(for: store).first else { return }
        try await store.delete(sample)
    }

    func latestBodyMassKg() async throws -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMassType)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1)
        return try await descriptor.result(for: store).first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    private func dose(from sample: HKQuantitySample) -> CaffeineDose {
        CaffeineDose(
            id: sample.uuid,
            date: sample.startDate,
            milligrams: sample.quantity.doubleValue(for: milligram),
            drinkID: sample.metadata?[MetadataKey.drinkID] as? String,
            volumeML: sample.metadata?[MetadataKey.volumeML] as? Double)
    }
}
