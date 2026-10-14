# US 11 — Démarrer un trajet, arriver, et valider

## 1. Ce que fait la fonctionnalité, en 2 phrases

Le chauffeur appuie sur **Démarrer** quand il part, puis sur **Arrivée à destination** quand il arrive :
chaque passager reçoit alors un e-mail lui demandant si tout s'est bien passé.
Le chauffeur n'est payé **que** lorsqu'un passager confirme ; si le passager signale un problème,
l'argent reste bloqué tant qu'un employé n'a pas tranché (US 12).

C'est le point le plus important de l'US : **l'argent ne bouge pas à la fin du trajet,
il bouge à la validation du passager.**

---

## 2. Le chemin complet, du bouton à la base

### a) Le chauffeur démarre
| Étape | Fichier | Détail |
|---|---|---|
| Bouton « ▶ Démarrer » | `frontend/profil.html` | fonction `demarrerTrajet()` |
| Appel réseau | `frontend/js/api.js` | `apiProtegee()` ajoute le jeton JWT |
| Route | `backend/routes/covoiturages.routes.js` | `PATCH /api/covoiturages/:id/demarrer` |
| Contrôle du jeton | `backend/middleware/auth.middleware.js` | remplit `req.user` |
| Contrôleur | `backend/controllers/covoiturages.controller.js` | `demarrer()` |
| Base | fonction PostgreSQL `demarrer_trajet` | `migration_v4.sql` |
| Table | `covoiturages` | `statut` passe de `planifie` à `en_cours` |

### b) Le chauffeur arrive
Même chemin, avec `PATCH /:id/terminer` → `terminer()` → fonction `terminer_trajet`.
`covoiturages.statut` passe à `termine`, **et personne n'est payé à ce moment-là**.
Le contrôleur envoie ensuite un e-mail à chaque passager (`backend/utils/mail.js`).

### c) Le passager répond
| Étape | Fichier | Détail |
|---|---|---|
| Boutons « Tout s'est bien passé » / « J'ai eu un problème » | `frontend/profil.html` | `creerLigneHistorique()` |
| Formulaire de signalement | `frontend/profil.html` | `afficherFormProbleme()` |
| Envoi | `frontend/profil.html` | `validerTrajet()` |
| Route | `backend/routes/covoiturages.routes.js` | `POST /api/covoiturages/:id/valider` |
| Contrôleur | `backend/controllers/covoiturages.controller.js` | `validerTrajet()` |
| Base (PostgreSQL) | fonction `valider_trajet` | `migration_v4.sql` |
| Tables touchées | `participations`, `users` | `trajet_valide`, `credits_verses`, `credits` |
| Base (MongoDB) | collection `signalements` | seulement si un problème est signalé |

---

## 3. La fonction principale, ligne par ligne

C'est la fonction PostgreSQL `valider_trajet` qui fait le vrai travail.
Elle est écrite dans `database/migration_v4.sql`.

**Pourquoi dans la base et pas en JavaScript ?**
Parce que payer le chauffeur, c'est plusieurs opérations qui doivent réussir **ensemble** :
marquer la participation comme validée **ET** ajouter les crédits **ET** noter qu'il a été payé.
Si le serveur Node tombe entre deux, on pourrait payer deux fois ou pas du tout.
Dans une fonction PostgreSQL, tout se fait dans une seule transaction : c'est tout ou rien.

```sql
CREATE OR REPLACE FUNCTION valider_trajet(
    p_covoiturage_id INTEGER,   -- quel trajet
    p_passager_id INTEGER,      -- qui répond (vient du jeton JWT, jamais du navigateur)
    p_tout_ok BOOLEAN,          -- TRUE = tout s'est bien passé
    p_commentaire TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER            -- la fonction s'exécute avec les droits de son propriétaire
SET search_path = public    -- on fige le schéma : personne ne peut rediriger la fonction
AS $$
DECLARE
    v_trajet        covoiturages%ROWTYPE;    -- une variable qui a la forme d'une ligne
    v_participation participations%ROWTYPE;
    v_gain          INTEGER;
BEGIN
    -- On lit le trajet ET on le verrouille.
    -- FOR UPDATE = "personne d'autre ne touche à cette ligne tant que je n'ai pas fini".
    SELECT * INTO v_trajet FROM covoiturages
    WHERE covoiturage_id = p_covoiturage_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'TRAJET_INTROUVABLE';   -- Node traduira ce code en phrase française
    END IF;

    -- On ne valide qu'un trajet terminé (pas un trajet encore en cours).
    IF v_trajet.statut <> 'termine' THEN
        RAISE EXCEPTION 'TRAJET_NON_TERMINE';
    END IF;

    -- On cherche la réservation de CE passager sur CE trajet, et on la verrouille aussi.
    -- Si elle n'existe pas, c'est que la personne n'a pas voyagé : on refuse.
    SELECT * INTO v_participation FROM participations
    WHERE covoiturage_id = p_covoiturage_id
      AND passager_id = p_passager_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PAS_INSCRIT';
    END IF;

    IF v_participation.statut = 'annulee' THEN
        RAISE EXCEPTION 'PARTICIPATION_ANNULEE';
    END IF;

    -- On ne valide qu'une seule fois.
    -- C'est ce contrôle qui empêche de payer le chauffeur deux fois.
    IF v_participation.trajet_valide IS NOT NULL THEN
        RAISE EXCEPTION 'DEJA_VALIDE';
    END IF;

    -- Un problème signalé doit être expliqué.
    IF NOT p_tout_ok AND (p_commentaire IS NULL OR TRIM(p_commentaire) = '') THEN
        RAISE EXCEPTION 'COMMENTAIRE_REQUIS';
    END IF;

    -- Ce que le chauffeur touche pour CE passager : le prix moins la commission.
    v_gain := v_trajet.prix_par_personne - v_trajet.credits_plateforme;
    IF v_gain < 0 THEN v_gain := 0; END IF;   -- sécurité : jamais un gain négatif

    IF p_tout_ok THEN
        -- Tout s'est bien passé : on paie le chauffeur.
        UPDATE participations
        SET trajet_valide = TRUE,
            valide_le = NOW(),
            credits_verses = TRUE,        -- la trace du paiement
            commentaire_probleme = NULL
        WHERE participation_id = v_participation.participation_id;

        UPDATE users SET credits = credits + v_gain
        WHERE user_id = v_trajet.chauffeur_id;

        RETURN json_build_object(
            'valide', TRUE,
            'credits_verses_au_chauffeur', v_gain,
            'credits_plateforme', v_trajet.credits_plateforme
        );
    ELSE
        -- Problème signalé : le chauffeur N'EST PAS payé.
        -- credits_verses reste FALSE. Un employé devra trancher (US 12).
        UPDATE participations
        SET trajet_valide = FALSE,
            valide_le = NOW(),
            credits_verses = FALSE,
            commentaire_probleme = TRIM(p_commentaire)
        WHERE participation_id = v_participation.participation_id;

        RETURN json_build_object(
            'valide', FALSE,
            'credits_verses_au_chauffeur', 0,
            'chauffeur_id', v_trajet.chauffeur_id,
            'commentaire', TRIM(p_commentaire)
        );
    END IF;
END;
$$;
```

