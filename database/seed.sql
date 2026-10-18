-- ============================================
-- ECORIDE — Jeu de données de test
--
-- À exécuter APRÈS schema.sql (base neuve) ou APRÈS migration_v2.sql.
--
-- ⚠️ ATTENTION : ce fichier commence par EFFACER toutes les données
-- existantes, pour repartir d'une base propre et prévisible.
--
-- 👉 Si tu veux GARDER tes comptes personnels (grcidd, grcdtech,
--    employer_martin), utilise « seed_garde_mes_comptes.sql » à la place.
--    Ce fichier-ci efface absolument tout.
--
-- Mot de passe de TOUS les comptes : Test1234!
--
-- Les dates sont RELATIVES au jour où tu exécutes le fichier
-- (CURRENT_DATE + INTERVAL '...'), de -30 à +90 jours.
-- Il y aura donc toujours des trajets à venir le jour de la soutenance.
-- ============================================


-- --------------------------------------------
-- REMISE À ZÉRO
-- TRUNCATE vide les tables. CASCADE suit les liens entre tables.
-- RESTART IDENTITY remet les compteurs d'identifiants à 1.
-- --------------------------------------------
TRUNCATE TABLE avis, participations, covoiturages,
               preferences_personnalisees, preferences,
               vehicules, users, roles
         RESTART IDENTITY CASCADE;


-- --------------------------------------------
-- 1. LES 3 RÔLES
-- --------------------------------------------
INSERT INTO roles (role_id, libelle) VALUES
    (1, 'utilisateur'),
    (2, 'employe'),
    (3, 'administrateur');


