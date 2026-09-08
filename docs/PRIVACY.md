# Politique de confidentialité de Kaff

Dernière mise à jour : 8 septembre 2026 (v0.3 : concentration estimée, volume de distribution transmis à la complication).

Kaff est une application Apple Watch qui estime la caféine présente dans votre organisme à partir des boissons
que vous enregistrez.

## Données traitées

- **Doses de caféine** : chaque boisson enregistrée est écrite dans l'app Santé (HealthKit, type
  « Caféine alimentaire ») sur votre montre. Kaff relit ces doses pour calculer son estimation.
- **Poids** : Kaff lit votre poids dans Santé pour adapter ses seuils (mg par kg) et, depuis la v0.3, estimer une concentration plasmatique (mg/L). Vous pouvez saisir
  un poids manuel à la place.
- **Sommeil (en option, depuis la v0.2)** : si vous activez « Coucher depuis Santé » dans Réglages, Kaff lit vos
  nuits (type « Analyse du sommeil », lecture seule) des 14 derniers jours pour en déduire votre heure de coucher
  habituelle. Seules cette heure (arrondie à 5 min) et le nombre de nuits sont conservés dans les réglages ;
  aucune nuit n'est stockée ni affichée. Désactivez l'option pour revenir à l'heure saisie manuellement.
- **Réglages** : demi-vie, heure de coucher, limites, boissons personnalisées, choix de notifications. Stockés sur
  la montre.
- **Notifications (en option, depuis la v0.2)** : « OK pour dormir » et « Dernière prise avant le coucher » sont
  des notifications locales calculées sur la montre ; leur texte ne contient qu'une heure, une quantité en mg et
  le nom d'une boisson.

## Ce que Kaff ne fait pas

- Kaff **n'envoie aucune donnée** : pas de serveur, pas de connexion réseau, pas de statistiques d'usage, pas de
  publicité, pas de suivi.
- Kaff ne lit dans Santé que les trois types ci-dessus (le sommeil seulement si vous l'activez), avec votre
  autorisation explicite, que vous pouvez retirer à tout moment dans Réglages › Santé.
- La complication (cadran) n'accède jamais à Santé : elle lit un instantané local (doses récentes et seuils déjà
  calculés — dont l'heure de coucher effective et, depuis la v0.3, le volume de distribution arrondi à 2 L (≈ 3 kg d'ambiguïté sur le poids)
  qui sert à afficher la concentration en mg/L —, jamais le poids exact ni les nuits) partagé entre l'app et
  la complication sur la montre.

## Vos données restent les vôtres

Les doses vivent dans Santé : elles sont sauvegardées et synchronisées selon vos réglages iCloud, et lisibles par
toute autre app que vous autorisez. Supprimer une dose dans Kaff la supprime de Santé. Supprimer Kaff ne supprime
pas les doses de Santé ; vous pouvez les effacer depuis l'app Santé.

## Avertissement

Kaff fournit une estimation indicative issue d'un modèle générique. Ce n'est pas un dispositif médical et cela ne
remplace pas un avis médical.

## Contact

Nicolas Bataille — via les issues du dépôt https://github.com/NicolasBataille/Kaff.
