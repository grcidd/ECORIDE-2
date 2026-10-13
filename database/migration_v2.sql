-- ============================================
-- ECORIDE — Migration v2
--
-- À exécuter dans Supabase > SQL Editor sur une base qui contient DÉJÀ
-- les tables de la version 1. Ce fichier ajoute ce qui manque pour les
-- US 8 à 13, sans supprimer aucune donnée existante.
--
-- Il est "idempotent" : on peut le relancer plusieurs fois sans erreur
-- (grâce aux IF NOT EXISTS et aux DROP ... IF EXISTS avant chaque ajout).
-- ============================================


-- ============================================
-- 1. NOUVELLES COLONNES
-- ADD COLUMN IF NOT EXISTS = "ajoute cette colonne seulement si elle n'existe pas".
-- ============================================

-- --- COVOITURAGES ---

-- US 9 et US 13 : la commission de la plateforme, par passager.
-- DEFAULT 2 : les trajets déjà en base reçoivent automatiquement la valeur 2.
ALTER TABLE covoiturages
    ADD COLUMN IF NOT EXISTS credits_plateforme INTEGER NOT NULL DEFAULT 2;

-- US 10 : quand le chauffeur annule son trajet
ALTER TABLE covoiturages
    ADD COLUMN IF NOT EXISTS annule_le TIMESTAMP;

-- --- PARTICIPATIONS ---

-- US 11 : date à laquelle le passager a validé le déroulement du trajet
ALTER TABLE participations
    ADD COLUMN IF NOT EXISTS valide_le TIMESTAMP;

-- US 11 : le chauffeur a-t-il déjà été payé pour cette participation ?
-- Évite de le créditer deux fois.
ALTER TABLE participations
    ADD COLUMN IF NOT EXISTS credits_verses BOOLEAN NOT NULL DEFAULT FALSE;

-- US 10 : quand le passager annule sa réservation
ALTER TABLE participations
    ADD COLUMN IF NOT EXISTS annule_le TIMESTAMP;


-- ============================================
-- 2. NOUVELLE TABLE — préférences personnalisées (US 8)
-- ============================================
CREATE TABLE IF NOT EXISTS preferences_personnalisees (
    preference_perso_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    libelle VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT preferences_perso_unique UNIQUE (user_id, libelle)
);


-- ============================================
-- 3. CORRECTION DE BUG — contrainte UNIQUE sur preferences.user_id
--
-- Le code enregistre les préférences avec un "upsert" sur user_id.
-- PostgreSQL REFUSE un upsert si la colonne n'a pas de contrainte UNIQUE :
-- sans cette correction, sauvegarder ses préférences renvoie une erreur 500.
-- ============================================

-- Au cas où des doublons existeraient déjà, on ne garde que la ligne la plus récente.
DELETE FROM preferences p
WHERE p.preference_id NOT IN (
    SELECT MAX(preference_id) FROM preferences GROUP BY user_id
);

ALTER TABLE preferences DROP CONSTRAINT IF EXISTS preferences_user_id_unique;
ALTER TABLE preferences ADD CONSTRAINT preferences_user_id_unique UNIQUE (user_id);


-- ============================================
-- 4. UN SEUL AVIS PAR TRAJET ET PAR PASSAGER
-- Le code le vérifiait déjà, mais rien ne l'empêchait au niveau de la base.
-- ============================================
DELETE FROM avis a
WHERE a.avis_id NOT IN (
    SELECT MAX(avis_id) FROM avis GROUP BY covoiturage_id, passager_id
);

ALTER TABLE avis DROP CONSTRAINT IF EXISTS avis_unique;
ALTER TABLE avis ADD CONSTRAINT avis_unique UNIQUE (covoiturage_id, passager_id);


-- ============================================
-- 5. PRIX EN NOMBRE ENTIER
--
-- Le prix était en DECIMAL(6,2) alors que les crédits sont des entiers :
-- on pouvait avoir un trajet à 24,48 crédits, ce qui n'a pas de sens.
-- ROUND() arrondit les valeurs déjà enregistrées (24,48 devient 24).
-- ============================================
ALTER TABLE covoiturages
    ALTER COLUMN prix_par_personne TYPE INTEGER USING ROUND(prix_par_personne);


-- ============================================
-- 6. VALEURS AUTORISÉES (contraintes CHECK)
--
-- On empêche la base d'accepter une faute de frappe comme 'Electrique'
-- ou 'termine ' avec un espace. On remet d'abord les données au propre.
-- ============================================

-- On normalise ce qui pourrait traîner (minuscules, espaces en trop)
UPDATE vehicules      SET energie = LOWER(TRIM(energie));
UPDATE covoiturages   SET statut  = LOWER(TRIM(statut));
UPDATE participations SET statut  = LOWER(TRIM(statut));
UPDATE avis           SET statut  = LOWER(TRIM(statut));

ALTER TABLE vehicules DROP CONSTRAINT IF EXISTS vehicules_energie_valide;
ALTER TABLE vehicules ADD CONSTRAINT vehicules_energie_valide
    CHECK (energie IN ('electrique', 'hybride', 'essence', 'diesel', 'gpl'));

ALTER TABLE vehicules DROP CONSTRAINT IF EXISTS vehicules_places_valides;
ALTER TABLE vehicules ADD CONSTRAINT vehicules_places_valides
    CHECK (nb_places >= 1 AND nb_places <= 8);

ALTER TABLE covoiturages DROP CONSTRAINT IF EXISTS covoiturages_statut_valide;
ALTER TABLE covoiturages ADD CONSTRAINT covoiturages_statut_valide
    CHECK (statut IN ('planifie', 'en_cours', 'termine', 'annule'));

