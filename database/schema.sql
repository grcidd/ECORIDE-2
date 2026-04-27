-- ============================================
-- ECORIDE — Script de création de la base de données
-- À exécuter dans Supabase > SQL Editor
-- ============================================


-- 1. TABLE DES ROLES
-- Stocke les rôles possibles : utilisateur, employé, administrateur
CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    libelle VARCHAR(50) NOT NULL UNIQUE  -- ex: 'utilisateur', 'employe', 'administrateur'
);


-- 2. TABLE DES UTILISATEURS
-- Contient tous les comptes : passagers, chauffeurs, employés, admins
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    pseudo VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,       -- mot de passe hashé avec bcrypt
    nom VARCHAR(50),
    prenom VARCHAR(50),
    telephone VARCHAR(20),
    photo VARCHAR(255),                   -- URL de la photo de profil
    credits INTEGER DEFAULT 20,           -- 20 crédits offerts à l'inscription
    role_id INTEGER DEFAULT 1 REFERENCES roles(role_id),  -- par défaut : utilisateur
    est_chauffeur BOOLEAN DEFAULT FALSE,
    est_passager BOOLEAN DEFAULT TRUE,
    est_suspendu BOOLEAN DEFAULT FALSE,   -- suspension par l'admin
    created_at TIMESTAMP DEFAULT NOW()
);


-- 3. TABLE DES VEHICULES
-- Un chauffeur peut avoir plusieurs véhicules
CREATE TABLE vehicules (
    vehicule_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    marque VARCHAR(50) NOT NULL,
    modele VARCHAR(50) NOT NULL,
    couleur VARCHAR(50),
    immatriculation VARCHAR(20) NOT NULL UNIQUE,
    date_premiere_immatriculation DATE,
    energie VARCHAR(50) NOT NULL,         -- 'electrique', 'essence', 'diesel', 'hybride'
    nb_places INTEGER NOT NULL,           -- nombre de places disponibles
    created_at TIMESTAMP DEFAULT NOW()
);


-- 4. TABLE DES PREFERENCES CHAUFFEUR
-- Fumeur/non-fumeur, animaux, + préférences personnalisées
CREATE TABLE preferences (
    preference_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    accepte_fumeur BOOLEAN DEFAULT FALSE,
    accepte_animaux BOOLEAN DEFAULT FALSE,
    preference_perso TEXT               -- texte libre pour les préférences custom
);


-- 5. TABLE DES COVOITURAGES
-- Un trajet proposé par un chauffeur
CREATE TABLE covoiturages (
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
    heure_arrivee TIME,
    duree_minutes INTEGER,               -- durée estimée du trajet
    prix_par_personne DECIMAL(6,2) NOT NULL,  -- prix fixé par le chauffeur
    nb_places_total INTEGER NOT NULL,
    nb_places_restantes INTEGER NOT NULL,
    statut VARCHAR(30) DEFAULT 'planifie', -- 'planifie', 'en_cours', 'termine', 'annule'
    est_ecologique BOOLEAN DEFAULT FALSE,  -- TRUE si véhicule électrique
    created_at TIMESTAMP DEFAULT NOW()
);


-- 6. TABLE DES PARTICIPATIONS
-- Enregistre qui a réservé quel trajet
CREATE TABLE participations (
    participation_id SERIAL PRIMARY KEY,
    covoiturage_id INTEGER NOT NULL REFERENCES covoiturages(covoiturage_id),
    passager_id INTEGER NOT NULL REFERENCES users(user_id),
    statut VARCHAR(30) DEFAULT 'confirmee',  -- 'confirmee', 'annulee', 'terminee'
    credits_utilises INTEGER NOT NULL,        -- crédits débités au moment de la réservation
    trajet_valide BOOLEAN DEFAULT NULL,       -- NULL = pas encore validé, TRUE/FALSE après le trajet
    commentaire_probleme TEXT,               -- si le passager signale un problème
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(covoiturage_id, passager_id)       -- un passager ne peut pas réserver 2 fois le même trajet
);


-- 7. TABLE DES AVIS
-- Notes et commentaires laissés sur les chauffeurs
CREATE TABLE avis (
    avis_id SERIAL PRIMARY KEY,
    covoiturage_id INTEGER NOT NULL REFERENCES covoiturages(covoiturage_id),
    passager_id INTEGER NOT NULL REFERENCES users(user_id),
    chauffeur_id INTEGER NOT NULL REFERENCES users(user_id),
    note INTEGER CHECK (note >= 1 AND note <= 5),   -- note de 1 à 5
    commentaire TEXT,
    statut VARCHAR(30) DEFAULT 'en_attente',  -- 'en_attente', 'valide', 'refuse'
    created_at TIMESTAMP DEFAULT NOW()
);


-- ============================================
-- INDEX utiles pour accélérer les recherches
-- ============================================

-- Recherche de trajets par ville et date (US3 — la fonctionnalité principale)
CREATE INDEX idx_covoiturages_recherche 
ON covoiturages(ville_depart, ville_arrivee, date_depart);

-- Recherche des trajets d'un chauffeur
CREATE INDEX idx_covoiturages_chauffeur 
ON covoiturages(chauffeur_id);

-- Recherche des participations d'un passager
CREATE INDEX idx_participations_passager 
ON participations(passager_id);