Les deux `UPDATE` du cas « tout s'est bien passé » sont dans la **même fonction**,
donc dans la **même transaction** : soit la participation est marquée validée **et**
le chauffeur est crédité, soit aucun des deux. On ne peut jamais créditer
quelqu'un sans en garder la trace.

Côté Node, `validerTrajet()` ne fait que deux choses :
traduire les codes d'erreur (`DEJA_VALIDE`...) en phrases françaises,
et — en cas de problème seulement — écrire le signalement dans MongoDB.

**Point important :** si MongoDB est injoignable, on l'écrit dans la console mais
on ne renvoie pas d'erreur. Le chauffeur reste non payé de toute façon,
parce que cette information vit dans **PostgreSQL** (`credits_verses = false`),
pas dans MongoDB. MongoDB ne sert qu'à afficher la liste aux employés.

---

## 4. Ce que j'ai vérifié, et avec quels chiffres

Trajet de test à 12 crédits, commission de la plateforme à 2 → le chauffeur doit toucher 10.

| Moment | Crédits du chauffeur |
|---|---|
| Au départ | 50 |
| Après « Démarrer » | 50 |
| Après « Arrivée à destination » | **50** (personne n'est payé) |
| Après validation du passager | **60** |
| Deuxième clic sur validation | 60 (refusé : « Tu as déjà donné ton avis ») |

Et sur un deuxième trajet où le passager signale un problème :
le chauffeur **reste à son solde**, `trajet_valide` passe à `false`,
le commentaire est enregistré, `credits_verses` reste à `false`.

Les 7 cas de refus testés : `DEJA_VALIDE`, `MAUVAIS_STATUT` (deux fois),
`PAS_TON_TRAJET`, `TRAJET_NON_TERMINE`, `PAS_INSCRIT`, `COMMENTAIRE_REQUIS`.

---

## 5. Cinq questions que le jury peut poser

**Q1 — Pourquoi le chauffeur n'est-il pas payé dès qu'il arrive ?**
Parce que rien ne prouverait que le trajet a vraiment eu lieu correctement.
C'est le passager qui a l'information. Tant qu'il n'a pas confirmé, l'argent reste
chez la plateforme. C'est exactement la demande de l'US 11.

**Q2 — Comment empêchez-vous de payer deux fois le chauffeur ?**
Par trois protections qui se superposent.
D'abord `SELECT ... FOR UPDATE` qui verrouille la ligne, donc deux clics simultanés
passent l'un après l'autre et pas en même temps.
Ensuite le test `trajet_valide IS NOT NULL` qui refuse une deuxième réponse.
Enfin la colonne `credits_verses`, qui garde la trace du paiement.
Je l'ai vérifié : au deuxième appel, l'API répond « Tu as déjà donné ton avis sur ce trajet ».

**Q3 — Pourquoi mettre cette logique dans PostgreSQL plutôt qu'en JavaScript ?**
Parce que le client Supabase en JavaScript ne sait pas faire de transaction
sur plusieurs requêtes. Or payer le chauffeur, c'est trois écritures qui doivent
réussir ensemble. Une fonction PostgreSQL s'exécute dans une seule transaction :
soit tout passe, soit rien ne passe. Node appelle cette fonction avec `supabase.rpc()`.

**Q4 — Que se passe-t-il si MongoDB est en panne au moment d'un signalement ?**
Le passager reçoit quand même sa confirmation et le chauffeur reste non payé,
parce que cette information est dans PostgreSQL, pas dans MongoDB.
Seul l'affichage de la liste côté employé serait incomplet.
J'ai testé ce cas : l'API répond bien `200` avec `signalement_enregistre: false`.

**Q5 — Un passager pourrait-il valider le trajet de quelqu'un d'autre ?**
Non. Le serveur ne regarde jamais l'identité envoyée par le navigateur :
il prend `req.user.user_id`, qui vient du jeton JWT signé par le serveur.
Puis la fonction PostgreSQL cherche une participation qui correspond
à CE passager ET à CE trajet. Si elle n'existe pas, elle refuse avec `PAS_INSCRIT`.
Je l'ai testé en envoyant l'identifiant d'un autre passager :
la réponse est `403` avec le message « Tu n'as pas participé à ce trajet. ».
