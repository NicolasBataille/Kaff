# Kaff — Roadmap & suivi

> Source de vérité du suivi : **ce fichier** pour l'état des jalons, et les cases à
> cocher de `docs/superpowers/plans/2026-08-27-kaff-implementation.md` pour les tâches.
> Règle : après chaque tâche terminée, cocher la tâche dans le plan et mettre à jour la
> ligne du jalon ici (statut + date). Ne pas dupliquer la liste des tâches ici.

Légende : ⬜ à faire · 🟨 en cours · ✅ terminé · ⛔ bloqué

| Jalon | Contenu | Critère de sortie | Statut | Mis à jour |
|---|---|---|---|---|
| M0 — Fondations | git, XcodeGen, cibles Watch App + widget, App Group, entitlements HealthKit, package `KaffCore` vide, script `make test` | `xcodegen generate` puis build + lancement de l'app vide et du widget vide sur le simulateur Series 11 ; `swift test` vert sur `KaffCore` | ✅ | 2026-08-27 |
| M1 — KaffCore | Modèles, catalogue, modèle PK (Bateman), `LevelAssessor`, `TimelineBuilder`, conversions | Tests unitaires verts, couverture `KaffCore` ≥ 90 % | ✅ | 2026-08-27 |
| M2 — Services | `HealthStore` (protocole + HealthKit), `CacheStore`, `ProfileStore`, autorisation, lecture `bodyMass` | Round-trip d'une dose écrite/lue dans HealthKit sur simulateur ; tests stores verts | ✅ | 2026-08-28 |
| M3 — App Watch | Home (niveau live, statut, courbe), QuickLog boisson/mg, Historique, Réglages, écran autorisation | Parcours complet sur simulateur : loguer, voir le niveau décroître, supprimer, régler ; captures dans `docs/screenshots/` | ✅ | 2026-08-28 |
| M4 — Complication | Extension WidgetKit 4 familles, timeline précalculée avec croisements de seuils, deep link `kaff://log` | Complication ajoutée à un cadran simulateur, valeur qui décroît sans ouvrir l'app, tap → QuickLog | ⬜ | 2026-08-27 |
| M5 — Finition & appareil | Haptiques, états vides/erreurs, `xcstrings`, test sur montre physique, revue code + sécurité, README | Installée sur la montre de l'utilisateur, une journée d'usage réel sans crash, couverture globale ≥ 80 % | ⬜ | 2026-08-27 |

## Journal

