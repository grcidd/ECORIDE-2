# US 12 — L'espace employé

## 1. Ce que fait la fonctionnalité, en 2 phrases

L'employé valide ou refuse les avis avant qu'ils n'apparaissent publiquement,
et il tranche les signalements laissés par les passagères.
C'est lui qui débloque — ou non — les crédits d'un chauffeur signalé :
sans sa décision, l'argent resterait bloqué pour toujours.

## 2. Le chemin complet, du bouton à la base

| Étape | Fichier | Détail |
|---|---|---|
| Page employé | `frontend/employe.html` | deux onglets : Avis / Signalements |
| Appel réseau | `frontend/js/api.js` | `apiProtegee()` ajoute le jeton JWT |
| Routes | `backend/routes/admin.routes.js` | `/api/admin/avis` et `/api/admin/signalements` |
| Contrôle du jeton | `backend/middleware/auth.middleware.js` | `authMiddleware` remplit `req.user` |
| Contrôle du rôle | idem | `checkRole([EMPLOYE, ADMIN])` |
| Contrôleur | `backend/controllers/admin.controller.js` | `getSignalements`, `traiterSignalement` |
| Base | fonction PostgreSQL `traiter_signalement` | `migration_v6.sql` |
| Tables | `participations`, `users` | `credits_verses`, `credits` |

## 3. D'où viennent les signalements ? De PostgreSQL, pas de MongoDB

C'est la décision la plus importante de cette US, et le jury peut la questionner.

Un signalement, c'est une ligne de `participations` où :

```sql
trajet_valide = FALSE         -- la passagère a dit « ça s'est mal passé »
signalement_traite_le IS NULL -- aucun employé n'a encore tranché
```

**Pourquoi pas MongoDB ?** Parce que c'est dans PostgreSQL que vit l'argent
(la colonne `credits_verses`). MongoDB ne garde qu'une copie pour les journaux.
Si on lisait la liste dans MongoDB et que MongoDB tombait, l'employé ne verrait
plus les signalements et les chauffeurs ne seraient jamais payés.
En lisant PostgreSQL, l'écran fonctionne tant que la base principale fonctionne.

### Et MongoDB dans tout ça ?

Quand une passagère signale un problème (US 11), l'application écrit le
signalement **dans les deux bases** : PostgreSQL (source de vérité) et MongoDB
(historique NoSQL). Quand l'employé tranche, `traiterSignalement` met aussi à
jour la copie MongoDB (`statut` passe de `en_attente` à `traite`).

Cette écriture MongoDB est dans un `try/catch` qui laisse passer : si MongoDB
est injoignable, la décision et le paiement sont **déjà** enregistrés dans
PostgreSQL. On ne bloque jamais une opération d'argent pour un historique.

## 4. La fonction principale, ligne par ligne

```sql
CREATE OR REPLACE FUNCTION traiter_signalement(
    p_participation_id INTEGER,
    p_employe_id INTEGER,   -- vient du jeton JWT, jamais du navigateur
    p_crediter BOOLEAN      -- TRUE = payer le chauffeur
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER          -- s'exécute avec les droits de son propriétaire
SET search_path = public  -- on fige le schéma : pas de redirection possible
AS $$
DECLARE
    v_participation participations%ROWTYPE;
    v_trajet        covoiturages%ROWTYPE;
    v_gain          INTEGER;
BEGIN
    -- On lit la participation ET on la verrouille.
    -- FOR UPDATE : deux employés qui cliquent en même temps passent
    -- l'un après l'autre, jamais en même temps.
    SELECT * INTO v_participation FROM participations
    WHERE participation_id = p_participation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SIGNALEMENT_INTROUVABLE';
    END IF;

    -- Est-ce bien un signalement ?
    -- NULL = pas encore répondu, TRUE = tout allait bien, FALSE = problème.
    IF v_participation.trajet_valide IS DISTINCT FROM FALSE THEN
        RAISE EXCEPTION 'PAS_UN_SIGNALEMENT';
    END IF;

    -- On ne tranche qu'une seule fois.
    IF v_participation.signalement_traite_le IS NOT NULL THEN
        RAISE EXCEPTION 'DEJA_TRAITE';
    END IF;

    SELECT * INTO v_trajet FROM covoiturages
    WHERE covoiturage_id = v_participation.covoiturage_id
    FOR UPDATE;

    IF p_crediter THEN
        -- L'employé donne raison au chauffeur : on le paie enfin.
        -- Même calcul que l'US 11 : le prix MOINS la commission.
        v_gain := v_trajet.prix_par_personne - v_trajet.credits_plateforme;
        IF v_gain < 0 THEN v_gain := 0; END IF;

        -- Garde-fou : on ne paie que si ça n'a jamais été fait.
        IF v_participation.credits_verses THEN
            v_gain := 0;
        ELSE
            UPDATE users SET credits = credits + v_gain
            WHERE user_id = v_trajet.chauffeur_id;
        END IF;

        UPDATE participations
        SET credits_verses = TRUE,
            signalement_traite_le = NOW(),
            signalement_decision = 'credite',
            signalement_employe_id = p_employe_id  -- qui a décidé
        WHERE participation_id = p_participation_id;

        RETURN json_build_object('decision','credite',
                                 'credits_verses_au_chauffeur', v_gain,
                                 'chauffeur_id', v_trajet.chauffeur_id);
    ELSE
        -- L'employé donne raison à la passagère : jamais payé.
        -- credits_verses reste FALSE, on note juste que c'est tranché.
        UPDATE participations
        SET signalement_traite_le = NOW(),
            signalement_decision = 'maintenu',
            signalement_employe_id = p_employe_id
        WHERE participation_id = p_participation_id;

        RETURN json_build_object('decision','maintenu',
                                 'credits_verses_au_chauffeur', 0,
                                 'chauffeur_id', v_trajet.chauffeur_id);
    END IF;
END;
$$;
```

