-- ============================================
-- ECORIDE — Migration v3 : les annulations (US 10)
--
-- À exécuter dans Supabase > SQL Editor, APRÈS migration_v2.sql.
-- Ce fichier ne crée que des fonctions : il ne touche à aucune donnée.
-- Il est rejouable autant de fois qu'on veut (CREATE OR REPLACE).
--
-- Pourquoi des fonctions PostgreSQL ? Parce qu'une annulation, c'est
-- plusieurs écritures qui vont ensemble (rembourser, libérer la place,
-- changer le statut). Une fonction s'exécute dans UNE SEULE TRANSACTION :
-- soit tout réussit, soit rien n'est appliqué.
-- ============================================


-- ============================================
-- 1. ANNULER SA PARTICIPATION (passager)
--
--    - on rembourse exactement ce qui avait été débité
--    - on libère la place
--    - on garde la ligne, avec le statut 'annulee' (pour l'historique)
-- ============================================
CREATE OR REPLACE FUNCTION annuler_participation(
    p_covoiturage_id INTEGER,
    p_passager_id INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_participation participations%ROWTYPE;
    v_trajet        covoiturages%ROWTYPE;
BEGIN
    -- On verrouille le trajet : personne d'autre ne le modifie pendant ce temps
    SELECT * INTO v_trajet FROM covoiturages
    WHERE covoiturage_id = p_covoiturage_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'TRAJET_INTROUVABLE';
    END IF;

    -- On ne peut plus annuler une fois le trajet commencé ou terminé
    IF v_trajet.statut <> 'planifie' THEN
        RAISE EXCEPTION 'TROP_TARD';
    END IF;

    SELECT * INTO v_participation FROM participations
    WHERE covoiturage_id = p_covoiturage_id
      AND passager_id = p_passager_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PAS_INSCRIT';
    END IF;

    IF v_participation.statut = 'annulee' THEN
        RAISE EXCEPTION 'DEJA_ANNULEE';
    END IF;

    -- 1) On rembourse EXACTEMENT ce qui avait été débité.
    --    On utilise credits_utilises, et pas le prix actuel du trajet :
    --    si le chauffeur a changé son prix entre-temps, la passagère doit
    --    récupérer ce qu'elle a réellement payé.
    UPDATE users
    SET credits = credits + v_participation.credits_utilises
    WHERE user_id = p_passager_id;

    -- 2) On libère la place (sans jamais dépasser le total)
    UPDATE covoiturages
    SET nb_places_restantes = LEAST(nb_places_restantes + 1, nb_places_total)
    WHERE covoiturage_id = p_covoiturage_id;

    -- 3) On garde la ligne pour l'historique, en la marquant annulée
    UPDATE participations
    SET statut = 'annulee', annule_le = NOW()
    WHERE participation_id = v_participation.participation_id;

    RETURN json_build_object(
        'credits_rembourses', v_participation.credits_utilises,
        'places_restantes', LEAST(v_trajet.nb_places_restantes + 1, v_trajet.nb_places_total)
    );
END;
$$;


-- ============================================
-- 2. ANNULER SON TRAJET (chauffeur)
--
--    - on rembourse TOUS les passagers confirmés
--    - on passe le trajet en 'annule'
--    - on renvoie la liste des passagers, pour que le serveur Node
--      puisse leur envoyer un mail
-- ============================================
CREATE OR REPLACE FUNCTION annuler_trajet(
    p_covoiturage_id INTEGER,
    p_chauffeur_id INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_trajet     covoiturages%ROWTYPE;
    v_passagers  JSON;
    v_total      INTEGER := 0;
BEGIN
    SELECT * INTO v_trajet FROM covoiturages
    WHERE covoiturage_id = p_covoiturage_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'TRAJET_INTROUVABLE';
    END IF;

    -- ⚠️ SÉCURITÉ : seul le chauffeur du trajet peut l'annuler.
    IF v_trajet.chauffeur_id <> p_chauffeur_id THEN
        RAISE EXCEPTION 'PAS_TON_TRAJET';
    END IF;

    IF v_trajet.statut <> 'planifie' THEN
        RAISE EXCEPTION 'TROP_TARD';
    END IF;

    -- On prépare la liste des passagers AVANT de les annuler,
    -- pour pouvoir la renvoyer au serveur Node (envoi des mails).
    SELECT COALESCE(json_agg(json_build_object(
               'user_id', u.user_id,
               'pseudo',  u.pseudo,
               'email',   u.email,
               'credits_rembourses', p.credits_utilises
           )), '[]'::json)
      INTO v_passagers
      FROM participations p
      JOIN users u ON u.user_id = p.passager_id
     WHERE p.covoiturage_id = p_covoiturage_id
       AND p.statut = 'confirmee';

    -- 1) On rembourse tous les passagers confirmés, d'un coup
    UPDATE users u
    SET credits = u.credits + p.credits_utilises
    FROM participations p
    WHERE p.covoiturage_id = p_covoiturage_id
      AND p.statut = 'confirmee'
      AND u.user_id = p.passager_id;

    GET DIAGNOSTICS v_total = ROW_COUNT;

    -- 2) On marque leurs participations comme annulées
    UPDATE participations
    SET statut = 'annulee', annule_le = NOW()
    WHERE covoiturage_id = p_covoiturage_id
      AND statut = 'confirmee';

    -- 3) On annule le trajet
    UPDATE covoiturages
    SET statut = 'annule', annule_le = NOW()
    WHERE covoiturage_id = p_covoiturage_id;

    RETURN json_build_object(
        'passagers_rembourses', v_total,
        'passagers', v_passagers,
        'ville_depart', v_trajet.ville_depart,
        'ville_arrivee', v_trajet.ville_arrivee,
        'date_depart', v_trajet.date_depart
    );
