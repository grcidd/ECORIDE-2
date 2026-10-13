# US 4 — Les filtres de recherche

## 1. Ce que ça fait, en 2 phrases

Une fois les trajets affichés, la passagère peut affiner avec quatre filtres :
voitures écologiques uniquement, prix maximum, durée maximum et note minimum du chauffeur.
Les filtres s'appliquent instantanément, sans recharger la page ni rappeler le serveur,
parce que les trajets sont déjà en mémoire dans le navigateur.

---

## 2. Le chemin complet

| Étape | Fichier | Ce qui se passe |
|---|---|---|
| 1. La recherche | `frontend/covoiturages.html` | `lancerRecherche()` appelle le serveur |
| 2. Les trajets sont gardés | `frontend/covoiturages.html` | `tousLesTrajets = data.trajets` (la liste complète, en mémoire) |
| 3. La passagère coche un filtre | `frontend/covoiturages.html` | `onchange="filtrerTrajets()"` sur chaque contrôle |
| 4. Le tri | `frontend/covoiturages.html` | `filtrerTrajets()` garde ou écarte chaque trajet |
| 5. L'affichage | `frontend/covoiturages.html` | `creerCarteTrajet()` redessine la liste |

**Important : aucun appel au serveur à l'étape 3.** Le serveur n'est sollicité qu'une seule
fois, au moment de la recherche. Les données nécessaires aux filtres (`est_ecologique`,
`prix_par_personne`, les heures, `note_chauffeur`) arrivent toutes dans cette même réponse.

---

## 3. Le code principal, ligne par ligne

### Lire les valeurs des quatre contrôles

```js
const eco = document.getElementById("filtre-eco").checked;
```
Une case à cocher : `.checked` donne `true` ou `false`.

```js
const prix = parseInt(document.getElementById("filtre-prix").value);
```
Un curseur donne toujours du **texte** (`"25"`). `parseInt` le transforme en **nombre** (`25`),
sinon la comparaison `>` se ferait entre deux textes et donnerait de faux résultats.

```js
const duree = parseInt(document.getElementById("filtre-duree").value) || Infinity;
```
Si le champ est vide, `parseInt` renvoie `NaN`, qui est considéré comme « faux » par
JavaScript. Le `||` prend alors la valeur de droite : `Infinity`, c'est-à-dire « pas de
limite ». Du coup, aucun trajet n'est écarté tant que la passagère n'a rien saisi.

### Trier la liste

```js
const filtres = tousLesTrajets.filter((t) => {
```
`filter` parcourt tous les trajets et garde uniquement ceux pour lesquels la fonction
renvoie `true`. **`tousLesTrajets` n'est jamais modifié** : on peut donc assouplir un filtre
et retrouver les trajets écartés, sans refaire de recherche.

```js
  if (eco && !t.est_ecologique) return false;
```
À lire comme : « si le filtre écologique est coché ET que ce trajet n'est pas écologique,
alors je l'écarte ». Si la case n'est pas cochée, la condition est fausse d'emblée et on
passe à la suite.

```js
  if (t.prix_par_personne > prix) return false;
```
Trop cher → écarté.

```js
  const dureeTrajet = calculerDureeMinutes(t);
  if (dureeTrajet !== null && dureeTrajet > duree) return false;
```
On calcule la durée réelle, puis on écarte si elle dépasse la limite.
Le test `!== null` sert aux trajets dont la durée est inconnue : on préfère les **laisser
passer** plutôt que de les cacher sans raison.

```js
  if (note > 0 && (!t.note_chauffeur || t.note_chauffeur < note)) return false;
```
Deux cas d'exclusion quand une note minimum est demandée : le chauffeur n'a aucune note
(`!t.note_chauffeur`), ou sa note est inférieure. Un chauffeur sans avis est donc écarté —
c'est voulu : on ne peut pas garantir qu'il atteint la note demandée.

```js
  return true;
});
```
Aucun filtre ne l'a écarté → on le garde.

### Calculer la durée avec l'heure d'arrivée

```js
function minutesDepuisMinuit(heure) {
  const morceaux = heure.split(":");
  return Number(morceaux[0]) * 60 + Number(morceaux[1]);
}
```
`"08:30:00".split(":")` donne `["08", "30", "00"]`. On prend les heures × 60 + les minutes :
08:30 devient 510 minutes. Travailler en minutes rend la soustraction simple.

