# US 7 — Création de compte

## 1. Ce que ça fait, en 2 phrases

Une visiteuse crée son compte avec un pseudo, un email et un mot de passe, et reçoit
automatiquement **20 crédits** pour sa première réservation.
Le mot de passe n'est jamais enregistré tel quel : il est transformé par bcrypt en une
empreinte impossible à inverser.

---

## 2. Le chemin complet

| Étape | Fichier | Ce qui se passe |
|---|---|---|
| 1. Le formulaire | `frontend/connexion.html` | onglet « Inscription » |
| 2. Contrôles rapides | `frontend/connexion.html` | `sInscrire()` : champs remplis, mots de passe identiques, format du mot de passe |
| 3. L'appel | `frontend/js/api.js` | `const API` donne l'adresse du serveur |
| 4. L'URL | — | `POST /api/auth/register` |
| 5. La route | `backend/routes/auth.routes.js` | `router.post("/register", register)` — **publique** |
| 6. Le traitement | `backend/controllers/auth.controller.js` | `register()` : 9 étapes de vérification |
| 7. Le chiffrement | `bcrypt` | `bcrypt.hash(password, 10)` |
| 8. La table | Supabase | `users` — `credits` et `role_id` par défaut |

---

## 3. Le code principal, ligne par ligne

### La règle du mot de passe

```js
const REGLE_MOT_DE_PASSE = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,}$/;
```
Une expression régulière, c'est un motif que le texte doit respecter. Morceau par morceau :

| Morceau | Ce qu'il exige |
|---|---|
| `^` … `$` | du début à la fin (tout le texte, pas juste un bout) |
| `(?=.*[a-z])` | il existe une minuscule quelque part |
| `(?=.*[A-Z])` | il existe une majuscule |
| `(?=.*\d)` | il existe un chiffre |
| `(?=.*[^\w\s])` | il existe un caractère ni lettre, ni chiffre, ni espace (donc `!`, `?`, `@`…) |
| `.{8,}` | et le tout fait au moins 8 caractères |

Les `(?=...)` s'appellent des **vérifications en avant**. Chacune regarde tout le texte sans
le consommer, puis revient au départ. C'est ce qui permet d'exiger plusieurs choses à la
fois, dans n'importe quel ordre : `Motdepasse1!` passe, `motdepasse1!` échoue (pas de
majuscule), `Motdepasse1` échoue (pas de caractère spécial).

### La mise au propre, avant toute vérification

```js
const pseudoPropre = pseudo.trim();
const emailPropre = email.trim().toLowerCase();
```
`trim()` enlève les espaces au début et à la fin : quelqu'un qui colle son email avec un
espace ne doit pas être bloqué.
`toLowerCase()` sur l'email est **indispensable** : sans lui, `Gracie@test.fr` et
`gracie@test.fr` créaient **deux comptes différents** pour la même adresse. Je l'ai constaté
avant correction : la base contenait bien deux lignes.

### Les deux vérifications d'unicité

```js
const { data: emailExistant } = await supabase
  .from("users").select("user_id").eq("email", emailPropre).maybeSingle();
if (emailExistant) {
  return res.status(400).json({ message: "Cet email est déjà utilisé." });
}
```
`maybeSingle()` veut dire « 0 ou 1 résultat, et 0 n'est pas une erreur ».

```js
const { data: pseudoExistant } = await supabase
  .from("users").select("user_id").ilike("pseudo", pseudoPropre).maybeSingle();
```
`ilike` compare **sans tenir compte des majuscules** : `GRACIE_P` est donc refusé si
`gracie_p` existe. Cette vérification manquait complètement : la base refusait
l'enregistrement (le pseudo est `UNIQUE`) et la personne recevait un **« Erreur serveur »**
sans comprendre pourquoi.

### Le chiffrement du mot de passe

```js
const hashedPassword = await bcrypt.hash(password, 10);
```
bcrypt transforme le mot de passe en une empreinte du type `$2b$10$I.pAy6VLfKD...`.
On ne peut pas revenir en arrière : même en volant la base, on ne retrouve pas les mots de
passe. À la connexion, on ne compare pas les textes mais les empreintes, avec
`bcrypt.compare()`.

Le `10` est le **coût** : bcrypt répète son calcul 2¹⁰ fois, soit 1024. Plus ce nombre est
grand, plus le calcul est lent — imperceptible pour une connexion, mais très coûteux pour
quelqu'un qui essaierait des millions de mots de passe.

bcrypt ajoute aussi automatiquement un **sel** : deux personnes avec le même mot de passe
obtiennent deux empreintes différentes. Un attaquant ne peut donc pas repérer les comptes
qui partagent un mot de passe.

### Les 20 crédits (le cœur de l'US 7)

```js
const { data: newUser, error } = await supabase
  .from("users")
  .insert({
    pseudo: pseudoPropre,
    email: emailPropre,
    password: hashedPassword,
  })
```
**On n'envoie que trois colonnes.** `credits` et `role_id` ne sont **pas** dans l'insertion :
ce sont les valeurs par défaut définies dans la base (`credits INTEGER DEFAULT 20`,
`role_id INTEGER DEFAULT 1`).

C'est un choix de sécurité. Si je reprenais `req.body` en entier, quelqu'un pourrait
s'inscrire en envoyant `{"credits": 999, "role_id": 3}` et deviendrait administrateur avec
999 crédits. Je l'ai testé : la tentative passe, mais la base enregistre bien 20 crédits et
le rôle 1.

