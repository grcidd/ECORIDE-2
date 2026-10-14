# US 6 — Participer à un covoiturage

## 1. Ce que ça fait, en 2 phrases

La passagère réserve une place : on vérifie qu'il en reste une et qu'elle a assez de crédits,
on lui montre un récapitulatif à confirmer, puis on enregistre la réservation.
Les trois écritures que cela demande — créer la participation, débiter les crédits, enlever
une place — se font **dans une seule transaction** : soit tout réussit, soit rien n'est écrit.

---

## 2. Le chemin complet

| Étape | Fichier | Ce qui se passe |
|---|---|---|
| 1. Clic sur « Participer » | `frontend/detail.html` | `participer()` — **ne réserve rien** |
| 2. Pas connectée ? | `frontend/detail.html` | redirection vers `connexion.html?retour=detail.html?id=10` |
| 3. Retour après connexion | `frontend/connexion.html` | `pageDeRetour()` ramène au trajet |
| 4. Récapitulatif | `frontend/detail.html` | « Cette réservation utilisera 5 crédits… » |
| 5. Clic sur « Oui, je confirme » | `frontend/detail.html` | `confirmerReservation()` |
| 6. L'appel | `frontend/js/api.js` | `apiProtegee()` ajoute le jeton JWT |
| 7. L'URL | — | `POST /api/covoiturages/10/participer` |
| 8. Le videur | `backend/middleware/auth.middleware.js` | `authMiddleware` : es-tu connectée ? |
| 9. La route | `backend/routes/covoiturages.routes.js` | `router.post("/:id/participer", …)` |
| 10. Le traitement | `backend/controllers/covoiturages.controller.js` | `participer()` → `supabase.rpc(...)` |
| 11. **La transaction** | PostgreSQL | fonction `reserver_covoiturage` |
| 12. Les tables | Supabase | `covoiturages`, `users`, `participations` |

---

## 3. Le code principal, ligne par ligne

### Le cœur de l'US 6 : la fonction PostgreSQL

**Le problème.** Une réservation, ce sont 3 écritures qui vont ensemble :

```js
await supabase.from("participations").insert({...});   // 1
await supabase.from("users").update({credits: ...});   // 2
await supabase.from("covoiturages").update({...});     // 3
```

C'était l'ancien code. Si le serveur tombait entre la 2 et la 3, la passagère était
**débitée sans que sa place soit réservée**. Et il y avait un second défaut : les crédits
étaient lus puis réécrits (`passager.credits - prix`) — si deux réservations arrivaient en
même temps, l'une des deux déductions était perdue.

**La solution.** Une fonction PostgreSQL s'exécute dans **une seule transaction**.

```sql
CREATE OR REPLACE FUNCTION reserver_covoiturage(
    p_covoiturage_id INTEGER,
    p_passager_id INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
```
On déclare la fonction et ce qu'elle attend : le numéro du trajet et celui de la passagère.
`RETURNS JSON` : elle renverra un petit résumé.

```sql
SECURITY DEFINER
SET search_path = public
```
`SECURITY DEFINER` : la fonction s'exécute avec les droits de son propriétaire. Elle
continuera donc de marcher si on active la sécurité RLS sur les tables plus tard.
`SET search_path = public` fige le chemin de recherche : sans ça, quelqu'un pourrait créer
une fausse table `users` dans un autre schéma pour détourner la fonction.

```sql
SELECT * INTO v_trajet
FROM covoiturages
WHERE covoiturage_id = p_covoiturage_id
FOR UPDATE;
```
**`FOR UPDATE` est la ligne la plus importante.** Elle verrouille la ligne du trajet jusqu'à
la fin de la transaction. Si deux passagères cliquent sur la dernière place au même instant,
la seconde **attend** que la première ait fini, puis constate qu'il n'y a plus de place.
Sans ce verrou, les deux passeraient et le trajet serait en surréservation.

```sql
IF v_trajet.nb_places_restantes <= 0 THEN
    RAISE EXCEPTION 'COMPLET';
END IF;
```
`RAISE EXCEPTION` arrête tout **et annule** ce qui aurait déjà été écrit. On utilise des
codes courts (`COMPLET`, `DEJA_INSCRIT`…) que le serveur Node traduira en français.

```sql
SELECT credits INTO v_credits FROM users
WHERE user_id = p_passager_id FOR UPDATE;
```
On verrouille aussi le compte de la passagère, pour que ses crédits ne bougent pas pendant
qu'on travaille (par exemple si elle réserve deux trajets en même temps).

```sql
INSERT INTO participations (...) VALUES (...);
UPDATE users SET credits = credits - v_trajet.prix_par_personne WHERE ...;
UPDATE covoiturages SET nb_places_restantes = nb_places_restantes - 1 WHERE ...;
```
Les 3 écritures. Noter `credits = credits - prix` : on demande à PostgreSQL de faire le
calcul **lui-même**, à partir de la valeur du moment. C'est plus sûr que de lui envoyer un
nombre calculé en JavaScript à partir d'une valeur peut-être périmée.

