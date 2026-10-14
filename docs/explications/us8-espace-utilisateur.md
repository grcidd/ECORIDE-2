# US 8 — Espace utilisateur

## 1. Ce que ça fait, en 2 phrases

Dans son espace, la personne choisit si elle est chauffeur, passager ou les deux, et si elle
est chauffeur, elle enregistre ses véhicules (plaque, date de première immatriculation,
marque, modèle, couleur, énergie, nombre de places).
Elle indique aussi ses préférences : fumeur ou non, animaux ou non, plus autant de
préférences libres qu'elle veut — chacune étant une ligne dans sa propre table.

---

## 2. Le chemin complet

| Étape | Fichier | Ce qui se passe |
|---|---|---|
| 1. La page | `frontend/profil.html` | section « Mon profil » |
| 2. Au chargement | `frontend/profil.html` | `chargerPreferences()` et `chargerVehicules()` |
| 3. L'appel | `frontend/js/api.js` | `apiProtegee()` ajoute le jeton JWT |
| 4. Les routes | `backend/routes/utilisateurs.routes.js` | 7 routes, **toutes derrière `authMiddleware`** |
| 5. Le traitement | `backend/controllers/utilisateurs.controller.js` | — |
| 6. Les tables | Supabase | `users`, `vehicules`, `preferences`, `preferences_personnalisees` |

### Les routes de l'US 8

| Route | Rôle |
|---|---|
| `PATCH /api/utilisateurs/role` | chauffeur / passager / les deux |
| `GET /api/utilisateurs/vehicules` | la liste de ses véhicules |
| `POST /api/utilisateurs/vehicules` | en ajouter un |
| `GET /api/utilisateurs/preferences` | **relire** ses préférences |
| `POST /api/utilisateurs/preferences` | enregistrer fumeur / animaux |
| `POST /api/utilisateurs/preferences-perso` | ajouter une préférence libre |
| `DELETE /api/utilisateurs/preferences-perso/:id` | en supprimer une |

---

## 3. Le code principal, ligne par ligne

### Pourquoi une table séparée pour les préférences libres ?

`preferences` contient deux informations **fixes** : fumeur et animaux. Une ligne par
personne suffit — c'est une relation **un-à-un**.

Les préférences libres sont en nombre **variable** : une personne peut en écrire une, cinq,
ou aucune. C'est une relation **un-à-plusieurs**, qui demande sa propre table :

```sql
CREATE TABLE preferences_personnalisees (
    preference_perso_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    libelle VARCHAR(100) NOT NULL,
    CONSTRAINT preferences_perso_unique UNIQUE (user_id, libelle)
);
```
`UNIQUE (user_id, libelle)` : la même personne ne peut pas enregistrer deux fois la même
préférence. La contrainte porte sur **le couple**, donc deux personnes différentes peuvent
très bien avoir la même préférence.

`ON DELETE CASCADE` : si le compte est supprimé, ses préférences partent avec lui.

Avant, tout tenait dans une seule zone de texte (`preferences.preference_perso`). On ne
pouvait ni en supprimer une seule, ni les afficher proprement une par une.

### La route de suppression, et sa sécurité

```js
const { data, error } = await supabase
  .from("preferences_personnalisees")
  .delete()
  .eq("preference_perso_id", id)
  .eq("user_id", user_id)
  .select();
```
**La deuxième ligne `.eq()` est la plus importante.** Sans elle, n'importe qui pourrait
supprimer les préférences des autres en changeant simplement le numéro dans l'adresse :
`DELETE /preferences-perso/42`. Le `user_id` vient du **jeton**, jamais du navigateur.

```js
if (!data || data.length === 0) {
  return res.status(404).json({ message: "Préférence introuvable." });
}
```
Si rien n'a été supprimé, c'est soit que la préférence n'existe pas, soit qu'elle appartient
à quelqu'un d'autre. **On répond la même chose dans les deux cas** : sinon, la différence de
message permettrait de deviner quelles préférences existent chez les autres.

### Afficher sans risque

```js
const texte = document.createElement("span");
texte.textContent = pref.libelle;
```
Le libellé est écrit par un utilisateur. Avec `innerHTML`, quelqu'un pourrait y glisser du
code qui s'exécuterait chez les autres. `textContent` l'affiche comme du texte. Je l'ai
testé en ajoutant `<img src=x onerror="...">` comme préférence : elle s'affiche en toutes
lettres, rien ne s'exécute.

```js
croix.addEventListener("click", () =>
  supprimerPrefPerso(pref.preference_perso_id)
);
```
On attache l'action avec `addEventListener` plutôt qu'en écrivant `onclick="..."` dans du
HTML : on n'a jamais besoin d'insérer une valeur au milieu de code.

### Le piège du zéro

```js
const nbPlacesVide =
  nb_places === undefined || nb_places === null || nb_places === "";

if (!marque || !modele || !immatriculation || !energie || nbPlacesVide) {
```
En JavaScript, le nombre `0` est considéré comme « faux ». Écrire `!nb_places` renvoyait
donc « champ non rempli » quand la personne saisissait 0 place — alors que le champ **était**
rempli. Elle ne pouvait pas comprendre son erreur. On teste donc explicitement « vide ».

### Rendre les erreurs compréhensibles

```js
const ENERGIES_AUTORISEES = ["electrique", "hybride", "essence", "diesel", "gpl"];

if (!ENERGIES_AUTORISEES.includes(energie)) {
  return res.status(400).json({
    message: "L'énergie doit être : " + ENERGIES_AUTORISEES.join(", ") + ".",
  });
}
```
La base a la même règle (contrainte `CHECK`). Mais sans cette vérification, c'est la base qui
refusait, l'erreur partait dans le `catch` général, et la personne recevait
**« Erreur serveur »** — un message qui ne l'aide pas. Même problème avec un nombre de places
hors bornes. On vérifie donc côté serveur **avant** d'écrire, pour pouvoir expliquer.

