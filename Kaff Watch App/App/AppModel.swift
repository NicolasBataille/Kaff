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
    private let logger = Logger(subsystem: "fr.batum.kaff", category: "AppModel")

    init(health: any HealthStore, profileStore: ProfileStore, cacheStore: CacheStore,
         widgets: any WidgetReloader, calendar: Calendar = .current,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.health = health
        self.profileStore = profileStore
        self.cacheStore = cacheStore
        self.widgets = widgets
        self.calendar = calendar
        self.now = now
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

    // MARK: Cycle de vie

    func start() async {
        guard health.isAvailable else { authorization = .unavailable; return }
        do { try await health.requestAuthorization() } catch { report("Autorisation Santé impossible", error) }
        authorization = health.isWriteAuthorized ? .authorized : .denied
        guard authorization == .authorized else { return }
        await refresh()
    }

    func refresh() async {
        let end = now()
        let start = calendar.date(byAdding: .day, value: -Self.historyDays, to: end) ?? end
        do {
            doses = try await health.doses(from: start, to: end)
            if let kg = try await health.latestBodyMassKg(), kg != profile.healthKitWeightKg {
                profile.healthKitWeightKg = kg
                try profileStore.save(profile)
            }
            publish()
        } catch {
            report("Lecture Santé impossible", error)
        }
    }

    // MARK: Actions

    func log(milligrams: Double, drink: Drink?, volumeML: Double?) async {
        let clamped = min(max(milligrams, UserProfile.Bounds.doseMg.lowerBound), UserProfile.Bounds.doseMg.upperBound)
        let dose = CaffeineDose(date: now(), milligrams: clamped, drinkID: drink?.id, volumeML: volumeML)
        do {
            let saved = try await health.save(dose)
            doses = (doses + [saved]).sorted { $0.date < $1.date }
            lastError = nil
            publish()
        } catch {
            report("Enregistrement impossible", error)
        }
    }

    func delete(_ dose: CaffeineDose) async {
        do {
            try await health.delete(doseID: dose.id)
            doses.removeAll { $0.id == dose.id }
            publish()
        } catch {
            report("Suppression impossible", error)
        }
    }

    func update(profile newProfile: UserProfile) async {
        profile = newProfile.clamped()
        do { try profileStore.save(profile) } catch { report("Sauvegarde des réglages impossible", error) }
        publish()
    }

    func save(customDrink: Drink) async {
        customDrinks = customDrinks.filter { $0.id != customDrink.id } + [customDrink]
        do { try profileStore.saveCustomDrinks(customDrinks) } catch { report("Sauvegarde de la boisson impossible", error) }
    }

    func deleteCustomDrink(id: String) async {
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
        logger.error("\(message): \(error.localizedDescription, privacy: .public)")
        lastError = message
    }
}