| Date | Note |
|---|---|
| 2026-08-27 | Cadrage validé : watch-only, HealthKit source de vérité, modèle Bateman, WidgetKit précalculé. Spec + plan rédigés. |
| 2026-08-27 | M0 terminé : package `KaffCore` + Makefile, projet XcodeGen (app Watch, extension WidgetKit embarquée, cible de tests), build/run/test verts sur Series 11 (46mm). Notables : `.gitignore` ignorait `Packages/` (ligne retirée) ; deux simulateurs portent le même nom (26.4/26.5) donc le Makefile résout l'UDID (`OS ?= 26.5`) ; `KaffTests` a besoin de `GENERATE_INFOPLIST_FILE: YES` ; vérification visuelle de la complication sur cadran non faite (seul `PlugIns/KaffComplication.appex` vérifié). |
| 2026-08-27 | M1 terminé : KaffCore complet, 38 tests, couverture lignes 99,2 %. |
| 2026-08-27 | Revue M1 : correction DST de `nextBedtime`, limites nulles neutralisées, `LevelReason` isolé, `sleepReadyAt` précalculé dans la timeline. |
| 2026-08-28 | M2 terminé : `HealthStore` (protocole + HealthKit), `WidgetReloader`, `AppModel` @Observable (7 tests verts). Round-trip HealthKit vérifié sur Series 11 (46mm) : autorisation, dose 63 mg écrite/relue après relance, snapshot présent dans le conteneur `group.fr.batum.kaff`. Notable : juste après la feuille d'autorisation, `authorizationStatus` renvoie encore `.sharingDenied` (l'app affiche « denied » jusqu'à la relance) — à traiter dans l'écran d'autorisation M3.1. |
| 2026-08-28 | Revue M2 : état d'erreur, publication robuste, sondage du statut Santé, tests renforcés. |
| 2026-08-28 | M3 terminé : UI redessinée selon `docs/design/ui-direction.md` (décision utilisateur 2026-08-28) — anneau `KaffRingView`, nombre héros animé, pastille glass + feuille statut, courbe 12 h + 6 h avec mode scrub couronne explicite (disposition compacte pendant le scrub), carrousel boissons, cadrans couronne volume/mg avec aperçu d'impact (`AppModel.preview/peak/chartPoints(adding:)`, 5 tests), historique avec carte du jour et glissement, réglages. Sonde API watchOS 26 SDK : `glassEffect`, `GlassEffectContainer`, `glassEffectID`, `.glass/.glassProminent`, `navigationTransition(.zoom)` + `matchedTransitionSource`, `.carousel`, `sensoryFeedback`, `numericText`, `digitalCrownRotation`, `isLuminanceReduced`, Swift Charts : tout compile ; seul `SensoryFeedback.failure` n'existe pas (→ `.error`). Écarts au brief, justifiés : (1) `DatePicker` inline et `Stepper` inline capturent la couronne dès qu'ils défilent au centre (le Form ne défile plus, une valeur a changé à l'insu de l'utilisateur) → remplacés par des cadrans couronne poussés (`ValueDialView`, `BedtimePickerView`) ; (2) pendant le scrub la disposition se compacte (mini-anneau + nombre + pastille sur une ligne, courbe 96 pt) pour que valeur et curseur restent visibles ensemble, y compris sur 42 mm ; (3) sur l'écran Quantité le nom de la boisson devient le titre de navigation (gain de place) ; (4) la couronne est liée à un index de crans (1 unité = 1 cran haptique) plutôt qu'aux minutes/ml/mg, sinon la rotation n'atteint jamais un cran ; (5) sortie du scrub 1,2 s après la dernière rotation, mais 3 s de grâce à l'entrée. Notables : `TimelineView(.periodic(from: .now))` recréait un planning à chaque rendu (boucle à 100 Hz) → `.everyMinute` ; `NavigationLink(value: Drink)` ignoré par une pile typée `[Route]` → `Route.amount(Drink)` ; le focus couronne d'un cadran poussé doit être relâché dans `onDisappear` sinon Home ne défile plus au retour ; `xcrun simctl openurl kaff://log` échoue (LSApplicationWorkspaceErrorDomain 115) sur le simulateur watchOS même après redémarrage — deep link non vérifiable ici, à valider via la complication en M4 ; sur simulateur, « Réessayer » ne re-présente pas la feuille Santé après une annulation (la voie Réglages › Santé reste la consigne). Vérifié : Series 11 46 mm (parcours complet), 42 mm (autorisation, parcours, taille de texte accessibility5 via la variable d'environnement debug `KAFF_DYNAMIC_TYPE` — `simctl ui content_size` n'est pas supporté sur watchOS et le launch arg `-UIPreferredContentSizeCategoryName` s'est avéré aléatoire), Ultra 3 49 mm (disposition, scrub : le focus couronne demandait un court délai après l'entrée en mode scrub). Aux tailles d'accessibilité : boutons Boisson/mg empilés, pastille sous le nombre en mode scrub, carte du jour et lignes d'historique empilées. Non vérifié sur simulateur : Always-On (`isLuminanceReduced`) et Reduce Motion (pas de bascule automatisable) — code en place. |

## Backlog (hors v1, à ne pas commencer sans décision)

- App iPhone compagnon (historique long terme, graphiques).
- Notification « dernière dose avant coucher » / « niveau redescendu ».
- Relevance Smart Stack (`RelevanceKit`) pour remonter la complication après un log.
- `HKObserverQuery` si des doses sont ajoutées depuis l'iPhone régulièrement.
- Localisation EN, préparation App Store (privacy manifest, icônes, disclaimer).
