# Kaff — Design

**Date :** 2026-08-27 · **Statut :** validé (approche) / en revue (détail) · **Plateforme :** watchOS 26 standalone

## 1. Objectif

Kaff est une app Apple Watch autonome qui estime en quasi temps réel la quantité de
caféine présente dans l'organisme, à partir des boissons (ou doses en mg) loguées
sur la montre. Elle indique si le niveau est correct ou trop élevé compte tenu du
poids de la personne et de l'heure de la journée (proximité du coucher), et expose
ce niveau sous forme de complication sur le cadran.

Usage personnel d'abord (sideload Xcode, compte Apple Developer disponible).
Publication App Store non prévue en v1.

**Hors périmètre v1 :** app iPhone, autres métriques vitales (FC, HRV, sommeil),
notifications, synchronisation multi-appareils au-delà de ce que HealthKit offre.

## 2. Décisions validées

| Sujet | Décision | Raison |
|---|---|---|
| Plateforme | watchOS seul, app standalone | Choix utilisateur |
| Stockage | HealthKit `dietaryCaffeine` = source de vérité | Données dans Santé, sauvegardées iCloud, réutilisables par une future app iPhone |
| Poids | Lu depuis HealthKit `bodyMass`, surchargeable | Zéro saisie si l'app Santé a déjà la donnée |
| Modèle PK | Un compartiment, absorption + élimination de 1er ordre (Bateman) | Rend la montée du pic (~45 min) ; ~10 lignes de plus que l'exponentielle simple |
| Complication | WidgetKit, familles `accessory*`, timeline précalculée | ClockKit est déprécié ; la décroissance entre doses est déterministe |
| Génération projet | XcodeGen (`project.yml`) | `.xcodeproj` reproductible, pas de conflits de merge |
| Logique métier | Package Swift pur `KaffCore`, testé sous macOS | TDD et couverture 80 % à bas coût |

## 3. Architecture

```
Kaff/
├── project.yml                  # XcodeGen
├── Packages/KaffCore/           # SwiftPM, sans dépendance UI, testé avec `swift test`
│   ├── Sources/KaffCore/
│   │   ├── Model/               # CaffeineDose, Drink, UserProfile, LevelStatus
│   │   ├── Pharmacokinetics/    # PharmacokineticModel (Bateman), superposition
│   │   ├── Assessment/          # LevelAssessor (seuils poids / journée / coucher)
│   │   ├── Timeline/            # TimelineBuilder (échantillons + croisements de seuils)
│   │   └── Catalog/             # DrinkCatalog (boissons prédéfinies), conversions
│   └── Tests/KaffCoreTests/
├── Kaff Watch App/              # SwiftUI, cible watchOS
│   ├── App/                     # KaffApp, deep links
│   ├── Services/                # HealthStore (protocole + impl HealthKit), CacheStore, ProfileStore
│   ├── Features/Home/           # niveau courant, statut, courbe, accès log
│   ├── Features/QuickLog/       # boisson ⇄ mg
│   ├── Features/History/        # liste du jour, suppression
│   └── Features/Settings/       # poids, demi-vie, coucher, limites, boissons perso
├── KaffComplication/            # extension WidgetKit (accessoryCircular/Rectangular/Corner/Inline)
└── docs/
```

### 3.1 Unités et responsabilités

| Unité | Rôle | Dépend de | Testé par |
|---|---|---|---|
| `KaffCore` | Toute la logique : PK, seuils, timeline, catalogue. Fonctions pures : doses + profil → courbe / statut. | Foundation uniquement | Tests unitaires (cible ≥ 90 %) |
| `HealthStore` (protocole) | Lire/écrire doses `dietaryCaffeine`, lire `bodyMass`, autorisation | HealthKit | Mock dans les tests de ViewModel |
| `CacheStore` | Snapshot JSON (doses 24 h + profil) dans l'App Group, lu par le widget | UserDefaults(suiteName:) | Tests unitaires |
| `ProfileStore` | Réglages utilisateur (demi-vie, coucher, limites, surcharge poids, boissons perso) dans l'App Group | UserDefaults | Tests unitaires |
| ViewModels (`@Observable`) | Orchestration : charge doses, calcule via KaffCore, écrit cache, recharge timelines widget | KaffCore, services | Tests avec mocks |
| Vues SwiftUI | Affichage, fines, sans logique | ViewModels | Vérification manuelle simulateur |
| `KaffComplication` | Lit le cache, génère la timeline via `TimelineBuilder`, rend les jauges | KaffCore, CacheStore | Tests du provider (timeline), rendu manuel |

