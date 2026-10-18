# US 9 — Saisir un voyage

## 1. Ce que ça fait, en 2 phrases

Un chauffeur publie un trajet : villes et adresses de départ et d'arrivée, date et heure de
départ **et** d'arrivée, prix qu'il fixe lui-même, nombre de places, et le véhicule qu'il
utilise (parmi les siens, ou un nouveau qu'il ajoute juste en dessous).
Avant de publier, on lui annonce clairement que la plateforme prélève **2 crédits par
passager**, et combien il touchera réellement.

---

## 2. Le chemin complet

| Étape | Fichier | Ce qui se passe |
|---|---|---|
| 1. Le formulaire | `frontend/profil.html` | section « Proposer un trajet » |
| 2. Calcul en direct | `frontend/profil.html` | `majGains()` dès que le prix ou les places changent |
| 3. L'envoi | `frontend/profil.html` | `proposerTrajet()` |
| 4. L'URL | — | `POST /api/covoiturages` |
| 5. Le videur | `backend/middleware/auth.middleware.js` | `authMiddleware` |
| 6. La route | `backend/routes/covoiturages.routes.js` | `router.post("/", authMiddleware, creer)` |
| 7. Le traitement | `backend/controllers/covoiturages.controller.js` | `creer()` : 8 étapes de vérification |
| 8. Les tables | Supabase | lecture `users` + `vehicules`, écriture `covoiturages` |

---

## 3. Le code principal, ligne par ligne

### La commission de la plateforme

```js
const CREDITS_PLATEFORME = 2;
```
Écrite une seule fois, en haut du fichier. On la range ensuite **dans le trajet** :

```js
credits_plateforme: CREDITS_PLATEFORME,
```
Pourquoi l'enregistrer plutôt que de la relire dans le code ? Parce que si la plateforme
passe un jour de 2 à 3 crédits, les anciens trajets doivent garder leur commission d'origine.
Sinon les statistiques de l'administrateur (US 13) deviendraient fausses rétroactivement.

```js
res.status(201).json({
  message: "Trajet créé !",
  credits_plateforme: CREDITS_PLATEFORME,
  gain_par_passager: prix - CREDITS_PLATEFORME,
  gain_maximum: (prix - CREDITS_PLATEFORME) * places,
});
```
On renvoie les chiffres **calculés par le serveur**. La page les réaffiche tels quels : ce
n'est pas elle qui refait le calcul, donc il n'y a aucun risque qu'elle annonce autre chose
que ce qui sera vraiment appliqué.

### La vérification la plus importante : le véhicule

```js
const { data: vehicule } = await supabase
  .from("vehicules")
  .select("vehicule_id, energie, nb_places")
  .eq("vehicule_id", vehicule_id)
  .eq("user_id", chauffeur_id)      // ⚠️ cette ligne
  .maybeSingle();

if (!vehicule) {
  return res.status(400).json({
    message: "Ce véhicule n'existe pas ou ne t'appartient pas.",
  });
}
```
**Le second `.eq()` est la correction d'une vraie faille.** Avant, on cherchait le véhicule
par son seul numéro. N'importe quel chauffeur pouvait donc publier un trajet avec la voiture
de quelqu'un d'autre, simplement en envoyant son identifiant. Je l'ai vérifié avant
correction : lisa a créé un trajet avec la Mercedes d'un autre compte, et le serveur a
répondu « Trajet créé ! ».

Le `user_id` vient du **jeton**, jamais du navigateur. Et la réponse est la même que le
véhicule n'existe pas ou qu'il appartienne à quelqu'un d'autre : sinon, en essayant les
numéros, on pourrait deviner quelles voitures existent.

### Les places disponibles

```js
const placesMax = vehicule.nb_places - 1;
if (!Number.isInteger(places) || places < 1 || places > placesMax) {
  return res.status(400).json({
    message: "Avec ce véhicule tu peux proposer entre 1 et " + placesMax + " place(s).",
  });
}
```
`- 1` parce que **le chauffeur occupe une place**. Une Tesla à 4 places permet donc d'en
proposer 3 au maximum. Avant, on pouvait annoncer 999 places dans une voiture de 4.

### Les dates

```js
const depart = new Date(date_depart + "T" + heure_depart);
const arrivee = new Date(date_arrivee + "T" + heure_arrivee);

if (depart < new Date()) {
  return res.status(400).json({ message: "Le départ doit être dans le futur." });
}
if (arrivee <= depart) {
  return res.status(400).json({ message: "L'arrivée doit être après le départ." });
}
```
On colle la date et l'heure pour obtenir un moment précis, puis on compare. Avant, on pouvait
publier un trajet au 1er janvier 2020, ou qui arrivait avant d'être parti.

### La durée, calculée par le serveur

```js
const duree_minutes = Math.round((arrivee - depart) / 60000);
```
Soustraire deux dates JavaScript donne un écart en **millisecondes** ; on divise par 60000
pour obtenir des minutes. Cette seule ligne gère tous les cas : même jour, lendemain, ou plus.

Avant, la durée était saisie à la main dans un champ et envoyée par le navigateur. Elle
pouvait donc ne pas correspondre aux heures affichées, ce qui faussait le filtre « durée
maximum » de l'US 4. Maintenant elle en découle forcément. **J'ai supprimé le champ du
formulaire** : il ne sert plus à rien.

### Le piège du zéro

```js
const vide = (v) => v === undefined || v === null || v === "";
if (... || vide(prix_par_personne) || vide(nb_places_total)) {
```
En JavaScript, `0` est considéré comme « faux ». Écrire `!prix_par_personne` renvoyait donc
« champ non rempli » quand on saisissait 0 — alors que le champ **était** rempli. On teste le
vide explicitement, et la valeur est contrôlée juste après.

### Le badge écologique

```js
const est_ecologique = vehicule.energie === "electrique";
```
C'est le **serveur** qui le décide, à partir de l'énergie du véhicule lue en base. Si on
laissait le navigateur l'envoyer, n'importe qui pourrait afficher un badge écologique sur un
diesel.

---

## 4. Cinq questions du jury, et les réponses

**Q1 — Pourquoi enregistrer la commission sur le trajet plutôt que dans le code ?**
Parce que les anciens trajets doivent garder la commission qui s'appliquait au moment où ils
ont été créés. Si demain la plateforme passe à 3 crédits et que je relis simplement la
constante, les statistiques de l'administrateur recalculeraient tout l'historique avec le
nouveau tarif, et les chiffres du passé deviendraient faux.

**Q2 — Quand les 2 crédits sont-ils réellement prélevés ?**
Pas à la création. À la création, on les **annonce** au chauffeur et on les **enregistre** sur
le trajet. Le prélèvement a lieu à la fin, quand le passager valide que tout s'est bien passé
(US 11) : le chauffeur reçoit alors le prix moins les 2 crédits, pour chaque passager.

**Q3 — Quelle était la faille sur le véhicule ?**
On cherchait le véhicule par son seul identifiant, sans vérifier qu'il appartenait au
chauffeur. N'importe qui pouvait donc publier un trajet avec la voiture d'un autre en
envoyant son numéro. J'ai ajouté `.eq("user_id", chauffeur_id)` dans la requête, avec le
`user_id` qui vient du jeton. Je l'ai testé avant et après : avant c'était accepté, maintenant
c'est refusé.

**Q4 — Pourquoi calculer la durée côté serveur ?**
Parce qu'elle doit toujours correspondre aux heures affichées. Si le navigateur l'envoie, il
peut envoyer n'importe quoi : un trajet affiché de 8h à 12h avec une durée annoncée de 30
minutes passerait le filtre « moins d'une heure » de l'US 4. En la calculant à partir des
deux dates, elle est forcément juste.

**Q5 — Pourquoi retirer une place au nombre de places du véhicule ?**
Parce que le chauffeur conduit : il occupe une place. Une voiture à 4 places permet donc d'en
proposer 3 au maximum. Avant, rien ne l'empêchait d'annoncer 999 places.

---

## 5. Ce que l'audit a trouvé

Les 7 cas ont été **constatés avant correction**, par de vrais appels à l'API :

| Test | Avant | Après |
|---|---|---|
| **Véhicule de quelqu'un d'autre** | `201 Trajet créé !` | `400 … ne t'appartient pas.` |
| **Date dans le passé** (2020) | `201 Trajet créé !` | `400 Le départ doit être dans le futur.` |
| **Arrivée avant le départ** | `201 Trajet créé !` | `400 L'arrivée doit être après le départ.` |
| **999 places dans une 4 places** | `201 Trajet créé !` | `400 … entre 1 et 3 place(s).` |
| Prix à 0 | `500 Erreur serveur` | `400 … au moins 1 crédit.` |
| Ville manquante | `500 Erreur serveur` | `400 … tous les champs obligatoires.` |
| Véhicule inexistant | `500 Erreur serveur` | `400 … n'existe pas` |

---

## 6. Ce qui a été vérifié

### Par de vrais appels HTTP

| Test | Résultat |
|---|---|
| Les 7 cas ci-dessus | ✅ tous en 400 avec un message clair |
| Création valide | ✅ 201 |
| Espaces en trop dans la ville | ✅ retirés (`'  Lyon  '` → `'Lyon'`) |
| Durée calculée (08:00 → 12:45) | ✅ 285 min |
| **Trajet de nuit (22:30 → 01:15 le lendemain)** | ✅ 165 min |
| Badge écologique (Tesla) | ✅ `true` |
| `credits_plateforme` en base | ✅ 2 |
| Places restantes à la création | ✅ égales au total |

### Dans un vrai navigateur

| Test | Résultat |
|---|---|
| Formulaire vide | ✅ « — » partout |
| Prix 20 | ✅ « Tu reçois 18 crédits » |
| Prix 20 + 3 places | ✅ « Soit au maximum 54 crédits » |
| Prix 5 | ✅ recalcul immédiat (3 et 9) |
| Champ « durée » supprimé | ✅ |
| Liste des véhicules | ✅ « Tesla Model 3 (electrique) » |
| **Publication complète** | ✅ « La plateforme prélève 2 crédits… tu recevras 16 crédits… soit 32 » |
| Formulaire vidé après publication | ✅ |
| Trajet en base | ✅ durée 190 min, commission 2, écologique |

*(Tous les trajets de test ont été supprimés : 6 trajets, 7 comptes, 3 véhicules — l'état d'origine.)*
