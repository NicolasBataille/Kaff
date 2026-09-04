# Kaff — Direction UI/UX (watchOS 26)

**Statut :** référence pour M3 (app) et M4 (complication). Remplace le code SwiftUI « baseline » des tâches M3.x du plan, qui reste valable pour la structure des fichiers et le câblage `AppModel`. Décision utilisateur du 2026-08-28 : le design est réalisé par Fable, avec une exigence élevée (animations, couronne, haptiques).

## 1. Principe

**Le niveau est le héros.** Tout l'écran d'accueil sert un seul nombre — les mg dans l'organisme — et son évolution dans le temps. Le reste (statut, sommeil, cumul) l'accompagne sans le concurrencer. Chaque interaction doit répondre en < 100 ms par un mouvement et une haptique cohérents.

Trois règles :
1. **Une info dominante par écran**, typographie `.rounded` + `monospacedDigit()` pour tous les chiffres.
2. **La couronne fait quelque chose d'utile partout** : scrubber temporel sur Home, défilement carrousel dans le sélecteur, réglage de quantité avec crans haptiques.
3. **Les transitions racontent la donnée** : un nombre ne saute jamais, il compte (`contentTransition(.numericText())`) ; une couleur ne bascule jamais, elle glisse (`animation(.smooth)`).

## 2. Système visuel

| Jeton | Valeur | Usage |
|---|---|---|
| `accent` | `#C8792B` (AccentColor) | café, boutons principaux, courbe passée |
| `status.ok` | `.mint` | anneau, pastille, texte statut |
| `status.elevated` | `.orange` | idem |
| `status.high` | `.red` (coral) | idem |
| `sleep` | `.indigo` | tout ce qui parle de coucher/sommeil |
| Fond | noir système | Liquid Glass ne fonctionne bien que sur fond sombre riche → glow radial discret de la couleur de statut derrière l'anneau (opacité 0,18) |
| Typo nombre héros | `.system(size: 44, weight: .bold, design: .rounded)` | mg sur Home |
| Typo secondaire | `.caption2` / `.footnote` | tout le reste |

Liquid Glass (`.glassEffect()`, `GlassEffectContainer`, `.buttonStyle(.glass/.glassProminent)`) réservé aux **éléments interactifs** : boutons Boisson / mg, pastille de statut (tappable → explication), cartes du carrousel. Jamais sur du texte statique.

