# Fact-check scientifique — modèle, seuils, métriques (2026-09-04)

Passe de vérification demandée avant la finalisation de v0.1 : l'approche retenue pour estimer la caféine dans
l'organisme à partir des données accessibles à une Apple Watch est-elle conforme à la littérature, et l'app
l'applique-t-elle correctement ? Deux revues indépendantes ont été menées puis réconciliées ici :

- [`fact-check-pk.md`](fact-check-pk.md) — modèle pharmacocinétique (Bateman, ka, t½, biodisponibilité, Vd,
  facteurs de variation, capteurs de la montre). 38 références, extraits cités.
- [`fact-check-seuils.md`](fact-check-seuils.md) — seuils (EFSA/FDA, sommeil), journée caféine, fractions
  d'alerte, catalogue de boissons (USDA/EFSA), types HealthKit. 21 références, extraits cités.

Les deux revues concordent sur tous les chiffres. Ce document est la synthèse et la liste des décisions.

## 1. Réponse à la question de fond

**Aucun capteur de l'Apple Watch ni aucun type HealthKit ne mesure la caféine.** La fréquence cardiaque et la
variabilité cardiaque ne sont pas des biomarqueurs exploitables (preuves contradictoires, effets faibles et
non monotones, confondus par l'activité et le sommeil ; Koenig 2013, Zimmermann-Viehoff 2016, Almeida 2024).
La seule mesure directe portable est un patch de sueur de laboratoire (Tai 2018). La meilleure estimation
possible aujourd'hui est donc **un modèle pharmacocinétique alimenté par le journal des prises**, avec le poids
pour pondérer les seuils — exactement l'architecture de Kaff (`dietaryCaffeine` + `bodyMass` → Bateman).

Ce que la littérature valide dans l'approche :

| Choix de Kaff | Verdict | Source principale |
|---|---|---|
| Modèle à 1 compartiment, absorption et élimination de 1er ordre | Conforme (meilleur ajustement en PK de population) | Seng 2009 ; Kamimori 2002 |
| Dose ingérée = dose absorbée (F ≈ 100 %) | Conforme (F = 108 ± 3,6 %) | Blanchard & Sawers 1983 |
| Superposition linéaire des prises | Conforme jusqu'à ~10 mg/kg ; non-linéaire ≥ 500 mg en une prise ou forte consommation chronique | Bonati 1982 ; Kaplan 1997 ; Denaro 1990 ; EFSA 2015 |
| ka = 5 h⁻¹ → tmax 34–52 min selon t½ | Acceptable : dans la fenêtre EFSA 30–120 min, calé sur le café (≈ 42 min, Liguori 1997) ; côté rapide vs gélules (ka 1,3–2,4 h⁻¹, Kamimori 2002) | EFSA 2015 ; Liguori 1997 ; Kamimori 2002 |
| t½ par défaut 5 h, réglable 2–10 h | Conforme : IOM 2001 (moyenne 5 h, 1,5–9,5 h) ; EFSA 2015 (≈ 4 h, 2–8 h). Bornes couvrent tabac, contraception orale, ciprofloxacine ; pas la grossesse T3 (11,5–18 h) ni la fluvoxamine (31 h) | IOM 2001 ; EFSA 2015 ; Parsons 1978 ; Abernethy 1985 ; Knutti 1981 ; Jeppesen 1996 |
| Affichage en mg dans l'organisme, poids dans les seuils (mg/kg) | Conforme : A(t) ne dépend pas de Vd ; les seuils EFSA sont en mg/kg pc ; Vd ≈ 0,67 L/kg si une concentration est un jour affichée | EFSA 2015 ; Abernethy & Todd 1985 |
| Dose unique 3 mg/kg plafonnée à 200 mg | Conforme (valeur) — voir §2 pour l'objet comparé | EFSA 2015 |
| Cumul journalier 400 mg | Conforme (EFSA « consommés au cours de la journée », FDA 400 mg/j) | EFSA 2015 ; FDA |
| Seuil coucher (charge corporelle projetée) | Approche validée ; valeur 50 mg légèrement laxiste — voir §2 | Gardiner 2023 ; Drake 2013 ; EFSA 2015 |

## 2. Écarts trouvés et décisions

### 2.1 Attributions erronées (commentaires de code, spec) — corrigées
- « tmax 30–60 min (EFSA 2015) » → EFSA dit **30–120 min** ; ≈ 42 min pour le café (Liguori 1997).
- « EFSA 2015 : demi-vie médiane ~5 h (1,5–9,5 h) » → ces chiffres sont ceux de l'**IOM 2001** (moyenne, pas
  médiane) ; EFSA 2015 dit ≈ 4 h (2–8 h). Le défaut 5 h est conservé (moyenne des groupes témoins de plusieurs
  études : Abernethy 5,37 h, Desmond 5,2 h, Healy 5,2 h, Jeppesen 5 h).
