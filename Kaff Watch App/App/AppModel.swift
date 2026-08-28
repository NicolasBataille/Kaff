import Foundation
import KaffCore
import Observation
import os

/// État global de l'app : doses, profil, autorisation. Orchestration HealthKit → cache → widget.
@MainActor
@Observable
final class AppModel {
    enum AuthorizationState: Equatable { case unknown, authorized, denied, unavailable }

    static let historyDays = 30
    static let cacheHours = 24.0
    static let favoritesLimit = 4
    /// Nombre de lectures du statut d'autorisation avant de conclure « refusé » (voir `pollWriteAuthorization`).
    static let authorizationAttempts = 3

    private(set) var authorization: AuthorizationState = .unknown
    private(set) var doses: [CaffeineDose] = []
    private(set) var profile: UserProfile
    private(set) var customDrinks: [Drink]
    private(set) var lastError: String?
    var path: [Route] = []

    private let health: any HealthStore
    private let profileStore: ProfileStore
    private let cacheStore: CacheStore
    private let widgets: any WidgetReloader
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let authorizationRetryDelay: Duration
    private let logger = Logger(subsystem: "fr.batum.kaff", category: "AppModel")

    init(health: any HealthStore, profileStore: ProfileStore, cacheStore: CacheStore,
         widgets: any WidgetReloader, calendar: Calendar = .current,
         now: @escaping @Sendable () -> Date = { Date() },
         authorizationRetryDelay: Duration = .milliseconds(300)) {
        self.health = health
        self.profileStore = profileStore
        self.cacheStore = cacheStore
        self.widgets = widgets
        self.calendar = calendar
        self.now = now
        self.authorizationRetryDelay = authorizationRetryDelay
        self.profile = profileStore.loadProfile()
        self.customDrinks = profileStore.loadCustomDrinks()
    }

    // MARK: Dérivés

    var assessor: LevelAssessor { LevelAssessor(profile: profile, calendar: calendar) }
    var allDrinks: [Drink] { DrinkCatalog.builtIn + customDrinks }

    var favoriteDrinks: [Drink] {
        DrinkCatalog.favoriteIDs(from: doses.compactMap(\.drinkID), limit: Self.favoritesLimit)
            .compactMap { DrinkCatalog.drink(id: $0, custom: customDrinks) }
    }

    func assessment(at date: Date? = nil) -> LevelAssessment {
        assessor.assess(doses: doses, at: date ?? now())
    }

    func drink(for dose: CaffeineDose) -> Drink? {
        dose.drinkID.flatMap { DrinkCatalog.drink(id: $0, custom: customDrinks) }
    }

    /// Points de courbe (passé + projection) pour les doses connues. Pur : ne modifie rien.
    func chartPoints(from start: Date, hours: Double, stepMinutes: Int) -> [TimelinePoint] {
        TimelineBuilder(assessor: assessor).chartPoints(doses: doses, from: start, hours: hours, stepMinutes: stepMinutes)
    }

    // MARK: Cycle de vie

    func start() async {
        guard health.isAvailable else { authorization = .unavailable; return }
        do { try await health.requestAuthorization() } catch { report("Autorisation Santé impossible", error) }
        authorization = await pollWriteAuthorization() ? .authorized : .denied
        guard authorization == .authorized else { return }
        await refresh()
    }

    /// HealthKit renvoie encore `.sharingDenied` juste après la fermeture de la feuille d'autorisation
    /// (observé sur simulateur en M2.3) : on relit le statut quelques fois avant de conclure.
    private func pollWriteAuthorization() async -> Bool {
        for attempt in 1...Self.authorizationAttempts {
            guard !Task.isCancelled else { return false }
            if health.isWriteAuthorized { return true }
            if attempt < Self.authorizationAttempts { try? await Task.sleep(for: authorizationRetryDelay) }
        }
        return false
    }

    func refresh() async {
        lastError = nil
        let end = now()
        let start = calendar.date(byAdding: .day, value: -Self.historyDays, to: end) ?? end
        do {
            doses = try await health.doses(from: start, to: end)
        } catch {
            report("Lecture Santé impossible", error)
            return
        }
        do {
            if let kg = try await health.latestBodyMassKg(), kg != profile.healthKitWeightKg {
                profile.healthKitWeightKg = kg
                try profileStore.save(profile)
            }
        } catch {
            report("Lecture du poids impossible", error)
        }
        publish()
    }

    // MARK: Actions

    func log(milligrams: Double, drink: Drink?, volumeML: Double?) async {
        lastError = nil
        let clamped = min(max(milligrams, UserProfile.Bounds.doseMg.lowerBound), UserProfile.Bounds.doseMg.upperBound)
        let dose = CaffeineDose(date: now(), milligrams: clamped, drinkID: drink?.id, volumeML: volumeML)
        do {
            let saved = try await health.save(dose)
            doses = (doses + [saved]).sorted { $0.date < $1.date }
            publish()
        } catch {
            report("Enregistrement impossible", error)
        }
    }

    func delete(_ dose: CaffeineDose) async {
        lastError = nil
        do {
            try await health.delete(doseID: dose.id)
            doses.removeAll { $0.id == dose.id }
            publish()
        } catch {
            report("Suppression impossible", error)
        }
    }

    func update(profile newProfile: UserProfile) async {
        lastError = nil
        profile = newProfile.clamped()
        do { try profileStore.save(profile) } catch { report("Sauvegarde des réglages impossible", error) }
        publish()
    }

    func save(customDrink: Drink) async {
        lastError = nil
        customDrinks = customDrinks.filter { $0.id != customDrink.id } + [customDrink]
        do { try profileStore.saveCustomDrinks(customDrinks) } catch { report("Sauvegarde de la boisson impossible", error) }
    }

    func deleteCustomDrink(id: String) async {
        lastError = nil
        customDrinks.removeAll { $0.id == id }
        do { try profileStore.saveCustomDrinks(customDrinks) } catch { report("Suppression de la boisson impossible", error) }
    }

    func clearError() { lastError = nil }

    // MARK: Privé

    /// Écrit le snapshot 24 h et demande le rechargement des complications.
    private func publish() {
        let cutoff = now().addingTimeInterval(-Self.cacheHours * 3600)
        let snapshot = CacheSnapshot(doses: doses.filter { $0.date >= cutoff }, profile: profile, updatedAt: now())
        do { try cacheStore.write(snapshot) } catch { report("Écriture du cache impossible", error) }
        widgets.reloadAll()
    }

    private func report(_ message: String, _ error: Error) {
        logger.error("\(message, privacy: .public): \(error.localizedDescription)")
        lastError = message
    }
}
