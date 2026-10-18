# US 3 — Vue des covoiturages

## 1. Ce que ça fait, en 2 phrases

Quand la visiteuse cherche un trajet (ville de départ, ville d'arrivée, date), on affiche
une carte par covoiturage avec le chauffeur, sa note, les horaires, le prix, les places
restantes et un badge si la voiture est électrique.
Si aucun trajet ne correspond, on propose automatiquement la date du prochain trajet
disponible sur le même parcours, avec un bouton pour relancer la recherche à cette date.

---

## 2. Le chemin complet

| Étape | Fichier | Ce qui se passe |
|---|---|---|
| 1. La visiteuse remplit le formulaire | `frontend/covoiturages.html` | `lancerRecherche()` lit les 3 champs |
| 2. Appel du serveur | `frontend/js/api.js` | `const API` donne l'adresse du serveur |
| 3. L'URL appelée | — | `GET /api/covoiturages?depart=Lyon&arrivee=Paris&date=2025-07-15` |
| 4. L'aiguillage | `backend/server.js` | `app.use("/api/covoiturages", covoituragesRoutes)` |
| 5. La route | `backend/routes/covoiturages.routes.js` | `router.get("/", rechercher)` — **publique**, pas besoin d'être connectée |
| 6. Le traitement | `backend/controllers/covoiturages.controller.js` | fonction `rechercher()` |
| 7. Les tables lues | Supabase | `covoiturages` + `users` (chauffeur) + `vehicules` + `avis` (pour la note) |
| 8. L'affichage | `frontend/covoiturages.html` | `creerCarteTrajet()` construit une carte par trajet |

---

## 3. Le code principal, ligne par ligne

### Côté serveur : la recherche

```js
const { depart, arrivee, date } = req.query;
```
On récupère les 3 informations envoyées dans l'adresse (`?depart=Lyon&...`).
Cette écriture avec les accolades s'appelle la **déstructuration** : c'est un raccourci
pour écrire `const depart = req.query.depart;` trois fois.

```js
if (!depart || !arrivee || !date) {
  return res.status(400).json({ message: "Départ, arrivée et date sont requis." });
}
```
Si une information manque, on renvoie l'erreur **400** (« la demande est mal formée »)
et on s'arrête. On ne fait jamais confiance à ce qui arrive de l'extérieur.

```js
let query = supabase
  .from("covoiturages")
  .select(`
    *,
    chauffeur:users(pseudo, photo, credits),
    vehicule:vehicules(marque, modele, energie)
  `)
```
On prépare la requête. `covoiturages` est la table principale.
`chauffeur:users(...)` veut dire : « va aussi chercher dans la table `users` la ligne liée,
et range-la dans une propriété appelée `chauffeur` ». C'est Supabase qui fait la jointure
pour nous, grâce à la clé étrangère `chauffeur_id`.

```js
  .ilike("ville_depart", `%${depart}%`)
  .ilike("ville_arrivee", `%${arrivee}%`)
```
`ilike` = « contient ce texte, sans tenir compte des majuscules ».
Les `%` veulent dire « n'importe quoi avant et après ». Donc « lyon » trouve « Lyon ».

```js
  .eq("date_depart", date)
  .eq("statut", "planifie")
  .gt("nb_places_restantes", 0);
```
`eq` = égal, `gt` = strictement supérieur (*greater than*).
**La dernière ligne répond à l'US 3** : on ne montre que les trajets où il reste
au moins une place. Un trajet complet n'apparaît pas.

```js
if (trajets.length === 0) {
  const { data: prochain } = await supabase
    .from("covoiturages")
    .select("date_depart")
    .ilike("ville_depart", `%${depart}%`)
    .ilike("ville_arrivee", `%${arrivee}%`)
    .gt("date_depart", date)
    .eq("statut", "planifie")
    .gt("nb_places_restantes", 0)
    .order("date_depart", { ascending: true })
    .limit(1)
    .maybeSingle();
```
Aucun résultat ? On refait une recherche, **même parcours mais date plus tard**
(`gt("date_depart", date)`). On trie du plus proche au plus lointain (`ascending: true`)
et on n'en garde qu'un (`limit(1)`). `maybeSingle()` veut dire « 0 ou 1 résultat, et 0
n'est pas une erreur ».

```js
const trajetsAvecNote = await Promise.all(
  trajets.map(async (trajet) => {
    const { data: avis } = await supabase
      .from("avis")
      .select("note")
      .eq("chauffeur_id", trajet.chauffeur_id)
      .eq("statut", "valide");
```
Pour chaque trajet, on va chercher les avis du chauffeur. **Seulement ceux qui ont le
statut `valide`** : un avis en attente de modération ne compte pas dans la note.
`Promise.all` attend que toutes ces recherches soient finies avant de continuer.

```js
    const moyenne = avis && avis.length > 0
      ? (avis.reduce((sum, a) => sum + a.note, 0) / avis.length).toFixed(1)
      : null;
```
`reduce` additionne toutes les notes, on divise par le nombre d'avis, et `toFixed(1)`
garde un chiffre après la virgule (4.5). S'il n'y a aucun avis, on met `null` et le front
affichera « Nouveau chauffeur ».

### Côté navigateur : construire une carte sans risque

```js
const carte = document.createElement("div");
carte.className = "carte-trajet";
```
On crée une vraie boîte HTML vide, au lieu d'écrire du texte qui ressemble à du HTML.

```js
carte.innerHTML = `
  <div class="carte-chauffeur">
    <div class="avatar js-avatar"></div>
    ...`;
```
On pose le **squelette**. Ce HTML est écrit par moi, il ne contient **aucune donnée
venant de la base** : il n'y a donc aucun risque. Les classes qui commencent par `js-`
servent uniquement à retrouver les cases à remplir juste après.

```js
dans("js-pseudo").textContent = pseudo;
```
**C'est la ligne la plus importante pour la sécurité.** `textContent` met le pseudo
comme du **texte**. Si un chauffeur s'appelle `<script>...</script>`, ces caractères
s'affichent tels quels à l'écran au lieu d'être exécutés par le navigateur.
Avec `innerHTML`, le code aurait été exécuté : c'est la faille **XSS**.

```js
if (chauffeur.photo) {
  const image = document.createElement("img");
  image.src = chauffeur.photo;
  image.alt = pseudo;
  dans("js-avatar").appendChild(image);
} else {
  dans("js-avatar").textContent = pseudo[0].toUpperCase();
}
```
S'il y a une photo on crée une balise `<img>` et on remplit `src` par la propriété
(jamais en collant du HTML). Sinon on affiche la première lettre du pseudo en majuscule.

```js
dans("js-horaires").textContent =
  "🕐 " + formatHeure(t.heure_depart) + " → " + formatHeure(t.heure_arrivee);
```
L'US 3 demande l'heure de départ **et** l'heure d'arrivée. `formatHeure` transforme
`"08:00:00"` (le format de la base) en `"08:00"` (lisible).

```js
if (t.est_ecologique) {
  dans("js-eco").hidden = false;
}
```
Le badge « 🌱 Écologique » est déjà dans le squelette mais caché (`hidden`).
On le montre seulement si le véhicule est électrique. `est_ecologique` est calculé
par le serveur au moment où le chauffeur crée son trajet, à partir de l'énergie du véhicule.

```js
filtres.forEach((t) => zone.appendChild(creerCarteTrajet(t)));
```
On ajoute les cartes une par une dans la page. `appendChild` pose un vrai élément :
rien n'est réinterprété comme du HTML.

---

## 4. Cinq questions du jury, et les réponses

**Q1 — Comment garantissez-vous qu'un trajet complet n'apparaît pas ?**
C'est filtré **côté serveur**, dans la requête : `.gt("nb_places_restantes", 0)` ne
remonte que les trajets où il reste au moins une place. Je ne le fais pas côté navigateur,
parce qu'un filtre en JavaScript peut être contourné par n'importe qui avec les outils de
développement. Le serveur reste la seule source de vérité.

**Q2 — Comment est calculée la note du chauffeur ?**
C'est une moyenne faite par le serveur sur la table `avis`, avec deux conditions :
les avis du bon chauffeur (`chauffeur_id`), et uniquement ceux dont le statut est
`valide`. Un avis en attente de modération ne compte pas. S'il n'y a aucun avis validé,
je renvoie `null` et l'interface affiche « Nouveau chauffeur » plutôt qu'un zéro,
qui donnerait l'impression d'une mauvaise note.

**Q3 — Expliquez la proposition de date quand il n'y a pas de résultat.**
Si la première requête ne renvoie rien, j'en lance une seconde sur le **même parcours**
mais avec `date_depart` strictement supérieure à la date demandée. Je trie par ordre
croissant et je garde le premier résultat : c'est donc le trajet disponible le plus
proche dans le temps. Le serveur renvoie cette date dans `prochain_dispo`, et le front
affiche un bouton qui remet cette date dans le formulaire et relance la recherche.

**Q4 — Pourquoi `textContent` et pas `innerHTML` ?**
Parce que le pseudo d'un chauffeur est une donnée que *lui* a saisie. Avec `innerHTML`,
s'il écrit `<img src=x onerror="...">`, le navigateur exécute ce code chez **toutes** les
visiteuses : c'est une faille XSS, et comme mon jeton de connexion est dans le
`localStorage`, il pourrait être volé. `textContent` affiche le contenu comme du texte,
donc le code ne s'exécute jamais. Je l'ai testé : j'ai mis `<img src=x onerror=...>`
dans le champ de recherche, et il s'affiche en toutes lettres sans rien déclencher.

**Q5 — Pourquoi `ilike` et pas `eq` pour les villes ?**
`eq` demande une correspondance exacte : « lyon » en minuscules ne trouverait pas
« Lyon ». `ilike` ignore les majuscules et, avec les `%` autour, accepte aussi une
correspondance partielle. C'est beaucoup plus tolérant pour la personne qui tape sa
recherche. Pour la date en revanche je garde `eq`, parce qu'on veut exactement ce jour-là.

---

## 5. Comment tester

**Serveur** (depuis la racine du projet) :
```bash
node backend/server.js
```

**API, les 3 cas :**
```bash
# 1. un résultat
curl "http://localhost:3000/api/covoiturages?depart=Lyon&arrivee=Paris&date=2025-07-15"

# 2. aucun résultat, mais une date est proposée
curl "http://localhost:3000/api/covoiturages?depart=Lyon&arrivee=Paris&date=2025-07-01"

# 3. aucun résultat et aucune date suivante
curl "http://localhost:3000/api/covoiturages?depart=Brest&arrivee=Nice&date=2026-01-01"
```

**Page web :** ouvrir `frontend/covoiturages.html` avec Live Server, puis
`?depart=Lyon&arrivee=Paris&date=2025-07-15`.
