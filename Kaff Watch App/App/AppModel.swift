import Foundation
import KaffCore
import Observation
import os

/// État global de l'app : doses, profil, autorisation. Orchestration HealthKit → cache → widget.
@MainActor
@Observable
final class AppModel {
    /// `notDetermined` : la feuille Santé n'a pas encore été présentée, l'écran d'accueil propose « Autoriser ».
    enum AuthorizationState: Equatable { case unknown, notDetermined, authorized, denied, unavailable }

    /// Source: spec §6 — favoris calculés sur 30 jours ; l'historique n'en affiche que 7.
    static let historyDays = 30
    /// Source: spec §6 — quatre favoris en tête du carrousel.
    static let favoritesLimit = 4
    /// Nombre de lectures du statut d'autorisation avant de conclure « refusé » (voir `pollWriteAuthorization`).
    static let authorizationAttempts = 3

    /// Coucher Santé (spec §5.1) : option inactive, valeur déduite (nombre de nuits), ou aucune nuit exploitable.
    enum HealthBedtimeState: Equatable { case off, inferred(nights: Int), noNights }

    private(set) var authorization: AuthorizationState = .unknown
    private(set) var doses: [CaffeineDose] = []
    private(set) var profile: UserProfile
    private(set) var customDrinks: [Drink]
    private(set) var lastError: String?
    /// Lu au démarrage ; la demande système ne part que de `setNotifications`, sur action de l'utilisateur.
    private(set) var notificationAuthorization: NotificationAuthorization = .notDetermined
    /// Dernier plan remis au planificateur (Réglages : « Prochain rappel 19:05 »).
    private(set) var plannedNotifications: [PlannedNotification] = []
    var path: [Route] = []

    private let health: any HealthStore
    private let profileStore: ProfileStore
    private let cacheStore: CacheStore
    private let widgets: any WidgetReloader
    private let notifications: any NotificationScheduler
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let authorizationRetryDelay: Duration
    private let logger = Logger(subsystem: "fr.nikou.kaff", category: "AppModel")

    init(health: any HealthStore, profileStore: ProfileStore, cacheStore: CacheStore,
         widgets: any WidgetReloader, notifications: any NotificationScheduler, calendar: Calendar = .current,
         now: @escaping @Sendable () -> Date = { Date() },
         authorizationRetryDelay: Duration = .milliseconds(300)) {
        self.health = health
        self.profileStore = profileStore
        self.cacheStore = cacheStore
        self.widgets = widgets
        self.notifications = notifications
        self.calendar = calendar
        self.now = now
        self.authorizationRetryDelay = authorizationRetryDelay
        self.profile = profileStore.loadProfile()
        self.customDrinks = profileStore.loadCustomDrinks()
    }

    // MARK: Dérivés

    var assessor: LevelAssessor { LevelAssessor(profile: profile, calendar: calendar) }
    var allDrinks: [Drink] { DrinkCatalog.builtIn + customDrinks }

    var healthBedtimeState: HealthBedtimeState {
        guard profile.usesHealthBedtime else { return .off }
        guard profile.healthBedtime != nil, let nights = profile.healthBedtimeNights else { return .noNights }
        return .inferred(nights: nights)
    }

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

    /// Points de courbe (passé + projection). `adding` > 0 ajoute une dose hypothétique prise à `now()`
    /// (aperçu d'impact). Pur : ne modifie rien.
    func chartPoints(from start: Date, hours: Double, stepMinutes: Int, adding milligrams: Double = 0) -> [TimelinePoint] {
        TimelineBuilder(assessor: assessor)
            .chartPoints(doses: doses(adding: milligrams), from: start, hours: hours, stepMinutes: stepMinutes)
    }

    // MARK: Historique (pur)

    /// Doses des `days` dernières journées caféine (04:00 → 04:00, aujourd'hui compris), groupées par journée :
    /// sections et doses les plus récentes en tête. Même découpage que le cumul de la carte du jour.
    func historySections(days: Int = 7) -> [HistorySection] {
        let day = assessor.day
        let todayStart = day.start(containing: now())
        guard days > 0, let cutoff = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else { return [] }
        let grouped = Dictionary(grouping: doses.filter { $0.date >= cutoff }) { day.start(containing: $0.date) }
        return grouped.keys.sorted(by: >).map { start in
            HistorySection(dayStart: start, doses: (grouped[start] ?? []).sorted { $0.date > $1.date })
        }
    }

    // MARK: Aperçu d'impact (pur)

    /// Pas d'échantillonnage pour `peak(afterAdding:)`.
    /// Source: choix produit — précision d'affichage « pic à 14:35 », bien sous la tolérance de ±10 min des tests.
    static let peakSampleStepMinutes = 2
    /// Horizon de recherche du pic : tmax vaut ≈ 0,74 h avec t½ = 5 h et reste < 2 h sur toute la plage 2–10 h.
    static let peakSearchHours = 3.0