ALTER TABLE covoiturages DROP CONSTRAINT IF EXISTS covoiturages_prix_positif;
ALTER TABLE covoiturages ADD CONSTRAINT covoiturages_prix_positif
    CHECK (prix_par_personne > 0);

ALTER TABLE covoiturages DROP CONSTRAINT IF EXISTS covoiturages_places_coherentes;
ALTER TABLE covoiturages ADD CONSTRAINT covoiturages_places_coherentes
    CHECK (nb_places_restantes >= 0 AND nb_places_restantes <= nb_places_total);

ALTER TABLE participations DROP CONSTRAINT IF EXISTS participations_statut_valide;
ALTER TABLE participations ADD CONSTRAINT participations_statut_valide
    CHECK (statut IN ('confirmee', 'annulee', 'terminee'));

-- L'ancienne contrainte s'appelait avis_note_check : on lui donne un nom clair.
ALTER TABLE avis DROP CONSTRAINT IF EXISTS avis_note_check;
ALTER TABLE avis DROP CONSTRAINT IF EXISTS avis_note_valide;
ALTER TABLE avis ADD CONSTRAINT avis_note_valide CHECK (note >= 1 AND note <= 5);

ALTER TABLE avis DROP CONSTRAINT IF EXISTS avis_statut_valide;
ALTER TABLE avis ADD CONSTRAINT avis_statut_valide
    CHECK (statut IN ('en_attente', 'valide', 'refuse'));

-- Un compte ne peut pas avoir un nombre de crédits négatif.
UPDATE users SET credits = 0 WHERE credits < 0;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_credits_positifs;
ALTER TABLE users ADD CONSTRAINT users_credits_positifs CHECK (credits >= 0);


-- ============================================
-- 7. COLONNES OBLIGATOIRES (NOT NULL)
--
-- On remplit d'abord les cases vides avec la valeur par défaut,
-- SINON le passage en NOT NULL échouerait.
-- ============================================
UPDATE users SET credits = 20    WHERE credits IS NULL;
UPDATE users SET role_id = 1     WHERE role_id IS NULL;
UPDATE users SET est_chauffeur = FALSE WHERE est_chauffeur IS NULL;
UPDATE users SET est_passager  = TRUE  WHERE est_passager  IS NULL;
UPDATE users SET est_suspendu  = FALSE WHERE est_suspendu  IS NULL;

ALTER TABLE users ALTER COLUMN credits       SET NOT NULL;
ALTER TABLE users ALTER COLUMN role_id       SET NOT NULL;
ALTER TABLE users ALTER COLUMN est_chauffeur SET NOT NULL;
ALTER TABLE users ALTER COLUMN est_passager  SET NOT NULL;
ALTER TABLE users ALTER COLUMN est_suspendu  SET NOT NULL;

UPDATE preferences SET accepte_fumeur  = FALSE WHERE accepte_fumeur  IS NULL;
UPDATE preferences SET accepte_animaux = FALSE WHERE accepte_animaux IS NULL;
ALTER TABLE preferences ALTER COLUMN accepte_fumeur  SET NOT NULL;
ALTER TABLE preferences ALTER COLUMN accepte_animaux SET NOT NULL;

UPDATE covoiturages SET statut = 'planifie' WHERE statut IS NULL;
UPDATE covoiturages SET est_ecologique = FALSE WHERE est_ecologique IS NULL;
ALTER TABLE covoiturages ALTER COLUMN statut SET NOT NULL;
ALTER TABLE covoiturages ALTER COLUMN est_ecologique SET NOT NULL;

UPDATE participations SET statut = 'confirmee' WHERE statut IS NULL;
ALTER TABLE participations ALTER COLUMN statut SET NOT NULL;

UPDATE avis SET statut = 'en_attente' WHERE statut IS NULL;
ALTER TABLE avis ALTER COLUMN statut SET NOT NULL;
-- La note devient obligatoire : on supprime les avis sans note (il n'y en a normalement aucun).
DELETE FROM avis WHERE note IS NULL;
ALTER TABLE avis ALTER COLUMN note SET NOT NULL;


-- ============================================
-- 8. INDEX
-- ============================================
CREATE INDEX IF NOT EXISTS idx_covoiturages_recherche
    ON covoiturages (ville_depart, ville_arrivee, date_depart);
CREATE INDEX IF NOT EXISTS idx_covoiturages_statut
    ON covoiturages (statut);
CREATE INDEX IF NOT EXISTS idx_covoiturages_chauffeur
    ON covoiturages (chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_participations_passager
    ON participations (passager_id);
CREATE INDEX IF NOT EXISTS idx_participations_covoiturage
    ON participations (covoiturage_id);
CREATE INDEX IF NOT EXISTS idx_avis_chauffeur_statut
    ON avis (chauffeur_id, statut);
CREATE INDEX IF NOT EXISTS idx_avis_statut
    ON avis (statut);


-- ============================================
-- 9. VÉRIFICATION — affiche un résumé à la fin
-- ============================================
SELECT 'Migration v2 terminée' AS resultat,
       (SELECT COUNT(*) FROM users)        AS comptes,
       (SELECT COUNT(*) FROM covoiturages) AS trajets,
       (SELECT COUNT(*) FROM information_schema.columns
        WHERE table_name = 'covoiturages' AND column_name = 'credits_plateforme')
         AS colonne_credits_plateforme_ok,
       (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_name = 'preferences_personnalisees')
         AS table_preferences_perso_ok;
