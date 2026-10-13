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
