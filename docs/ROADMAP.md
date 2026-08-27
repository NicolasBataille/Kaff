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
| M2 — Services | `HealthStore` (protocole + HealthKit), `CacheStore`, `ProfileStore`, autorisation, lecture `bodyMass` | Round-trip d'une dose écrite/lue dans HealthKit sur simulateur ; tests stores verts | ⬜ | 2026-08-27 |
| M3 — App Watch | Home (niveau live, statut, courbe), QuickLog boisson/mg, Historique, Réglages, écran autorisation | Parcours complet sur simulateur : loguer, voir le niveau décroître, supprimer, régler ; captures dans `docs/screenshots/` | ⬜ | 2026-08-27 |
| M4 — Complication | Extension WidgetKit 4 familles, timeline précalculée avec croisements de seuils, deep link `kaff://log` | Complication ajoutée à un cadran simulateur, valeur qui décroît sans ouvrir l'app, tap → QuickLog | ⬜ | 2026-08-27 |
| M5 — Finition & appareil | Haptiques, états vides/erreurs, `xcstrings`, test sur montre physique, revue code + sécurité, README | Installée sur la montre de l'utilisateur, une journée d'usage réel sans crash, couverture globale ≥ 80 % | ⬜ | 2026-08-27 |

## Journal

| Date | Note |
|---|---|
| 2026-08-27 | Cadrage validé : watch-only, HealthKit source de vérité, modèle Bateman, WidgetKit précalculé. Spec + plan rédigés. |
| 2026-08-27 | M0 terminé : package `KaffCore` + Makefile, projet XcodeGen (app Watch, extension WidgetKit embarquée, cible de tests), build/run/test verts sur Series 11 (46mm). Notables : `.gitignore` ignorait `Packages/` (ligne retirée) ; deux simulateurs portent le même nom (26.4/26.5) donc le Makefile résout l'UDID (`OS ?= 26.5`) ; `KaffTests` a besoin de `GENERATE_INFOPLIST_FILE: YES` ; vérification visuelle de la complication sur cadran non faite (seul `PlugIns/KaffComplication.appex` vérifié). |
| 2026-08-27 | M1 terminé : KaffCore complet, 38 tests, couverture lignes 99,2 %. |
| 2026-08-27 | Revue M1 : correction DST de `nextBedtime`, limites nulles neutralisées, `LevelReason` isolé, `sleepReadyAt` précalculé dans la timeline. |

## Backlog (hors v1, à ne pas commencer sans décision)

- App iPhone compagnon (historique long terme, graphiques).
- Notification « dernière dose avant coucher » / « niveau redescendu ».
- Relevance Smart Stack (`RelevanceKit`) pour remonter la complication après un log.
- `HKObserverQuery` si des doses sont ajoutées depuis l'iPhone régulièrement.
- Localisation EN, préparation App Store (privacy manifest, icônes, disclaimer).
