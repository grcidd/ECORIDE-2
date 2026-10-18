# US 10 — Historique et annulation

## 1. Ce que ça fait, en 2 phrases

Chacun retrouve dans son espace la liste de ses covoiturages, en tant que chauffeur **et**
en tant que passager, avec le statut de chacun.
Un passager peut annuler sa réservation (ses crédits lui sont rendus et la place est
libérée), et un chauffeur peut annuler son trajet : **tous** ses passagers sont alors
remboursés et prévenus par e-mail.

---

## 2. Le chemin complet

### Annuler sa réservation (passager)

| Étape | Fichier | Ce qui se passe |
|---|---|---|
| 1. Le clic | `frontend/profil.html` | `annulerReservation()` + demande de confirmation |
| 2. L'URL | — | `DELETE /api/covoiturages/:id/participer` |
| 3. La route | `backend/routes/covoiturages.routes.js` | derrière `authMiddleware` |
| 4. Le controller | `backend/controllers/covoiturages.controller.js` | `annulerParticipation()` |
| 5. **La transaction** | PostgreSQL | fonction `annuler_participation` |

### Annuler son trajet (chauffeur)

| Étape | Fichier | Ce qui se passe |
|---|---|---|
| 1. Le clic | `frontend/profil.html` | `annulerTrajet()` + confirmation |
| 2. L'URL | — | `DELETE /api/covoiturages/:id` |
| 3. Le controller | `backend/controllers/covoiturages.controller.js` | `annulerTrajet()` |
| 4. **La transaction** | PostgreSQL | `annuler_trajet` rembourse tous les passagers |
| 5. **Les e-mails** | `backend/utils/mail.js` | `envoyerMails()` |

---

## 3. Le code principal, ligne par ligne

### Rembourser le bon montant

```sql
UPDATE users
SET credits = credits + v_participation.credits_utilises
WHERE user_id = p_passager_id;
```
On rembourse `credits_utilises`, c'est-à-dire **ce qui avait réellement été débité**, et
surtout **pas** le prix actuel du trajet. Si le chauffeur a changé son prix entre-temps, la
passagère doit récupérer exactement ce qu'elle a payé, ni plus ni moins.

### Libérer la place sans jamais dépasser

```sql
UPDATE covoiturages
SET nb_places_restantes = LEAST(nb_places_restantes + 1, nb_places_total)
WHERE covoiturage_id = p_covoiturage_id;
```
`LEAST` prend la plus petite des deux valeurs. C'est une sécurité : même en cas de problème,
on ne pourra jamais avoir plus de places libres que de places dans la voiture — ce que la
contrainte `CHECK` de la base refuserait de toute façon.

### Garder la trace

```sql
UPDATE participations
SET statut = 'annulee', annule_le = NOW()
WHERE participation_id = v_participation.participation_id;
```
On ne **supprime pas** la ligne : on la marque annulée. L'historique reste complet, et on
sait quand l'annulation a eu lieu.

### Rembourser tous les passagers d'un coup

```sql
UPDATE users u
SET credits = u.credits + p.credits_utilises
FROM participations p
WHERE p.covoiturage_id = p_covoiturage_id
  AND p.statut = 'confirmee'
  AND u.user_id = p.passager_id;
```
Une seule requête rembourse **tous** les passagers, chacun du montant qu'il avait payé.
C'est le `FROM participations p` qui relie les deux tables : pour chaque ligne de
participation, PostgreSQL trouve l'utilisateur correspondant et ajoute ses crédits.

Le filtre `statut = 'confirmee'` est important : quelqu'un qui avait **déjà annulé** sa
réservation a déjà été remboursé, il ne doit pas l'être une seconde fois. J'ai vérifié ce
cas précis : sur un trajet avec une annulation antérieure, cette personne n'a pas reçu de
deuxième remboursement.

### Renvoyer la liste des passagers, pour les mails

