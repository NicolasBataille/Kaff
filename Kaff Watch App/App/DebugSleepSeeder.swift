#if DEBUG
import Foundation
import HealthKit
import os

/// Debug simulateur uniquement (`SIMCTL_CHILD_KAFF_SEED_SLEEP=1 xcrun simctl launch …`) : écrit sept nuits
/// `sleepAnalysis` dans la base Santé du simulateur, qui n'en contient aucune, pour voir « Coucher depuis Santé »
/// déduire une valeur. Demande l'écriture du sommeil sur son propre `HKHealthStore` : cette autorisation ne fait
/// jamais partie de la demande de production (`HealthKitStore` ne lit le sommeil qu'en lecture).
enum DebugSleepSeeder {
    /// Une nuit : coucher (`inBed`) à `bedtime`, endormissement (`asleepCore`) un quart d'heure après, lever 07:00.
    private struct Night {
        let bedtime: (hour: Int, minute: Int)
        static let inBedEnd = (hour: 7, minute: 0)
        static let asleepEnd = (hour: 6, minute: 50)
        static let asleepDelayMinutes = 15
    }

    /// Sept couchers autour de 23:20 (médiane), du plus ancien (il y a 7 jours) au plus récent (hier soir).
    private static let nights: [Night] = [(23, 10), (23, 25), (23, 20), (23, 40), (23, 15), (23, 30), (23, 20)]
        .map { Night(bedtime: (hour: $0.0, minute: $0.1)) }

    /// Fenêtre de recherche des échantillons déjà écrits par Kaff : les sept nuits, avec une journée de marge.
    private static let lookbackDays = 8

    private static let logger = Logger(subsystem: "fr.nikou.kaff", category: "Debug")
    private static let sleepType = HKCategoryType(.sleepAnalysis)

    static var isRequested: Bool { ProcessInfo.processInfo.environment["KAFF_SEED_SLEEP"] != nil }

    /// Demande l'écriture, puis écrit les nuits manquantes. Relancer l'app ne duplique rien : dès qu'un échantillon
    /// de sommeil écrit par Kaff existe dans la fenêtre, le semis est sauté.
    static func seedIfNeeded(now: Date = .now, calendar: Calendar = .current) async {
        guard HKHealthStore.isHealthDataAvailable() else { logger.error("Santé indisponible, semis ignoré"); return }
        let store = HKHealthStore()
        do {
            try await store.requestAuthorization(toShare: [sleepType], read: [])
        } catch {
            logger.error("Autorisation d'écriture du sommeil refusée : \(error.localizedDescription, privacy: .public)")
            return
        }
        // Juste après la fermeture de la feuille, le statut reste un instant `.sharingDenied` (simulateur, vu en M2.3) :
        // on relit quelques fois, puis on tente l'écriture quoi qu'il en soit (`save` échoue proprement si refusée).
        for _ in 0..<3 where store.authorizationStatus(for: sleepType) != .sharingAuthorized {
            try? await Task.sleep(for: .milliseconds(300))
        }
        if store.authorizationStatus(for: sleepType) != .sharingAuthorized {
            logger.error("Écriture du sommeil non signalée autorisée, tentative quand même")
        }
        do {
            if try await hasSeededSamples(store: store, now: now, calendar: calendar) {
                logger.info("Nuits déjà semées par Kaff, rien à écrire"); return
            }
            let samples = samples(now: now, calendar: calendar)
            try await store.save(samples)
            logger.info("\(samples.count, privacy: .public) échantillons de sommeil écrits (\(nights.count, privacy: .public) nuits)")
        } catch {
            logger.error("Semis du sommeil impossible : \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Une app lit toujours ses propres échantillons : aucune autorisation de lecture nécessaire ici.
    private static func hasSeededSamples(store: HKHealthStore, now: Date, calendar: Calendar) async throws -> Bool {
        guard let start = calendar.date(byAdding: .day, value: -lookbackDays, to: now) else { return false }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: now),
            HKQuery.predicateForObjects(from: HKSource.default()),
        ])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)], sortDescriptors: [], limit: 1)
        return try await !descriptor.result(for: store).isEmpty
    }

    /// Nuit `k` (1 = hier soir … 7 = il y a une semaine) : coucher le jour `now − k`, lever le lendemain.
    private static func samples(now: Date, calendar: Calendar) -> [HKCategorySample] {
        nights.reversed().enumerated().flatMap { offset, night -> [HKCategorySample] in
            let daysAgo = offset + 1
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
                  let inBedStart = calendar.date(bySettingHour: night.bedtime.hour, minute: night.bedtime.minute, second: 0, of: day),
                  let asleepStart = calendar.date(byAdding: .minute, value: Night.asleepDelayMinutes, to: inBedStart),
                  let inBedEnd = calendar.date(bySettingHour: Night.inBedEnd.hour, minute: Night.inBedEnd.minute, second: 0, of: nextDay),
                  let asleepEnd = calendar.date(bySettingHour: Night.asleepEnd.hour, minute: Night.asleepEnd.minute, second: 0, of: nextDay)
            else { return [] }
            return [
                HKCategorySample(type: sleepType, value: HKCategoryValueSleepAnalysis.inBed.rawValue,
                                 start: inBedStart, end: inBedEnd),
                HKCategorySample(type: sleepType, value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                 start: asleepStart, end: asleepEnd),
            ]
        }
    }
}
#endif
