# Kaff — instructions projet

App Apple Watch standalone (watchOS 26, SwiftUI, Swift 6) qui estime la caféine dans
l'organisme et l'expose en complication. Détails : `docs/superpowers/specs/2026-08-27-kaff-design.md`.

## Où sont les choses

- `docs/ROADMAP.md` — état des jalons (M0→M5) + journal. **Source de vérité du suivi.**
- `docs/superpowers/plans/2026-08-27-kaff-implementation.md` — tâches détaillées avec cases à cocher.
- `Packages/KaffCore` — logique pure (PK, seuils, timeline, catalogue). Testé avec `swift test`.
- `Kaff Watch App/` — SwiftUI, services HealthKit/cache/profil, ViewModels `@Observable`.
- `KaffComplication/` — extension WidgetKit (familles accessory).
- `project.yml` — XcodeGen. Ne jamais éditer le `.xcodeproj` à la main ; `xcodegen generate`.

## Règles de travail

1. **Suivi** : après chaque tâche terminée, cocher la case dans le plan, puis mettre à jour
   la ligne du jalon dans `docs/ROADMAP.md` (statut, date) et ajouter une ligne au journal
   si quelque chose de notable s'est passé (décision, blocage, changement de périmètre).
2. **TDD** : la logique va dans `KaffCore`, test d'abord. Les vues restent fines.
3. **Commits** : conventionnels (`feat:`, `fix:`, `test:`, `docs:`, `chore:`), un commit
   par tâche du plan, message référençant la tâche (ex. `feat(core): M1.3 LevelAssessor`).
4. **HealthKit** : le widget ne touche jamais HealthKit ; il lit le snapshot de l'App Group.
5. **Constantes PK et seuils** : toute valeur numérique porte un commentaire avec sa source.
6. **Immutabilité** : modèles `struct` + fonctions pures ; pas de mutation partagée hors ViewModels.

## Commandes

```bash
make generate   # xcodegen generate
make test-core  # swift test dans Packages/KaffCore
make test       # xcodebuild test sur le simulateur Watch (Series 11 46mm)
make build      # build debug de l'app Watch
make run        # build + install + lancement sur le simulateur
```
(Makefile créé en M0.)

## Simulateurs

- Apple Watch Series 11 (46mm), watchOS 26.5 — cible par défaut.
- Apple Watch Ultra 3 (49mm) — vérification des tailles.
