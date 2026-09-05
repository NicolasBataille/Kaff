import Foundation
import KaffCore

/// Abstraction de HealthKit pour les doses de caféine et le poids.
protocol HealthStore: Sendable {
    var isAvailable: Bool { get }
    /// Statut d'écriture des doses (le statut de lecture est masqué par HealthKit).
    var writeStatus: HealthWriteStatus { get }
    /// Présente la feuille Santé. À appeler sur action de l'utilisateur, app au premier plan : HealthKit ne la
    /// montre qu'une fois par type, et ne la ré-affiche jamais après un refus (seul Réglages › Santé reste).
    func requestAuthorization() async throws
    func doses(from start: Date, to end: Date) async throws -> [CaffeineDose]
    /// Retourne la dose telle qu'enregistrée (l'`id` devient l'UUID HealthKit).
    func save(_ dose: CaffeineDose) async throws -> CaffeineDose
    func delete(doseID: UUID) async throws
    /// Dernière pesée présente dans la base Santé **de la montre** (copie partielle et récente de celle de l'iPhone).
    func latestBodyMass() async throws -> BodyMassReading?
}

/// Une pesée lue dans HealthKit.
struct BodyMassReading: Equatable, Sendable {
    let kg: Double
    let date: Date
}

/// Autorisation d'écriture telle que HealthKit la rapporte (`HKAuthorizationStatus`).
enum HealthWriteStatus: Equatable, Sendable {
    /// La feuille Santé n'a pas encore été présentée : on peut la demander.
    case notDetermined
    case authorized
    /// Refusée ou balayée : la feuille ne reviendra pas, l'utilisateur doit passer par Réglages.
    case denied
}

extension HealthStore {
    var isWriteAuthorized: Bool { writeStatus == .authorized }
}

/// Erreurs métier du magasin Santé, distinguées des erreurs techniques de HealthKit.
enum HealthStoreError: Error {
    /// HealthKit refuse la suppression d'un échantillon écrit par une autre app (`errorAuthorizationDenied`).
    case notOwnedByKaff
}
