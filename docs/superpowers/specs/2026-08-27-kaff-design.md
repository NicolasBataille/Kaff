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

**v0.2 (M6, 2026-09-06)** : le sommeil Santé (`sleepAnalysis`) sert uniquement à déduire
l'heure de coucher habituelle (§5.1), jamais affiché ni utilisé autrement ; deux notifications
locales opt-in (§7.6). Toujours hors périmètre : app iPhone, FC/VFC, grossesse, mineurs.

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
| Coucher (v0.2) — *décision d'agent du 2026-09-06, à confirmer par l'utilisateur* | Médiane circulaire des 14 dernières nuits Santé, opt-in, repli sur la valeur manuelle. Revient partiellement sur « pas de sommeil » (2026-08-27) : lu uniquement pour le coucher, jamais affiché | Le fact-check commandé par l'utilisateur (`docs/science/2026-09-04-fact-check.md` §5) ne retient que le sommeil comme métrique utile |
| Notifications (v0.2) — *décision d'agent du 2026-09-06, à confirmer par l'utilisateur* | Locales, opt-in, replanifiées à chaque publication du snapshot ; jamais de fond HealthKit | Aucune permission de plus que nécessaire ; contenu calculé par `KaffCore` |

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
| `HealthStore` (protocole) | Lire/écrire doses `dietaryCaffeine`, lire `bodyMass`, lire `sleepAnalysis` (v0.2, autorisation séparée), autorisation | HealthKit | Mock dans les tests de ViewModel |
| `NotificationScheduler` (protocole, v0.2) | Autorisation `UNUserNotificationCenter`, remplacer les notifications planifiées de Kaff par le plan calculé | UserNotifications | Mock dans les tests de ViewModel |
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
- Pour `t ≫ tmax`, la courbe suit l'asymptote `1,0285 · D · e^(−ke·t)` (le préfacteur `ka/(ka−ke)` persiste ; ex. à 10 h : ≈ 25,7 % de D, pas 25 %).

**Références** (fact-check du 2026-09-04, `docs/science/`) : modèle à 1 compartiment
= meilleur ajustement en PK de population (Seng 2009) ; biodisponibilité orale ≈ 100 %
(Blanchard & Sawers 1983) ; demi-vie ≈ 5 h, 1,5–9,5 h (IOM 2001) ou ≈ 4 h, 2–8 h
(EFSA 2015) ; tmax 30–120 min (EFSA 2015), ≈ 42 min pour le café (Liguori 1997) ;
Vd ≈ 0,67 L/kg (EFSA 2015, non utilisé puisqu'on affiche des mg). Limites : cinétique
non linéaire au-delà de ~500 mg en une prise (Kaplan 1997) ; ka unique calé sur les
boissons chaudes ; grossesse et fluvoxamine hors bornes de t½.

`peakFraction = A(tmax)/D` (0,82 à t½ = 2 h, 0,90 à 5 h, 0,94 à 10 h) sert à convertir
une limite ingérée en plafond de charge corporelle (§5).

## 5. Évaluation du niveau (`LevelAssessor`)

Trois vérifications, chacune produisant `ok / elevated / high` ; le statut global
est le pire des trois, et la raison est affichée.

| Vérification | Valeur comparée | Seuil par défaut | `elevated` | `high` |
|---|---|---|---|---|
| Pic ponctuel | `A_total(now)` | `peakLimitMg` = `min(3 mg/kg × poids, 200 mg) × peakFraction(t½)` — Cmax d'une dose unique à la limite EFSA (§5.1.3 : les prises répétées ne doivent pas dépasser la concentration maximale d'une dose de 200 mg) ; ≈ 180 mg pour 200 mg à t½ 5 h | ≥ 60 % | ≥ 100 % |
| Cumul journalier | Σ doses ingérées depuis 04:00 local | 400 mg (EFSA 2015 « au cours de la journée », FDA) | ≥ 75 % | ≥ 100 % |
| Coucher | `A_total(heure de coucher)` projeté | 35 mg — résidu, avec ce modèle à t½ 5 h, des cut-offs de Gardiner 2023 (107 mg à 8,8 h → 32,5 mg ; 217,5 mg à 13,2 h → 35,9 mg) ; borne absolue : 100 mg près du coucher perturbe le sommeil (EFSA 2015) | ≥ 60 % | ≥ 100 % |