-- --------------------------------------------
-- 2. LES COMPTES (30)
-- Mot de passe de tous : Test1234!
--
--   admin@ecoride.fr    → administrateur
--   employe@ecoride.fr  → employé
--   lisa@test.fr        → chauffeuse (Tesla, donc trajets écologiques)
--   gracie@test.fr      → passagère
-- --------------------------------------------
INSERT INTO users (user_id, pseudo, email, password, nom, prenom, telephone,
                   credits, role_id, est_chauffeur, est_passager) VALUES
    (1, 'admin', 'admin@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Admin', 'EcoRide', '0614857511', 999, 3, FALSE, FALSE),
    (2, 'employe1', 'employe@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Martin', 'Sophie', '0651846762', 0, 2, FALSE, FALSE),
    (3, 'lisa_drive', 'lisa@test.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Dupont', 'Lisa', '0680498733', 50, 1, TRUE, TRUE),
    (4, 'gracie_p', 'gracie@test.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Doure', 'Gracie', '0677584213', 20, 1, FALSE, TRUE),
    (5, 'thomas_b', 'thomas_b@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Bernard', 'Thomas', '0674082405', 15, 1, TRUE, TRUE),
    (6, 'julie_p', 'julie_p@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Petit', 'Julie', '0670247790', 25, 1, TRUE, TRUE),
    (7, 'max_r', 'max_r@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Robert', 'Maxime', '0681010270', 40, 1, TRUE, TRUE),
    (8, 'chloe_r', 'chloe_r@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Richard', 'Chloe', '0622935591', 40, 1, TRUE, TRUE),
    (9, 'antoine_d', 'antoine_d@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Durand', 'Antoine', '0666439753', 55, 1, TRUE, TRUE),
    (10, 'emma_m', 'emma_m@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Moreau', 'Emma', '0663659674', 70, 1, TRUE, TRUE),
    (11, 'hugo_l', 'hugo_l@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Laurent', 'Hugo', '0620417339', 15, 1, TRUE, TRUE),
    (12, 'lea_s', 'lea_s@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Simon', 'Lea', '0624109447', 20, 1, TRUE, TRUE),
    (13, 'nathan_m', 'nathan_m@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Michel', 'Nathan', '0651020839', 40, 1, TRUE, TRUE),
    (14, 'camille_l', 'camille_l@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Lefevre', 'Camille', '0663782093', 40, 1, TRUE, TRUE),
    (15, 'lucas_l', 'lucas_l@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Leroy', 'Lucas', '0641983382', 40, 1, TRUE, TRUE),
    (16, 'manon_r', 'manon_r@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Roux', 'Manon', '0657711000', 30, 1, TRUE, TRUE),
    (17, 'theo_d', 'theo_d@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'David', 'Theo', '0621223621', 70, 1, TRUE, TRUE),
    (18, 'sarah_b', 'sarah_b@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Bertrand', 'Sarah', '0620762256', 40, 1, TRUE, TRUE),
    (19, 'enzo_m', 'enzo_m@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Morel', 'Enzo', '0610673434', 40, 1, TRUE, TRUE),
    (20, 'ines_f', 'ines_f@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Fournier', 'Ines', '0634932905', 70, 1, TRUE, TRUE),
    (21, 'paul_g', 'paul_g@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Girard', 'Paul', '0613817462', 55, 1, FALSE, TRUE),
    (22, 'alice_b', 'alice_b@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Bonnet', 'Alice', '0642927294', 70, 1, FALSE, TRUE),
    (23, 'louis_d', 'louis_d@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Dupuis', 'Louis', '0678680664', 70, 1, FALSE, TRUE),
    (24, 'jade_l', 'jade_l@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Lambert', 'Jade', '0642250025', 30, 1, FALSE, TRUE),
    (25, 'noah_f', 'noah_f@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Fontaine', 'Noah', '0615225472', 70, 1, FALSE, TRUE),
    (26, 'zoe_r', 'zoe_r@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Rousseau', 'Zoe', '0616681913', 70, 1, FALSE, TRUE),
    (27, 'adam_v', 'adam_v@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Vincent', 'Adam', '0650991638', 40, 1, FALSE, TRUE),
    (28, 'eva_m', 'eva_m@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Muller', 'Eva', '0610752947', 30, 1, FALSE, TRUE),
    (29, 'gabin_f', 'gabin_f@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Faure', 'Gabin', '0694539529', 20, 1, FALSE, TRUE),
    (30, 'rose_a', 'rose_a@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Andre', 'Rose', '0637671495', 15, 1, FALSE, TRUE);


-- --------------------------------------------
-- 3. LES VÉHICULES (25, dont 9 électriques)
-- Seuls les véhicules électriques donnent le badge « écologique » (US 3).
-- --------------------------------------------
INSERT INTO vehicules (vehicule_id, user_id, marque, modele, couleur, immatriculation,
                       date_premiere_immatriculation, energie, nb_places) VALUES
    (1, 3, 'Tesla', 'Model 3', 'Blanc', 'AB-123-CD', CURRENT_DATE - INTERVAL '1400 days', 'electrique', 4),
    (2, 5, 'Renault', 'Zoe', 'Noir', 'CH-114-EF', CURRENT_DATE - INTERVAL '753 days', 'electrique', 4),
    (3, 5, 'Peugeot', 'e-208', 'Noir', 'DI-121-FG', CURRENT_DATE - INTERVAL '2141 days', 'electrique', 4),
    (4, 6, 'Nissan', 'Leaf', 'Argent', 'EJ-128-GH', CURRENT_DATE - INTERVAL '1587 days', 'electrique', 4),
    (5, 6, 'Hyundai', 'Kona Electric', 'Beige', 'FK-135-HI', CURRENT_DATE - INTERVAL '1330 days', 'electrique', 4),
    (6, 7, 'Kia', 'e-Niro', 'Vert', 'GL-142-IJ', CURRENT_DATE - INTERVAL '1841 days', 'electrique', 7),
    (7, 7, 'Fiat', '500e', 'Noir', 'HM-149-JK', CURRENT_DATE - INTERVAL '1694 days', 'electrique', 4),
    (8, 8, 'Volkswagen', 'ID.3', 'Rouge', 'IN-156-KL', CURRENT_DATE - INTERVAL '1478 days', 'electrique', 5),
    (9, 8, 'BMW', 'i3', 'Gris', 'JO-163-LM', CURRENT_DATE - INTERVAL '2665 days', 'electrique', 4),
    (10, 9, 'Toyota', 'Yaris Hybride', 'Blanc', 'KP-170-MN', CURRENT_DATE - INTERVAL '1810 days', 'hybride', 4),
    (11, 9, 'Toyota', 'Prius', 'Argent', 'LQ-177-NO', CURRENT_DATE - INTERVAL '2029 days', 'hybride', 4),
    (12, 10, 'Renault', 'Clio E-Tech', 'Beige', 'MR-184-OP', CURRENT_DATE - INTERVAL '2699 days', 'hybride', 5),
    (13, 10, 'Honda', 'Jazz Hybride', 'Argent', 'NS-191-PQ', CURRENT_DATE - INTERVAL '776 days', 'hybride', 5),
    (14, 11, 'Peugeot', '308', 'Beige', 'OT-198-QR', CURRENT_DATE - INTERVAL '2448 days', 'diesel', 4),
    (15, 11, 'Renault', 'Megane', 'Argent', 'PU-205-RS', CURRENT_DATE - INTERVAL '2401 days', 'diesel', 5),
    (16, 12, 'Citroen', 'C4', 'Bleu', 'QV-212-ST', CURRENT_DATE - INTERVAL '828 days', 'essence', 4),
    (17, 12, 'Volkswagen', 'Golf', 'Beige', 'RW-219-TU', CURRENT_DATE - INTERVAL '2225 days', 'essence', 4),
    (18, 13, 'Ford', 'Focus', 'Bleu', 'SX-226-UV', CURRENT_DATE - INTERVAL '799 days', 'diesel', 7),
    (19, 14, 'Opel', 'Astra', 'Argent', 'TY-233-VW', CURRENT_DATE - INTERVAL '2534 days', 'diesel', 4),
    (20, 15, 'Seat', 'Leon', 'Rouge', 'UF-240-WX', CURRENT_DATE - INTERVAL '2545 days', 'diesel', 7),
    (21, 16, 'Skoda', 'Octavia', 'Beige', 'VG-247-XY', CURRENT_DATE - INTERVAL '2073 days', 'diesel', 4),
    (22, 17, 'Dacia', 'Sandero', 'Rouge', 'WH-254-YD', CURRENT_DATE - INTERVAL '337 days', 'diesel', 4),
    (23, 18, 'Citroen', 'C3', 'Argent', 'XI-261-CE', CURRENT_DATE - INTERVAL '2441 days', 'essence', 5),
    (24, 19, 'Peugeot', '208', 'Bleu', 'YJ-268-DF', CURRENT_DATE - INTERVAL '1365 days', 'diesel', 7),
    (25, 20, 'Renault', 'Captur', 'Argent', 'ZK-275-EG', CURRENT_DATE - INTERVAL '2394 days', 'diesel', 5);


-- --------------------------------------------
-- 4. LES PRÉFÉRENCES DES CHAUFFEURS (US 8)
-- --------------------------------------------
INSERT INTO preferences (user_id, accepte_fumeur, accepte_animaux, preference_perso) VALUES
    (3, TRUE, TRUE, 'Discussion bienvenue !'),
    (5, FALSE, FALSE, 'Musique calme acceptee.'),
    (6, FALSE, FALSE, NULL),
    (7, FALSE, TRUE, NULL),
    (8, FALSE, TRUE, 'Discussion bienvenue !'),
    (9, FALSE, TRUE, 'Pause toutes les deux heures.'),
    (10, TRUE, TRUE, NULL),
    (11, FALSE, TRUE, 'Musique calme acceptee.'),
    (12, FALSE, FALSE, NULL),
    (13, FALSE, FALSE, NULL),
    (14, TRUE, FALSE, NULL),
    (15, TRUE, FALSE, 'Discussion bienvenue !'),
    (16, TRUE, TRUE, 'Discussion bienvenue !'),
    (17, FALSE, FALSE, 'Musique calme acceptee.'),
    (18, FALSE, TRUE, NULL),
    (19, FALSE, TRUE, NULL),
    (20, FALSE, FALSE, 'Musique calme acceptee.');


-- --------------------------------------------
-- 5. LES PRÉFÉRENCES PERSONNALISÉES (US 8)
-- Table dédiée : chaque chauffeur peut en ajouter autant qu'il veut.
-- --------------------------------------------
INSERT INTO preferences_personnalisees (user_id, libelle) VALUES
    (3, 'Depart a l''heure precise'),
    (3, 'Pas de nourriture dans la voiture'),
    (5, 'Coffre a skis possible'),
    (5, 'Arret pause toutes les 2h'),
    (5, 'Musique au choix du passager'),
    (6, 'Climatisation disponible'),
    (6, 'Depart a l''heure precise'),
    (7, 'Pas de nourriture dans la voiture'),
    (7, 'Arret pause toutes les 2h'),
    (8, 'Arret pause toutes les 2h'),
    (8, 'Coffre a skis possible'),
    (9, 'Bagage cabine uniquement'),
    (9, 'Arret pause toutes les 2h'),
    (10, 'Coffre a skis possible'),
    (10, 'Depart a l''heure precise'),
    (11, 'Musique au choix du passager'),
    (11, 'Coffre a skis possible'),
    (11, 'Depart a l''heure precise'),
    (12, 'Depart a l''heure precise'),
    (12, 'Bagage cabine uniquement'),
    (12, 'Musique au choix du passager'),
    (13, 'Bagage cabine uniquement'),
    (13, 'Depart a l''heure precise'),
    (13, 'Musique au choix du passager');


-- --------------------------------------------
-- 6. LES COVOITURAGES (206)
--
-- Dates RELATIVES : de -30 à +90 jours autour d'aujourd'hui.
-- Paris ↔ Lyon a plusieurs départs par jour, pour la démonstration.
--
-- statut : 'planifie' (à venir) · 'termine' (passé) · 'annule'
-- est_ecologique : TRUE si le véhicule est électrique
-- credits_plateforme : commission de la plateforme, par passager (US 9)
-- --------------------------------------------
INSERT INTO covoiturages (covoiturage_id, chauffeur_id, vehicule_id,
    ville_depart, ville_arrivee, adresse_depart, adresse_arrivee,
    date_depart, heure_depart, date_arrivee, heure_arrivee, duree_minutes,
    prix_par_personne, nb_places_total, nb_places_restantes,
    statut, est_ecologique, credits_plateforme) VALUES
    (1, 17, 22, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '7 days', '08:00', CURRENT_DATE - INTERVAL '7 days', '12:45', 285, 25, 3, 2, 'termine', FALSE, 2),
    (2, 18, 23, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '7 days', '08:00', CURRENT_DATE - INTERVAL '7 days', '12:45', 285, 25, 4, 4, 'termine', FALSE, 2),
    (3, 12, 17, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '7 days', '14:00', CURRENT_DATE - INTERVAL '7 days', '18:45', 285, 25, 3, 1, 'termine', FALSE, 2),
    (4, 17, 22, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '7 days', '14:00', CURRENT_DATE - INTERVAL '7 days', '18:45', 285, 25, 3, 2, 'termine', FALSE, 2),
    (5, 19, 24, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '6 days', '08:00', CURRENT_DATE - INTERVAL '6 days', '12:45', 285, 25, 4, 3, 'termine', FALSE, 2),
    (6, 8, 9, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '6 days', '08:00', CURRENT_DATE - INTERVAL '6 days', '12:45', 285, 25, 3, 0, 'termine', TRUE, 2),
    (7, 3, 1, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '6 days', '14:00', CURRENT_DATE - INTERVAL '6 days', '18:45', 285, 25, 3, 0, 'termine', TRUE, 2),
    (8, 10, 12, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '6 days', '14:00', CURRENT_DATE - INTERVAL '6 days', '18:45', 285, 25, 4, 0, 'termine', FALSE, 2),
    (9, 12, 17, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '5 days', '08:00', CURRENT_DATE - INTERVAL '5 days', '12:45', 285, 25, 3, 2, 'termine', FALSE, 2),
    (10, 19, 24, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '5 days', '08:00', CURRENT_DATE - INTERVAL '5 days', '12:45', 285, 25, 4, 3, 'termine', FALSE, 2),
    (11, 8, 9, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '5 days', '14:00', CURRENT_DATE - INTERVAL '5 days', '18:45', 285, 25, 3, 1, 'termine', TRUE, 2),
    (12, 8, 9, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '5 days', '14:00', CURRENT_DATE - INTERVAL '5 days', '18:45', 285, 25, 3, 3, 'termine', TRUE, 2),
    (13, 8, 8, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '4 days', '08:00', CURRENT_DATE - INTERVAL '4 days', '12:45', 285, 25, 4, 0, 'termine', TRUE, 2),
    (14, 16, 21, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '4 days', '08:00', CURRENT_DATE - INTERVAL '4 days', '12:45', 285, 25, 3, 2, 'annule', FALSE, 2),
    (15, 15, 20, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '4 days', '14:00', CURRENT_DATE - INTERVAL '4 days', '18:45', 285, 25, 4, 3, 'annule', FALSE, 2),
    (16, 14, 19, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '4 days', '14:00', CURRENT_DATE - INTERVAL '4 days', '18:45', 285, 25, 3, 0, 'termine', FALSE, 2),
    (17, 19, 24, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '3 days', '08:00', CURRENT_DATE - INTERVAL '3 days', '12:45', 285, 25, 4, 1, 'termine', FALSE, 2),
    (18, 8, 8, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '3 days', '08:00', CURRENT_DATE - INTERVAL '3 days', '12:45', 285, 25, 4, 2, 'termine', TRUE, 2),
    (19, 18, 23, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '3 days', '14:00', CURRENT_DATE - INTERVAL '3 days', '18:45', 285, 25, 4, 0, 'termine', FALSE, 2),
    (20, 16, 21, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '3 days', '14:00', CURRENT_DATE - INTERVAL '3 days', '18:45', 285, 25, 3, 1, 'termine', FALSE, 2),
    (21, 5, 2, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '2 days', '08:00', CURRENT_DATE - INTERVAL '2 days', '12:45', 285, 25, 3, 1, 'termine', TRUE, 2),
    (22, 19, 24, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '2 days', '08:00', CURRENT_DATE - INTERVAL '2 days', '12:45', 285, 25, 4, 4, 'termine', FALSE, 2),
    (23, 10, 12, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '2 days', '14:00', CURRENT_DATE - INTERVAL '2 days', '18:45', 285, 25, 4, 1, 'termine', FALSE, 2),
    (24, 16, 21, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '2 days', '14:00', CURRENT_DATE - INTERVAL '2 days', '18:45', 285, 25, 3, 3, 'termine', FALSE, 2),
    (25, 6, 5, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '1 days', '08:00', CURRENT_DATE - INTERVAL '1 days', '12:45', 285, 25, 3, 2, 'termine', TRUE, 2),
    (26, 9, 11, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '1 days', '08:00', CURRENT_DATE - INTERVAL '1 days', '12:45', 285, 25, 3, 3, 'termine', FALSE, 2),
    (27, 13, 18, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '1 days', '14:00', CURRENT_DATE - INTERVAL '1 days', '18:45', 285, 25, 4, 4, 'termine', FALSE, 2),
    (28, 19, 24, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '1 days', '14:00', CURRENT_DATE - INTERVAL '1 days', '18:45', 285, 25, 4, 4, 'termine', FALSE, 2),
    (29, 12, 16, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE, '07:00', CURRENT_DATE, '11:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (30, 3, 1, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE, '07:00', CURRENT_DATE, '11:45', 285, 25, 3, 3, 'planifie', TRUE, 2),
    (31, 14, 19, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE, '11:00', CURRENT_DATE, '15:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (32, 9, 10, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE, '11:00', CURRENT_DATE, '15:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (33, 15, 20, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE, '15:00', CURRENT_DATE, '19:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (34, 10, 13, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE, '15:00', CURRENT_DATE, '19:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (35, 7, 7, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE, '18:00', CURRENT_DATE, '22:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (36, 9, 10, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE, '18:00', CURRENT_DATE, '22:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (37, 9, 10, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '1 days', '07:00', CURRENT_DATE + INTERVAL '1 days', '11:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (38, 6, 5, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '1 days', '07:00', CURRENT_DATE + INTERVAL '1 days', '11:45', 285, 25, 3, 1, 'planifie', TRUE, 2),
    (39, 12, 17, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '1 days', '11:00', CURRENT_DATE + INTERVAL '1 days', '15:45', 285, 25, 3, 0, 'planifie', FALSE, 2),
    (40, 17, 22, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '1 days', '11:00', CURRENT_DATE + INTERVAL '1 days', '15:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (41, 5, 2, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '1 days', '15:00', CURRENT_DATE + INTERVAL '1 days', '19:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (42, 7, 6, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '1 days', '15:00', CURRENT_DATE + INTERVAL '1 days', '19:45', 285, 25, 4, 3, 'planifie', TRUE, 2),
    (43, 14, 19, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '1 days', '18:00', CURRENT_DATE + INTERVAL '1 days', '22:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (44, 5, 3, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '1 days', '18:00', CURRENT_DATE + INTERVAL '1 days', '22:45', 285, 25, 3, 1, 'planifie', TRUE, 2),
    (45, 18, 23, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '2 days', '07:00', CURRENT_DATE + INTERVAL '2 days', '11:45', 285, 25, 4, 1, 'planifie', FALSE, 2),
    (46, 15, 20, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '2 days', '07:00', CURRENT_DATE + INTERVAL '2 days', '11:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (47, 5, 3, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '2 days', '11:00', CURRENT_DATE + INTERVAL '2 days', '15:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (48, 14, 19, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '2 days', '11:00', CURRENT_DATE + INTERVAL '2 days', '15:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (49, 13, 18, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '2 days', '15:00', CURRENT_DATE + INTERVAL '2 days', '19:45', 285, 25, 4, 1, 'planifie', FALSE, 2),
    (50, 14, 19, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '2 days', '15:00', CURRENT_DATE + INTERVAL '2 days', '19:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (51, 7, 6, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '2 days', '18:00', CURRENT_DATE + INTERVAL '2 days', '22:45', 285, 25, 4, 1, 'planifie', TRUE, 2),
    (52, 5, 2, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '2 days', '18:00', CURRENT_DATE + INTERVAL '2 days', '22:45', 285, 25, 3, 3, 'planifie', TRUE, 2),
    (53, 13, 18, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '3 days', '07:00', CURRENT_DATE + INTERVAL '3 days', '11:45', 285, 25, 4, 1, 'planifie', FALSE, 2),
    (54, 15, 20, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '3 days', '07:00', CURRENT_DATE + INTERVAL '3 days', '11:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (55, 17, 22, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '3 days', '11:00', CURRENT_DATE + INTERVAL '3 days', '15:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (56, 3, 1, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '3 days', '11:00', CURRENT_DATE + INTERVAL '3 days', '15:45', 285, 25, 3, 1, 'planifie', TRUE, 2),
    (57, 11, 14, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '3 days', '15:00', CURRENT_DATE + INTERVAL '3 days', '19:45', 285, 25, 3, 0, 'planifie', FALSE, 2),
    (58, 19, 24, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '3 days', '15:00', CURRENT_DATE + INTERVAL '3 days', '19:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (59, 8, 8, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '3 days', '18:00', CURRENT_DATE + INTERVAL '3 days', '22:45', 285, 25, 4, 1, 'planifie', TRUE, 2),
    (60, 20, 25, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '3 days', '18:00', CURRENT_DATE + INTERVAL '3 days', '22:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (61, 5, 2, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '4 days', '07:00', CURRENT_DATE + INTERVAL '4 days', '11:45', 285, 25, 3, 1, 'planifie', TRUE, 2),
    (62, 19, 24, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '4 days', '07:00', CURRENT_DATE + INTERVAL '4 days', '11:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (63, 16, 21, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '4 days', '11:00', CURRENT_DATE + INTERVAL '4 days', '15:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (64, 12, 17, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '4 days', '11:00', CURRENT_DATE + INTERVAL '4 days', '15:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (65, 15, 20, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '4 days', '15:00', CURRENT_DATE + INTERVAL '4 days', '19:45', 285, 25, 4, 4, 'planifie', FALSE, 2),
    (66, 13, 18, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '4 days', '15:00', CURRENT_DATE + INTERVAL '4 days', '19:45', 285, 25, 4, 4, 'planifie', FALSE, 2),
    (67, 8, 9, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '4 days', '18:00', CURRENT_DATE + INTERVAL '4 days', '22:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (68, 20, 25, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '4 days', '18:00', CURRENT_DATE + INTERVAL '4 days', '22:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (69, 6, 5, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '5 days', '07:00', CURRENT_DATE + INTERVAL '5 days', '11:45', 285, 25, 3, 3, 'planifie', TRUE, 2),
    (70, 12, 16, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '5 days', '07:00', CURRENT_DATE + INTERVAL '5 days', '11:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (71, 3, 1, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '5 days', '11:00', CURRENT_DATE + INTERVAL '5 days', '15:45', 285, 25, 3, 3, 'planifie', TRUE, 2),
    (72, 13, 18, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '5 days', '11:00', CURRENT_DATE + INTERVAL '5 days', '15:45', 285, 25, 4, 4, 'planifie', FALSE, 2),
    (73, 20, 25, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '5 days', '15:00', CURRENT_DATE + INTERVAL '5 days', '19:45', 285, 25, 4, 1, 'planifie', FALSE, 2),
    (74, 6, 4, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '5 days', '15:00', CURRENT_DATE + INTERVAL '5 days', '19:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (75, 12, 17, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '5 days', '18:00', CURRENT_DATE + INTERVAL '5 days', '22:45', 285, 25, 3, 0, 'planifie', FALSE, 2),
    (76, 10, 12, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '5 days', '18:00', CURRENT_DATE + INTERVAL '5 days', '22:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (77, 13, 18, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '6 days', '07:00', CURRENT_DATE + INTERVAL '6 days', '11:45', 285, 25, 4, 4, 'planifie', FALSE, 2),
    (78, 10, 12, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '6 days', '07:00', CURRENT_DATE + INTERVAL '6 days', '11:45', 285, 25, 4, 4, 'planifie', FALSE, 2),
    (79, 17, 22, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '6 days', '11:00', CURRENT_DATE + INTERVAL '6 days', '15:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (80, 9, 10, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '6 days', '11:00', CURRENT_DATE + INTERVAL '6 days', '15:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (81, 8, 8, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '6 days', '15:00', CURRENT_DATE + INTERVAL '6 days', '19:45', 285, 25, 4, 0, 'planifie', TRUE, 2),
    (82, 7, 6, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '6 days', '15:00', CURRENT_DATE + INTERVAL '6 days', '19:45', 285, 25, 4, 1, 'planifie', TRUE, 2),
    (83, 15, 20, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '6 days', '18:00', CURRENT_DATE + INTERVAL '6 days', '22:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (84, 11, 14, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '6 days', '18:00', CURRENT_DATE + INTERVAL '6 days', '22:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (85, 19, 24, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '7 days', '07:00', CURRENT_DATE + INTERVAL '7 days', '11:45', 285, 25, 4, 1, 'planifie', FALSE, 2),
    (86, 16, 21, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '7 days', '07:00', CURRENT_DATE + INTERVAL '7 days', '11:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (87, 7, 7, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '7 days', '11:00', CURRENT_DATE + INTERVAL '7 days', '15:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (88, 7, 6, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '7 days', '11:00', CURRENT_DATE + INTERVAL '7 days', '15:45', 285, 25, 4, 4, 'planifie', TRUE, 2),
    (89, 15, 20, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '7 days', '15:00', CURRENT_DATE + INTERVAL '7 days', '19:45', 285, 25, 4, 0, 'planifie', FALSE, 2),
    (90, 6, 5, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '7 days', '15:00', CURRENT_DATE + INTERVAL '7 days', '19:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (91, 11, 14, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '7 days', '18:00', CURRENT_DATE + INTERVAL '7 days', '22:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (92, 14, 19, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '7 days', '18:00', CURRENT_DATE + INTERVAL '7 days', '22:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (93, 19, 24, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '8 days', '07:00', CURRENT_DATE + INTERVAL '8 days', '11:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (94, 18, 23, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '8 days', '07:00', CURRENT_DATE + INTERVAL '8 days', '11:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (95, 15, 20, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '8 days', '11:00', CURRENT_DATE + INTERVAL '8 days', '15:45', 285, 25, 4, 4, 'planifie', FALSE, 2),
    (96, 10, 12, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '8 days', '11:00', CURRENT_DATE + INTERVAL '8 days', '15:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (97, 17, 22, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '8 days', '15:00', CURRENT_DATE + INTERVAL '8 days', '19:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (98, 14, 19, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '8 days', '15:00', CURRENT_DATE + INTERVAL '8 days', '19:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (99, 12, 16, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '8 days', '18:00', CURRENT_DATE + INTERVAL '8 days', '22:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (100, 11, 15, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '8 days', '18:00', CURRENT_DATE + INTERVAL '8 days', '22:45', 285, 25, 4, 1, 'planifie', FALSE, 2),
    (101, 12, 17, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '9 days', '07:00', CURRENT_DATE + INTERVAL '9 days', '11:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (102, 16, 21, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '9 days', '07:00', CURRENT_DATE + INTERVAL '9 days', '11:45', 285, 25, 3, 0, 'planifie', FALSE, 2),
    (103, 14, 19, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '9 days', '11:00', CURRENT_DATE + INTERVAL '9 days', '15:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (104, 19, 24, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '9 days', '11:00', CURRENT_DATE + INTERVAL '9 days', '15:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (105, 5, 3, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '9 days', '15:00', CURRENT_DATE + INTERVAL '9 days', '19:45', 285, 25, 3, 1, 'planifie', TRUE, 2),
    (106, 12, 17, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '9 days', '15:00', CURRENT_DATE + INTERVAL '9 days', '19:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (107, 17, 22, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '9 days', '18:00', CURRENT_DATE + INTERVAL '9 days', '22:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (108, 14, 19, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '9 days', '18:00', CURRENT_DATE + INTERVAL '9 days', '22:45', 285, 25, 3, 0, 'planifie', FALSE, 2),
    (109, 11, 14, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '10 days', '07:00', CURRENT_DATE + INTERVAL '10 days', '11:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (110, 14, 19, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '10 days', '07:00', CURRENT_DATE + INTERVAL '10 days', '11:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (111, 20, 25, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '10 days', '11:00', CURRENT_DATE + INTERVAL '10 days', '15:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (112, 6, 4, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '10 days', '11:00', CURRENT_DATE + INTERVAL '10 days', '15:45', 285, 25, 3, 1, 'planifie', TRUE, 2),
    (113, 7, 6, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '10 days', '15:00', CURRENT_DATE + INTERVAL '10 days', '19:45', 285, 25, 4, 2, 'planifie', TRUE, 2),
    (114, 18, 23, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '10 days', '15:00', CURRENT_DATE + INTERVAL '10 days', '19:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (115, 13, 18, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '10 days', '18:00', CURRENT_DATE + INTERVAL '10 days', '22:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (116, 7, 6, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '10 days', '18:00', CURRENT_DATE + INTERVAL '10 days', '22:45', 285, 25, 4, 4, 'planifie', TRUE, 2),
    (117, 20, 25, 'Paris', 'Lille', 'Gare de Lyon', 'Place du General de Gaulle', CURRENT_DATE - INTERVAL '25 days', '08:00', CURRENT_DATE - INTERVAL '25 days', '10:10', 130, 15, 4, 3, 'termine', FALSE, 2),
    (118, 15, 20, 'Paris', 'Lille', 'Gare de Lyon', 'Place du General de Gaulle', CURRENT_DATE + INTERVAL '54 days', '13:00', CURRENT_DATE + INTERVAL '54 days', '15:10', 130, 14, 4, 3, 'planifie', FALSE, 2),
    (119, 12, 16, 'Paris', 'Lille', 'Gare de Lyon', 'Place du General de Gaulle', CURRENT_DATE + INTERVAL '32 days', '13:00', CURRENT_DATE + INTERVAL '32 days', '15:10', 130, 17, 3, 1, 'planifie', FALSE, 2),
    (120, 15, 20, 'Lille', 'Paris', 'Place du General de Gaulle', 'Gare de Lyon', CURRENT_DATE - INTERVAL '28 days', '16:00', CURRENT_DATE - INTERVAL '28 days', '18:10', 130, 17, 4, 3, 'termine', FALSE, 2),
    (121, 20, 25, 'Lille', 'Paris', 'Place du General de Gaulle', 'Gare de Lyon', CURRENT_DATE - INTERVAL '5 days', '13:00', CURRENT_DATE - INTERVAL '5 days', '15:10', 130, 14, 4, 4, 'termine', FALSE, 2),
    (122, 6, 5, 'Lille', 'Paris', 'Place du General de Gaulle', 'Gare de Lyon', CURRENT_DATE - INTERVAL '24 days', '14:00', CURRENT_DATE - INTERVAL '24 days', '16:10', 130, 17, 3, 0, 'termine', TRUE, 2),
    (123, 14, 19, 'Paris', 'Bordeaux', 'Gare de Lyon', 'Place de la Victoire', CURRENT_DATE + INTERVAL '79 days', '17:00', CURRENT_DATE + INTERVAL '79 days', '22:40', 340, 31, 3, 2, 'planifie', FALSE, 2),
    (124, 9, 11, 'Paris', 'Bordeaux', 'Gare de Lyon', 'Place de la Victoire', CURRENT_DATE + INTERVAL '16 days', '08:00', CURRENT_DATE + INTERVAL '16 days', '13:40', 340, 28, 3, 3, 'planifie', FALSE, 2),
    (125, 7, 6, 'Paris', 'Bordeaux', 'Gare de Lyon', 'Place de la Victoire', CURRENT_DATE + INTERVAL '36 days', '14:00', CURRENT_DATE + INTERVAL '36 days', '19:40', 340, 32, 4, 0, 'planifie', TRUE, 2),
    (126, 20, 25, 'Bordeaux', 'Paris', 'Place de la Victoire', 'Gare de Lyon', CURRENT_DATE, '09:00', CURRENT_DATE, '14:40', 340, 30, 4, 3, 'planifie', FALSE, 2),
    (127, 14, 19, 'Bordeaux', 'Paris', 'Place de la Victoire', 'Gare de Lyon', CURRENT_DATE + INTERVAL '69 days', '16:00', CURRENT_DATE + INTERVAL '69 days', '21:40', 340, 29, 3, 2, 'planifie', FALSE, 2),
    (128, 10, 12, 'Bordeaux', 'Paris', 'Place de la Victoire', 'Gare de Lyon', CURRENT_DATE + INTERVAL '38 days', '18:00', CURRENT_DATE + INTERVAL '38 days', '23:40', 340, 32, 4, 2, 'planifie', FALSE, 2),
    (129, 5, 2, 'Paris', 'Nantes', 'Gare de Lyon', 'Place du Commerce', CURRENT_DATE + INTERVAL '63 days', '08:00', CURRENT_DATE + INTERVAL '63 days', '12:00', 240, 21, 3, 2, 'planifie', TRUE, 2),
    (130, 12, 17, 'Paris', 'Nantes', 'Gare de Lyon', 'Place du Commerce', CURRENT_DATE + INTERVAL '90 days', '08:00', CURRENT_DATE + INTERVAL '90 days', '12:00', 240, 21, 3, 1, 'planifie', FALSE, 2),
    (131, 9, 10, 'Paris', 'Nantes', 'Gare de Lyon', 'Place du Commerce', CURRENT_DATE - INTERVAL '7 days', '06:00', CURRENT_DATE - INTERVAL '7 days', '10:00', 240, 25, 3, 3, 'termine', FALSE, 2),
    (132, 13, 18, 'Nantes', 'Paris', 'Place du Commerce', 'Gare de Lyon', CURRENT_DATE + INTERVAL '86 days', '17:00', CURRENT_DATE + INTERVAL '86 days', '21:00', 240, 20, 4, 1, 'planifie', FALSE, 2),
    (133, 14, 19, 'Nantes', 'Paris', 'Place du Commerce', 'Gare de Lyon', CURRENT_DATE + INTERVAL '29 days', '14:00', CURRENT_DATE + INTERVAL '29 days', '18:00', 240, 21, 3, 1, 'planifie', FALSE, 2),
    (134, 7, 7, 'Nantes', 'Paris', 'Place du Commerce', 'Gare de Lyon', CURRENT_DATE + INTERVAL '30 days', '06:00', CURRENT_DATE + INTERVAL '30 days', '10:00', 240, 20, 3, 3, 'planifie', TRUE, 2),
    (135, 3, 1, 'Paris', 'Strasbourg', 'Gare de Lyon', 'Place Kleber', CURRENT_DATE + INTERVAL '59 days', '10:00', CURRENT_DATE + INTERVAL '59 days', '14:50', 290, 26, 3, 1, 'planifie', TRUE, 2),
    (136, 9, 10, 'Paris', 'Strasbourg', 'Gare de Lyon', 'Place Kleber', CURRENT_DATE + INTERVAL '24 days', '14:00', CURRENT_DATE + INTERVAL '24 days', '18:50', 290, 25, 3, 2, 'planifie', FALSE, 2),
    (137, 17, 22, 'Paris', 'Strasbourg', 'Gare de Lyon', 'Place Kleber', CURRENT_DATE - INTERVAL '3 days', '13:00', CURRENT_DATE - INTERVAL '3 days', '17:50', 290, 25, 3, 2, 'termine', FALSE, 2),
    (138, 18, 23, 'Strasbourg', 'Paris', 'Place Kleber', 'Gare de Lyon', CURRENT_DATE + INTERVAL '60 days', '09:00', CURRENT_DATE + INTERVAL '60 days', '13:50', 290, 26, 4, 2, 'planifie', FALSE, 2),
    (139, 6, 5, 'Strasbourg', 'Paris', 'Place Kleber', 'Gare de Lyon', CURRENT_DATE + INTERVAL '64 days', '09:00', CURRENT_DATE + INTERVAL '64 days', '13:50', 290, 24, 3, 3, 'planifie', TRUE, 2),
    (140, 9, 10, 'Strasbourg', 'Paris', 'Place Kleber', 'Gare de Lyon', CURRENT_DATE + INTERVAL '58 days', '08:00', CURRENT_DATE + INTERVAL '58 days', '12:50', 290, 24, 3, 1, 'planifie', FALSE, 2),
    (141, 8, 9, 'Paris', 'Rennes', 'Gare de Lyon', 'Place de la Republique', CURRENT_DATE + INTERVAL '85 days', '14:00', CURRENT_DATE + INTERVAL '85 days', '17:35', 215, 18, 3, 2, 'planifie', TRUE, 2),
    (142, 20, 25, 'Paris', 'Rennes', 'Gare de Lyon', 'Place de la Republique', CURRENT_DATE + INTERVAL '20 days', '06:00', CURRENT_DATE + INTERVAL '20 days', '09:35', 215, 20, 4, 3, 'planifie', FALSE, 2),
    (143, 8, 8, 'Paris', 'Rennes', 'Gare de Lyon', 'Place de la Republique', CURRENT_DATE + INTERVAL '32 days', '08:00', CURRENT_DATE + INTERVAL '32 days', '11:35', 215, 18, 4, 4, 'planifie', TRUE, 2),
    (144, 5, 3, 'Rennes', 'Paris', 'Place de la Republique', 'Gare de Lyon', CURRENT_DATE + INTERVAL '18 days', '18:00', CURRENT_DATE + INTERVAL '18 days', '21:35', 215, 22, 3, 3, 'planifie', TRUE, 2),
    (145, 15, 20, 'Rennes', 'Paris', 'Place de la Republique', 'Gare de Lyon', CURRENT_DATE - INTERVAL '20 days', '16:00', CURRENT_DATE - INTERVAL '20 days', '19:35', 215, 20, 4, 2, 'termine', FALSE, 2),
    (146, 5, 2, 'Rennes', 'Paris', 'Place de la Republique', 'Gare de Lyon', CURRENT_DATE - INTERVAL '26 days', '07:00', CURRENT_DATE - INTERVAL '26 days', '10:35', 215, 21, 3, 3, 'termine', TRUE, 2),
    (147, 18, 23, 'Lyon', 'Marseille', 'Place Bellecour', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '42 days', '07:00', CURRENT_DATE + INTERVAL '42 days', '10:10', 190, 18, 4, 2, 'planifie', FALSE, 2),
    (148, 3, 1, 'Lyon', 'Marseille', 'Place Bellecour', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '84 days', '13:00', CURRENT_DATE + INTERVAL '84 days', '16:10', 190, 17, 3, 1, 'planifie', TRUE, 2),
    (149, 5, 2, 'Lyon', 'Marseille', 'Place Bellecour', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '38 days', '10:00', CURRENT_DATE + INTERVAL '38 days', '13:10', 190, 16, 3, 3, 'planifie', TRUE, 2),
    (150, 8, 9, 'Marseille', 'Lyon', 'Gare Saint-Charles', 'Place Bellecour', CURRENT_DATE - INTERVAL '15 days', '13:00', CURRENT_DATE - INTERVAL '15 days', '16:10', 190, 20, 3, 1, 'termine', TRUE, 2),
    (151, 11, 15, 'Marseille', 'Lyon', 'Gare Saint-Charles', 'Place Bellecour', CURRENT_DATE + INTERVAL '11 days', '16:00', CURRENT_DATE + INTERVAL '11 days', '19:10', 190, 20, 4, 3, 'planifie', FALSE, 2),
    (152, 11, 14, 'Marseille', 'Lyon', 'Gare Saint-Charles', 'Place Bellecour', CURRENT_DATE + INTERVAL '23 days', '06:00', CURRENT_DATE + INTERVAL '23 days', '09:10', 190, 18, 3, 1, 'planifie', FALSE, 2),
    (153, 16, 21, 'Lyon', 'Montpellier', 'Place Bellecour', 'Place de la Comedie', CURRENT_DATE + INTERVAL '45 days', '16:00', CURRENT_DATE + INTERVAL '45 days', '19:05', 185, 18, 3, 2, 'planifie', FALSE, 2),
    (154, 5, 3, 'Lyon', 'Montpellier', 'Place Bellecour', 'Place de la Comedie', CURRENT_DATE - INTERVAL '3 days', '14:00', CURRENT_DATE - INTERVAL '3 days', '17:05', 185, 19, 3, 2, 'termine', TRUE, 2),
    (155, 12, 17, 'Lyon', 'Montpellier', 'Place Bellecour', 'Place de la Comedie', CURRENT_DATE, '17:00', CURRENT_DATE, '20:05', 185, 17, 3, 3, 'planifie', FALSE, 2),
    (156, 20, 25, 'Montpellier', 'Lyon', 'Place de la Comedie', 'Place Bellecour', CURRENT_DATE - INTERVAL '27 days', '13:00', CURRENT_DATE - INTERVAL '27 days', '16:05', 185, 18, 4, 0, 'termine', FALSE, 2),
    (157, 10, 12, 'Montpellier', 'Lyon', 'Place de la Comedie', 'Place Bellecour', CURRENT_DATE + INTERVAL '42 days', '13:00', CURRENT_DATE + INTERVAL '42 days', '16:05', 185, 20, 4, 4, 'planifie', FALSE, 2),
    (158, 7, 7, 'Montpellier', 'Lyon', 'Place de la Comedie', 'Place Bellecour', CURRENT_DATE + INTERVAL '21 days', '07:00', CURRENT_DATE + INTERVAL '21 days', '10:05', 185, 20, 3, 1, 'planifie', TRUE, 2),
    (159, 12, 16, 'Lyon', 'Strasbourg', 'Place Bellecour', 'Place Kleber', CURRENT_DATE + INTERVAL '1 days', '09:00', CURRENT_DATE + INTERVAL '1 days', '13:50', 290, 24, 3, 2, 'planifie', FALSE, 2),
    (160, 5, 2, 'Lyon', 'Strasbourg', 'Place Bellecour', 'Place Kleber', CURRENT_DATE - INTERVAL '20 days', '10:00', CURRENT_DATE - INTERVAL '20 days', '14:50', 290, 25, 3, 0, 'termine', TRUE, 2),
    (161, 5, 3, 'Lyon', 'Strasbourg', 'Place Bellecour', 'Place Kleber', CURRENT_DATE + INTERVAL '85 days', '16:00', CURRENT_DATE + INTERVAL '85 days', '20:50', 290, 27, 3, 3, 'planifie', TRUE, 2),
    (162, 5, 2, 'Strasbourg', 'Lyon', 'Place Kleber', 'Place Bellecour', CURRENT_DATE + INTERVAL '29 days', '17:00', CURRENT_DATE + INTERVAL '29 days', '21:50', 290, 28, 3, 2, 'planifie', TRUE, 2),
    (163, 9, 10, 'Strasbourg', 'Lyon', 'Place Kleber', 'Place Bellecour', CURRENT_DATE - INTERVAL '24 days', '10:00', CURRENT_DATE - INTERVAL '24 days', '14:50', 290, 24, 3, 0, 'termine', FALSE, 2),
    (164, 5, 3, 'Strasbourg', 'Lyon', 'Place Kleber', 'Place Bellecour', CURRENT_DATE + INTERVAL '6 days', '18:00', CURRENT_DATE + INTERVAL '6 days', '22:50', 290, 28, 3, 1, 'planifie', TRUE, 2),
    (165, 20, 25, 'Marseille', 'Nice', 'Gare Saint-Charles', 'Promenade des Anglais', CURRENT_DATE + INTERVAL '83 days', '17:00', CURRENT_DATE + INTERVAL '83 days', '19:10', 130, 11, 4, 1, 'planifie', FALSE, 2),
    (166, 16, 21, 'Marseille', 'Nice', 'Gare Saint-Charles', 'Promenade des Anglais', CURRENT_DATE + INTERVAL '39 days', '13:00', CURRENT_DATE + INTERVAL '39 days', '15:10', 130, 11, 3, 1, 'planifie', FALSE, 2),
    (167, 6, 5, 'Marseille', 'Nice', 'Gare Saint-Charles', 'Promenade des Anglais', CURRENT_DATE - INTERVAL '29 days', '14:00', CURRENT_DATE - INTERVAL '29 days', '16:10', 130, 12, 3, 1, 'termine', TRUE, 2),
    (168, 10, 13, 'Nice', 'Marseille', 'Promenade des Anglais', 'Gare Saint-Charles', CURRENT_DATE - INTERVAL '9 days', '09:00', CURRENT_DATE - INTERVAL '9 days', '11:10', 130, 11, 4, 1, 'termine', FALSE, 2),
    (169, 15, 20, 'Nice', 'Marseille', 'Promenade des Anglais', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '29 days', '07:00', CURRENT_DATE + INTERVAL '29 days', '09:10', 130, 10, 4, 2, 'planifie', FALSE, 2),
    (170, 20, 25, 'Nice', 'Marseille', 'Promenade des Anglais', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '90 days', '18:00', CURRENT_DATE + INTERVAL '90 days', '20:10', 130, 15, 4, 4, 'planifie', FALSE, 2),
    (171, 14, 19, 'Marseille', 'Toulouse', 'Gare Saint-Charles', 'Place du Capitole', CURRENT_DATE + INTERVAL '81 days', '08:00', CURRENT_DATE + INTERVAL '81 days', '12:00', 240, 24, 3, 1, 'planifie', FALSE, 2),
    (172, 16, 21, 'Marseille', 'Toulouse', 'Gare Saint-Charles', 'Place du Capitole', CURRENT_DATE - INTERVAL '13 days', '06:00', CURRENT_DATE - INTERVAL '13 days', '10:00', 240, 25, 3, 3, 'termine', FALSE, 2),
    (173, 14, 19, 'Marseille', 'Toulouse', 'Gare Saint-Charles', 'Place du Capitole', CURRENT_DATE + INTERVAL '50 days', '14:00', CURRENT_DATE + INTERVAL '50 days', '18:00', 240, 24, 3, 3, 'planifie', FALSE, 2),
    (174, 12, 16, 'Toulouse', 'Marseille', 'Place du Capitole', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '45 days', '06:00', CURRENT_DATE + INTERVAL '45 days', '10:00', 240, 24, 3, 1, 'planifie', FALSE, 2),
    (175, 9, 11, 'Toulouse', 'Marseille', 'Place du Capitole', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '90 days', '10:00', CURRENT_DATE + INTERVAL '90 days', '14:00', 240, 23, 3, 1, 'planifie', FALSE, 2),
    (176, 9, 11, 'Toulouse', 'Marseille', 'Place du Capitole', 'Gare Saint-Charles', CURRENT_DATE - INTERVAL '27 days', '13:00', CURRENT_DATE - INTERVAL '27 days', '17:00', 240, 24, 3, 1, 'termine', FALSE, 2),
    (177, 9, 11, 'Bordeaux', 'Toulouse', 'Place de la Victoire', 'Place du Capitole', CURRENT_DATE + INTERVAL '55 days', '16:00', CURRENT_DATE + INTERVAL '55 days', '18:30', 150, 17, 3, 1, 'planifie', FALSE, 2),
    (178, 13, 18, 'Bordeaux', 'Toulouse', 'Place de la Victoire', 'Place du Capitole', CURRENT_DATE - INTERVAL '30 days', '18:00', CURRENT_DATE - INTERVAL '30 days', '20:30', 150, 15, 4, 2, 'termine', FALSE, 2),
    (179, 13, 18, 'Bordeaux', 'Toulouse', 'Place de la Victoire', 'Place du Capitole', CURRENT_DATE - INTERVAL '28 days', '16:00', CURRENT_DATE - INTERVAL '28 days', '18:30', 150, 15, 4, 0, 'termine', FALSE, 2),
    (180, 7, 6, 'Toulouse', 'Bordeaux', 'Place du Capitole', 'Place de la Victoire', CURRENT_DATE + INTERVAL '26 days', '18:00', CURRENT_DATE + INTERVAL '26 days', '20:30', 150, 12, 4, 4, 'planifie', TRUE, 2),
    (181, 16, 21, 'Toulouse', 'Bordeaux', 'Place du Capitole', 'Place de la Victoire', CURRENT_DATE + INTERVAL '73 days', '07:00', CURRENT_DATE + INTERVAL '73 days', '09:30', 150, 17, 3, 2, 'planifie', FALSE, 2),
    (182, 18, 23, 'Toulouse', 'Bordeaux', 'Place du Capitole', 'Place de la Victoire', CURRENT_DATE + INTERVAL '63 days', '10:00', CURRENT_DATE + INTERVAL '63 days', '12:30', 150, 14, 4, 3, 'planifie', FALSE, 2),
    (183, 3, 1, 'Bordeaux', 'Nantes', 'Place de la Victoire', 'Place du Commerce', CURRENT_DATE + INTERVAL '74 days', '08:00', CURRENT_DATE + INTERVAL '74 days', '11:20', 200, 17, 3, 3, 'planifie', TRUE, 2),
    (184, 14, 19, 'Bordeaux', 'Nantes', 'Place de la Victoire', 'Place du Commerce', CURRENT_DATE + INTERVAL '7 days', '14:00', CURRENT_DATE + INTERVAL '7 days', '17:20', 200, 18, 3, 1, 'planifie', FALSE, 2),
    (185, 14, 19, 'Bordeaux', 'Nantes', 'Place de la Victoire', 'Place du Commerce', CURRENT_DATE + INTERVAL '19 days', '08:00', CURRENT_DATE + INTERVAL '19 days', '11:20', 200, 20, 3, 3, 'planifie', FALSE, 2),
    (186, 16, 21, 'Nantes', 'Bordeaux', 'Place du Commerce', 'Place de la Victoire', CURRENT_DATE + INTERVAL '8 days', '17:00', CURRENT_DATE + INTERVAL '8 days', '20:20', 200, 20, 3, 2, 'planifie', FALSE, 2),
    (187, 13, 18, 'Nantes', 'Bordeaux', 'Place du Commerce', 'Place de la Victoire', CURRENT_DATE + INTERVAL '1 days', '08:00', CURRENT_DATE + INTERVAL '1 days', '11:20', 200, 20, 4, 2, 'planifie', FALSE, 2),
    (188, 17, 22, 'Nantes', 'Bordeaux', 'Place du Commerce', 'Place de la Victoire', CURRENT_DATE + INTERVAL '8 days', '08:00', CURRENT_DATE + INTERVAL '8 days', '11:20', 200, 22, 3, 2, 'planifie', FALSE, 2),
    (189, 5, 3, 'Nantes', 'Rennes', 'Place du Commerce', 'Place de la Republique', CURRENT_DATE + INTERVAL '51 days', '16:00', CURRENT_DATE + INTERVAL '51 days', '17:15', 75, 10, 3, 3, 'planifie', TRUE, 2),
    (190, 13, 18, 'Nantes', 'Rennes', 'Place du Commerce', 'Place de la Republique', CURRENT_DATE + INTERVAL '35 days', '13:00', CURRENT_DATE + INTERVAL '35 days', '14:15', 75, 9, 4, 3, 'planifie', FALSE, 2),
    (191, 15, 20, 'Nantes', 'Rennes', 'Place du Commerce', 'Place de la Republique', CURRENT_DATE + INTERVAL '72 days', '18:00', CURRENT_DATE + INTERVAL '72 days', '19:15', 75, 9, 4, 2, 'planifie', FALSE, 2),
    (192, 17, 22, 'Rennes', 'Nantes', 'Place de la Republique', 'Place du Commerce', CURRENT_DATE - INTERVAL '29 days', '14:00', CURRENT_DATE - INTERVAL '29 days', '15:15', 75, 9, 3, 2, 'termine', FALSE, 2),
    (193, 16, 21, 'Rennes', 'Nantes', 'Place de la Republique', 'Place du Commerce', CURRENT_DATE + INTERVAL '79 days', '09:00', CURRENT_DATE + INTERVAL '79 days', '10:15', 75, 9, 3, 1, 'planifie', FALSE, 2),
    (194, 9, 11, 'Rennes', 'Nantes', 'Place de la Republique', 'Place du Commerce', CURRENT_DATE - INTERVAL '17 days', '09:00', CURRENT_DATE - INTERVAL '17 days', '10:15', 75, 7, 3, 3, 'termine', FALSE, 2),
    (195, 20, 25, 'Montpellier', 'Toulouse', 'Place de la Comedie', 'Place du Capitole', CURRENT_DATE + INTERVAL '74 days', '08:00', CURRENT_DATE + INTERVAL '74 days', '10:30', 150, 14, 4, 1, 'planifie', FALSE, 2),
    (196, 16, 21, 'Montpellier', 'Toulouse', 'Place de la Comedie', 'Place du Capitole', CURRENT_DATE - INTERVAL '18 days', '07:00', CURRENT_DATE - INTERVAL '18 days', '09:30', 150, 13, 3, 2, 'termine', FALSE, 2),
    (197, 7, 7, 'Montpellier', 'Toulouse', 'Place de la Comedie', 'Place du Capitole', CURRENT_DATE + INTERVAL '51 days', '17:00', CURRENT_DATE + INTERVAL '51 days', '19:30', 150, 16, 3, 2, 'planifie', TRUE, 2),
    (198, 6, 5, 'Toulouse', 'Montpellier', 'Place du Capitole', 'Place de la Comedie', CURRENT_DATE + INTERVAL '84 days', '06:00', CURRENT_DATE + INTERVAL '84 days', '08:30', 150, 12, 3, 2, 'planifie', TRUE, 2),
    (199, 7, 6, 'Toulouse', 'Montpellier', 'Place du Capitole', 'Place de la Comedie', CURRENT_DATE + INTERVAL '50 days', '14:00', CURRENT_DATE + INTERVAL '50 days', '16:30', 150, 12, 4, 4, 'planifie', TRUE, 2),
    (200, 7, 6, 'Toulouse', 'Montpellier', 'Place du Capitole', 'Place de la Comedie', CURRENT_DATE + INTERVAL '13 days', '18:00', CURRENT_DATE + INTERVAL '13 days', '20:30', 150, 13, 4, 2, 'planifie', TRUE, 2),
    (201, 7, 7, 'Nice', 'Lyon', 'Promenade des Anglais', 'Place Bellecour', CURRENT_DATE + INTERVAL '26 days', '16:00', CURRENT_DATE + INTERVAL '26 days', '20:50', 290, 30, 3, 1, 'planifie', TRUE, 2),
    (202, 18, 23, 'Nice', 'Lyon', 'Promenade des Anglais', 'Place Bellecour', CURRENT_DATE - INTERVAL '19 days', '06:00', CURRENT_DATE - INTERVAL '19 days', '10:50', 290, 29, 4, 0, 'termine', FALSE, 2),
    (203, 18, 23, 'Nice', 'Lyon', 'Promenade des Anglais', 'Place Bellecour', CURRENT_DATE + INTERVAL '26 days', '16:00', CURRENT_DATE + INTERVAL '26 days', '20:50', 290, 25, 4, 1, 'planifie', FALSE, 2),
    (204, 17, 22, 'Lyon', 'Nice', 'Place Bellecour', 'Promenade des Anglais', CURRENT_DATE - INTERVAL '24 days', '14:00', CURRENT_DATE - INTERVAL '24 days', '18:50', 290, 26, 3, 1, 'termine', FALSE, 2),
    (205, 9, 10, 'Lyon', 'Nice', 'Place Bellecour', 'Promenade des Anglais', CURRENT_DATE + INTERVAL '24 days', '07:00', CURRENT_DATE + INTERVAL '24 days', '11:50', 290, 27, 3, 3, 'planifie', FALSE, 2),
    (206, 17, 22, 'Lyon', 'Nice', 'Place Bellecour', 'Promenade des Anglais', CURRENT_DATE + INTERVAL '47 days', '10:00', CURRENT_DATE + INTERVAL '47 days', '14:50', 290, 27, 3, 2, 'planifie', FALSE, 2);


-- --------------------------------------------
-- 7. LES PARTICIPATIONS (80)
--
-- trajet_valide : TRUE = « tout s'est bien passé » (US 11)
--                 FALSE = problème signalé → le chauffeur N'EST PAS payé
--                 NULL = le passager n'a pas encore validé
-- credits_verses : TRUE quand le chauffeur a été crédité (une seule fois)
-- --------------------------------------------
INSERT INTO participations (participation_id, covoiturage_id, passager_id, statut,
    credits_utilises, trajet_valide, valide_le, commentaire_probleme, credits_verses) VALUES
    (1, 25, 23, 'terminee', 25, TRUE, CURRENT_DATE, NULL, TRUE),
    (2, 13, 28, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '3 days', NULL, TRUE),
    (3, 13, 25, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '3 days', NULL, TRUE),
    (4, 13, 18, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '3 days', NULL, TRUE),
    (5, 122, 26, 'terminee', 17, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (6, 122, 13, 'terminee', 17, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (7, 122, 21, 'terminee', 17, NULL, NULL, NULL, FALSE),
    (8, 3, 9, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '6 days', NULL, TRUE),
    (9, 3, 4, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '6 days', NULL, TRUE),
    (10, 8, 13, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (11, 8, 7, 'terminee', 25, NULL, NULL, NULL, FALSE),
    (12, 8, 6, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (13, 11, 27, 'terminee', 25, FALSE, CURRENT_DATE - INTERVAL '4 days', 'Le chauffeur est arrive avec 45 minutes de retard sans prevenir.', FALSE),
    (14, 11, 16, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '4 days', NULL, TRUE),
    (15, 1, 28, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '6 days', NULL, TRUE),
    (16, 4, 21, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '6 days', NULL, TRUE),
    (17, 18, 13, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (18, 18, 7, 'terminee', 25, NULL, NULL, NULL, FALSE),
    (19, 204, 22, 'terminee', 26, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (20, 204, 16, 'terminee', 26, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (21, 145, 29, 'terminee', 20, TRUE, CURRENT_DATE - INTERVAL '19 days', NULL, TRUE),
    (22, 145, 7, 'terminee', 20, TRUE, CURRENT_DATE - INTERVAL '19 days', NULL, TRUE),
    (23, 150, 3, 'terminee', 20, TRUE, CURRENT_DATE - INTERVAL '14 days', NULL, TRUE),
    (24, 150, 6, 'terminee', 20, TRUE, CURRENT_DATE - INTERVAL '14 days', NULL, TRUE),
    (25, 192, 13, 'terminee', 9, TRUE, CURRENT_DATE - INTERVAL '28 days', NULL, TRUE),
    (26, 21, 30, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '1 days', NULL, TRUE),
    (27, 21, 21, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '1 days', NULL, TRUE),
    (28, 7, 25, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (29, 7, 7, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (30, 7, 16, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (31, 16, 21, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '3 days', NULL, TRUE),
    (32, 16, 15, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '3 days', NULL, TRUE),
    (33, 16, 10, 'terminee', 25, NULL, NULL, NULL, FALSE),
    (34, 10, 25, 'terminee', 25, NULL, NULL, NULL, FALSE),
    (35, 179, 14, 'terminee', 15, TRUE, CURRENT_DATE - INTERVAL '27 days', NULL, TRUE),
    (36, 179, 12, 'terminee', 15, TRUE, CURRENT_DATE - INTERVAL '27 days', NULL, TRUE),
    (37, 179, 7, 'terminee', 15, NULL, NULL, NULL, FALSE),
    (38, 137, 13, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (39, 9, 20, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '4 days', NULL, TRUE),
    (40, 163, 4, 'terminee', 24, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (41, 163, 15, 'terminee', 24, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (42, 163, 30, 'terminee', 24, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (43, 20, 29, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (44, 20, 15, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (45, 176, 24, 'terminee', 24, FALSE, CURRENT_DATE - INTERVAL '26 days', 'La voiture sentait tres fort la cigarette alors que l''annonce indiquait non-fumeur.', FALSE),
    (46, 176, 23, 'terminee', 24, TRUE, CURRENT_DATE - INTERVAL '26 days', NULL, TRUE),
    (47, 196, 6, 'terminee', 13, TRUE, CURRENT_DATE - INTERVAL '17 days', NULL, TRUE),
    (48, 154, 10, 'terminee', 19, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (49, 17, 14, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (50, 17, 8, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (51, 17, 15, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (52, 160, 10, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '19 days', NULL, TRUE),
    (53, 160, 23, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '19 days', NULL, TRUE),
    (54, 160, 21, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '19 days', NULL, TRUE),
    (55, 178, 29, 'terminee', 15, TRUE, CURRENT_DATE - INTERVAL '29 days', NULL, TRUE),
    (56, 178, 14, 'terminee', 15, TRUE, CURRENT_DATE - INTERVAL '29 days', NULL, TRUE),
    (57, 120, 12, 'terminee', 17, TRUE, CURRENT_DATE - INTERVAL '27 days', NULL, TRUE),
    (58, 23, 26, 'terminee', 25, FALSE, CURRENT_DATE - INTERVAL '1 days', 'Le chauffeur a change le lieu de depart au dernier moment, j''ai du payer un taxi.', FALSE),
    (59, 23, 5, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '1 days', NULL, TRUE),
    (60, 23, 24, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '1 days', NULL, TRUE),
    (61, 19, 28, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (62, 19, 15, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (63, 19, 20, 'terminee', 25, NULL, NULL, NULL, FALSE),
    (64, 167, 4, 'terminee', 12, TRUE, CURRENT_DATE - INTERVAL '28 days', NULL, TRUE),
    (65, 167, 20, 'terminee', 12, TRUE, CURRENT_DATE - INTERVAL '28 days', NULL, TRUE),
    (66, 156, 3, 'terminee', 18, TRUE, CURRENT_DATE - INTERVAL '26 days', NULL, TRUE),
    (67, 156, 25, 'terminee', 18, TRUE, CURRENT_DATE - INTERVAL '26 days', NULL, TRUE),
    (68, 156, 12, 'terminee', 18, TRUE, CURRENT_DATE - INTERVAL '26 days', NULL, TRUE),
    (69, 6, 16, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (70, 6, 3, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (71, 6, 9, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (72, 168, 3, 'terminee', 11, TRUE, CURRENT_DATE - INTERVAL '8 days', NULL, TRUE),
    (73, 168, 5, 'terminee', 11, NULL, NULL, NULL, FALSE),
    (74, 168, 4, 'terminee', 11, TRUE, CURRENT_DATE - INTERVAL '8 days', NULL, TRUE),
    (75, 117, 3, 'terminee', 15, TRUE, CURRENT_DATE - INTERVAL '24 days', NULL, TRUE),
    (76, 5, 22, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (77, 202, 4, 'terminee', 29, TRUE, CURRENT_DATE - INTERVAL '18 days', NULL, TRUE),
    (78, 202, 9, 'terminee', 29, TRUE, CURRENT_DATE - INTERVAL '18 days', NULL, TRUE),
    (79, 202, 28, 'terminee', 29, TRUE, CURRENT_DATE - INTERVAL '18 days', NULL, TRUE),
    (80, 53, 4, 'confirmee', 25, NULL, NULL, NULL, FALSE);


-- --------------------------------------------
-- 8. LES AVIS (32 : 22 validés, 10 en attente)
--
-- Seuls les avis 'valide' comptent dans la note affichée (US 3).
-- Les avis 'en_attente' alimentent l'espace employé (US 12).
-- --------------------------------------------
INSERT INTO avis (avis_id, covoiturage_id, passager_id, chauffeur_id,
                  note, commentaire, statut, created_at) VALUES
    (1, 25, 23, 6, 5, 'Excellent covoiturage, on a bien discute.', 'valide', CURRENT_DATE),
    (2, 13, 28, 8, 3, 'Voiture propre et confortable.', 'valide', CURRENT_DATE - INTERVAL '3 days'),
    (3, 13, 25, 8, 4, 'Trajet tres agreable, chauffeur ponctuel.', 'valide', CURRENT_DATE - INTERVAL '3 days'),
    (4, 122, 26, 6, 5, 'Excellent covoiturage, on a bien discute.', 'valide', CURRENT_DATE - INTERVAL '23 days'),
    (5, 3, 4, 12, 5, 'Trajet tres agreable, chauffeur ponctuel.', 'valide', CURRENT_DATE - INTERVAL '6 days'),
    (6, 4, 21, 17, 5, 'Excellent covoiturage, on a bien discute.', 'valide', CURRENT_DATE - INTERVAL '6 days'),
    (7, 18, 13, 8, 4, 'Excellent covoiturage, on a bien discute.', 'valide', CURRENT_DATE - INTERVAL '2 days'),
    (8, 145, 7, 15, 3, 'Ponctuel et sympathique, rien a redire.', 'valide', CURRENT_DATE - INTERVAL '19 days'),
    (9, 150, 3, 8, 5, 'Trajet tres agreable, chauffeur ponctuel.', 'valide', CURRENT_DATE - INTERVAL '14 days'),
    (10, 150, 6, 8, 5, 'Tout s''est bien passe, merci beaucoup.', 'valide', CURRENT_DATE - INTERVAL '14 days'),
    (11, 21, 21, 5, 5, 'Ponctuel et sympathique, rien a redire.', 'valide', CURRENT_DATE - INTERVAL '1 days'),
    (12, 7, 25, 3, 5, 'Conduite souple et bonne ambiance.', 'valide', CURRENT_DATE - INTERVAL '5 days'),
    (13, 7, 16, 3, 3, 'Trajet tres agreable, chauffeur ponctuel.', 'valide', CURRENT_DATE - INTERVAL '5 days'),
    (14, 16, 15, 14, 3, 'Super voyage, je recommande !', 'valide', CURRENT_DATE - INTERVAL '3 days'),
    (15, 179, 12, 13, 5, 'Tout s''est bien passe, merci beaucoup.', 'valide', CURRENT_DATE - INTERVAL '27 days'),
    (16, 137, 13, 17, 5, 'Parfait du debut a la fin.', 'valide', CURRENT_DATE - INTERVAL '2 days'),
    (17, 9, 20, 12, 4, 'Tout s''est bien passe, merci beaucoup.', 'valide', CURRENT_DATE - INTERVAL '4 days'),
    (18, 163, 30, 9, 5, 'Voiture propre et confortable.', 'valide', CURRENT_DATE - INTERVAL '23 days'),
    (19, 20, 15, 16, 4, 'Trajet tres agreable, chauffeur ponctuel.', 'valide', CURRENT_DATE - INTERVAL '2 days'),
    (20, 176, 23, 9, 4, 'Voiture propre et confortable.', 'valide', CURRENT_DATE - INTERVAL '26 days'),
    (21, 196, 6, 16, 5, 'Ponctuel et sympathique, rien a redire.', 'valide', CURRENT_DATE - INTERVAL '17 days'),
    (22, 154, 10, 5, 4, 'Parfait du debut a la fin.', 'valide', CURRENT_DATE - INTERVAL '2 days'),
    (23, 17, 14, 19, 5, 'Ponctuel et sympathique, rien a redire.', 'en_attente', CURRENT_DATE - INTERVAL '2 days'),
    (24, 17, 8, 19, 3, 'Excellent covoiturage, on a bien discute.', 'en_attente', CURRENT_DATE - INTERVAL '2 days'),
    (25, 17, 15, 19, 3, 'Voiture propre et confortable.', 'en_attente', CURRENT_DATE - INTERVAL '2 days'),
    (26, 178, 14, 13, 3, 'Tout s''est bien passe, merci beaucoup.', 'en_attente', CURRENT_DATE - INTERVAL '29 days'),
    (27, 120, 12, 15, 5, 'Ponctuel et sympathique, rien a redire.', 'en_attente', CURRENT_DATE - INTERVAL '27 days'),
    (28, 19, 15, 18, 4, 'Ponctuel et sympathique, rien a redire.', 'en_attente', CURRENT_DATE - INTERVAL '2 days'),
    (29, 167, 4, 6, 5, 'Voiture propre et confortable.', 'en_attente', CURRENT_DATE - INTERVAL '28 days'),
    (30, 167, 20, 6, 4, 'Ponctuel et sympathique, rien a redire.', 'en_attente', CURRENT_DATE - INTERVAL '28 days'),
    (31, 156, 25, 20, 4, 'Super voyage, je recommande !', 'en_attente', CURRENT_DATE - INTERVAL '26 days'),
    (32, 156, 12, 20, 3, 'Ponctuel et sympathique, rien a redire.', 'en_attente', CURRENT_DATE - INTERVAL '26 days');


-- --------------------------------------------
-- 9. REMISE À NIVEAU DES COMPTEURS D'IDENTIFIANTS
--
-- On a imposé les identifiants à la main (1, 2, 3...).
-- Sans ces lignes, la prochaine inscription réutiliserait l'identifiant 1
-- et provoquerait une erreur de doublon.
-- --------------------------------------------
SELECT setval('users_user_id_seq',                 30);
SELECT setval('roles_role_id_seq',                 3);
SELECT setval('vehicules_vehicule_id_seq',         25);
SELECT setval('covoiturages_covoiturage_id_seq',   206);
SELECT setval('participations_participation_id_seq', 80);
SELECT setval('avis_avis_id_seq',                  32);
SELECT setval('preferences_preference_id_seq',     (SELECT COALESCE(MAX(preference_id), 1) FROM preferences));
SELECT setval('preferences_personnalisees_preference_perso_id_seq',
              (SELECT COALESCE(MAX(preference_perso_id), 1) FROM preferences_personnalisees));


-- --------------------------------------------
-- 10. VÉRIFICATION
-- --------------------------------------------
SELECT
  (SELECT COUNT(*) FROM users)          AS comptes,
  (SELECT COUNT(*) FROM vehicules)      AS vehicules,
  (SELECT COUNT(*) FROM vehicules WHERE energie = 'electrique') AS dont_electriques,
  (SELECT COUNT(*) FROM covoiturages)   AS trajets,
  (SELECT COUNT(*) FROM covoiturages WHERE statut = 'planifie'
                                       AND date_depart >= CURRENT_DATE
                                       AND nb_places_restantes > 0) AS trajets_reservables,
  (SELECT COUNT(*) FROM participations) AS participations,
  (SELECT COUNT(*) FROM avis WHERE statut = 'valide')     AS avis_valides,
  (SELECT COUNT(*) FROM avis WHERE statut = 'en_attente') AS avis_en_attente;