### 3.2 Flux de données

```
Log (boisson ou mg) ──► HealthStore.save(dose) ──► HealthKit
                                   │
                                   ▼
                     ViewModel recharge les doses (24 h)
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
          KaffCore.levelNow / status      CacheStore.write(snapshot)
                    │                             │
                    ▼                             ▼
             Écran Home (TimelineView)   WidgetCenter.reloadAllTimelines()
                                                  │
                                                  ▼
                              KaffComplication lit le snapshot,
                              TimelineBuilder → entrées 12 h
```

- **Rafraîchissement du cache** : à chaque écriture/suppression par l'app et à
  chaque passage au premier plan. Pas d'`HKObserverQuery` en v1 : l'app est de
  fait le seul rédacteur. Limitation connue : une dose ajoutée depuis l'app Santé
  de l'iPhone apparaît à la prochaine ouverture de Kaff.
- **Home** utilise `TimelineView(.periodic(from:by: 60))` pour que le nombre
  affiché décroisse en direct.
- Le widget ne touche jamais HealthKit ; il lit uniquement le snapshot.

## 4. Modèle pharmacocinétique

Modèle à un compartiment, absorption et élimination de premier ordre. On affiche
la **quantité dans l'organisme en mg** (pas la concentration) ; la corpulence
intervient dans les seuils (mg/kg), pas dans l'affichage.

Pour une dose `D` (mg) prise à `t = 0` :

```
A(t) = D · ka / (ka − ke) · (e^(−ke·t) − e^(−ka·t))      t en heures, t ≥ 0
ke   = ln 2 / t½            (t½ = demi-vie d'élimination, défaut 5 h, réglable 2–10 h)
ka   = 5,0 h⁻¹              (constante d'absorption, fixe en v1)
```

Plusieurs doses se superposent (PK linéaire) : `A_total(t) = Σ A_i(t − t_i)`.

Vérification indépendante des constantes (à reprendre dans les tests) :
- `tmax = ln(ka/ke) / (ka − ke)`. Avec `t½ = 5 h` → `ke = 0,1386` → `tmax ≈ 0,74 h ≈ 44 min`.
- Au pic, `A(tmax) ≈ 0,90 · D`.
- Pour `t ≫ tmax`, la courbe rejoint `D · e^(−ke·t)` à < 1 % près (ex. à 10 h : ≈ 25 % de D).

