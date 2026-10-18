# US 5 — Détail d'un covoiturage

## 1. Ce que ça fait, en 2 phrases

Quand la passagère clique sur « Voir le détail », elle arrive sur une page qui reprend toutes
les informations de la liste et y ajoute le véhicule (marque, modèle, couleur, énergie),
les préférences du conducteur — y compris celles qu'il a écrites lui-même — et tous ses
avis déjà validés par un employé.
C'est la page qui lui permet de décider en confiance avant de réserver.

---

## 2. Le chemin complet

| Étape | Fichier | Ce qui se passe |
|---|---|---|
| 1. Le clic | `frontend/covoiturages.html` | le bouton pointe vers `detail.html?id=12` |
| 2. Lecture du numéro | `frontend/detail.html` | `new URLSearchParams(window.location.search).get("id")` |
| 3. L'appel | `frontend/js/api.js` | `apiPublique("/covoiturages/12")` |
| 4. L'URL | — | `GET /api/covoiturages/12` |
| 5. L'aiguillage | `backend/server.js` | `app.use("/api/covoiturages", covoituragesRoutes)` |
| 6. La route | `backend/routes/covoiturages.routes.js` | `router.get("/:id", getDetail)` — **publique** |
| 7. Le traitement | `backend/controllers/covoiturages.controller.js` | fonction `getDetail()` |
| 8. Les tables | Supabase | `covoiturages`, `users`, `vehicules`, `avis`, `preferences`, `preferences_personnalisees` |
| 9. L'affichage | `frontend/detail.html` | 4 blocs : le trajet, le véhicule, les préférences, les avis |

### ⚠️ L'ordre des routes compte

```js
router.get("/historique", authMiddleware, historique);
router.get("/:id", getDetail);
```
`/:id` veut dire « n'importe quoi ». Si on l'écrivait **avant** `/historique`, Express
prendrait le mot « historique » pour un identifiant et n'atteindrait jamais la bonne route.
Les chemins précis se déclarent donc toujours avant les chemins génériques.

---

## 3. Le code principal, ligne par ligne

### Côté serveur : rassembler les informations

```js
const { id } = req.params;
```
`req.params` contient les morceaux variables de l'adresse. Pour `/api/covoiturages/12`,
`id` vaut `"12"`.

```js
const { data: trajet, error } = await supabase
  .from("covoiturages")
  .select(`
    *,
    chauffeur:users(pseudo, photo),
    vehicule:vehicules(marque, modele, couleur, energie)
  `)
  .eq("covoiturage_id", id)
  .single();
```
Une seule requête ramène le trajet **et** son chauffeur **et** son véhicule.
Je ne demande que les colonnes utiles : la **plaque d'immatriculation est volontairement
exclue**, c'est une donnée personnelle que l'énoncé ne demande pas d'afficher.
`single()` est correct ici : un identifiant correspond à un trajet et un seul.

