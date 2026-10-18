-- ============================================
-- ECORIDE — migration_v6.sql
-- US 12 : l'espace employé traite les signalements
--
-- À exécuter dans Supabase > SQL Editor, APRÈS migration_v5.sql.
-- Ce fichier n'efface rien : il ne fait qu'AJOUTER des colonnes et une fonction.
-- ============================================
--
-- RAPPEL DU PROBLÈME QU'ON RÉSOUT (suite de l'US 11)
--
-- Quand une passagère dit « ça s'est mal passé », le chauffeur n'est PAS payé :
--   participations.trajet_valide  = FALSE
--   participations.credits_verses = FALSE
-- L'argent reste donc bloqué... pour toujours, parce que personne ne peut trancher.
--
-- L'US 12 donne ce pouvoir à l'employé : soit il donne raison au chauffeur
-- (et le chauffeur est enfin payé), soit il donne raison à la passagère
-- (et le chauffeur n'est jamais payé). Dans les deux cas, on garde la trace
-- de QUI a décidé et QUAND.
-- ============================================


-- --------------------------------------------
-- 1. GARDER LA TRACE DE LA DÉCISION DE L'EMPLOYÉ
--
-- Trois colonnes, toutes facultatives (NULL) :
-- tant qu'elles sont vides, le signalement est « à traiter ».
-- --------------------------------------------
ALTER TABLE participations
    ADD COLUMN IF NOT EXISTS signalement_traite_le TIMESTAMP,
    ADD COLUMN IF NOT EXISTS signalement_decision  VARCHAR(20),
    ADD COLUMN IF NOT EXISTS signalement_employe_id INTEGER REFERENCES users(user_id);

-- 'credite'  = l'employé a donné raison au chauffeur, il a été payé
-- 'maintenu' = l'employé a donné raison à la passagère, le chauffeur n'est pas payé
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'participations_decision_valide'
    ) THEN
        ALTER TABLE participations
            ADD CONSTRAINT participations_decision_valide
            CHECK (signalement_decision IS NULL
                   OR signalement_decision IN ('credite', 'maintenu'));
    END IF;
END $$;

-- La file d'attente de l'employé : les signalements pas encore traités.
-- Un index PARTIEL ne contient que ces lignes-là, donc il reste tout petit.
CREATE INDEX IF NOT EXISTS idx_participations_signalements_a_traiter
    ON participations (covoiturage_id)
 WHERE trajet_valide = FALSE AND signalement_traite_le IS NULL;


-- --------------------------------------------
-- 2. LA FONCTION QUI TRANCHE
--
-- Pourquoi une fonction PostgreSQL et pas du JavaScript ?
-- Parce que « payer le chauffeur » = plusieurs écritures qui doivent
-- réussir ENSEMBLE (créditer le compte ET noter qu'on l'a fait).
-- Une fonction s'exécute dans une seule transaction : tout ou rien.
--
-- SECURITY DEFINER : la fonction s'exécute avec les droits de son
-- propriétaire. SET search_path : on fige le schéma, personne ne peut
-- rediriger la fonction vers d'autres tables.
-- --------------------------------------------
CREATE OR REPLACE FUNCTION traiter_signalement(
    p_participation_id INTEGER,
    p_employe_id INTEGER,
    p_crediter BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_participation participations%ROWTYPE;
    v_trajet        covoiturages%ROWTYPE;
    v_gain          INTEGER;
BEGIN
    -- On lit la participation ET on la verrouille.
    -- FOR UPDATE = « personne d'autre ne touche à cette ligne tant que je n'ai pas fini ».
    -- Sans ça, deux employés qui cliquent en même temps paieraient deux fois.
    SELECT * INTO v_participation FROM participations
    WHERE participation_id = p_participation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SIGNALEMENT_INTROUVABLE';
    END IF;

    -- Est-ce bien un signalement ? (trajet_valide = FALSE)
    -- NULL = la passagère n'a pas encore répondu, TRUE = tout allait bien.
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

    IF NOT FOUND THEN
        RAISE EXCEPTION 'TRAJET_INTROUVABLE';
    END IF;

    IF p_crediter THEN
        -- L'employé donne raison au chauffeur : on le paie enfin.
        -- Même calcul que l'US 11 : le prix MOINS la commission de la plateforme.
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
            signalement_employe_id = p_employe_id
        WHERE participation_id = p_participation_id;

        RETURN json_build_object(
            'decision', 'credite',
            'credits_verses_au_chauffeur', v_gain,
            'chauffeur_id', v_trajet.chauffeur_id
        );
    ELSE
        -- L'employé donne raison à la passagère : le chauffeur n'est jamais payé.
        -- credits_verses reste FALSE, on note juste que c'est tranché.
        UPDATE participations
        SET signalement_traite_le = NOW(),
            signalement_decision = 'maintenu',
            signalement_employe_id = p_employe_id
        WHERE participation_id = p_participation_id;

        RETURN json_build_object(
            'decision', 'maintenu',
            'credits_verses_au_chauffeur', 0,
            'chauffeur_id', v_trajet.chauffeur_id
        );
    END IF;
END;
$$;


-- --------------------------------------------
-- 3. VÉRIFICATION — à lancer après coup.
-- --------------------------------------------
-- SELECT column_name FROM information_schema.columns
--  WHERE table_name = 'participations' AND column_name LIKE 'signalement%';