Tous les seuils sont réglables ; la limite ingérée (« dose unique max ») reste celle
affichée dans Réglages, la conversion en charge corporelle est interne. Les fractions
« élevé » et la borne 04:00 sont des choix produit sans base littéraire. Poids : `bodyMass` HealthKit, sinon surcharge
manuelle, sinon 70 kg avec badge « poids estimé » sur Home.

Dérivés affichés :
- **« OK pour dormir à HH:MM »** : premier instant où `A_total(t) < seuil coucher`
  (ou « maintenant »).
- **Équivalences** : `mg ⇄ boisson` via le catalogue (ex. « 150 mg ≈ 2,4 espressos »).

Une ligne dans Réglages et dans le README : *estimation indicative, pas un avis médical.*

### 5.1 Heure de coucher effective (v0.2)

`UserProfile.effectiveBedtime` alimente `AssessmentLimits.bedtime` (donc le widget via le
snapshot, sans changement de schéma) : c'est `healthBedtime` quand `usesHealthBedtime` est
vrai et qu'une valeur a pu être déduite, sinon `bedtime` (saisie manuelle, inchangée).

`BedtimeInference` (KaffCore, pure) déduit `healthBedtime` des sessions `sleepAnalysis` :

| Règle | Valeur | Raison |
|---|---|---|
| Fenêtre | nuits des 14 derniers jours | Fact-check §5 : « médiane des 7–14 dernières nuits » ; assez court pour suivre un changement d'habitude |
| Fusion | fragments (phases, réveils) qui se chevauchent ou se suivent à ≤ 2 h fusionnés en une session (début du premier, fin la plus tardive) | HealthKit écrit une nuit en plusieurs échantillons ; sans fusion, un fragment commençant après 04:00 basculerait dans la journée caféine suivante (revue M6.7) |
| Nuit | sessions fusionnées `inBed` ou `asleep*` groupées par journée caféine (04:00 → 04:00) de leur début ; le coucher de la nuit = début le plus tôt du groupe | Une nuit qui commence à 23:30 et une à 00:30 tombent dans la même journée caféine ; `inBed` précède `asleep` de quelques minutes, écart négligeable |
| Sieste exclue | session ignorée si elle commence entre 05:00 et 18:59 **et** dure ≤ 3 h | Choix produit, sans base littéraire |
| Minimum | 3 nuits, sinon `nil` (repli manuel) | Une médiane sur 1–2 nuits n'est pas une habitude |
| Médiane circulaire | minutes depuis 12:00 (23:30 → 690, 00:30 → 750), médiane, retour en heure ; arrondi aux 5 min | 23:30 et 00:30 doivent donner 00:00, pas 12:00 |
| Rejet | résultat entre 04:00 et 18:59 → `nil` | Un coucher après 04:00 tombe dans la journée caféine suivante (`CaffeineDay.startHour`) |

Le résultat est mémorisé dans le profil (`healthBedtime`, `healthBedtimeNights`) et recalculé
à chaque `refresh()` quand l'option est active. Limitation : la base Santé de la montre ne
contient que le sommeil suivi par la montre elle-même ou synchronisé récemment ; un sommeil
saisi seulement sur l'iPhone ou par une app tierce peut manquer → « aucune nuit trouvée »,
jamais un diagnostic de refus (HealthKit masque le statut de lecture).

### 5.2 Dernière prise avant le coucher (v0.2)

