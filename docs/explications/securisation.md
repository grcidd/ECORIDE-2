# Sécurisation de l'application

## 1. Ce que ça fait, en 2 phrases

On empêche les personnes non autorisées d'utiliser les pages réservées à l'employé
et à l'administrateur, en vérifiant à chaque appel « es-tu connecté ? » puis « as-tu le bon rôle ? ».
On a aussi sorti les mots de passe et les clés secrètes du dépôt GitHub, et limité quels
sites ont le droit d'appeler notre API.

---

## 2. Le chemin complet d'un appel protégé

Exemple : l'employé clique sur « Valider » un avis.

| Étape | Fichier | Rôle |
|---|---|---|
| 1. Le clic | `frontend/employe.html` | la fonction `traiterAvis(id, "valider")` |
| 2. L'appel | `frontend/js/api.js` | `apiProtegee()` ajoute le jeton JWT dans l'en-tête |
| 3. L'adresse | `frontend/js/api.js` | `const API` = l'adresse du serveur (locale ou en ligne) |
| 4. L'aiguillage | `backend/server.js` | `app.use("/api/admin", adminRoutes)` |
| 5. Le videur 1 | `backend/middleware/auth.middleware.js` | `authMiddleware` vérifie le jeton |
| 6. Le videur 2 | `backend/middleware/auth.middleware.js` | `checkRole([2, 3])` vérifie le rôle |
| 7. La route | `backend/routes/admin.routes.js` | `router.patch("/avis/:id/valider", ...)` |
| 8. Le traitement | `backend/controllers/admin.controller.js` | `validerAvis()` |
| 9. La base | Supabase (PostgreSQL) | table `avis`, colonne `statut` passe à `"valide"` |

---

## 3. Le code principal, ligne par ligne

### Le videur 1 : « es-tu connecté ? »

