-- ============================================
-- ECORIDE — US 6 : réserver une place
--
-- Cette fonction fait TOUT d'un bloc :
--   1. elle vérifie que la réservation est possible,
--   2. elle crée la participation,
--   3. elle débite les crédits du passager,
--   4. elle enlève une place au trajet.
--
-- Pourquoi une fonction PostgreSQL plutôt que 3 requêtes depuis Node ?
-- Parce qu'une fonction s'exécute dans UNE SEULE TRANSACTION : soit les
-- 3 écritures réussissent toutes, soit AUCUNE n'est appliquée.
-- Avec 3 requêtes séparées, une coupure réseau au milieu pouvait débiter
-- la passagère sans lui réserver sa place.
--
-- Appelée depuis Node avec : supabase.rpc("reserver_covoiturage", {...})
-- ============================================

CREATE OR REPLACE FUNCTION reserver_covoiturage(
    p_covoiturage_id INTEGER,
    p_passager_id INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
-- SECURITY DEFINER : la fonction s'exécute avec les droits de son propriétaire.
-- Elle continuera donc de fonctionner même si on active la sécurité RLS
-- sur les tables plus tard.
SECURITY DEFINER
-- On fige le chemin de recherche : sans ça, quelqu'un pourrait créer une
-- fausse table "users" dans un autre schéma pour détourner la fonction.
SET search_path = public
AS $$
DECLARE
    v_trajet   covoiturages%ROWTYPE;  -- une variable qui a la forme d'une ligne de covoiturages
    v_credits  INTEGER;
    v_existe   INTEGER;
BEGIN
    -- ----------------------------------------
    -- 1. On lit le trajet ET on le verrouille
    -- ----------------------------------------
    -- FOR UPDATE bloque la ligne jusqu'à la fin de la transaction.
    -- Si deux passagères cliquent sur la dernière place au même instant,
    -- la seconde attend que la première ait fini, puis voit qu'il n'y a
    -- plus de place. Sans ce verrou, les deux passeraient.
    SELECT * INTO v_trajet
    FROM covoiturages
    WHERE covoiturage_id = p_covoiturage_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'TRAJET_INTROUVABLE';
    END IF;

    -- ----------------------------------------
    -- 2. Les vérifications
    -- ----------------------------------------
    IF v_trajet.statut <> 'planifie' THEN
        RAISE EXCEPTION 'TRAJET_NON_RESERVABLE';
    END IF;

    IF v_trajet.chauffeur_id = p_passager_id THEN
        RAISE EXCEPTION 'PROPRE_TRAJET';
    END IF;

    IF v_trajet.nb_places_restantes <= 0 THEN
        RAISE EXCEPTION 'COMPLET';
    END IF;

    -- A-t-elle déjà réservé ce trajet ?
    SELECT COUNT(*) INTO v_existe
    FROM participations
    WHERE covoiturage_id = p_covoiturage_id
      AND passager_id = p_passager_id;

    IF v_existe > 0 THEN
        RAISE EXCEPTION 'DEJA_INSCRIT';
    END IF;

    -- On lit et verrouille aussi le compte de la passagère,
    -- pour que ses crédits ne bougent pas pendant qu'on travaille.
    SELECT credits INTO v_credits
    FROM users
    WHERE user_id = p_passager_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'UTILISATEUR_INTROUVABLE';
    END IF;

    IF v_credits < v_trajet.prix_par_personne THEN
        RAISE EXCEPTION 'CREDITS_INSUFFISANTS';
    END IF;

    -- ----------------------------------------
    -- 3. Les 3 écritures, dans la même transaction
    -- ----------------------------------------
    INSERT INTO participations (covoiturage_id, passager_id, credits_utilises, statut)
    VALUES (p_covoiturage_id, p_passager_id, v_trajet.prix_par_personne, 'confirmee');

    UPDATE users
    SET credits = credits - v_trajet.prix_par_personne
    WHERE user_id = p_passager_id;

    UPDATE covoiturages
    SET nb_places_restantes = nb_places_restantes - 1
    WHERE covoiturage_id = p_covoiturage_id;

    -- ----------------------------------------
    -- 4. On renvoie un résumé au serveur Node
    -- ----------------------------------------
    RETURN json_build_object(
        'credits_utilises', v_trajet.prix_par_personne,
        'credits_restants', v_credits - v_trajet.prix_par_personne,
        'places_restantes', v_trajet.nb_places_restantes - 1
    );

-- Si N'IMPORTE LAQUELLE des lignes ci-dessus échoue, PostgreSQL annule
-- automatiquement tout ce qui a été fait dans la fonction.
END;
$$;
