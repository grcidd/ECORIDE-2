-- ============================================
-- ECORIDE — Données de test
-- ============================================

-- Insertion des rôles
INSERT INTO roles (libelle) VALUES 
    ('utilisateur'),
    ('employe'),
    ('administrateur');


-- Insertion des utilisateurs de test
-- ⚠️ Les mots de passe ci-dessous sont des hashs bcrypt
-- Mot de passe réel pour tous les comptes test : "Test1234!"

INSERT INTO users (pseudo, email, password, nom, prenom, credits, role_id, est_chauffeur, est_passager) VALUES
    -- Administrateur (role_id = 3)
    ('admin', 'admin@ecoride.fr', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Admin', 'EcoRide', 999, 3, FALSE, FALSE),
    
    -- Employé (role_id = 2)
    ('employe1', 'employe@ecoride.fr', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Martin', 'Sophie', 0, 2, FALSE, FALSE),

    -- Chauffeur (role_id = 1, est_chauffeur = true)
    ('lisa_drive', 'lisa@test.fr', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Dupont', 'Lisa', 50, 1, TRUE, TRUE),

    -- Passager (role_id = 1)
    ('gracie_p', 'gracie@test.fr', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Doure', 'Gracie', 20, 1, FALSE, TRUE);


-- Insertion d'un véhicule pour Lisa
INSERT INTO vehicules (user_id, marque, modele, couleur, immatriculation, date_premiere_immatriculation, energie, nb_places) VALUES
    (3, 'Tesla', 'Model 3', 'Blanc', 'AB-123-CD', '2022-03-15', 'electrique', 4);


-- Préférences de Lisa
INSERT INTO preferences (user_id, accepte_fumeur, accepte_animaux, preference_perso) VALUES
    (3, FALSE, TRUE, 'Musique calme acceptée. Ponctualité appréciée.');


-- Un covoiturage de test proposé par Lisa
INSERT INTO covoiturages (
    chauffeur_id, vehicule_id, ville_depart, ville_arrivee, 
    adresse_depart, adresse_arrivee,
    date_depart, heure_depart, date_arrivee, heure_arrivee, 
    duree_minutes, prix_par_personne, nb_places_total, nb_places_restantes, 
    est_ecologique
) VALUES (
    3, 1, 'Lyon', 'Paris',
    'Place Bellecour, Lyon', 'Gare de Lyon, Paris',
    '2025-07-15', '08:00', '2025-07-15', '12:00',
    240, 24.48, 3, 3,
    TRUE  -- Tesla = écologique ✅
);