    /// Évaluation à `date ?? now()` avec une dose hypothétique de `milligrams` prise à `now()`.
    func preview(adding milligrams: Double, at date: Date? = nil) -> LevelAssessment {
        assessor.assess(doses: doses(adding: milligrams), at: date ?? now())
    }

    /// Instant et valeur du niveau maximal dans les 3 h après l'ajout hypothétique de `milligrams` à `now()`.
    /// Échantillonne la quantité seule (pas d'évaluation complète par point : appelé à chaque cran de couronne).
    func peak(afterAdding milligrams: Double) -> (date: Date, mg: Double) {
        let start = now()
        let all = doses(adding: milligrams)
        let pk = assessor.model
        let step = TimeInterval(Self.peakSampleStepMinutes * 60)
        let samples = stride(from: 0.0, through: Self.peakSearchHours * 3600, by: step).map { offset in
            let date = start.addingTimeInterval(offset)
            return (date: date, mg: pk.amount(doses: all, at: date))
        }
        return samples.max { $0.mg < $1.mg } ?? (start, 0)
    }

    private func doses(adding milligrams: Double) -> [CaffeineDose] {
        guard milligrams > 0 else { return doses }
        return doses + [CaffeineDose(date: now(), milligrams: milligrams)]
    }

    // MARK: Cycle de vie

    /// Lit l'état sans rien demander : la feuille Santé ne part que de `requestAccess()`, sur action de
    /// l'utilisateur (au lancement, sur montre réelle, elle n'apparaît pas de façon fiable).
    func start() async {
        notificationAuthorization = await notifications.authorization()
        guard health.isAvailable else { authorization = .unavailable; return }
        await apply(status: health.writeStatus)
    }

    /// Présente la feuille Santé puis relit le statut (bouton « Autoriser » de l'écran d'accueil).
    func requestAccess() async {
        guard health.isAvailable else { authorization = .unavailable; return }
        do { try await health.requestAuthorization() } catch { report("Autorisation Santé impossible", error) }
        await apply(status: await pollWriteStatus())
    }

    private func apply(status: HealthWriteStatus) async {
        switch status {
        case .authorized:
            authorization = .authorized
            await refresh()
        case .notDetermined:
            authorization = .notDetermined
        case .denied:
            authorization = .denied
        }
    }

    /// HealthKit renvoie encore `.sharingDenied` juste après la fermeture de la feuille d'autorisation
    /// (observé sur simulateur en M2.3) : on relit le statut quelques fois avant de conclure.
    private func pollWriteStatus() async -> HealthWriteStatus {
        var status = health.writeStatus
        for attempt in 1...Self.authorizationAttempts where status != .authorized {
            guard !Task.isCancelled else { break }
            if attempt < Self.authorizationAttempts { try? await Task.sleep(for: authorizationRetryDelay) }
            status = health.writeStatus
        }
        return status
    }