### Le filet de sécurité

```js
if (error.code === "23505") {
  return res.status(400).json({ message: "Ce pseudo ou cet email vient d'être pris." });
}
```
`23505` est le code PostgreSQL pour « violation de contrainte d'unicité ». Si deux personnes
s'inscrivent au même instant avec le même pseudo, les deux vérifications peuvent passer
toutes les deux avant qu'aucune n'ait écrit. C'est alors la base qui refuse, et on traduit
son code en message clair plutôt qu'en « Erreur serveur ».

---

## 4. Cinq questions du jury, et les réponses

**Q1 — Comment les 20 crédits sont-ils attribués ?**
Par la valeur par défaut de la colonne, `credits INTEGER DEFAULT 20` dans `schema.sql`.
Le code d'inscription n'envoie pas cette colonne du tout : la base la remplit elle-même.
C'est plus sûr que de l'écrire dans le code, parce que personne ne peut alors s'en attribuer
davantage en modifiant la requête.

**Q2 — Pourquoi bcrypt et pas un simple chiffrement ?**
Parce qu'un chiffrement se déchiffre : si on vole la clé, on récupère tous les mots de passe.
bcrypt est une fonction à sens unique, on ne peut pas revenir en arrière. Il est aussi
**volontairement lent** et ajoute un sel différent pour chaque mot de passe, ce qui rend
inutilisables les tables de correspondances toutes faites.

**Q3 — Pourquoi valider deux fois, dans le navigateur et sur le serveur ?**
Le contrôle côté navigateur n'est qu'un **confort** : il évite un aller-retour réseau et
prévient tout de suite. Mais il se contourne en deux clics dans les outils de développement,
ou en appelant l'API directement. La vraie sécurité est côté serveur, et je l'ai vérifiée en
envoyant des requêtes `curl` sans passer par la page : tous les mots de passe faibles sont
refusés.

**Q4 — Pourquoi mettre l'email en minuscules ?**
Parce qu'une adresse email ne distingue pas les majuscules : `Gracie@test.fr` et
`gracie@test.fr` sont la même boîte. Mais la contrainte `UNIQUE` de PostgreSQL, elle, les
considère comme différentes. Sans normalisation, on pouvait créer deux comptes pour la même
adresse — je l'ai constaté en base. Je mets donc l'email en minuscules à l'inscription **et**
à la connexion, pour que les deux se retrouvent toujours.

**Q5 — Que se passait-il si le pseudo était déjà pris ?**
Le code ne vérifiait que l'email. Pour le pseudo, la base refusait l'enregistrement à cause
de la contrainte `UNIQUE`, l'erreur partait dans le `catch` général, et la personne recevait
« Erreur serveur » — un message qui ne l'aide pas du tout. J'ai ajouté la vérification du
pseudo avant l'insertion, plus un filet qui traduit le code `23505` de PostgreSQL au cas où
deux inscriptions arriveraient au même instant.

---

## 5. Ce que l'audit a trouvé, et ce qui a été corrigé

L'US 7 fonctionnait pour l'essentiel (20 crédits, bcrypt, rôle utilisateur), mais quatre
problèmes se cachaient derrière. Chacun a été **constaté avant correction** :

| Problème constaté | Avant | Après |
|---|---|---|
| **Pseudo déjà pris** | `500 Erreur serveur` | `400 Ce pseudo est déjà pris.` |
| **Email en majuscules** | `201` — un **2e compte créé** pour la même adresse | `400 Cet email est déjà utilisé.` |
| **Email invalide** (`pas-un-email`) | `201` — compte créé | `400 Cet email n'est pas valide.` |
| **Mot de passe sans caractère spécial** | `201` accepté | `400` refusé |

---

## 6. Ce qui a été vérifié

### Par de vrais appels HTTP

| Test | Résultat |
|---|---|
| Sans minuscule / majuscule / chiffre / caractère spécial | ✅ 400 (4 cas) |
| Trop court | ✅ 400 |
| Email invalide | ✅ 400 |
| Pseudo trop court | ✅ 400 |
| Pseudo déjà pris | ✅ 400 (plus de 500) |
| Email déjà pris | ✅ 400 |
| **Email en MAJUSCULES d'un compte existant** | ✅ 400 (plus de doublon) |
| **Pseudo en MAJUSCULES d'un compte existant** | ✅ 400 |
| Inscription valide (avec espaces et casse mélangée) | ✅ 201, `credits: 20` |
| Connexion avec une casse différente | ✅ 200 |
| **Tentative `{"credits":999,"role_id":3}`** | ✅ enregistré avec **20 crédits et rôle 1** |

### Dans un vrai navigateur

| Test | Résultat |
|---|---|
| Bandeau « 20 crédits offerts » | ✅ affiché |
| Texte d'aide à jour | ✅ « …une minuscule, une majuscule, un chiffre et un caractère spécial » |
| Mots de passe différents | ✅ « Les mots de passe ne correspondent pas. » |
| Mot de passe faible | ✅ bloqué **avant** l'envoi au serveur |
| Champs vides | ✅ « Merci de remplir tous les champs. » |
| Inscription complète | ✅ bascule sur l'onglet connexion, email pré-rempli |
| Connexion derrière | ✅ `profil.html`, 20 crédits, rôle 1 |

*(Tous les comptes de test ont été supprimés : la base est revenue à ses 7 comptes d'origine.)*