`LevelAssessor.latestIntakeDate(milligrams:doses:from:)` : dernier instant `t ≥ now` où une
dose de `D` mg garde `A_total(coucher) < seuil coucher`. Contrainte réelle : le maximum de la
courbe **après** le coucher doit rester sous le seuil ; pour `t ≤ coucher − tmax` ce maximum est
`A_total(coucher)`, croissant en `t` → dichotomie à la minute près sur `[now, coucher − tmax]`.
Résultats : `nil` si le coucher est passé dans la journée caféine, si `now > coucher − tmax`
(intervalle vide) ou si même `now` dépasse le seuil (« plus de caféine aujourd'hui ») ;
`coucher − tmax` si la dose passe partout (petite dose). Ordre de grandeur : 63 mg seuls,
seuil 35 mg, t½ 5 h → `ln(1,0285 × 63/35)/ke ≈ 4,44 h` avant le coucher (18:34 pour 23:00). Une prise plus tardive que `coucher − tmax` culmine pendant le sommeil : jamais proposée.

Dose de référence de la notification : la boisson favorite de l'utilisateur (première de
`favoriteDrinks`), sinon l'espresso du catalogue (63 mg).

## 6. Catalogue de boissons

Prédéfinies (mg pour un volume standard, réglables) : espresso 63 mg/30 ml,
double espresso 125 mg/60 ml, café filtre 95 mg/240 ml, allongé 80 mg/120 ml,
cappuccino/latte 63 mg, décaféiné 3 mg, thé noir 47 mg/240 ml, thé vert 28 mg,
maté 80 mg/150 ml (Heck & de Mejia 2007), cola 32 mg/330 ml, boisson énergisante
80 mg/250 ml, chocolat noir 70–85 % 24 mg/30 g (USDA FDC 170273). Sources USDA
FoodData Central / EFSA 2015 dans `DrinkCatalog.swift` ; vérification du 2026-09-04
dans `docs/science/fact-check-seuils.md`. Une tasse réelle varie du simple au
sextuple (espresso 48–322 mg, Crozier 2012 et Ludwig 2014).

Boissons personnalisées : nom, mg, volume, icône ; stockées dans `ProfileStore`.
Favoris = les 4 plus loguées sur 30 jours, en tête de grille.

Chaque dose enregistrée dans HealthKit porte les métadonnées
`fr.nikou.kaff.drinkID`, `fr.nikou.kaff.volumeML`, `fr.nikou.kaff.source` (`drink` | `manual`).

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
5. **Réglages** — poids (valeur HealthKit + surcharge), demi-vie (v0.2 : indices sourcés —
   tabac ≈ 3,5 h, contraception œstroprogestative ≈ 8 h, grossesse hors modèle), heure de
   coucher (v0.2 : interrupteur « Coucher depuis Santé », valeur déduite + nombre de nuits,
   repli manuel visible), seuils, boissons personnalisées, mention non médicale.
6. **Notifications (v0.2, Réglages)** — deux interrupteurs indépendants, chacun déclenche la
   demande d'autorisation `UNUserNotificationCenter` la première fois :
   - « OK pour dormir » : une notification à `sleepReadyAt` quand le niveau est encore au-dessus
     du seuil coucher (« Niveau redescendu sous 35 mg : OK pour dormir ») ; jamais si
     `sleepReadyAt` tombe après le prochain 04:00 (pas de vibration en pleine nuit).
   - « Dernière prise avant le coucher » : une notification à `latestIntakeDate` pour la dose de
     référence (§5.2), texte « Dernier espresso (63 mg) pour dormir à 23:00 ».
     Omise quand `latestIntakeDate` vaut la borne `coucher − tmax` : la dose de référence passe de toute façon
     (décaféiné, petite dose), il n'y a rien à annoncer.
   Planification : à chaque publication du snapshot (log, suppression, réglage, premier plan),
   Kaff remplace ses notifications en attente par le plan de `NotificationPlanner` (KaffCore,
   pure) ; rien n'est planifié dans le passé ni à moins d'une minute ; désactiver un
   interrupteur retire ses notifications. Limitation connue : sans ouverture de l'app, le plan
   du jour n'est pas recalculé pour le lendemain (pas de tâche de fond en v0.2).

Deep link `kaff://home` (tap complication) ouvre l'écran principal (Home), pile de navigation vidée — décision
utilisateur du 2026-09-07 ; jusqu'à v0.1 le tap ouvrait directement QuickLog — Boisson via `kaff://log`, qui
reste géré.

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
- **Obsolescence (v0.2)** : `WidgetEntryData.isStale` vrai quand `now − snapshot.updatedAt`
  dépasse la fenêtre des doses du snapshot (`CacheSnapshot.windowHours`, écrite par l'app :
  `max(30, 10 × t½)`) — le widget ne peut alors plus connaître de dose non transmise. Rendu
  discret : rectangulaire et inline remplacent la ligne secondaire par « Ouvrir Kaff », le
  circulaire et le coin gardent la valeur (elle reste juste : la caféine connue a décru).