END;
$$;


-- ============================================
-- 3. MISE À JOUR DE LA RÉSERVATION (US 6)
--
-- Après une annulation, la ligne de participation reste en base avec le
-- statut 'annulee'. Comme la table interdit deux lignes pour le même couple
-- (trajet, passager), réserver à nouveau échouerait.
-- On réactive donc la ligne existante au lieu d'en créer une deuxième.
-- ============================================
CREATE OR REPLACE FUNCTION reserver_covoiturage(
    p_covoiturage_id INTEGER,
    p_passager_id INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_trajet        covoiturages%ROWTYPE;
    v_credits       INTEGER;
    v_participation participations%ROWTYPE;
BEGIN
    SELECT * INTO v_trajet FROM covoiturages
    WHERE covoiturage_id = p_covoiturage_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'TRAJET_INTROUVABLE';
    END IF;

    IF v_trajet.statut <> 'planifie' THEN
        RAISE EXCEPTION 'TRAJET_NON_RESERVABLE';
    END IF;

    IF v_trajet.chauffeur_id = p_passager_id THEN
        RAISE EXCEPTION 'PROPRE_TRAJET';
    END IF;

    IF v_trajet.nb_places_restantes <= 0 THEN
        RAISE EXCEPTION 'COMPLET';
    END IF;

    -- A-t-elle déjà une ligne pour ce trajet ?
    SELECT * INTO v_participation FROM participations
    WHERE covoiturage_id = p_covoiturage_id
      AND passager_id = p_passager_id;

    -- Oui, et elle n'est pas annulée : elle participe déjà.
    IF FOUND AND v_participation.statut <> 'annulee' THEN
        RAISE EXCEPTION 'DEJA_INSCRIT';
    END IF;

    SELECT credits INTO v_credits FROM users
    WHERE user_id = p_passager_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'UTILISATEUR_INTROUVABLE';
    END IF;

    IF v_credits < v_trajet.prix_par_personne THEN
        RAISE EXCEPTION 'CREDITS_INSUFFISANTS';
    END IF;

    IF v_participation.participation_id IS NOT NULL THEN
        -- Une ancienne réservation annulée existe : on la réactive.
        UPDATE participations
        SET statut = 'confirmee',
            credits_utilises = v_trajet.prix_par_personne,
            annule_le = NULL,
            trajet_valide = NULL,
            valide_le = NULL,
            commentaire_probleme = NULL,
            credits_verses = FALSE,
            created_at = NOW()
        WHERE participation_id = v_participation.participation_id;
    ELSE
        INSERT INTO participations (covoiturage_id, passager_id, credits_utilises, statut)
        VALUES (p_covoiturage_id, p_passager_id, v_trajet.prix_par_personne, 'confirmee');
    END IF;

    UPDATE users
    SET credits = credits - v_trajet.prix_par_personne
    WHERE user_id = p_passager_id;

    UPDATE covoiturages
    SET nb_places_restantes = nb_places_restantes - 1
    WHERE covoiturage_id = p_covoiturage_id;

    RETURN json_build_object(
        'credits_utilises', v_trajet.prix_par_personne,
        'credits_restants', v_credits - v_trajet.prix_par_personne,
        'places_restantes', v_trajet.nb_places_restantes - 1
    );
END;
$$;


-- Vérification
SELECT 'Migration v3 terminée' AS resultat,
       (SELECT COUNT(*) FROM information_schema.routines
        WHERE routine_schema = 'public'
          AND routine_name IN ('reserver_covoiturage','annuler_participation','annuler_trajet'))
         AS fonctions_presentes_sur_3;
