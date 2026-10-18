-- ============================================
-- ECORIDE — Migration v4 : démarrer, terminer, valider (US 11)
--
-- À exécuter dans Supabase > SQL Editor, APRÈS migration_v3.sql.
-- Ne crée que des fonctions : aucune donnée n'est touchée.
-- Rejouable autant de fois qu'on veut.
--
-- LA RÈGLE CENTRALE DE L'US 11 :
-- le chauffeur n'est payé QUE lorsqu'un passager confirme que tout
-- s'est bien passé. Terminer le trajet ne paie rien.
-- ============================================


-- ============================================
-- 1. DÉMARRER LE TRAJET
-- ============================================
CREATE OR REPLACE FUNCTION demarrer_trajet(
    p_covoiturage_id INTEGER,
    p_chauffeur_id INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_trajet covoiturages%ROWTYPE;
BEGIN
    SELECT * INTO v_trajet FROM covoiturages
    WHERE covoiturage_id = p_covoiturage_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'TRAJET_INTROUVABLE';
    END IF;

    -- ⚠️ SÉCURITÉ : seul le chauffeur du trajet peut le démarrer
    IF v_trajet.chauffeur_id <> p_chauffeur_id THEN
        RAISE EXCEPTION 'PAS_TON_TRAJET';
    END IF;

    -- On ne démarre qu'un trajet prévu : ni déjà en route, ni fini, ni annulé.
    IF v_trajet.statut <> 'planifie' THEN
        RAISE EXCEPTION 'MAUVAIS_STATUT';
    END IF;

    UPDATE covoiturages SET statut = 'en_cours'
    WHERE covoiturage_id = p_covoiturage_id;

    RETURN json_build_object('statut', 'en_cours');
END;
$$;


-- ============================================
-- 2. ARRIVÉE À DESTINATION
--
-- ⚠️ CETTE FONCTION NE PAIE PERSONNE.
-- Elle renvoie la liste des passagers, pour que le serveur Node leur
-- envoie le mail les invitant à valider le trajet.
-- ============================================
CREATE OR REPLACE FUNCTION terminer_trajet(
    p_covoiturage_id INTEGER,
    p_chauffeur_id INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_trajet    covoiturages%ROWTYPE;
    v_passagers JSON;
BEGIN
    SELECT * INTO v_trajet FROM covoiturages
    WHERE covoiturage_id = p_covoiturage_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'TRAJET_INTROUVABLE';
    END IF;

    IF v_trajet.chauffeur_id <> p_chauffeur_id THEN
        RAISE EXCEPTION 'PAS_TON_TRAJET';
    END IF;

    -- On ne termine qu'un trajet en cours.
    -- Sans ce contrôle, on pouvait terminer deux fois le même trajet.
    IF v_trajet.statut <> 'en_cours' THEN
        RAISE EXCEPTION 'MAUVAIS_STATUT';
    END IF;

    -- La liste des passagers à prévenir par mail
    SELECT COALESCE(json_agg(json_build_object(
               'user_id', u.user_id,
               'pseudo',  u.pseudo,
               'email',   u.email
           )), '[]'::json)
      INTO v_passagers
      FROM participations p
      JOIN users u ON u.user_id = p.passager_id
     WHERE p.covoiturage_id = p_covoiturage_id
       AND p.statut = 'confirmee';

    UPDATE covoiturages SET statut = 'termine'
    WHERE covoiturage_id = p_covoiturage_id;

    -- Les participations passent de 'confirmee' à 'terminee'
    UPDATE participations SET statut = 'terminee'
    WHERE covoiturage_id = p_covoiturage_id
      AND statut = 'confirmee';

    RETURN json_build_object(
        'passagers', v_passagers,
        'ville_depart', v_trajet.ville_depart,
        'ville_arrivee', v_trajet.ville_arrivee,
        'date_depart', v_trajet.date_depart
    );
END;
$$;


-- ============================================
-- 3. LE PASSAGER VALIDE (ou signale un problème)
--
-- C'est ICI, et seulement ici, que le chauffeur est payé.
-- Il reçoit, pour CE passager : prix - credits_plateforme.
-- ============================================
CREATE OR REPLACE FUNCTION valider_trajet(
    p_covoiturage_id INTEGER,
    p_passager_id INTEGER,
    p_tout_ok BOOLEAN,
    p_commentaire TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_trajet        covoiturages%ROWTYPE;
    v_participation participations%ROWTYPE;
    v_gain          INTEGER;
BEGIN
    SELECT * INTO v_trajet FROM covoiturages
    WHERE covoiturage_id = p_covoiturage_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'TRAJET_INTROUVABLE';
    END IF;

    -- On ne valide qu'un trajet terminé.
    IF v_trajet.statut <> 'termine' THEN
        RAISE EXCEPTION 'TRAJET_NON_TERMINE';
    END IF;

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

    -- Ce que le chauffeur touche pour CE passager
    v_gain := v_trajet.prix_par_personne - v_trajet.credits_plateforme;
    IF v_gain < 0 THEN v_gain := 0; END IF;

    IF p_tout_ok THEN
        -- Tout s'est bien passé : on paie le chauffeur.
        UPDATE participations
        SET trajet_valide = TRUE,
            valide_le = NOW(),
            credits_verses = TRUE,
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


-- Vérification
SELECT 'Migration v4 terminée' AS resultat,
       (SELECT COUNT(*) FROM information_schema.routines
        WHERE routine_schema = 'public'
          AND routine_name IN ('demarrer_trajet','terminer_trajet','valider_trajet'))
         AS fonctions_presentes_sur_3;