## 9. Gestion des erreurs

| Situation | Comportement |
|---|---|
| HealthKit non autorisé | Écran bloquant explicatif avec rappel du chemin Réglages → Santé ; pas de mode dégradé en v1 |
| Échec d'écriture HealthKit | Alerte, dose non ajoutée, log détaillé (`os.Logger`, sous-système `fr.nikou.kaff`) |
| Poids absent | 70 kg par défaut + badge « poids estimé » + lien Réglages |
| Cache absent côté widget | Vue placeholder « Ouvrir Kaff » |
| Valeurs saisies aberrantes | Validation aux bornes (mg 0–1000, poids 30–250 kg, demi-vie 2–10 h) |
| Sommeil absent ou < 3 nuits (v0.2) | Interrupteur reste actif, note « Aucune nuit trouvée dans Santé sur la montre », coucher manuel utilisé et affiché comme tel |
| Notifications refusées (v0.2) | Interrupteurs désactivés, note avec le chemin Réglages › Notifications ; aucune re-demande automatique |
| Lecture du sommeil en erreur (v0.2) | `lastError` « Lecture du sommeil impossible », dernière valeur déduite conservée |

## 10. Tests

- **KaffCore** (Swift Testing, `swift test` sous macOS, couverture ≥ 90 %) :
  courbe d'une dose (tmax ≈ 44 min, pic ≈ 0,90 D, décroissance asymptotique),
  superposition, seuils (chaque cellule du tableau §5), heure « OK pour dormir »,
  croisements de seuils de la timeline, conversions mg ⇄ boisson, favoris.
- **Services** : `CacheStore`/`ProfileStore` round-trip JSON ; `HealthStore` derrière
  un protocole, mock injecté dans les ViewModels.
- **ViewModels** : log → cache écrit → reload widget demandé (spy).
- **v0.2** : `BedtimeInference` (chaque règle du tableau §5.1, dont 23:30/00:30 → 00:00),
  `latestIntakeDate` (monotonie, `nil` trop tard, `nil` coucher passé, petite dose → coucher − tmax),
  `NotificationPlanner`, décodage d'un profil v0.1 sans les nouveaux champs, `AppModel`
  (autorisation sommeil demandée une seule fois sur action, déduction stockée, plan de
  notifications remplacé à chaque publication, retrait à la désactivation), `isStale`.
- **UI** : vérification manuelle sur simulateur Apple Watch Series 11 (46 mm) et
  Ultra 3 ; captures dans `docs/screenshots/` à chaque jalon.
- Couverture globale cible ≥ 80 % (les vues SwiftUI sont exclues de la mesure).

## 11. Hypothèses

- Cible de déploiement **watchOS 26.0** (à ajuster si la montre physique est plus ancienne).
- Bundle IDs : `fr.nikou.kaff` (conteneur iOS sans code, cible `Kaff`, c'est lui que voit App Store
  Connect), `fr.nikou.kaff.watchkitapp` (app Watch), `fr.nikou.kaff.watchkitapp.widget` (complication) ;
  App Group `group.fr.nikou.kaff` (préfixe `fr.nikou` depuis le 2026-09-04, à la demande de l'utilisateur). Le conteneur a été ajouté le 2026-09-04 : Xcode n'a pas de méthode de
  distribution App Store pour watchOS (forums Apple 817223, 738218), une app watch-only doit être embarquée
  dans une app iOS `watchapp2-container`. `DEVELOPMENT_TEAM` dans `Config/Local.xcconfig` (ignoré par git).
- Langue de l'UI : français uniquement en v1 (chaînes dans `Localizable.xcstrings`
  pour ne pas bloquer une traduction ultérieure).
- Swift 6 avec concurrence stricte activée dès le départ.
