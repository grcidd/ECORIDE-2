-- ============================================
-- ECORIDE — Création complète de la base de données
--
-- À exécuter dans Supabase > SQL Editor, sur une base VIDE.
-- Si ta base contient déjà les tables, utilise migration_v2.sql à la place.
--
-- Ordre des tables : on crée d'abord celles qui ne dépendent de rien
-- (roles, users), puis celles qui pointent vers elles (clés étrangères).
-- ============================================


-- ============================================
-- 1. ROLES — les 3 types de comptes
-- ============================================
CREATE TABLE IF NOT EXISTS roles (
    role_id SERIAL PRIMARY KEY,
    libelle VARCHAR(50) NOT NULL UNIQUE   -- 'utilisateur', 'employe', 'administrateur'
);


-- ============================================
-- 2. USERS — tous les comptes
-- Un même compte peut être chauffeur ET passager (US 8).
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    user_id SERIAL PRIMARY KEY,
    pseudo VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,        -- mot de passe chiffré avec bcrypt, jamais en clair
    nom VARCHAR(50),
    prenom VARCHAR(50),
    telephone VARCHAR(20),
    photo VARCHAR(255),                    -- adresse de la photo de profil
    credits INTEGER NOT NULL DEFAULT 20,   -- US 7 : 20 crédits offerts à l'inscription
    role_id INTEGER NOT NULL DEFAULT 1 REFERENCES roles(role_id),
    est_chauffeur BOOLEAN NOT NULL DEFAULT FALSE,
    est_passager BOOLEAN NOT NULL DEFAULT TRUE,
    est_suspendu BOOLEAN NOT NULL DEFAULT FALSE,  -- US 13 : suspension par l'admin
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),

    -- On ne peut jamais descendre en dessous de 0 crédit.
    CONSTRAINT users_credits_positifs CHECK (credits >= 0)
);


-- ============================================
-- 3. VEHICULES — US 8
-- Un chauffeur peut en avoir plusieurs.
-- ============================================
CREATE TABLE IF NOT EXISTS vehicules (
    vehicule_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    marque VARCHAR(50) NOT NULL,
    modele VARCHAR(50) NOT NULL,
    couleur VARCHAR(50),
    immatriculation VARCHAR(20) NOT NULL UNIQUE,   -- une plaque = un seul véhicule
    date_premiere_immatriculation DATE,
    energie VARCHAR(50) NOT NULL,
    nb_places INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),

    -- On limite les valeurs possibles : une faute de frappe est refusée par la base.
    -- Important : c'est 'electrique' qui déclenche le badge écologique (US 3).
    CONSTRAINT vehicules_energie_valide
        CHECK (energie IN ('electrique', 'hybride', 'essence', 'diesel', 'gpl')),
    CONSTRAINT vehicules_places_valides
        CHECK (nb_places >= 1 AND nb_places <= 8)
);


-- ============================================
-- 4. PREFERENCES — US 8 (fumeur / animaux)
-- Une seule ligne par utilisateur.
-- ============================================
CREATE TABLE IF NOT EXISTS preferences (
    preference_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    accepte_fumeur BOOLEAN NOT NULL DEFAULT FALSE,
    accepte_animaux BOOLEAN NOT NULL DEFAULT FALSE,
    preference_perso TEXT,                 -- ancien champ texte libre, gardé pour compatibilité

    -- OBLIGATOIRE : le code fait un "upsert" sur user_id.
    -- Sans cette contrainte UNIQUE, l'enregistrement des préférences échoue.
    CONSTRAINT preferences_user_id_unique UNIQUE (user_id)
);


-- ============================================
-- 5. PREFERENCES_PERSONNALISEES — US 8
-- Table dédiée : un chauffeur peut ajouter autant de préférences
-- libres qu'il veut ("Pas de musique forte", "Pause toutes les 2h"...).
-- ============================================
CREATE TABLE IF NOT EXISTS preferences_personnalisees (
    preference_perso_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    libelle VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),

    -- Empêche d'enregistrer deux fois la même préférence.
    CONSTRAINT preferences_perso_unique UNIQUE (user_id, libelle)
);


-- ============================================
-- 6. COVOITURAGES — US 9
-- Un trajet proposé par un chauffeur.
-- ============================================
CREATE TABLE IF NOT EXISTS covoiturages (
    covoiturage_id SERIAL PRIMARY KEY,
    chauffeur_id INTEGER NOT NULL REFERENCES users(user_id),
    vehicule_id INTEGER NOT NULL REFERENCES vehicules(vehicule_id),
    ville_depart VARCHAR(100) NOT NULL,
    ville_arrivee VARCHAR(100) NOT NULL,
    adresse_depart VARCHAR(255),
    adresse_arrivee VARCHAR(255),
    date_depart DATE NOT NULL,
    heure_depart TIME NOT NULL,
    date_arrivee DATE,
    heure_arrivee TIME,                    -- US 3 et US 4 : sert à calculer la durée
    duree_minutes INTEGER,
    prix_par_personne INTEGER NOT NULL,    -- en crédits, donc un nombre entier
    nb_places_total INTEGER NOT NULL,
    nb_places_restantes INTEGER NOT NULL,
    statut VARCHAR(30) NOT NULL DEFAULT 'planifie',
    est_ecologique BOOLEAN NOT NULL DEFAULT FALSE,  -- vrai si le véhicule est électrique

    -- US 9 et US 13 : commission prélevée par la plateforme, par passager.
    -- Elle est figée à la création du trajet, pour que les statistiques
    -- restent justes même si le tarif de la plateforme change plus tard.
    credits_plateforme INTEGER NOT NULL DEFAULT 2,

    annule_le TIMESTAMP,                   -- US 10 : date d'annulation par le chauffeur
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT covoiturages_statut_valide
        CHECK (statut IN ('planifie', 'en_cours', 'termine', 'annule')),
    CONSTRAINT covoiturages_prix_positif
        CHECK (prix_par_personne > 0),
    -- Les places restantes ne peuvent ni être négatives, ni dépasser le total.
    CONSTRAINT covoiturages_places_coherentes
        CHECK (nb_places_restantes >= 0 AND nb_places_restantes <= nb_places_total)
);