- Spec : Vd ≈ 0,6 L/kg → **0,67 L/kg** (EFSA 2015, d'après Abernethy & Todd 1985).
- Catalogue : « Maté, EFSA ~35 mg/100 ml » — cette ligne n'existe pas dans la Table 1 de l'EFSA.
- Fractions d'alerte 60/75/60 % et journée caféine à 04:00 : étiquetées explicitement « choix produit, sans
  base littéraire ».

### 2.2 Limite de pic : charge corporelle vs quantité ingérée — corrigée
La dose unique EFSA (200 mg ≈ 3 mg/kg) est une **quantité ingérée**. Kaff compare la **charge corporelle**
`A_total(now)` à cette valeur. L'EFSA §5.1.3 tranche : les prises répétées « ne doivent pas dépasser la
concentration plasmatique maximale atteinte avec une dose unique de 200 mg ». Comparer la charge corporelle est
donc la bonne opérationnalisation, mais le plafond est la **Cmax d'une dose à la limite**, soit
`singleDoseLimitMg × peakFraction(t½)` (peakFraction = A(tmax)/D : 0,82 à t½ 2 h, 0,90 à 5 h, 0,94 à 10 h).
Avant : une dose de 200 mg culminait à 180 mg = 90 % → jamais « trop haut » ; deux prises rapprochées
totalisant 220 mg passaient sous le radar de ~10 %.

Décision : `UserProfile.peakLimitMg = singleDoseLimitMg × peakFraction`, transporté dans `AssessmentLimits`
(snapshot widget **v3**), utilisé par `LevelAssessor` et par toutes les comparaisons de charge corporelle de
l'UI (anneau, ligne de limite de la courbe, aperçu d'impact, feuille de statut). Les Réglages continuent
d'afficher la limite ingérée (« Dose unique max 200 mg · 3 mg/kg »).

### 2.3 Seuil coucher 50 mg → 35 mg — corrigé
Gardiner 2023 (méta-analyse, 24 études) donne deux cut-offs empiriques pour « pas de réduction significative
du temps de sommeil » : café 107 mg ≥ 8,8 h avant le coucher, pré-workout 217,5 mg ≥ 13,2 h. Projetés avec
le modèle de Kaff (ka 5, t½ 5 h), ces deux scénarios très différents donnent un résidu quasi identique :
**32,5 mg et 35,9 mg**. La méta-régression trace donc une courbe iso-charge ≈ 34 mg, ce qui valide
l'approche « charge corporelle au coucher » et fixe la valeur à **35 mg**. Contrôles : thé noir 47 mg au
coucher (résidu 48 mg) n'a pas de cut-off chez Gardiner ; 100 mg près du coucher perturbe le sommeil (EFSA) ;
400 mg à 6 h du coucher (Drake 2013, résidu 179 mg) réduit le sommeil de plus d'une heure. 50 mg était donc
dans l'enveloppe, à sa borne haute. La constante reste fixe (les cut-offs sont empiriques sur une population,
pas à recalculer par t½). La fraction « élevé » reste 60 % (21 mg).

