import Foundation
import KaffCore

/// Abstraction de HealthKit pour les doses de caféine et le poids.
protocol HealthStore: Sendable {
    var isAvailable: Bool { get }
    /// `true` si l'utilisateur a autorisé l'écriture des doses (le statut de lecture est masqué par HealthKit).
    var isWriteAuthorized: Bool { get }
    func requestAuthorization() async throws
    func doses(from start: Date, to end: Date) async throws -> [CaffeineDose]
    /// Retourne la dose telle qu'enregistrée (l'`id` devient l'UUID HealthKit).
    func save(_ dose: CaffeineDose) async throws -> CaffeineDose
    func delete(doseID: UUID) async throws
    func latestBodyMassKg() async throws -> Double?
}

/// Erreurs métier du magasin Santé, distinguées des erreurs techniques de HealthKit.
enum HealthStoreError: Error {
    /// HealthKit refuse la suppression d'un échantillon écrit par une autre app (`errorAuthorizationDenied`).
    case notOwnedByKaff
}