```js
if (error || !trajet) {
  return res.status(404).json({ message: "Trajet introuvable." });
}
```
Numéro inexistant → erreur **404** (« cette ressource n'existe pas »).

```js
const { data: avis } = await supabase
  .from("avis")
  .select("note, commentaire, created_at, passager:users(pseudo)")
  .eq("chauffeur_id", trajet.chauffeur_id)
  .eq("statut", "valide")
  .order("created_at", { ascending: false });
```
**La ligne la plus importante de l'US 5 est `.eq("statut", "valide")`** : un avis en attente
de modération, ou refusé par un employé, ne doit jamais apparaître publiquement.
`ascending: false` met les plus récents en premier.

```js
const { data: preferences } = await supabase
  .from("preferences")
  .select("*")
  .eq("user_id", trajet.chauffeur_id)
  .maybeSingle();
```
`maybeSingle()` et non `single()` : un chauffeur peut très bien n'avoir rien renseigné.
Avec `single()`, ce cas parfaitement normal déclenchait une erreur.

```js
const { data: preferencesPerso } = await supabase
  .from("preferences_personnalisees")
  .select("libelle")
  .eq("user_id", trajet.chauffeur_id)
  .order("preference_perso_id", { ascending: true });
```
Les préférences libres vivent dans leur **propre table**, parce qu'un chauffeur peut en
avoir autant qu'il veut. On en récupère donc une liste, pas une seule ligne.

### Côté navigateur : remplir sans risque

```js
const params = new URLSearchParams(window.location.search);
const id = params.get("id");
```
`window.location.search` donne `"?id=12"`. `URLSearchParams` sait le découper proprement,
sans avoir à manipuler le texte à la main.

```js
carte.innerHTML = `
  <div class="entete">
    <span class="auteur js-auteur"></span>
    ...`;
```
Le squelette est écrit par moi, il ne contient **aucune donnée de la base** : il est sûr.

```js
carte.querySelector(".js-auteur").textContent = passager.pseudo || "Passager";
carte.querySelector(".js-texte-avis").textContent = a.commentaire || "";
```
Les données arrivent ensuite en `textContent`. Le commentaire d'un avis est du texte écrit
par un utilisateur : c'est exactement le genre de champ où quelqu'un pourrait glisser du code.
Avec `textContent`, il s'affiche comme du texte.

```js
carte.querySelector(".js-note-avis").textContent =
  "⭐".repeat(a.note) + " " + a.note + "/5";
```
`repeat(4)` répète l'étoile 4 fois. La note vient de la base, où une contrainte `CHECK`
garantit qu'elle est comprise entre 1 et 5 : `repeat` ne peut donc pas recevoir un nombre absurde.

```js
if (prefs.accepte_fumeur) ajouterPastille("🚬 Fumeur accepté", false);
else ajouterPastille("🚭 Non-fumeur", true);
```
Le second argument met la pastille en rouge. On affiche l'information **dans les deux sens** :
« non-fumeur » est une information utile, pas une absence d'information.

```js
if (t.nb_places_restantes <= 0) {
  const bouton = document.getElementById("btn-participer");
  bouton.disabled = true;
  bouton.textContent = "Complet";
}
```
Plus de place : le bouton est désactivé. C'est du confort d'affichage — le vrai contrôle
reste côté serveur, dans la fonction `participer()`.

---

## 4. Cinq questions du jury, et les réponses

**Q1 — Pourquoi cette route n'est-elle pas protégée par un middleware ?**
Parce que consulter un trajet doit être possible **sans compte** : c'est ce qui donne envie
de s'inscrire. La protection intervient plus loin, au moment de réserver — `participer()` est
bien derrière `authMiddleware`. Je sépare donc « consulter », qui est public, et « agir »,
qui demande d'être connecté.

**Q2 — Comment garantissez-vous qu'un avis non validé n'apparaît pas ?**
Par le filtre `.eq("statut", "valide")` dans la requête SQL. Le tri se fait **côté serveur** :
les avis en attente ne quittent jamais la base. Si je filtrais côté navigateur, ils seraient
visibles dans l'onglet Réseau, ce qui reviendrait à les publier.

**Q3 — Pourquoi deux tables pour les préférences ?**
`preferences` contient deux informations fixes, toujours les mêmes : fumeur et animaux.
Une ligne par chauffeur suffit, c'est une relation un-à-un. Les préférences personnalisées
sont en nombre libre : un chauffeur peut en écrire une, cinq ou aucune. C'est une relation
un-à-plusieurs, qui demande sa propre table. Tout mettre dans une seule colonne texte aurait
rendu impossible de les afficher proprement ou d'en supprimer une seule.

**Q4 — Pourquoi ne pas afficher la plaque d'immatriculation ?**
Parce que c'est une donnée personnelle qui permet d'identifier le propriétaire d'un véhicule,
et que l'énoncé demande seulement la marque, le modèle, la couleur et l'énergie. Je l'ai même
retirée de la réponse de l'API : ce n'est pas suffisant de ne pas l'afficher, il ne faut pas
l'envoyer du tout, sinon elle reste lisible dans l'onglet Réseau du navigateur.

**Q5 — Que se passe-t-il si le numéro de trajet n'existe pas ?**
Le serveur renvoie un 404 avec un message clair, et la page affiche ce message à la place du
contenu. J'ai aussi prévu le cas où l'adresse n'a pas de `?id=` du tout, et le cas où le
serveur ne répond pas. La page ne reste jamais bloquée sur « Chargement… ».

---

## 5. Ce qui a été vérifié

### Dans un vrai navigateur ✅

| Vérification | Résultat |
|---|---|
| Les 4 blocs s'affichent | ✅ trajet, véhicule, préférences, avis |
| Véhicule complet | ✅ Tesla · Model 3 · Blanc · Électrique ⚡ |
| Heures de départ **et** d'arrivée | ✅ 08:00 → 12:45, durée 4 h 45 |
| Badge écologique | ✅ affiché pour une voiture électrique |
| Préférences fumeur / animaux | ✅ « Non-fumeur » en rouge, « Animaux acceptés » en vert |
| **Préférences personnalisées** (table dédiée) | ✅ les 2 pastilles supplémentaires |
| Avis validés | ✅ 2 avis avec pseudo, note en étoiles, date |
| **XSS : pseudo contenant `<img src=x onerror=...>`** | ✅ affiché en texte, code **non exécuté** |
| **XSS : commentaire contenant `<b>`** | ✅ affiché en texte, pas de gras |
| Trajet complet (0 place) | ✅ bouton désactivé, libellé « Complet » |
| Chauffeur sans avis | ✅ « Nouveau chauffeur » |
| Aucune préférence | ✅ « Ce conducteur n'a pas indiqué de préférences. » |
| Erreur 404 du serveur | ✅ message affiché, contenu masqué |
| Serveur injoignable | ✅ « Le serveur ne répond pas. » |

**Un bug trouvé et corrigé pendant ces tests** : en rechargeant les données, les pastilles de
préférences s'**ajoutaient** aux anciennes au lieu de les remplacer, parce que `appendChild`
n'efface rien. Les trois zones concernées (avatar, préférences, avis) sont maintenant vidées
avant d'être remplies. Revérifié : après rechargement avec un trajet sans préférences,
il reste bien 0 pastille.

### Avec le vrai serveur et la vraie base ✅

Les modifications du serveur ont bien été exercées par de vrais appels HTTP :

| Vérification | Résultat |
|---|---|
| `GET /api/covoiturages/1` | ✅ HTTP 200 |
| **Plaque d'immatriculation dans la réponse** | ✅ **absente** (retirée de la requête) |
| Clé `preferences_perso` présente | ✅ |
| Table `preferences_personnalisees` pas encore créée | ✅ renvoie `[]` **sans planter** |
| Préférences d'un chauffeur qui en a | ✅ lues correctement |
| **Préférences d'un chauffeur qui n'en a PAS** | ✅ HTTP 200 + `null` — c'est le correctif `maybeSingle()` : avec `single()`, ce cas normal déclenchait une erreur |
| `GET /api/covoiturages/99999` | ✅ HTTP 404 « Trajet introuvable. » |
| Page `detail.html?id=6` contre le vrai serveur | ✅ « Ce conducteur n'a pas indiqué de préférences. » |

Et aucune régression sur ce qui existait déjà :

| Vérification | Résultat |
|---|---|
| Recherche US 3 | ✅ 1 trajet, chauffeur, places, prix, heures de départ et d'arrivée |
| Proposition de date US 3 | ✅ renvoie bien le 15 juillet |
| Routes admin sans jeton | ✅ 401 sur les 3 |

> **Note sur l'environnement** : pendant une partie de la session, la synchronisation iCloud
> du dossier `Documents` saturait le disque — `require('express')` mettait **169 secondes**
> au lieu de 72 millisecondes, et le serveur ne démarrait plus. Une fois la synchronisation
> terminée, tout est redevenu normal et ces tests ont pu être faits. C'est la raison pour
> laquelle il vaut mieux sortir le projet d'un dossier synchronisé.

---

## 6. Comment tester

```bash
node backend/server.js
```

```bash
# un trajet qui existe
curl http://localhost:3000/api/covoiturages/1

# un trajet qui n'existe pas → 404
curl http://localhost:3000/api/covoiturages/99999
```

Dans le navigateur : `detail.html?id=1` (puis `?id=99999` pour voir le message d'erreur).