    /// Relit doses, poids et (option active) nuits ; une erreur de poids ou de sommeil n'empêche pas la publication.
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
        await refreshWeight()
        if profile.usesHealthBedtime {
            let before = profile
            await inferHealthBedtime()
            if profile != before { saveProfile() }
        }
        await publish()
    }

    private func refreshWeight() async {
        do {
            if let reading = try await health.latestBodyMass(),
               reading.kg != profile.healthKitWeightKg || reading.date != profile.healthKitWeightDate {
                profile.healthKitWeightKg = reading.kg
                profile.healthKitWeightDate = reading.date
                try profileStore.save(profile)
            }
        } catch {
            report("Lecture du poids impossible", error)
        }
    }

    // MARK: Actions

    func log(milligrams: Double, drink: Drink?, volumeML: Double?) async {
        lastError = nil
        let clamped = min(max(milligrams, UserProfile.Bounds.doseMg.lowerBound), UserProfile.Bounds.doseMg.upperBound)
        let dose = CaffeineDose(date: now(), milligrams: clamped, drinkID: drink?.id, volumeML: volumeML)
        do {
            let saved = try await health.save(dose)
            doses = (doses + [saved]).sorted { $0.date < $1.date }
            await publish()
        } catch {
            report("Enregistrement impossible", error)
        }
    }

    func delete(_ dose: CaffeineDose) async {
        lastError = nil
        do {
            try await health.delete(doseID: dose.id)
            doses.removeAll { $0.id == dose.id }
            await publish()
        } catch HealthStoreError.notOwnedByKaff {
            report("Cette dose n'a pas été ajoutée par Kaff", HealthStoreError.notOwnedByKaff)
        } catch {
            report("Suppression impossible", error)
        }
    }

    func update(profile newProfile: UserProfile) async {
        lastError = nil
        profile = newProfile.clamped()
        saveProfile()
        await publish()
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

    // MARK: Coucher Santé (spec §5.1)

    /// Interrupteur « Coucher depuis Santé » : demande la lecture du sommeil (une fois, sur cette action), déduit le
    /// coucher et publie. Un échec de la demande n'empêche pas de lire : HealthKit masque le statut de lecture, et
    /// une autorisation déjà accordée reste valable.
    func enableHealthBedtime() async {
        lastError = nil
        do { try await health.requestSleepAuthorization() } catch { report("Autorisation sommeil impossible", error) }
        profile.usesHealthBedtime = true
        await inferHealthBedtime()
        saveProfile()
        await publish()
    }

    /// Retour au coucher manuel ; la dernière valeur déduite reste mémorisée (réactivation sans relecture visible).
    func disableHealthBedtime() async {
        lastError = nil
        profile.usesHealthBedtime = false
        saveProfile()
        await publish()
    }

    /// Lit les nuits des `BedtimeInference.lookbackDays` derniers jours et met à jour `healthBedtime`/`nights` dans
    /// le profil (nil/nil sans estimation). En cas d'erreur de lecture, la valeur précédente est conservée (spec §9).
    /// Ne sauvegarde pas : l'appelant décide.
    private func inferHealthBedtime() async {
        let end = now()
        guard let start = calendar.date(byAdding: .day, value: -BedtimeInference.lookbackDays, to: end) else { return }
        do {
            let sessions = try await health.sleepSessions(from: start, to: end)
            let estimate = BedtimeInference.estimate(sessions: sessions, now: end, calendar: calendar)
            profile.healthBedtime = estimate?.time
            profile.healthBedtimeNights = estimate?.nights
        } catch {
            report("Lecture du sommeil impossible", error)
        }
    }

    // MARK: Notifications (spec §7.6)

    /// Interrupteurs des deux rappels. La demande système part une seule fois, à la première activation, quand
    /// l'état est encore `notDetermined` ; un refus remet les deux drapeaux à faux et retire les rappels en attente
    /// (via `publish()`), sans re-demande automatique (spec §9).
    func setNotifications(sleepReady: Bool, lastIntake: Bool) async {
        lastError = nil
        if (sleepReady || lastIntake) && notificationAuthorization == .notDetermined {
            do {
                notificationAuthorization = try await notifications.requestAuthorization()
            } catch {
                report("Autorisation des notifications impossible", error)
            }
        }
        let denied = notificationAuthorization == .denied
        profile.notifySleepReady = sleepReady && !denied
        profile.notifyLastIntake = lastIntake && !denied
        saveProfile()
        await publish()
    }

    /// Boisson du rappel « dernier » (spec §5.2) : la favorite, sinon l'espresso du catalogue.
    private var referenceDrink: Drink {
        favoriteDrinks.first ?? DrinkCatalog.drink(id: "espresso", custom: []) ?? Self.fallbackReferenceDrink
    }

    /// Source: USDA 212 mg/100 g, 30 ml — même valeur que l'espresso du catalogue, au cas où son identifiant changerait.
    private static let fallbackReferenceDrink = Drink(
        id: "espresso", name: "Espresso", milligrams: 63, volumeML: 30, symbol: "cup.and.saucer.fill")

    // MARK: Privé

    /// Fenêtre des doses conservées dans le snapshot widget.
    // Source: 10 demi-vies → contribution résiduelle < 0,1 % ; plancher 30 h pour couvrir une journée caféine de 25 h
    // (changement d'heure) avec marge.
    static func cacheWindowHours(halfLifeHours: Double) -> Double { max(30, 10 * halfLifeHours) }

    /// Écrit le snapshot (fenêtre `cacheWindowHours`), demande le rechargement des complications, puis remplace les
    /// notifications en attente par le plan courant — même vide, pour retirer celles d'un état précédent.
    private func publish() async {
        let cutoff = now().addingTimeInterval(-Self.cacheWindowHours(halfLifeHours: profile.halfLifeHours) * 3600)
        let snapshot = CacheSnapshot(doses: doses.filter { $0.date >= cutoff }, limits: assessor.limits, updatedAt: now())
        do { try cacheStore.write(snapshot) } catch { report("Écriture du cache impossible", error) }
        widgets.reloadAll()
        await scheduleNotifications()
    }

    private func scheduleNotifications() async {
        let drink = referenceDrink
        let plan = NotificationPlanner.plan(
            doses: doses, limits: assessor.limits, referenceMg: drink.milligrams,
            wantsSleepReady: profile.notifySleepReady, wantsLastIntake: profile.notifyLastIntake,
            now: now(), calendar: calendar)
        plannedNotifications = plan
        let content = NotificationContent(
            referenceDrinkName: drink.name, bedtime: profile.effectiveBedtime, bedtimeLimitMg: profile.bedtimeLimitMg)
        await notifications.replace(plan, content: content)
    }

    private func saveProfile() {
        do { try profileStore.save(profile) } catch { report("Sauvegarde des réglages impossible", error) }
    }

    private func report(_ message: String, _ error: Error) {
        logger.error("\(message, privacy: .public): \(error.localizedDescription)")
        lastError = message
    }
}