Fichier de tokens : `Kaff Watch App/Shared/Theme.swift` (couleurs de statut, tailles, durées d'animation `Motion.quick = 0.18 s`, `Motion.snap = .spring(duration: 0.45, bounce: 0.25)`).

## 3. Écrans

### 3.1 Home — « Maintenant »
- **Anneau** (`KaffRingView`) : arc 300° style anneaux Activité, épaisseur 9 pt, dégradé angulaire de la couleur de statut (clair → saturé), extrémité arrondie avec un léger glow. Valeur = `currentMg / peakLimitMg` — depuis M5.6 la charge corporelle se rapporte à la Cmax d'une dose unique à la limite (≈ 180 mg pour 200 mg), pas à la dose ingérée ; seul l'anneau du cadran mg (§Quantité) garde `singleDoseLimitMg` puisqu'il note une quantité ingérée (plafonné à 1 ; au-delà, une seconde couche plus fine se superpose en rouge pour montrer le dépassement). Animation de remplissage `.spring` à l'apparition et à chaque changement.
- **Nombre héros** au centre : mg, `contentTransition(.numericText())`, en dessous « mg » en `.caption2`. À gauche/droite de l'anneau : rien (respirer).
- **Pastille statut** sous l'anneau : glass capsule, icône + libellé (« OK », « Élevé », « Trop haut ») tinté ; tap → `sheet` courte expliquant la raison (« Cumul du jour : 420 / 400 mg ») avec les trois vérifications en liste (pic, jour, coucher) et leurs jauges linéaires.
- **Ligne sommeil** : `moon.zzz.fill` indigo + « OK pour dormir à 05:12 » / « OK pour dormir maintenant ».
- **Courbe** (`CaffeineChartView`) : 12 h passées + 6 h projetées, aire dégradée accent, projection en pointillés, ligne « maintenant », ligne limite. Hauteur 64 pt au repos.
- **Scrubber couronne** (le geste signature) — **mode explicite**, parce que sur Home la couronne appartient déjà au défilement et à la navigation `TabView(.verticalPage)` (un seul consommateur focalisé reçoit la rotation). Entrée : tap sur la courbe (ou sur l'anneau) → la courbe passe à 96 pt avec un spring, un curseur vertical apparaît, haptique `.selection`, et la vue de courbe prend le focus (`.focusable(isScrubbing)` + `.digitalCrownRotation` sur un offset temporel `−12 h … +6 h`, pas 15 min, `isHapticFeedbackEnabled`, `sensitivity: .low`). Pendant la rotation : le nombre héros affiche la valeur à cet instant, l'heure s'affiche en surtitre (« à 23:00 » / « il y a 3 h »), la pastille reflète le statut projeté. Sortie : nouveau tap, ou 1,2 s sans rotation → retour spring à « maintenant », focus rendu, la couronne redevient défilement/pages. Hors mode scrub, aucune vue de Home ne capture la couronne. Implémentation : `@State isScrubbing`, `@State scrubOffsetMinutes: Double`, `TimelineView(.periodic(by: 60))` continue de faire vivre le niveau réel ; un `Task` annulable gère la sortie par inactivité.
- **Actions** : `GlassEffectContainer` avec deux boutons capsule « ☕ Boisson » (`.glassProminent`, accent) et « # mg » (`.glass`). `glassEffectID` + `@Namespace` pour morphing vers l'écran suivant (`navigationTransition(.zoom(sourceID:in:))` sur le `NavigationLink`).
- **Badge poids estimé** : petit `Label` orange sous la courbe, tap → Réglages.
- **Empty state** (aucune dose 24 h) : anneau vide en gris, nombre « 0 », texte « Aucune caféine dans le sang. » + les deux boutons — pas d'illustration.
- **Toolbar** : `gearshape` en `.topBarTrailing`. Titre « Kaff ».
- **Always-On** (`@Environment(\.isLuminanceReduced)`) : on garde anneau + nombre, on masque courbe et boutons, pas d'animation.

### 3.2 Sélecteur de boisson
- `List` en style `.carousel`, une carte par boisson : symbole SF grand (28 pt) à gauche dans un disque teinté accent 0,2, nom `.headline`, sous-titre « 63 mg · 30 ml ». Favoris en tête avec un `star.fill` discret. Boisson personnalisée : icône `mug.fill`.
- Couronne = défilement natif du carrousel (cartes qui s'agrandissent au centre, gratuit avec `.carousel`).
- Tap → `DrinkAmountView` avec `navigationTransition(.zoom)`.

### 3.3 Quantité (boisson)
- En haut : symbole + nom. Au centre : **volume** héros (`240 ml`) contrôlé par la couronne (pas 10 ml, `from: 10, through: 1000`, haptique cran). Sous le volume : « ≈ 95 mg », `numericText`.
- **Aperçu d'impact** (différenciateur) : mini-courbe 6 h « avant / après » : courbe actuelle en gris, courbe avec la dose ajoutée en accent ; sous-titre « Pic 148 mg à 14:35 · coucher 61 mg ». Calcul pur via `TimelineBuilder`/`LevelAssessor` sur `doses + [dose hypothétique à now]`. Si le résultat passe `high`, la ligne devient rouge (« Trop pour dormir »).
- Bouton « Ajouter » `.glassProminent` pleine largeur. Au tap : le bouton se transforme en coche (`contentTransition(.symbolEffect(.replace))`), haptique `.success`, puis `model.path = []` après 350 ms → Home apparaît avec le nombre qui compte et l'anneau qui se remplit.
- Échec HealthKit : haptique `.failure`, bouton redevient actif, alerte gérée par `RootView`.

### 3.4 Dose manuelle (mg)
- Grand cadran : nombre héros mg, couronne pas 5 mg (`from: 5, through: 1000`), `sensitivity: .medium`. Autour du nombre, le **même anneau** que Home qui se remplit en fonction de `mg / singleDoseLimitMg` (tout de suite lisible : « c'est beaucoup ? »).
- Sous le nombre : équivalence « ≈ 2,4 espressos » et une rangée de `cup.and.saucer.fill` (arrondie à l'unité, max 5, puis « +2 »).
- Même aperçu d'impact et même bouton Ajouter que 3.3.

### 3.5 Historique (page verticale sous Home)
- En tête : carte « Aujourd'hui 320 / 400 mg » avec jauge linéaire tintée `dailyStatus`.
- Liste 7 jours par sections (« Jeu 28 »), ligne : heure `monospacedDigit`, symbole boisson dans un petit disque, nom, mg à droite. `.swipeActions` supprimer (rouge, `trash.fill`) → `.sensoryFeedback(.impact(weight: .light))`.
- Vide : « Aucune dose sur 7 jours. »

### 3.6 Réglages
- `Form` standard mais soigné : sections Poids (valeur Santé, toggle manuel + `Stepper`), Modèle (demi-vie, `Stepper` 0,5 h, ligne explicative « ≈ 44 min jusqu'au pic »), Sommeil (`DatePicker` heure + limite), Limites (jour, dose unique calculée), Boissons personnalisées, mention non médicale.
- Toute modification met à jour Home immédiatement (déjà câblé via `AppModel.update`).

### 3.7 Autorisation
- Icône `heart.text.square.fill` rouge grande, titre, deux lignes d'explication, bouton « Réessayer » `.glassProminent`. **Correctif M2** : `AppModel.start()` doit re-vérifier `isWriteAuthorized` jusqu'à 3 fois à 300 ms d'intervalle après `requestAuthorization()` (statut en retard sur le simulateur), et `RootView` relance `start()` quand `scenePhase == .active` si l'état est `.denied`.

## 4. Complication (M4, à venir)
- `accessoryCircular` : anneau identique à Home (mêmes proportions), nombre au centre, `widgetAccentable`.
- `accessoryRectangular` : anneau miniature + « 142 mg · OK » + sparkline 6 h (Swift Charts, `LineMark` seul) + « Sommeil 05:12 ».
- `accessoryCorner` : nombre + jauge linéaire en `widgetLabel`.
- `accessoryInline` : « ☕ 142 mg · OK ».
- Mode `.accented` géré (`widgetRenderingMode`).

## 5. Mouvement & haptiques

| Événement | Animation | Haptique |
|---|---|---|
| Apparition Home | anneau se remplit `Motion.snap`, nombre compte de 0 | — |
| Changement de valeur (minute) | `numericText` | — |
| Rotation couronne (scrub, volume, mg) | immédiat, `.smooth(duration: 0.18)` | crans natifs (`isHapticFeedbackEnabled`) |
| Fin de scrub | retour spring | `.sensoryFeedback(.selection)` |
| Ajouter | bouton → coche, pop vers Home | `.success` / `.failure` |
| Supprimer | ligne glisse | `.impact(weight: .light)` |
| Changement de statut | couleur glisse `.smooth(duration: 0.4)` | `.sensoryFeedback(.warning)` uniquement si passage à `.high` |

`.sensoryFeedback` (SwiftUI) plutôt que `WKInterfaceDevice.play` partout où possible.

## 6. Accessibilité & tailles
- Toutes les vues testées en taille de texte max et sur Ultra 3 (49 mm) + Series 11 42 mm (plus petit) : aucun texte tronqué, `minimumScaleFactor(0.8)` sur les nombres héros. Home reste un `ScrollView` (anneau + pastille + sommeil visibles sans défiler sur 42 mm ; courbe et boutons accessibles en défilant).
- VoiceOver : anneau = un seul élément « 142 milligrammes, niveau OK » ; boutons libellés ; scrubber annonce l'heure visée.
- `Reduce Motion` : pas de spring, `.easeInOut` courts ; pas de glow animé.

## 7. Architecture (inchangée)
- Vues fines ; tout calcul via `AppModel` + `KaffCore`. L'aperçu d'impact et le scrubber n'ajoutent que des fonctions **pures** (ex. `AppModel.preview(adding mg: Double) -> LevelAssessment` et `assessment(at:)` déjà existante).
- Nouveaux fichiers : `Shared/Theme.swift`, `Shared/KaffRingView.swift`, `Features/Home/StatusPillView.swift`, `Features/Home/StatusDetailSheet.swift`, `Features/QuickLog/ImpactPreviewView.swift`. Le reste suit la structure du plan.
- Tests : `AppModel.preview(adding:)` testé dans `KaffTests` ; le reste vérifié visuellement (captures dans `docs/screenshots/`).