```sql
SELECT COALESCE(json_agg(json_build_object(
           'user_id', u.user_id, 'pseudo', u.pseudo,
           'email', u.email, 'credits_rembourses', p.credits_utilises
       )), '[]'::json)
  INTO v_passagers
  FROM participations p
  JOIN users u ON u.user_id = p.passager_id
 WHERE p.covoiturage_id = p_covoiturage_id
   AND p.statut = 'confirmee';
```
On construit la liste **avant** de les annuler : après, le filtre `statut = 'confirmee'` ne
trouverait plus personne. `COALESCE(..., '[]')` renvoie une liste vide plutôt que `null`
quand le trajet n'a aucun passager — comme ça le code JavaScript n'a pas de cas particulier
à gérer.

### La sécurité

```sql
IF v_trajet.chauffeur_id <> p_chauffeur_id THEN
    RAISE EXCEPTION 'PAS_TON_TRAJET';
END IF;
```
Seul le chauffeur du trajet peut l'annuler. Le `p_chauffeur_id` vient du **jeton**, jamais du
navigateur. Testé : connectée en gracie, j'ai essayé d'annuler le trajet de lisa, et j'ai
reçu un 403.

### Les e-mails qui ne font jamais échouer l'annulation

```js
const apercus = await envoyerMails(mails);
```
À ce stade, **l'annulation est déjà enregistrée en base**. Si l'envoi des mails échouait et
qu'on renvoyait une erreur, la personne croirait que rien ne s'est passé alors que tout est
fait. `envoyerMails()` ne lève donc jamais d'erreur : elle attrape tout et renvoie
simplement la liste des liens d'aperçu.

### Le compte de test Ethereal

```js
if (process.env.MAIL_HOST && process.env.MAIL_USER && process.env.MAIL_PASS) {
  // vrai serveur
}
const compte = await nodemailer.createTestAccount();
```
Si aucun serveur n'est configuré, Nodemailer crée tout seul une boîte de test. Les mails ne
partent chez personne, mais `nodemailer.getTestMessageUrl(info)` donne un **lien pour les
lire dans le navigateur**. Ce lien s'affiche dans la console du serveur **et** dans la page
après l'annulation : c'est ce qui permet de montrer les mails pendant la soutenance.

```js
let transporteur = null;
```
On garde le transporteur en mémoire. Sans ça, on créerait une nouvelle boîte de test à
chaque mail, et chacun atterrirait dans une boîte différente.

### Le retour à la ligne en HTML

```js
html: html || "<p>" + texte.replaceAll("\n", "<br>") + "</p>",
```
En HTML, un retour à la ligne du texte ne s'affiche pas : tout apparaîtrait collé sur une
seule ligne. Je l'ai constaté sur le premier mail envoyé, puis corrigé.

---

## 4. Cinq questions du jury, et les réponses

**Q1 — Pourquoi ne pas simplement supprimer la ligne quand on annule ?**
Parce que l'US 10 demande un **historique**. En gardant la ligne avec le statut `annulee` et
la date, la personne voit ce qu'elle a réservé puis annulé. Et pour les statistiques de
l'administrateur, on garde la trace de ce qui s'est passé.

**Q2 — Que se passe-t-il si quelqu'un réserve à nouveau un trajet qu'il avait annulé ?**
C'est le point délicat. La table interdit deux lignes pour le même couple (trajet, passager) :
une nouvelle réservation échouerait. J'ai donc modifié la fonction de réservation pour
qu'elle **réactive** la ligne annulée au lieu d'en créer une deuxième. Testé sur le cycle
complet : réserver, annuler, re-réserver — il reste toujours une seule ligne en base.

**Q3 — Pourquoi rembourser `credits_utilises` et pas le prix du trajet ?**
Parce que le chauffeur peut avoir changé son prix entre-temps. Si quelqu'un a payé 15 crédits
et que le prix est passé à 20, le rembourser au prix actuel lui ferait gagner 5 crédits. En
stockant ce qui a été réellement débité au moment de la réservation, le remboursement est
toujours juste.