### Côté serveur : un seul appel

```js
const { data, error } = await supabase.rpc("reserver_covoiturage", {
  p_covoiturage_id: Number(id),
  p_passager_id: user_id,
});
```
`rpc` veut dire « appel de procédure distante » : on demande à la base d'exécuter sa
fonction. Les 11 lignes de vérifications et les 3 écritures de l'ancien code tiennent
maintenant en un seul appel.

```js
const user_id = req.user.user_id;
```
L'identité vient **du jeton**, jamais du navigateur. Sinon n'importe qui pourrait réserver
au nom de quelqu'un d'autre en modifiant la requête.

```js
const trouve = codes.find((c) => error.message.includes(c));
if (trouve) {
  const reponse = MESSAGES_RESERVATION[trouve];
  return res.status(reponse.code).json({ message: reponse.message });
}
```
On cherche lequel de nos codes apparaît dans l'erreur renvoyée, et on le traduit en message
clair avec le bon code HTTP (404 si le trajet n'existe pas, 400 dans les autres cas).

```js
try {
  await Log.create({...});
} catch (erreurMongo) {
  console.log("Log Mongo non enregistré :", erreurMongo.message);
}
```
Le log MongoDB est un **bonus**. S'il échoue, la réservation reste valable. Avant, une panne
de MongoDB faisait répondre « Erreur serveur » alors que la passagère avait bien été débitée.

### Côté navigateur : la double confirmation

```js
function participer() {
  if (!estConnecte()) {
    const retour = "detail.html?id=" + id;
    window.location.href = "connexion.html?retour=" + encodeURIComponent(retour);
    return;
  }
```
Première étape : **elle ne réserve rien**. Si la personne n'est pas connectée, on l'envoie
se connecter en gardant l'adresse du trajet, pour la ramener ici ensuite.

```js
  ligne1.textContent = "Cette réservation utilisera " + prix + " crédits.";
  ligne2.textContent = "Il te restera " + (utilisateur.credits - prix) + " crédits sur " +
                       utilisateur.credits + ".";
  document.getElementById("confirmation").hidden = false;
  document.getElementById("btn-participer").hidden = true;
```
On affiche le récapitulatif demandé par l'US 6, et on cache le premier bouton pour qu'il n'y
ait qu'une action possible à l'écran.

```js
async function confirmerReservation() {
  const boutonOui = document.getElementById("btn-confirmer");
  boutonOui.disabled = true;
```
Deuxième étape : c'est seulement ici qu'on appelle le serveur. On désactive tout de suite le
bouton pour éviter un double clic qui enverrait deux réservations.

```js
utilisateur.credits = data.credits_restants;
localStorage.setItem("user", JSON.stringify(utilisateur));
```
Le serveur renvoie le solde **réel**. On met à jour la session pour que le reste du site
affiche le bon nombre de crédits.

### La protection contre la redirection ouverte

```js
const formatAutorise = /^[a-z0-9-]+\.html(\?[a-z0-9=&_-]*)?$/i;
if (!formatAutorise.test(retour)) return null;
```
Le paramètre `retour` vient de l'adresse, donc de l'extérieur. Sans contrôle, quelqu'un
pourrait envoyer un lien `connexion.html?retour=https://site-pirate.com` : la personne se
connecterait chez nous puis serait expédiée ailleurs, sur une fausse page qui lui
redemanderait son mot de passe. Cette faille s'appelle une **redirection ouverte**.
On n'accepte donc que le nom d'une page de notre site.

---

## 4. Cinq questions du jury, et les réponses

**Q1 — Pourquoi une fonction PostgreSQL plutôt que trois requêtes depuis Node ?**
Parce que les trois écritures doivent réussir ou échouer ensemble. Depuis Node, elles sont
trois requêtes indépendantes : si la connexion tombe entre la deuxième et la troisième, la
passagère est débitée sans avoir sa place, et la base reste dans un état faux. Une fonction
PostgreSQL s'exécute dans une seule transaction : à la moindre erreur, PostgreSQL annule
automatiquement tout ce qui a été fait. Je l'ai vérifié en faisant échouer volontairement la
troisième écriture : ni la participation, ni le débit n'ont été enregistrés.

**Q2 — À quoi sert `FOR UPDATE` ?**
Il verrouille la ligne jusqu'à la fin de la transaction. C'est ce qui empêche la
surréservation : si deux personnes cliquent sur la dernière place au même moment, la seconde
attend que la première ait terminé, puis voit qu'il n'y a plus de place. Sans ce verrou, les
deux liraient « 1 place restante » et passeraient toutes les deux.

**Q3 — Pourquoi une double confirmation ?**
Parce qu'une réservation dépense de l'argent (des crédits) et qu'elle est difficile à
annuler. Le premier clic n'envoie rien : il affiche combien de crédits vont être utilisés et
combien il en restera. C'est seulement le second clic qui appelle le serveur. Ça évite les
réservations par erreur.

**Q4 — Le bouton est désactivé si les crédits manquent. Est-ce suffisant comme sécurité ?**
Non, et c'est important : désactiver un bouton n'est qu'un confort d'affichage. N'importe qui
peut l'activer avec les outils de développement, ou appeler l'API directement. La vraie
sécurité est dans la fonction PostgreSQL, qui revérifie les crédits, les places, le fait que
ce n'est pas son propre trajet et qu'on n'a pas déjà réservé. Je l'ai testé en appelant l'API
sans passer par la page : la réservation est bien refusée.

**Q5 — Comment savez-vous que c'est bien la bonne personne qui réserve ?**
L'identité vient du jeton JWT, lu par `authMiddleware` et rangé dans `req.user`. Le controller
utilise `req.user.user_id`, jamais une valeur envoyée dans le corps de la requête. Si je
faisais confiance au navigateur, n'importe qui pourrait réserver au nom d'un autre compte et
vider ses crédits.

---

## 5. Ce qui a été vérifié

### La transaction, dans un schéma de test isolé

| Vérification | Résultat |
|---|---|
| Réservation normale | ✅ 15 crédits utilisés, 20 → 5, places 3 → 2 |
| Déjà inscrite | ✅ `DEJA_INSCRIT` |
| Son propre trajet | ✅ `PROPRE_TRAJET` |
| Trajet complet | ✅ `COMPLET` |
| Trajet déjà terminé | ✅ `TRAJET_NON_RESERVABLE` |
| Crédits insuffisants | ✅ `CREDITS_INSUFFISANTS` |
| Trajet inexistant | ✅ `TRAJET_INTROUVABLE` |

**Le test décisif — l'annulation complète.** J'ai piégé la base pour que la *troisième*
écriture échoue, après que les deux premières aient déjà eu lieu :

| | Avant | Après |
|---|---|---|
| Crédits | 100 | **100** (non débités) |
| Places | 1 | **1** (non décrémentée) |
| Participations | 0 | **0** (non créée) |

### L'API, avec de vrais appels HTTP

| Test | Résultat |
|---|---|
| Réservation (trajet à 5 crédits) | ✅ 200 — 5 utilisés, 15 restants, 3 places |
| Base après coup | ✅ crédits 20→15, places 4→3, participation créée |
| Deuxième fois | ✅ 400 « Tu participes déjà à ce trajet. » |
| Crédits insuffisants | ✅ 400 |
| Trajet terminé | ✅ 400 |
| Trajet inexistant | ✅ 404 |
| Sans jeton | ✅ 401 |
| Son propre trajet | ✅ 400 |

### Le parcours, dans un vrai navigateur

| Test | Résultat |
|---|---|
| Non connectée → clic | ✅ `connexion.html?retour=detail.html%3Fid%3D10` |
| Connexion → retour au trajet | ✅ |
| **Redirection ouverte** : `https://site-pirate.com` | ✅ refusée |
| **Redirection ouverte** : `//site-pirate.com` | ✅ refusée |
| **Redirection ouverte** : `javascript:alert(1)` | ✅ refusée |
| Page légitime `detail.html?id=10` | ✅ acceptée |
| Clic 1 → récapitulatif | ✅ « utilisera 5 crédits… restera 15 sur 20 » |
| « Annuler » | ✅ rien réservé, crédits inchangés |
| « Oui, je confirme » | ✅ « Participation confirmée ! 5 crédits… » |
| Crédits de session mis à jour | ✅ 20 → 15 |
| Crédits insuffisants | ✅ bouton désactivé + « Il te faut 24.48 crédits, tu en as 15. » |

*(Données de test supprimées après coup : crédits, places et participations remis à l'identique.)*

---

## 6. Deux bugs trouvés pendant ces tests

**1. L'attribut `hidden` ne cachait rien.** Le navigateur applique `display: none` aux
éléments marqués `hidden`, mais n'importe quelle règle CSS qui fixe un `display` l'emporte —
et nos boutons et pastilles utilisent `display: inline-flex`. Conséquence : **le badge
« 🌱 Écologique » s'affichait sur tous les trajets**, y compris les diesel, dans la liste
(US 3) comme sur la page de détail (US 5). Corrigé par une règle globale
`[hidden] { display: none !important; }`, puis revérifié sur les deux pages.

**2. Chaque réservation attendait 10 secondes.** Quand MongoDB est injoignable, Mongoose met
les opérations en attente pendant 10 secondes avant d'abandonner. Comme le serveur écrit un
log après chaque réservation, la réponse partait avec 10 secondes de retard — alors que le
log n'est qu'un bonus. Corrigé avec `mongoose.set("bufferCommands", false)` : l'opération
échoue tout de suite. Mesuré : **236 ms au lieu de plus de 10 000 ms**.

---

## 7. Limite connue

Après avoir réservé, le bouton affiche toujours « Participer au trajet ». Un nouveau clic est
refusé proprement par le serveur (« Tu participes déjà à ce trajet. »), mais la page ne sait
pas encore afficher « Tu participes à ce trajet ». Ce sera traité avec l'US 10, qui ajoute
l'historique des réservations.