### Au moins un rôle

```js
if (!est_chauffeur && !est_passager) {
  return res.status(400).json({
    message: "Choisis au moins un rôle : chauffeur ou passager.",
  });
}
```
L'US 8 dit « chauffeur, passager **ou les deux** ». « Ni l'un ni l'autre » n'est pas dans la
liste : le compte ne servirait plus à rien.

---

## 4. Cinq questions du jury, et les réponses

**Q1 — Pourquoi deux tables pour les préférences ?**
Parce que ce sont deux formes différentes. Fumeur et animaux sont deux informations fixes :
une ligne par personne suffit, c'est du un-à-un. Les préférences libres sont en nombre
variable, c'est du un-à-plusieurs, donc une table à part. Si je mettais tout dans une seule
colonne texte, je ne pourrais ni en supprimer une seule, ni les afficher une par une.

**Q2 — Comment empêchez-vous quelqu'un de supprimer les préférences d'un autre ?**
Par un deuxième filtre dans la requête : `.eq("user_id", user_id)`, où `user_id` vient du
jeton JWT et non du navigateur. Même en changeant le numéro dans l'adresse, la requête ne
trouve rien. Je l'ai vérifié : connectée en tant que gracie, j'ai essayé de supprimer une
préférence de lisa, et j'ai reçu un 404.

**Q3 — Pourquoi répondre 404 au lieu de 403 quand la préférence appartient à quelqu'un d'autre ?**
Parce qu'un 403 dirait « cette préférence existe, mais elle n'est pas à toi ». En essayant
les numéros un par un, on pourrait cartographier ce que les autres ont enregistré. Un 404
dans les deux cas ne révèle rien.

**Q4 — Pourquoi avoir ajouté une route `GET /preferences` ?**
Parce qu'il n'y avait que l'enregistrement. La page ne pouvait donc pas afficher ce qui était
déjà en base : les cases repartaient vides à chaque visite, et on ne savait pas ce qu'on
avait enregistré. C'est un oubli que j'ai trouvé en testant la page, pas en lisant le code.

**Q5 — La contrainte `UNIQUE` existe déjà en base. Pourquoi aussi vérifier dans le code ?**
Pour le message. La base sait refuser, mais elle renvoie un code technique (`23505`) que la
personne ne comprendrait pas. Je vérifie donc avant, pour expliquer clairement — et je garde
quand même le traitement du code `23505` comme filet de sécurité, au cas où deux ajouts
arriveraient exactement au même instant.

---

## 5. Ce qui a été corrigé

L'audit a montré que le rôle, les véhicules et l'enregistrement des préférences
fonctionnaient. Trois choses manquaient ou cassaient :

| Problème constaté | Avant | Après |
|---|---|---|
| **Énergie invalide** (`Electrique`) | `500 Erreur serveur` | `400` avec la liste des énergies |
| **Nombre de places 99** | `500 Erreur serveur` | `400 … entre 1 et 8` |
| **Nombre de places 0** | « champs obligatoires » (trompeur) | `400 … entre 1 et 8` |
| **Relire ses préférences** | impossible, aucune route | `GET /preferences` |
| **Préférences personnalisées** | une zone de texte unique | table dédiée, ajout et suppression |
| **Aucun rôle choisi** | accepté | `400 Choisis au moins un rôle` |

---

## 6. Ce qui a été vérifié

### Par de vrais appels HTTP

| Test | Résultat |
|---|---|
| Énergie `Electrique` (majuscule) | ✅ 400 avec la liste |
| Places 99 / 0 | ✅ 400 « entre 1 et 8 » |
| Aucun rôle | ✅ 400 |
| Chauffeur **et** passager | ✅ 200 |
| `GET /preferences` | ✅ fumeur, animaux **et** liste perso |
| Ajout (avec espaces autour) | ✅ 201, espaces retirés |
| Doublon | ✅ 400 « Tu as déjà ajouté cette préférence. » |
| Préférence vide | ✅ 400 |
| Plus de 100 caractères | ✅ 400 |
| **gracie supprime une préférence de lisa** | ✅ **404 — refusé** |
| lisa supprime la sienne | ✅ 200 |
| Suppression d'une préférence déjà partie | ✅ 404 |
| Véhicule complet (7 champs) | ✅ 201, relu correctement |

### Dans un vrai navigateur

| Test | Résultat |
|---|---|
| Préférences pré-remplies au chargement | ✅ fumeur non coché, animaux coché (valeurs de la base) |
| Ajout par le bouton | ✅ pastille ajoutée, champ vidé |
| Ajout par la touche Entrée | ✅ |
| Doublon | ✅ message d'erreur |
| Champ vide | ✅ message d'erreur |
| Suppression par la croix | ✅ pastille retirée |
| **Préférence contenant `<img src=x onerror=...>`** | ✅ affichée en texte, **code non exécuté** |

*(Toutes les données de test ont été supprimées : 7 comptes, 3 véhicules, 1 préférence,
0 préférence personnalisée — exactement l'état d'avant.)*

---

## 7. Note sur l'ancienne zone de texte

La colonne `preferences.preference_perso` existe toujours et son contenu reste affiché sur la
page de détail d'un trajet. Le formulaire ne la modifie plus — les nouvelles préférences vont
dans la table dédiée — mais on renvoie son ancienne valeur inchangée à chaque enregistrement,
pour ne pas effacer ce qui avait été écrit avant.