**Q4 — Pourquoi l'envoi des mails ne peut-il pas faire échouer l'annulation ?**
Parce que l'annulation est déjà enregistrée quand on envoie les mails. Si je laissais l'erreur
remonter, le chauffeur verrait « Erreur serveur » alors que son trajet est bien annulé et ses
passagers remboursés — il risquerait de recommencer. Ma fonction d'envoi attrape donc toutes
les erreurs et se contente de les écrire dans la console.

**Q5 — Comment montrez-vous les mails sans vraie boîte mail ?**
J'utilise Ethereal, un service de test intégré à Nodemailer. Quand aucun serveur n'est
configuré, l'application crée automatiquement une boîte de test et renvoie un lien par mail
envoyé. Le lien s'affiche dans la console **et** dans la page. Si je remplis `MAIL_HOST`,
`MAIL_USER` et `MAIL_PASS` dans le `.env`, les mails partent pour de vrai sans changer une
ligne de code.

---

## 5. Ce qui a été vérifié

### Les transactions, dans un schéma de test isolé

| Vérification | Résultat |
|---|---|
| Annuler sa réservation | ✅ 15 crédits rendus, place libérée |
| Annuler deux fois | ✅ `DEJA_ANNULEE` |
| Annuler sans être inscrite | ✅ `PAS_INSCRIT` |
| Annuler sur un trajet terminé | ✅ `TROP_TARD` |
| **Annuler le trajet d'un autre chauffeur** | ✅ `PAS_TON_TRAJET` |
| Annuler un trajet déjà terminé | ✅ `TROP_TARD` |
| **Trajet avec 2 passagers** | ✅ les 2 remboursés, crédits exacts |
| **Quelqu'un ayant déjà annulé** | ✅ **pas remboursé une 2e fois** |
| Statut du trajet + date d'annulation | ✅ `annule`, date posée |
| Lignes conservées pour l'historique | ✅ 3 lignes, toutes `annulee` |
| **Cycle réserver → annuler → re-réserver** | ✅ toujours **une seule ligne** |

### Par de vrais appels HTTP

| Test | Résultat |
|---|---|
| Réserver puis annuler | ✅ 10 crédits rendus, 2 places libres |
| Annuler une 2e fois | ✅ 400 |
| Re-réserver après annulation | ✅ 200 |
| **gracie annule le trajet de lisa** | ✅ **403** |
| lisa annule son trajet | ✅ 1 passager remboursé + mail |
| Crédits en base | ✅ gracie 20, lisa 50 |

### Les e-mails (ouverts dans le navigateur)

| Vérification | Résultat |
|---|---|
| Lien d'aperçu généré | ✅ |
| Objet | ✅ « EcoRide — Ton covoiturage Lyon → Annecy a été annulé » |
| Destinataire | ✅ `gracie@test.fr` |
| Montant remboursé | ✅ « Tes 8 crédits t'ont été remboursés » |
| Date en français | ✅ « 4 novembre 2026 » |
| Retours à la ligne | ✅ (corrigé après le premier essai) |

### Dans un vrai navigateur

| Test | Résultat |
|---|---|
| Vue passagère | ✅ bouton sur la réservation active, badge sur les annulées |
| Confirmation avant d'annuler | ✅ |
| Annulation passagère | ✅ crédits 14 → 20, liste rafraîchie |
| Vue chauffeur | ✅ « ▶ Démarrer » + « Annuler le trajet » |
| Confirmation chauffeur | ✅ « Tous les passagers seront remboursés et prévenus » |
| **Lien « 📧 Voir le mail envoyé » dans la page** | ✅ |

*(Toutes les données de test supprimées : 6 trajets, 1 participation, 7 comptes, crédits d'origine.)*

---

## 6. Un bug corrigé au passage

La fonction qui affichait l'historique construisait ses lignes avec `innerHTML` en y
insérant les villes du trajet — qui sont saisies par les chauffeurs. C'était la **même faille
XSS** que celle corrigée aux US 3 et 5. Elle est maintenant construite en DOM, avec
`textContent` pour toutes les données venant de la base.