Les deux `UPDATE` du cas « on paie » sont dans la **même fonction**, donc dans la
**même transaction** : soit le chauffeur est crédité **et** la décision est notée,
soit aucun des deux. On ne peut jamais payer quelqu'un sans en garder la trace.

## 5. Ce que j'ai vérifié, et avec quels chiffres

Trajet à 25 crédits, commission 2 → le chauffeur doit toucher 23.

| Test | Résultat |
|---|---|
| L'employé paie le chauffeur | emma_m **70 → 93** |
| L'employé confirme le problème | antoine_d **reste à 55**, `credits_verses` false |
| Deuxième traitement du même signalement | refusé `DEJA_TRAITE` |
| Participation qui n'est pas un signalement | refusé `PAS_UN_SIGNALEMENT` |
| Passagère n'ayant pas encore répondu | refusé `PAS_UN_SIGNALEMENT` |
| Identifiant inexistant | refusé `SIGNALEMENT_INTROUVABLE` |
| Simple utilisatrice sur `/api/admin/signalements` | **403 Accès interdit** |
| Simple utilisatrice sur `employe.html` | renvoyée vers son profil |

## 6. Cinq questions que le jury peut poser

**Q1 — Qui peut accéder à cet espace ?**
Seulement les rôles employé et administrateur. Deux contrôles, dans cet ordre :
`authMiddleware` vérifie le jeton JWT, puis `checkRole([EMPLOYE, ADMIN])` vérifie
le rôle. Le rôle vient du jeton signé par le serveur, jamais du navigateur.
Je l'ai testé : une simple utilisatrice reçoit `403 Accès interdit`.

**Q2 — Et si quelqu'un modifie le JavaScript de la page pour afficher l'écran ?**
Il verra une page vide. La page ne contient aucune donnée : elle les demande à
l'API, et c'est l'API qui refuse. La sécurité n'est jamais dans le navigateur.

**Q3 — Pourquoi lire les signalements dans PostgreSQL et pas dans MongoDB ?**
Parce que la décision déplace de l'argent, et que l'argent vit dans PostgreSQL.
Si MongoDB tombe, l'écran continuerait de fonctionner. MongoDB garde une copie
pour les journaux : c'est un complément, pas la source de vérité.

**Q4 — Comment empêchez-vous de payer deux fois le même chauffeur ?**
Par trois protections superposées : `FOR UPDATE` verrouille la ligne pendant la
décision, le test `signalement_traite_le IS NOT NULL` refuse une deuxième
décision, et la colonne `credits_verses` garde la trace du paiement.
Testé : au deuxième appel, l'API répond « Ce signalement a déjà été traité ».

**Q5 — Garde-t-on une trace de qui a décidé ?**
Oui, trois colonnes : `signalement_traite_le` (quand), `signalement_decision`
(`credite` ou `maintenu`) et `signalement_employe_id` (qui). Cet identifiant
vient de `req.user.user_id`, c'est-à-dire du jeton JWT : un employé ne peut pas
se faire passer pour un autre.