```js
const authMiddleware = (req, res, next) => {
```
On crée le middleware. Il reçoit 3 choses : `req` (la demande), `res` (la réponse),
et `next` (la fonction à appeler pour dire « c'est bon, tu peux passer »).

```js
  const enTete = req.headers.authorization;
```
On lit l'en-tête `Authorization` envoyé par le navigateur.
Il ressemble à : `Bearer eyJhbGciOi...`

```js
  if (!enTete) {
    return res.status(401).json({ message: "Accès refusé. Connecte-toi d'abord." });
  }
```
Pas d'en-tête = pas connecté. On renvoie l'erreur **401** (« non authentifié ») et on s'arrête
(`return` empêche la suite de s'exécuter).

```js
  const jeton = enTete.split(" ")[1];
```
`split(" ")` coupe le texte à chaque espace et donne un tableau : `["Bearer", "eyJhbGci..."]`.
`[1]` prend la 2e case, c'est-à-dire le jeton lui-même.

```js
  try {
    const donnees = jwt.verify(jeton, process.env.JWT_SECRET);
```
`jwt.verify` fait deux choses : il vérifie que le jeton a bien été signé avec NOTRE phrase
secrète, et que sa date d'expiration n'est pas dépassée. Si quelqu'un a fabriqué un faux
jeton, cette ligne lève une erreur. Sinon, elle rend le contenu : `user_id`, `pseudo`, `role_id`.

```js
    req.user = donnees;
```
On accroche ces infos à la requête. Toutes les fonctions suivantes pourront lire `req.user`
pour savoir qui parle. **C'est important : l'identité vient du jeton, jamais du navigateur.**

```js
    next();
  } catch (erreur) {
    return res.status(401).json({ message: "Token invalide ou expiré." });
  }
};
```
`next()` = feu vert. En cas de jeton invalide, on tombe dans le `catch` et on renvoie 401.

### Le videur 2 : « as-tu le bon rôle ? »

```js
export const checkRole = (rolesAutorises) => {
  return (req, res, next) => {
```
Particularité : cette fonction **renvoie une autre fonction**. Ça permet de l'utiliser
avec un réglage différent selon la route : `checkRole([3])` pour l'admin seul,
`checkRole([2, 3])` pour l'employé ou l'admin.

```js
    if (!req.user) {
      return res.status(401).json({ message: "Accès refusé. Connecte-toi." });
    }
```
Garde-fou : si on a oublié de mettre `authMiddleware` avant, `req.user` n'existe pas.
On refuse plutôt que de planter.

```js
    if (!rolesAutorises.includes(req.user.role_id)) {
      return res.status(403).json({ message: "Accès interdit. Rôle insuffisant." });
    }
```
`includes()` répond vrai ou faux : « mon rôle est-il dans la liste autorisée ? ».
Si non → erreur **403** (« connecté, mais pas le droit »). Attention à la différence :
401 = je ne sais pas qui tu es ; 403 = je sais qui tu es, mais tu n'as pas le droit.

```js
    next();
  };
};
```

### Comment on les branche sur une route

```js
router.get("/avis", authMiddleware, checkRole(EMPLOYE_OU_ADMIN), getAvisEnAttente);
```
Express exécute ces fonctions **dans l'ordre, de gauche à droite**. Si l'une d'elles
répond au lieu d'appeler `next()`, la chaîne s'arrête : `getAvisEnAttente` n'est jamais atteint.

---

## 4. Cinq questions du jury, et les réponses

**Q1 — Quelle était la faille exactement ?**
Dans `admin.routes.js`, aucune route n'avait de middleware : le fichier n'importait même pas
`authMiddleware`. N'importe qui, sans être connecté, pouvait appeler `/api/admin/utilisateurs`
et récupérer la liste complète des comptes, ou suspendre le compte de quelqu'un. J'ai ajouté
les deux contrôles sur les 6 routes du fichier.

**Q2 — Pourquoi 401 et 403, et pas une seule erreur ?**
Ce sont deux problèmes différents. **401** veut dire « je ne sais pas qui tu es » : il faut se
connecter. **403** veut dire « je sais qui tu es, mais ce n'est pas pour toi » : se reconnecter
n'y changera rien. Côté front, ça permet de réagir correctement : sur un 401 je renvoie vers la
page de connexion, sur un 403 j'affiche « accès interdit ».

**Q3 — Pourquoi ne faut-il pas faire `select("*")` sur la table `users` ?**
Parce que l'étoile prend **toutes** les colonnes, y compris `password` qui contient le mot de
passe chiffré. Il serait alors renvoyé au navigateur, visible par n'importe qui dans l'onglet
Réseau. Je liste donc les colonnes une par une. Seule exception : la fonction de connexion, qui
a besoin du mot de passe chiffré pour le comparer avec bcrypt — mais elle ne le renvoie jamais
dans sa réponse.

**Q4 — À quoi sert CORS et qu'est-ce que vous avez changé ?**
CORS est une sécurité du navigateur : par défaut, un site n'a pas le droit d'appeler une API
hébergée à une autre adresse. Avant, mon code disait `cors()` tout court, c'est-à-dire « tout le
monde a le droit » : n'importe quel site pouvait faire appeler mon API par ses visiteurs.
Maintenant je donne une liste précise : mon site Netlify, plus `localhost` pour développer.

**Q5 — Le fichier `.env` était sur GitHub. Suffit-il de le supprimer ?**
Non, et c'est le point important. Git garde tout l'historique : même supprimé aujourd'hui, le
fichier reste consultable dans les anciens commits. La seule vraie solution est de **changer
tous les secrets** (clé Supabase, mot de passe MongoDB, `JWT_SECRET`, mot de passe mail), pour
que ceux qui ont fuité ne servent plus à rien. J'ai ensuite ajouté un `.gitignore` pour que ça
ne se reproduise pas, et un `.env.example` qui liste les variables nécessaires sans aucune
valeur réelle.