```js
function calculerDureeMinutes(t) {
  if (t.heure_depart && t.heure_arrivee) {
    const depart = minutesDepuisMinuit(t.heure_depart);
    const arrivee = minutesDepuisMinuit(t.heure_arrivee);
    let duree = arrivee - depart;
    if (duree < 0) duree = duree + 24 * 60;
    return duree;
  }
```
L'énoncé demande une durée **calculée avec l'heure d'arrivée**, c'est donc ce qu'on fait.
La ligne `if (duree < 0)` traite les trajets de nuit : un départ à 22:30 et une arrivée à
01:15 donnent `75 - 1350 = -1275`, auquel on ajoute 24 h (1440 min) pour obtenir 165 minutes.

```js
  if (t.duree_minutes) return t.duree_minutes;
  return null;
}
```
Repli : si l'heure d'arrivée manque, on prend la durée enregistrée en base.
Et si on n'a vraiment rien, on renvoie `null` — le filtre laissera passer le trajet.

---

## 4. Cinq questions du jury, et les réponses

**Q1 — Pourquoi filtrer côté navigateur plutôt que côté serveur ?**
Parce que les trajets sont déjà tous chargés en mémoire après la recherche. Filtrer sur place
est instantané et évite un aller-retour réseau à chaque case cochée. Attention : c'est valable
pour le **confort d'affichage**. La règle de sécurité de l'US 3 — ne montrer que les trajets
avec au moins une place — reste, elle, appliquée côté serveur, parce qu'un filtre dans le
navigateur peut être contourné.

**Q2 — Pourquoi calculer la durée au lieu d'utiliser la colonne `duree_minutes` ?**
Parce que l'énoncé demande explicitement une durée calculée avec l'heure d'arrivée, et surtout
parce que `duree_minutes` peut être vide : le formulaire de création de trajet ne la demande
pas forcément. L'ancien code écrivait `if (t.duree_minutes && t.duree_minutes > duree)` :
quand la colonne était vide, le trajet passait le filtre **même s'il durait dix heures**.
Je calcule donc à partir des heures, qui sont toujours renseignées, et je garde la colonne
comme solution de repli.

**Q3 — Comment gérez-vous un trajet qui part à 22h30 et arrive à 1h15 ?**
Une simple soustraction donnerait un nombre négatif. Je teste donc `if (duree < 0)` et
j'ajoute 24 heures, soit 1440 minutes. J'obtiens bien 165 minutes. Je l'ai vérifié avec
ce cas précis.

**Q4 — Que se passe-t-il pour un chauffeur sans aucun avis ?**
Sa note vaut `null`. Sans filtre de note, il apparaît normalement et l'interface affiche
« Nouveau chauffeur ». Dès que la passagère demande une note minimum, il est écarté : on ne
peut pas affirmer qu'il atteint ce niveau. C'est un choix que j'assume, parce que l'inverse
reviendrait à promettre une qualité qu'on ne connaît pas.

**Q5 — Pourquoi `|| Infinity` sur le champ durée ?**
Quand le champ est vide, `parseInt("")` renvoie `NaN`, que JavaScript considère comme faux.
L'opérateur `||` prend alors la valeur de droite. En mettant `Infinity`, aucune durée ne peut
lui être supérieure, donc le filtre laisse tout passer. C'est plus simple que d'écrire une
condition « si le champ est vide, ne pas filtrer ».

---

## 5. Ce qui a été vérifié (dans un vrai navigateur)

Avec quatre trajets d'essai couvrant tous les cas :

| Filtre | Résultat |
|---|---|
| Aucun filtre | 4 trajets ✅ |
| Écologique seul | les 2 électriques ✅ |
| Prix ≤ 13 crédits | les 2 à 10 et 12 crédits ✅ |
| Durée ≤ 120 min | le seul de 90 min ✅ |
| Note ≥ 4 | les 2 notés 4.8 — celui sans note et celui à 2.5 écartés ✅ |
| Écologique **et** note ≥ 4 | 1 seul trajet ✅ |
| Prix ≤ 1 | message « Aucun trajet avec ces filtres » ✅ |
| Réinitialiser | retour aux 4 trajets ✅ |

Calcul de la durée :

| Cas | Attendu | Obtenu |
|---|---|---|
| 08:00 → 12:45 | 285 min | 285 ✅ |
| 22:30 → 01:15 (passe minuit) | 165 min | 165 ✅ |
| 09:00 → 10:15 | 75 min | 75 ✅ |
| Sans heure d'arrivée (repli base) | 200 min | 200 ✅ |
| Aucune information | `null` | `null` ✅ |
| Affichage | — | « 4 h 45 », « 1 h 15 », « 45 min » ✅ |