### 2.4 Catalogue — corrigé
| Boisson | Avant | Après | Source |
|---|---|---|---|
| Chocolat noir | 12 mg / 30 g (valeur du 45–59 % cacao) | **24 mg / 30 g** | USDA FDC 170273, 70–85 % cacao, 80 mg/100 g |
| Maté | 85 mg / 240 ml (« EFSA », inexistant) | **80 mg / 150 ml** | Heck & de Mejia 2007, ≈ 78 mg par tasse de 150 ml |
| Allongé | 80 mg (« estimation ») | inchangé, sourcé | Ludwig 2014 : extraction longue +20–33 % vs espresso court |

Les dix autres entrées sont à ±10 % de l'USDA. L'incertitude réelle par tasse dépasse de loin ces écarts :
espresso 48–322 mg selon le café (Crozier 2012, Ludwig 2014), cappuccino 85–311 mg — voir « Limites ».

## 3. Tests qui encodent la science (KaffCore)
- tmax ∈ [30, 120] min et peakFraction ∈ [0,80, 0,95] pour t½ ∈ {2, 3, 5, 8, 10} h (EFSA 2015).
- Bilan de masse : ∫ ke·A(t) dt = D à 0,5 % près (absorption et élimination complètes, Blanchard & Sawers 1983).
- Coucher : 107 mg à 8,8 h → « élevé » (32,5/35, borne Gardiner) ; 107 mg à 8,0 h → « trop haut » ;
  400 mg à 6 h → « trop haut » (Drake 2013).
- Pic : une dose à 95 % de la limite ingérée n'atteint jamais « trop haut » ; une dose à 105 % l'atteint au pic.
- `AssessmentLimits(profile:).peakLimitMg == singleDoseLimitMg × peakFraction` ; purge des snapshots v1/v2.
- Catalogue : chocolat noir 24 mg, maté 80 mg / 150 ml.

## 4. Limites documentées (hors périmètre v0.1)
1. **Linéarité** : au-delà de ~500 mg en une prise (≈ 7 mg/kg) ou d'une forte consommation chronique, la
   clairance baisse et l'app **sous-estime** le résidu (Kaplan 1997, Denaro 1990). Palliatif : augmenter t½.
2. **ka unique** calé sur les boissons chaudes ; gélules (tmax 1–2 h), soda et chocolat (1,5–2 h, Mumford 1996)
   montent plus lentement. Variabilité interindividuelle du ka ≈ 50 % (Seng 2009).
3. **t½ hors bornes** : grossesse T3 (11,5–18 h), fluvoxamine (31 h), nourrissons. Usage adulte uniquement.
4. **Contenu réel d'une tasse** : facteur 2 à 6 selon l'établissement ; la saisie en mg ou une boisson
   personnalisée reste le seul remède.
5. **Journée caféine 04:00** et **fractions d'alerte** : choix produit.
6. **Profil existant** : le profil vit dans `UserDefaults.standard` ; une installation antérieure garde son
   seuil coucher (50 mg) — les nouveaux défauts ne s'appliquent qu'aux profils neufs (pas de migration en v0.1).

## 5. Backlog issu de la revue (avec sources)
- Heure de coucher réelle depuis `sleepAnalysis` (médiane des 7–14 dernières nuits ; validité 2 états
  suffisante : Miller 2022, Apple 2025) à la place du 23:00 par défaut.
- Fraîcheur de `bodyMass` (avertir si > 6–12 mois, repli manuel).
- Mode grossesse/allaitement (`HKCategoryType.pregnancy/.lactation`, watchOS 7.2+) : limite 200 mg/j et t½
  ×3–4 (EFSA 2015).
- Indices de demi-vie dans Réglages : tabac ↓ (3,5 h vs 6 h, Parsons 1978), contraception œstroprogestative ↑
  (7,9 h vs 5,4 h, Abernethy 1985), inhibiteurs du CYP1A2 ↑ (voir médecin). Pas de type HealthKit « tabac ».
- ka par véhicule (café/thé ≈ 5, gélule ≈ 2, soda/chocolat ≈ 1 h⁻¹).
- Mineurs (`dateOfBirth`) : 3 mg/kg aussi comme limite journalière (EFSA 2015).
- Note UI « ± 50 % selon le café » sur les boissons prédéfinies.