**Références à confirmer à l'implémentation** (ordres de grandeur issus de la
littérature, à sourcer dans le code) : demi-vie 1,5–9,5 h (médiane ~5 h),
tmax 30–60 min, Vd ≈ 0,6 L/kg (non utilisé en v1 puisqu'on affiche des mg).

## 5. Évaluation du niveau (`LevelAssessor`)

Trois vérifications, chacune produisant `ok / elevated / high` ; le statut global
est le pire des trois, et la raison est affichée.

| Vérification | Valeur comparée | Seuil par défaut | `elevated` | `high` |
|---|---|---|---|---|
| Pic ponctuel | `A_total(now)` | `3 mg/kg × poids`, plafonné à 200 mg (EFSA dose unique) | ≥ 60 % | ≥ 100 % |
| Cumul journalier | Σ doses depuis 04:00 local | 400 mg (EFSA/FDA adulte) | ≥ 75 % | ≥ 100 % |
| Coucher | `A_total(heure de coucher)` projeté | 50 mg | ≥ 60 % | ≥ 100 % |

Tous les seuils sont réglables. Poids : `bodyMass` HealthKit, sinon surcharge
manuelle, sinon 70 kg avec badge « poids estimé » sur Home.

Dérivés affichés :
- **« OK pour dormir à HH:MM »** : premier instant où `A_total(t) < seuil coucher`
  (ou « maintenant »).
- **Équivalences** : `mg ⇄ boisson` via le catalogue (ex. « 150 mg ≈ 2,4 espressos »).

Une ligne dans Réglages et dans le README : *estimation indicative, pas un avis médical.*

## 6. Catalogue de boissons

Prédéfinies (mg pour un volume standard, réglables) : espresso 63 mg/30 ml,
double espresso 125 mg/60 ml, café filtre 95 mg/240 ml, allongé 80 mg/120 ml,
cappuccino/latte 63 mg, décaféiné 3 mg, thé noir 47 mg/240 ml, thé vert 28 mg,
maté 85 mg/240 ml, cola 34 mg/355 ml, boisson énergisante 80 mg/250 ml,
chocolat noir 12 mg/30 g. Valeurs à sourcer (USDA/EFSA) à l'implémentation.

Boissons personnalisées : nom, mg, volume, icône ; stockées dans `ProfileStore`.
Favoris = les 4 plus loguées sur 30 jours, en tête de grille.

Chaque dose enregistrée dans HealthKit porte les métadonnées
`fr.batum.kaff.drinkID`, `fr.batum.kaff.volumeML`, `fr.batum.kaff.source` (`drink` | `manual`).

## 7. Écrans watchOS

1. **Home** — grand nombre `mg` + anneau/jauge coloré par statut, raison du statut,
   « OK pour dormir à HH:MM », total du jour, mini-courbe 12 h passées + 6 h projetées
   (Swift Charts). Deux boutons : *Boisson* / *mg*. Digital Crown défile vers Historique.
2. **QuickLog — Boisson** — grille de boissons (favoris d'abord), tap → étape taille
   (Crown ajuste le volume, mg recalculés en direct) → *Ajouter*. Haptique de succès.
3. **QuickLog — mg** — Crown règle les mg (pas de 5), équivalence affichée
   (« ≈ 1,6 espresso ») → *Ajouter*.
4. **Historique** — doses du jour (heure, boisson, mg), swipe pour supprimer
   (supprime l'échantillon HealthKit), sections par jour sur 7 jours.
5. **Réglages** — poids (valeur HealthKit + surcharge), demi-vie, heure de coucher,
   seuils, boissons personnalisées, mention non médicale.

Deep link `kaff://log` (tap complication) ouvre directement QuickLog — Boisson.

## 8. Complication (`KaffComplication`)

- Familles : `accessoryCircular` (jauge + mg), `accessoryRectangular` (jauge, mg,
  statut, « sommeil OK 22:30 »), `accessoryCorner` (jauge + mg), `accessoryInline`
  (« ☕ 142 mg · OK »).
- Provider : lit le snapshot du cache, appelle `TimelineBuilder`, produit des entrées
  toutes les **15 min sur 12 h** plus une entrée à chaque **croisement de seuil**
  (changement de statut, passage sous le seuil coucher) pour que l'état bascule à
  l'heure exacte. Politique `.atEnd`.
- Rechargement : `WidgetCenter.shared.reloadAllTimelines()` après chaque écriture /
  suppression / changement de réglage.
- Sans données ou sans autorisation : jauge vide, texte « Ouvrir Kaff ».

## 9. Gestion des erreurs

| Situation | Comportement |
|---|---|
| HealthKit non autorisé | Écran bloquant explicatif avec rappel du chemin Réglages → Santé ; pas de mode dégradé en v1 |
| Échec d'écriture HealthKit | Alerte, dose non ajoutée, log détaillé (`os.Logger`, sous-système `fr.batum.kaff`) |
| Poids absent | 70 kg par défaut + badge « poids estimé » + lien Réglages |
| Cache absent côté widget | Vue placeholder « Ouvrir Kaff » |
| Valeurs saisies aberrantes | Validation aux bornes (mg 0–1000, poids 30–250 kg, demi-vie 2–10 h) |

## 10. Tests

- **KaffCore** (Swift Testing, `swift test` sous macOS, couverture ≥ 90 %) :
  courbe d'une dose (tmax ≈ 44 min, pic ≈ 0,90 D, décroissance asymptotique),
  superposition, seuils (chaque cellule du tableau §5), heure « OK pour dormir »,
  croisements de seuils de la timeline, conversions mg ⇄ boisson, favoris.
- **Services** : `CacheStore`/`ProfileStore` round-trip JSON ; `HealthStore` derrière
  un protocole, mock injecté dans les ViewModels.
- **ViewModels** : log → cache écrit → reload widget demandé (spy).
- **UI** : vérification manuelle sur simulateur Apple Watch Series 11 (46 mm) et
  Ultra 3 ; captures dans `docs/screenshots/` à chaque jalon.
- Couverture globale cible ≥ 80 % (les vues SwiftUI sont exclues de la mesure).

## 11. Hypothèses

- Cible de déploiement **watchOS 26.0** (à ajuster si la montre physique est plus ancienne).
- Bundle IDs : `fr.batum.kaff.watchkitapp`, `fr.batum.kaff.watchkitapp.complication` ;
  App Group `group.fr.batum.kaff`. `DEVELOPMENT_TEAM` renseigné dans `project.yml`.
- Langue de l'UI : français uniquement en v1 (chaînes dans `Localizable.xcstrings`
  pour ne pas bloquer une traduction ultérieure).
- Swift 6 avec concurrence stricte activée dès le départ.