-- ============================================
-- 7. PARTICIPATIONS — US 6, 10 et 11
-- Qui a réservé quel trajet.
-- ============================================
CREATE TABLE IF NOT EXISTS participations (
    participation_id SERIAL PRIMARY KEY,
    covoiturage_id INTEGER NOT NULL REFERENCES covoiturages(covoiturage_id),
    passager_id INTEGER NOT NULL REFERENCES users(user_id),
    statut VARCHAR(30) NOT NULL DEFAULT 'confirmee',
    credits_utilises INTEGER NOT NULL,     -- crédits débités au moment de la réservation

    -- US 11 : NULL = le passager n'a pas encore donné son avis sur le déroulement.
    -- TRUE = "tout s'est bien passé", FALSE = problème signalé.
    trajet_valide BOOLEAN,
    valide_le TIMESTAMP,                   -- quand le passager a validé
    commentaire_probleme TEXT,             -- US 11 : ce qu'il raconte si ça s'est mal passé

    -- US 11 : le chauffeur n'est payé QU'UNE FOIS, et seulement après validation.
    -- Ce drapeau évite de le créditer deux fois.
    credits_verses BOOLEAN NOT NULL DEFAULT FALSE,

    annule_le TIMESTAMP,                   -- US 10 : date d'annulation par le passager
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),

    -- Un passager ne peut pas réserver deux fois le même trajet.
    CONSTRAINT participations_unique UNIQUE (covoiturage_id, passager_id),
    CONSTRAINT participations_statut_valide
        CHECK (statut IN ('confirmee', 'annulee', 'terminee'))
);


-- ============================================
-- 8. AVIS — US 11 et 12
-- Note et commentaire laissés sur un chauffeur, après validation par un employé.
-- ============================================
CREATE TABLE IF NOT EXISTS avis (
    avis_id SERIAL PRIMARY KEY,
    covoiturage_id INTEGER NOT NULL REFERENCES covoiturages(covoiturage_id),
    passager_id INTEGER NOT NULL REFERENCES users(user_id),
    chauffeur_id INTEGER NOT NULL REFERENCES users(user_id),
    note INTEGER NOT NULL,
    commentaire TEXT,
    statut VARCHAR(30) NOT NULL DEFAULT 'en_attente',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT avis_note_valide CHECK (note >= 1 AND note <= 5),
    CONSTRAINT avis_statut_valide
        CHECK (statut IN ('en_attente', 'valide', 'refuse')),
    -- Un passager ne laisse qu'un seul avis par trajet.
    CONSTRAINT avis_unique UNIQUE (covoiturage_id, passager_id)
);


-- ============================================
-- INDEX — pour que les recherches restent rapides
--
-- Un index, c'est comme l'index d'un livre : au lieu de lire toutes
-- les pages, la base va directement à la bonne ligne.
-- ============================================

-- US 3 : la recherche principale (ville de départ + ville d'arrivée + date)
CREATE INDEX IF NOT EXISTS idx_covoiturages_recherche
    ON covoiturages (ville_depart, ville_arrivee, date_depart);

-- Filtrer sur le statut (on ne montre que les trajets 'planifie')
CREATE INDEX IF NOT EXISTS idx_covoiturages_statut
    ON covoiturages (statut);

-- Retrouver les trajets d'un chauffeur (US 10 : historique)
CREATE INDEX IF NOT EXISTS idx_covoiturages_chauffeur
    ON covoiturages (chauffeur_id);

-- Retrouver les réservations d'un passager (US 10 : historique)
CREATE INDEX IF NOT EXISTS idx_participations_passager
    ON participations (passager_id);

CREATE INDEX IF NOT EXISTS idx_participations_covoiturage
    ON participations (covoiturage_id);

-- US 3 : calcul de la note moyenne d'un chauffeur (avis validés uniquement)
CREATE INDEX IF NOT EXISTS idx_avis_chauffeur_statut
    ON avis (chauffeur_id, statut);

-- US 12 : la liste des avis en attente de modération
CREATE INDEX IF NOT EXISTS idx_avis_statut
    ON avis (statut);


-- ============================================
-- FONCTION DE RÉSERVATION (US 6)
--
-- Les 3 écritures d'une réservation (participation, débit des crédits,
-- place en moins) doivent réussir ensemble ou pas du tout.
-- Une fonction PostgreSQL s'exécute dans UNE SEULE TRANSACTION :
-- c'est elle qui donne cette garantie, pas le code Node.
--
-- Appelée depuis le serveur avec supabase.rpc("reserver_covoiturage", ...)
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