## 6. Réserves de méthode
- La version finale de l'avis EFSA 2015 chez Wiley renvoie 403 aux outils ; le texte a été lu depuis la copie
  PDF déposée par DTU Orbit (revue seuils) et le projet de consultation publique de janvier 2015 (revue PK),
  corroborés par la fiche « EFSA explains » du 27/05/2015 et la reprise du VKM 2015. Les deux copies concordent.
- Clark & Landolt 2017, Nehlig 2018, Koenig 2013 : résumés seulement. Fredholm 1999, Landolt 1995 : non
  consultés en ligne.

## 7. Addendum du 2026-09-08 — concentration plasmatique estimée (v0.3)

Demande utilisateur : afficher « la mesure par litre » en plus des mg, « avec les seuils recommandés pour
cette métrique », et laisser choisir l'unité de la complication.

**Conversion.** Modèle à un compartiment : `C(t) = A(t) / V`, `V = Vd × poids`, **Vd = 0,67 L/kg** (EFSA 2015
§4.2, d'après Abernethy & Todd 1985 ; IOM 2001 donne 0,7 ; plage publiée 0,5–0,75 — voir
[`fact-check-pk.md`](fact-check-pk.md) §6). Le Vd n'est pas modifié par le tabac ni la contraception
orale (Parsons 1978, Abernethy 1985) ; il est plus faible chez la personne âgée (Blanchard & Sawers 1983).
Pour 70 kg, `V ≈ 46,9 L` ; l'app arrondit `V` à 0,5 L près avant de le transmettre à la complication.

**Contrôle de cohérence.** 200 mg ingérés → `Cmax ≈ 180,6 mg / 46,9 L ≈ 3,85 mg/L`, dans la plage des Cmax
mesurées après une dose de cet ordre (≈ 4–5 mg/L dans les études d'interaction où la caféine sert de sonde
CYP1A2). Pour un poids ≤ 66,7 kg, la limite de pic vaut `3 mg/kg × peakFraction / 0,67 ≈ 4,04 mg/L` quel que
soit le poids : la limite EFSA de 3 mg/kg est nativement une concentration. Au-delà du plafond de 200 mg,
elle décroît avec le poids (70 kg : 3,85 mg/L).

**Seuils.** Il n'existe pas de recommandation de sécurité formulée en mg/L pour la population générale :
l'EFSA raisonne en mg/kg et en mg/jour, et c'est précisément ce que l'app applique déjà. La concentration
n'est donc pas une quatrième vérification : `C / C_limite = A / A_limite` (même `V` des deux côtés), le
statut et l'anneau sont identiques dans les deux unités. Seules les vérifications **pic** et **coucher**
ont une lecture en mg/L ; le cumul journalier (400 mg) est une quantité ingérée et n'en a pas.

**Repères de toxicité (informatifs).** Willson C., *The clinical toxicology of caffeine: A review and case
study*, Toxicology Reports 2018 (5:1140-1152, DOI 10.1016/j.toxrep.2018.11.002) et la revue *Toxicology of
caffeine poisoning: molecular mechanisms, toxicokinetic profiles, and clinical implications*, Frontiers in
Toxicology 2026 (DOI 10.3389/ftox.2026.1933375) : toxicité symptomatique à partir de **15 mg/L**
(agitation, vomissements, tachyarythmies), concentrations **> 50 mg/L** toxiques, **> 80 mg/L** associées à
des issues fatales (fibrillation ventriculaire ; séries médico-légales suédoises, Banerjee 2014). Ces valeurs
sont affichées comme repères dans la feuille de statut, pas comme seuils : le statut « trop haut » se
déclenche dès ≈ 4 mg/L, et le modèle est documenté non linéaire au-delà de 500 mg (§4). La dose maximale
saisissable (1 000 mg) donnerait ≈ 19 mg/L à 70 kg, la ligne des 15 mg/L est donc atteignable dans l'app.

**Réserves.** La concentration est doublement estimée quand le poids est celui de repli (70 kg) : le badge
« poids estimé » accompagne toute valeur en mg/L. Concentration plasmatique ≠ concentration salivaire
(rapport ≈ 0,7–0,8) ni cérébrale ; l'app parle de « concentration plasmatique estimée », jamais de dosage.
