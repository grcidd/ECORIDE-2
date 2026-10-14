-- ============================================
-- ECORIDE — Jeu de données de test
--            VERSION QUI GARDE MES COMPTES PERSONNELS
--
-- À exécuter dans Supabase > SQL Editor, APRÈS schema.sql ou migration_v2.sql.
--
-- ✅ CE FICHIER NE TOUCHE PAS à ces 3 comptes (repérés par leur e-mail) :
--      grcdtech@gmail.com         (pseudo grcidd)
--      gracedoure1234@gmail.com   (pseudo grcdtech)
--      grcidd25@gmail.com         (pseudo employer_martin)
--    Leurs véhicules, leurs trajets et leurs réservations sont conservés.
--
-- 🗑️ Tout le RESTE est effacé puis recréé, y compris les 4 comptes de
--    démonstration (admin@ecoride.fr, employe@ecoride.fr, lisa@test.fr,
--    gracie@test.fr) : ils font partie du jeu de test.
--
-- Mot de passe de tous les comptes créés ici : Test1234!
--
-- Les dates sont RELATIVES au jour où tu exécutes le fichier
-- (CURRENT_DATE + INTERVAL '...'), de -30 à +90 jours.
-- Il y aura donc toujours des trajets à venir le jour de la soutenance.
--
-- Tu peux relancer ce fichier autant de fois que tu veux : il recommence
-- toujours du même état.
--
-- --------------------------------------------
-- POURQUOI DES NUMÉROS QUI COMMENCENT À 101 ?
--
-- Mes comptes personnels portent les numéros 10, 11 et 12.
-- Le jeu de test d'origine (seed.sql) utilise les numéros 1 à 30 :
-- il écraserait donc mes comptes.
--
-- Ici, tout le jeu de test est décalé très haut, dans des plages
-- qui ne peuvent jamais tomber sur les miennes :
--     comptes        : 101 à 130
--     véhicules      : 101 à 125
--     trajets        : 1001 à 1206
--     participations : 1001 à 1080
--     avis           : 1001 à 1032
-- --------------------------------------------
-- ============================================


-- --------------------------------------------
-- 0. QUELS COMPTES GARDE-T-ON ?
--
-- On les repère par leur e-mail, jamais par leur numéro : un numéro peut
-- changer d'une base à l'autre, pas une adresse e-mail.
-- Une table TEMP n'existe que le temps de la requête.
-- --------------------------------------------
CREATE TEMP TABLE comptes_gardes AS
SELECT user_id FROM users
 WHERE email IN (
     'grcdtech@gmail.com',
     'gracedoure1234@gmail.com',
     'grcidd25@gmail.com'
 );

-- Les trajets proposés par ces comptes-là, qu'on garde aussi.
CREATE TEMP TABLE trajets_gardes AS
SELECT covoiturage_id FROM covoiturages
 WHERE chauffeur_id IN (SELECT user_id FROM comptes_gardes);


-- --------------------------------------------
-- 1. EFFACER TOUT LE RESTE
--
-- On supprime dans l'ordre inverse des liens entre tables :
-- d'abord ce qui dépend des autres (avis, participations), en dernier
-- les comptes. Sinon PostgreSQL refuse (clé étrangère).
--
-- ⚠️ Pas de TRUNCATE ici : TRUNCATE vide TOUT, y compris mes comptes.
-- --------------------------------------------
DELETE FROM avis
 WHERE covoiturage_id NOT IN (SELECT covoiturage_id FROM trajets_gardes)
    OR passager_id    NOT IN (SELECT user_id FROM comptes_gardes)
    OR chauffeur_id   NOT IN (SELECT user_id FROM comptes_gardes);

DELETE FROM participations
 WHERE covoiturage_id NOT IN (SELECT covoiturage_id FROM trajets_gardes)
    OR passager_id    NOT IN (SELECT user_id FROM comptes_gardes);

DELETE FROM covoiturages
 WHERE chauffeur_id NOT IN (SELECT user_id FROM comptes_gardes);

DELETE FROM vehicules
 WHERE user_id NOT IN (SELECT user_id FROM comptes_gardes);

DELETE FROM preferences
 WHERE user_id NOT IN (SELECT user_id FROM comptes_gardes);

DELETE FROM preferences_personnalisees
 WHERE user_id NOT IN (SELECT user_id FROM comptes_gardes);

DELETE FROM users
 WHERE user_id NOT IN (SELECT user_id FROM comptes_gardes);


-- --------------------------------------------
-- 1. LES 3 RÔLES
-- --------------------------------------------
-- ON CONFLICT DO NOTHING : si les 3 rôles existent déjà, on passe sans erreur.
-- (On ne les a pas effacés : mes comptes gardés s'appuient dessus.)
INSERT INTO roles (role_id, libelle) VALUES
    (1, 'utilisateur'),
    (2, 'employe'),
    (3, 'administrateur')
ON CONFLICT (role_id) DO NOTHING;


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
    (101, 'admin', 'admin@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Admin', 'EcoRide', '0614857511', 999, 3, FALSE, FALSE),
    (102, 'employe1', 'employe@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Martin', 'Sophie', '0651846762', 0, 2, FALSE, FALSE),
    (103, 'lisa_drive', 'lisa@test.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Dupont', 'Lisa', '0680498733', 50, 1, TRUE, TRUE),
    (104, 'gracie_p', 'gracie@test.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Doure', 'Gracie', '0677584213', 20, 1, FALSE, TRUE),
    (105, 'thomas_b', 'thomas_b@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Bernard', 'Thomas', '0674082405', 15, 1, TRUE, TRUE),
    (106, 'julie_p', 'julie_p@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Petit', 'Julie', '0670247790', 25, 1, TRUE, TRUE),
    (107, 'max_r', 'max_r@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Robert', 'Maxime', '0681010270', 40, 1, TRUE, TRUE),
    (108, 'chloe_r', 'chloe_r@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Richard', 'Chloe', '0622935591', 40, 1, TRUE, TRUE),
    (109, 'antoine_d', 'antoine_d@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Durand', 'Antoine', '0666439753', 55, 1, TRUE, TRUE),
    (110, 'emma_m', 'emma_m@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Moreau', 'Emma', '0663659674', 70, 1, TRUE, TRUE),
    (111, 'hugo_l', 'hugo_l@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Laurent', 'Hugo', '0620417339', 15, 1, TRUE, TRUE),
    (112, 'lea_s', 'lea_s@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Simon', 'Lea', '0624109447', 20, 1, TRUE, TRUE),
    (113, 'nathan_m', 'nathan_m@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Michel', 'Nathan', '0651020839', 40, 1, TRUE, TRUE),
    (114, 'camille_l', 'camille_l@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Lefevre', 'Camille', '0663782093', 40, 1, TRUE, TRUE),
    (115, 'lucas_l', 'lucas_l@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Leroy', 'Lucas', '0641983382', 40, 1, TRUE, TRUE),
    (116, 'manon_r', 'manon_r@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Roux', 'Manon', '0657711000', 30, 1, TRUE, TRUE),
    (117, 'theo_d', 'theo_d@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'David', 'Theo', '0621223621', 70, 1, TRUE, TRUE),
    (118, 'sarah_b', 'sarah_b@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Bertrand', 'Sarah', '0620762256', 40, 1, TRUE, TRUE),
    (119, 'enzo_m', 'enzo_m@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Morel', 'Enzo', '0610673434', 40, 1, TRUE, TRUE),
    (120, 'ines_f', 'ines_f@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Fournier', 'Ines', '0634932905', 70, 1, TRUE, TRUE),
    (121, 'paul_g', 'paul_g@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Girard', 'Paul', '0613817462', 55, 1, FALSE, TRUE),
    (122, 'alice_b', 'alice_b@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Bonnet', 'Alice', '0642927294', 70, 1, FALSE, TRUE),
    (123, 'louis_d', 'louis_d@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Dupuis', 'Louis', '0678680664', 70, 1, FALSE, TRUE),
    (124, 'jade_l', 'jade_l@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Lambert', 'Jade', '0642250025', 30, 1, FALSE, TRUE),
    (125, 'noah_f', 'noah_f@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Fontaine', 'Noah', '0615225472', 70, 1, FALSE, TRUE),
    (126, 'zoe_r', 'zoe_r@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Rousseau', 'Zoe', '0616681913', 70, 1, FALSE, TRUE),
    (127, 'adam_v', 'adam_v@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Vincent', 'Adam', '0650991638', 40, 1, FALSE, TRUE),
    (128, 'eva_m', 'eva_m@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Muller', 'Eva', '0610752947', 30, 1, FALSE, TRUE),
    (129, 'gabin_f', 'gabin_f@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Faure', 'Gabin', '0694539529', 20, 1, FALSE, TRUE),
    (130, 'rose_a', 'rose_a@ecoride.fr', '$2b$10$I.pAy6VLfKDbqYmLjEy1TOBEDdOlrnmAQfyG6xHwIRw4fnlb4ORgO', 'Andre', 'Rose', '0637671495', 15, 1, FALSE, TRUE);


-- --------------------------------------------
-- 3. LES VÉHICULES (25, dont 9 électriques)
-- Seuls les véhicules électriques donnent le badge « écologique » (US 3).
-- --------------------------------------------
INSERT INTO vehicules (vehicule_id, user_id, marque, modele, couleur, immatriculation,
                       date_premiere_immatriculation, energie, nb_places) VALUES
    (101, 103, 'Tesla', 'Model 3', 'Blanc', 'AB-123-CD', CURRENT_DATE - INTERVAL '1400 days', 'electrique', 4),
    (102, 105, 'Renault', 'Zoe', 'Noir', 'CH-114-EF', CURRENT_DATE - INTERVAL '753 days', 'electrique', 4),
    (103, 105, 'Peugeot', 'e-208', 'Noir', 'DI-121-FG', CURRENT_DATE - INTERVAL '2141 days', 'electrique', 4),
    (104, 106, 'Nissan', 'Leaf', 'Argent', 'EJ-128-GH', CURRENT_DATE - INTERVAL '1587 days', 'electrique', 4),
    (105, 106, 'Hyundai', 'Kona Electric', 'Beige', 'FK-135-HI', CURRENT_DATE - INTERVAL '1330 days', 'electrique', 4),
    (106, 107, 'Kia', 'e-Niro', 'Vert', 'GL-142-IJ', CURRENT_DATE - INTERVAL '1841 days', 'electrique', 7),
    (107, 107, 'Fiat', '500e', 'Noir', 'HM-149-JK', CURRENT_DATE - INTERVAL '1694 days', 'electrique', 4),
    (108, 108, 'Volkswagen', 'ID.3', 'Rouge', 'IN-156-KL', CURRENT_DATE - INTERVAL '1478 days', 'electrique', 5),
    (109, 108, 'BMW', 'i3', 'Gris', 'JO-163-LM', CURRENT_DATE - INTERVAL '2665 days', 'electrique', 4),
    (110, 109, 'Toyota', 'Yaris Hybride', 'Blanc', 'KP-170-MN', CURRENT_DATE - INTERVAL '1810 days', 'hybride', 4),
    (111, 109, 'Toyota', 'Prius', 'Argent', 'LQ-177-NO', CURRENT_DATE - INTERVAL '2029 days', 'hybride', 4),
    (112, 110, 'Renault', 'Clio E-Tech', 'Beige', 'MR-184-OP', CURRENT_DATE - INTERVAL '2699 days', 'hybride', 5),
    (113, 110, 'Honda', 'Jazz Hybride', 'Argent', 'NS-191-PQ', CURRENT_DATE - INTERVAL '776 days', 'hybride', 5),
    (114, 111, 'Peugeot', '308', 'Beige', 'OT-198-QR', CURRENT_DATE - INTERVAL '2448 days', 'diesel', 4),
    (115, 111, 'Renault', 'Megane', 'Argent', 'PU-205-RS', CURRENT_DATE - INTERVAL '2401 days', 'diesel', 5),
    (116, 112, 'Citroen', 'C4', 'Bleu', 'QV-212-ST', CURRENT_DATE - INTERVAL '828 days', 'essence', 4),
    (117, 112, 'Volkswagen', 'Golf', 'Beige', 'RW-219-TU', CURRENT_DATE - INTERVAL '2225 days', 'essence', 4),
    (118, 113, 'Ford', 'Focus', 'Bleu', 'SX-226-UV', CURRENT_DATE - INTERVAL '799 days', 'diesel', 7),
    (119, 114, 'Opel', 'Astra', 'Argent', 'TY-233-VW', CURRENT_DATE - INTERVAL '2534 days', 'diesel', 4),
    (120, 115, 'Seat', 'Leon', 'Rouge', 'UF-240-WX', CURRENT_DATE - INTERVAL '2545 days', 'diesel', 7),
    (121, 116, 'Skoda', 'Octavia', 'Beige', 'VG-247-XY', CURRENT_DATE - INTERVAL '2073 days', 'diesel', 4),
    (122, 117, 'Dacia', 'Sandero', 'Rouge', 'WH-254-YD', CURRENT_DATE - INTERVAL '337 days', 'diesel', 4),
    (123, 118, 'Citroen', 'C3', 'Argent', 'XI-261-CE', CURRENT_DATE - INTERVAL '2441 days', 'essence', 5),
    (124, 119, 'Peugeot', '208', 'Bleu', 'YJ-268-DF', CURRENT_DATE - INTERVAL '1365 days', 'diesel', 7),
    (125, 120, 'Renault', 'Captur', 'Argent', 'ZK-275-EG', CURRENT_DATE - INTERVAL '2394 days', 'diesel', 5);


-- --------------------------------------------
-- 4. LES PRÉFÉRENCES DES CHAUFFEURS (US 8)
-- --------------------------------------------
INSERT INTO preferences (user_id, accepte_fumeur, accepte_animaux, preference_perso) VALUES
    (103, TRUE, TRUE, 'Discussion bienvenue !'),
    (105, FALSE, FALSE, 'Musique calme acceptee.'),
    (106, FALSE, FALSE, NULL),
    (107, FALSE, TRUE, NULL),
    (108, FALSE, TRUE, 'Discussion bienvenue !'),
    (109, FALSE, TRUE, 'Pause toutes les deux heures.'),
    (110, TRUE, TRUE, NULL),
    (111, FALSE, TRUE, 'Musique calme acceptee.'),
    (112, FALSE, FALSE, NULL),
    (113, FALSE, FALSE, NULL),
    (114, TRUE, FALSE, NULL),
    (115, TRUE, FALSE, 'Discussion bienvenue !'),
    (116, TRUE, TRUE, 'Discussion bienvenue !'),
    (117, FALSE, FALSE, 'Musique calme acceptee.'),
    (118, FALSE, TRUE, NULL),
    (119, FALSE, TRUE, NULL),
    (120, FALSE, FALSE, 'Musique calme acceptee.');


-- --------------------------------------------
-- 5. LES PRÉFÉRENCES PERSONNALISÉES (US 8)
-- Table dédiée : chaque chauffeur peut en ajouter autant qu'il veut.
-- --------------------------------------------
INSERT INTO preferences_personnalisees (user_id, libelle) VALUES
    (103, 'Depart a l''heure precise'),
    (103, 'Pas de nourriture dans la voiture'),
    (105, 'Coffre a skis possible'),
    (105, 'Arret pause toutes les 2h'),
    (105, 'Musique au choix du passager'),
    (106, 'Climatisation disponible'),
    (106, 'Depart a l''heure precise'),
    (107, 'Pas de nourriture dans la voiture'),
    (107, 'Arret pause toutes les 2h'),
    (108, 'Arret pause toutes les 2h'),
    (108, 'Coffre a skis possible'),
    (109, 'Bagage cabine uniquement'),
    (109, 'Arret pause toutes les 2h'),
    (110, 'Coffre a skis possible'),
    (110, 'Depart a l''heure precise'),
    (111, 'Musique au choix du passager'),
    (111, 'Coffre a skis possible'),
    (111, 'Depart a l''heure precise'),
    (112, 'Depart a l''heure precise'),
    (112, 'Bagage cabine uniquement'),
    (112, 'Musique au choix du passager'),
    (113, 'Bagage cabine uniquement'),
    (113, 'Depart a l''heure precise'),
    (113, 'Musique au choix du passager');


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
    (1001, 117, 122, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '7 days', '08:00', CURRENT_DATE - INTERVAL '7 days', '12:45', 285, 25, 3, 2, 'termine', FALSE, 2),
    (1002, 118, 123, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '7 days', '08:00', CURRENT_DATE - INTERVAL '7 days', '12:45', 285, 25, 4, 4, 'termine', FALSE, 2),
    (1003, 112, 117, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '7 days', '14:00', CURRENT_DATE - INTERVAL '7 days', '18:45', 285, 25, 3, 1, 'termine', FALSE, 2),
    (1004, 117, 122, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '7 days', '14:00', CURRENT_DATE - INTERVAL '7 days', '18:45', 285, 25, 3, 2, 'termine', FALSE, 2),
    (1005, 119, 124, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '6 days', '08:00', CURRENT_DATE - INTERVAL '6 days', '12:45', 285, 25, 4, 3, 'termine', FALSE, 2),
    (1006, 108, 109, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '6 days', '08:00', CURRENT_DATE - INTERVAL '6 days', '12:45', 285, 25, 3, 0, 'termine', TRUE, 2),
    (1007, 103, 101, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '6 days', '14:00', CURRENT_DATE - INTERVAL '6 days', '18:45', 285, 25, 3, 0, 'termine', TRUE, 2),
    (1008, 110, 112, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '6 days', '14:00', CURRENT_DATE - INTERVAL '6 days', '18:45', 285, 25, 4, 0, 'termine', FALSE, 2),
    (1009, 112, 117, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '5 days', '08:00', CURRENT_DATE - INTERVAL '5 days', '12:45', 285, 25, 3, 2, 'termine', FALSE, 2),
    (1010, 119, 124, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '5 days', '08:00', CURRENT_DATE - INTERVAL '5 days', '12:45', 285, 25, 4, 3, 'termine', FALSE, 2),
    (1011, 108, 109, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '5 days', '14:00', CURRENT_DATE - INTERVAL '5 days', '18:45', 285, 25, 3, 1, 'termine', TRUE, 2),
    (1012, 108, 109, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '5 days', '14:00', CURRENT_DATE - INTERVAL '5 days', '18:45', 285, 25, 3, 3, 'termine', TRUE, 2),
    (1013, 108, 108, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '4 days', '08:00', CURRENT_DATE - INTERVAL '4 days', '12:45', 285, 25, 4, 0, 'termine', TRUE, 2),
    (1014, 116, 121, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '4 days', '08:00', CURRENT_DATE - INTERVAL '4 days', '12:45', 285, 25, 3, 2, 'annule', FALSE, 2),
    (1015, 115, 120, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '4 days', '14:00', CURRENT_DATE - INTERVAL '4 days', '18:45', 285, 25, 4, 3, 'annule', FALSE, 2),
    (1016, 114, 119, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '4 days', '14:00', CURRENT_DATE - INTERVAL '4 days', '18:45', 285, 25, 3, 0, 'termine', FALSE, 2),
    (1017, 119, 124, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '3 days', '08:00', CURRENT_DATE - INTERVAL '3 days', '12:45', 285, 25, 4, 1, 'termine', FALSE, 2),
    (1018, 108, 108, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '3 days', '08:00', CURRENT_DATE - INTERVAL '3 days', '12:45', 285, 25, 4, 2, 'termine', TRUE, 2),
    (1019, 118, 123, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '3 days', '14:00', CURRENT_DATE - INTERVAL '3 days', '18:45', 285, 25, 4, 0, 'termine', FALSE, 2),
    (1020, 116, 121, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '3 days', '14:00', CURRENT_DATE - INTERVAL '3 days', '18:45', 285, 25, 3, 1, 'termine', FALSE, 2),
    (1021, 105, 102, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '2 days', '08:00', CURRENT_DATE - INTERVAL '2 days', '12:45', 285, 25, 3, 1, 'termine', TRUE, 2),
    (1022, 119, 124, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '2 days', '08:00', CURRENT_DATE - INTERVAL '2 days', '12:45', 285, 25, 4, 4, 'termine', FALSE, 2),
    (1023, 110, 112, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '2 days', '14:00', CURRENT_DATE - INTERVAL '2 days', '18:45', 285, 25, 4, 1, 'termine', FALSE, 2),
    (1024, 116, 121, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '2 days', '14:00', CURRENT_DATE - INTERVAL '2 days', '18:45', 285, 25, 3, 3, 'termine', FALSE, 2),
    (1025, 106, 105, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '1 days', '08:00', CURRENT_DATE - INTERVAL '1 days', '12:45', 285, 25, 3, 2, 'termine', TRUE, 2),
    (1026, 109, 111, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '1 days', '08:00', CURRENT_DATE - INTERVAL '1 days', '12:45', 285, 25, 3, 3, 'termine', FALSE, 2),
    (1027, 113, 118, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE - INTERVAL '1 days', '14:00', CURRENT_DATE - INTERVAL '1 days', '18:45', 285, 25, 4, 4, 'termine', FALSE, 2),
    (1028, 119, 124, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE - INTERVAL '1 days', '14:00', CURRENT_DATE - INTERVAL '1 days', '18:45', 285, 25, 4, 4, 'termine', FALSE, 2),
    (1029, 112, 116, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE, '07:00', CURRENT_DATE, '11:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (1030, 103, 101, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE, '07:00', CURRENT_DATE, '11:45', 285, 25, 3, 3, 'planifie', TRUE, 2),
    (1031, 114, 119, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE, '11:00', CURRENT_DATE, '15:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (1032, 109, 110, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE, '11:00', CURRENT_DATE, '15:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (1033, 115, 120, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE, '15:00', CURRENT_DATE, '19:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (1034, 110, 113, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE, '15:00', CURRENT_DATE, '19:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (1035, 107, 107, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE, '18:00', CURRENT_DATE, '22:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (1036, 109, 110, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE, '18:00', CURRENT_DATE, '22:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (1037, 109, 110, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '1 days', '07:00', CURRENT_DATE + INTERVAL '1 days', '11:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (1038, 106, 105, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '1 days', '07:00', CURRENT_DATE + INTERVAL '1 days', '11:45', 285, 25, 3, 1, 'planifie', TRUE, 2),
    (1039, 112, 117, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '1 days', '11:00', CURRENT_DATE + INTERVAL '1 days', '15:45', 285, 25, 3, 0, 'planifie', FALSE, 2),
    (1040, 117, 122, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '1 days', '11:00', CURRENT_DATE + INTERVAL '1 days', '15:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (1041, 105, 102, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '1 days', '15:00', CURRENT_DATE + INTERVAL '1 days', '19:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (1042, 107, 106, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '1 days', '15:00', CURRENT_DATE + INTERVAL '1 days', '19:45', 285, 25, 4, 3, 'planifie', TRUE, 2),
    (1043, 114, 119, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '1 days', '18:00', CURRENT_DATE + INTERVAL '1 days', '22:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (1044, 105, 103, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '1 days', '18:00', CURRENT_DATE + INTERVAL '1 days', '22:45', 285, 25, 3, 1, 'planifie', TRUE, 2),
    (1045, 118, 123, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '2 days', '07:00', CURRENT_DATE + INTERVAL '2 days', '11:45', 285, 25, 4, 1, 'planifie', FALSE, 2),
    (1046, 115, 120, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '2 days', '07:00', CURRENT_DATE + INTERVAL '2 days', '11:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (1047, 105, 103, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '2 days', '11:00', CURRENT_DATE + INTERVAL '2 days', '15:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (1048, 114, 119, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '2 days', '11:00', CURRENT_DATE + INTERVAL '2 days', '15:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (1049, 113, 118, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '2 days', '15:00', CURRENT_DATE + INTERVAL '2 days', '19:45', 285, 25, 4, 1, 'planifie', FALSE, 2),
    (1050, 114, 119, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '2 days', '15:00', CURRENT_DATE + INTERVAL '2 days', '19:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (1051, 107, 106, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '2 days', '18:00', CURRENT_DATE + INTERVAL '2 days', '22:45', 285, 25, 4, 1, 'planifie', TRUE, 2),
    (1052, 105, 102, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '2 days', '18:00', CURRENT_DATE + INTERVAL '2 days', '22:45', 285, 25, 3, 3, 'planifie', TRUE, 2),
    (1053, 113, 118, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '3 days', '07:00', CURRENT_DATE + INTERVAL '3 days', '11:45', 285, 25, 4, 1, 'planifie', FALSE, 2),
    (1054, 115, 120, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '3 days', '07:00', CURRENT_DATE + INTERVAL '3 days', '11:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (1055, 117, 122, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '3 days', '11:00', CURRENT_DATE + INTERVAL '3 days', '15:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (1056, 103, 101, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '3 days', '11:00', CURRENT_DATE + INTERVAL '3 days', '15:45', 285, 25, 3, 1, 'planifie', TRUE, 2),
    (1057, 111, 114, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '3 days', '15:00', CURRENT_DATE + INTERVAL '3 days', '19:45', 285, 25, 3, 0, 'planifie', FALSE, 2),
    (1058, 119, 124, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '3 days', '15:00', CURRENT_DATE + INTERVAL '3 days', '19:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (1059, 108, 108, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '3 days', '18:00', CURRENT_DATE + INTERVAL '3 days', '22:45', 285, 25, 4, 1, 'planifie', TRUE, 2),
    (1060, 120, 125, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '3 days', '18:00', CURRENT_DATE + INTERVAL '3 days', '22:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (1061, 105, 102, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '4 days', '07:00', CURRENT_DATE + INTERVAL '4 days', '11:45', 285, 25, 3, 1, 'planifie', TRUE, 2),
    (1062, 119, 124, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '4 days', '07:00', CURRENT_DATE + INTERVAL '4 days', '11:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (1063, 116, 121, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '4 days', '11:00', CURRENT_DATE + INTERVAL '4 days', '15:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (1064, 112, 117, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '4 days', '11:00', CURRENT_DATE + INTERVAL '4 days', '15:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (1065, 115, 120, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '4 days', '15:00', CURRENT_DATE + INTERVAL '4 days', '19:45', 285, 25, 4, 4, 'planifie', FALSE, 2),
    (1066, 113, 118, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '4 days', '15:00', CURRENT_DATE + INTERVAL '4 days', '19:45', 285, 25, 4, 4, 'planifie', FALSE, 2),
    (1067, 108, 109, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '4 days', '18:00', CURRENT_DATE + INTERVAL '4 days', '22:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (1068, 120, 125, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '4 days', '18:00', CURRENT_DATE + INTERVAL '4 days', '22:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (1069, 106, 105, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '5 days', '07:00', CURRENT_DATE + INTERVAL '5 days', '11:45', 285, 25, 3, 3, 'planifie', TRUE, 2),
    (1070, 112, 116, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '5 days', '07:00', CURRENT_DATE + INTERVAL '5 days', '11:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (1071, 103, 101, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '5 days', '11:00', CURRENT_DATE + INTERVAL '5 days', '15:45', 285, 25, 3, 3, 'planifie', TRUE, 2),
    (1072, 113, 118, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '5 days', '11:00', CURRENT_DATE + INTERVAL '5 days', '15:45', 285, 25, 4, 4, 'planifie', FALSE, 2),
    (1073, 120, 125, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '5 days', '15:00', CURRENT_DATE + INTERVAL '5 days', '19:45', 285, 25, 4, 1, 'planifie', FALSE, 2),
    (1074, 106, 104, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '5 days', '15:00', CURRENT_DATE + INTERVAL '5 days', '19:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (1075, 112, 117, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '5 days', '18:00', CURRENT_DATE + INTERVAL '5 days', '22:45', 285, 25, 3, 0, 'planifie', FALSE, 2),
    (1076, 110, 112, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '5 days', '18:00', CURRENT_DATE + INTERVAL '5 days', '22:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (1077, 113, 118, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '6 days', '07:00', CURRENT_DATE + INTERVAL '6 days', '11:45', 285, 25, 4, 4, 'planifie', FALSE, 2),
    (1078, 110, 112, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '6 days', '07:00', CURRENT_DATE + INTERVAL '6 days', '11:45', 285, 25, 4, 4, 'planifie', FALSE, 2),
    (1079, 117, 122, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '6 days', '11:00', CURRENT_DATE + INTERVAL '6 days', '15:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (1080, 109, 110, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '6 days', '11:00', CURRENT_DATE + INTERVAL '6 days', '15:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (1081, 108, 108, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '6 days', '15:00', CURRENT_DATE + INTERVAL '6 days', '19:45', 285, 25, 4, 0, 'planifie', TRUE, 2),
    (1082, 107, 106, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '6 days', '15:00', CURRENT_DATE + INTERVAL '6 days', '19:45', 285, 25, 4, 1, 'planifie', TRUE, 2),
    (1083, 115, 120, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '6 days', '18:00', CURRENT_DATE + INTERVAL '6 days', '22:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (1084, 111, 114, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '6 days', '18:00', CURRENT_DATE + INTERVAL '6 days', '22:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (1085, 119, 124, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '7 days', '07:00', CURRENT_DATE + INTERVAL '7 days', '11:45', 285, 25, 4, 1, 'planifie', FALSE, 2),
    (1086, 116, 121, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '7 days', '07:00', CURRENT_DATE + INTERVAL '7 days', '11:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (1087, 107, 107, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '7 days', '11:00', CURRENT_DATE + INTERVAL '7 days', '15:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (1088, 107, 106, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '7 days', '11:00', CURRENT_DATE + INTERVAL '7 days', '15:45', 285, 25, 4, 4, 'planifie', TRUE, 2),
    (1089, 115, 120, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '7 days', '15:00', CURRENT_DATE + INTERVAL '7 days', '19:45', 285, 25, 4, 0, 'planifie', FALSE, 2),
    (1090, 106, 105, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '7 days', '15:00', CURRENT_DATE + INTERVAL '7 days', '19:45', 285, 25, 3, 2, 'planifie', TRUE, 2),
    (1091, 111, 114, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '7 days', '18:00', CURRENT_DATE + INTERVAL '7 days', '22:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (1092, 114, 119, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '7 days', '18:00', CURRENT_DATE + INTERVAL '7 days', '22:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (1093, 119, 124, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '8 days', '07:00', CURRENT_DATE + INTERVAL '8 days', '11:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (1094, 118, 123, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '8 days', '07:00', CURRENT_DATE + INTERVAL '8 days', '11:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (1095, 115, 120, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '8 days', '11:00', CURRENT_DATE + INTERVAL '8 days', '15:45', 285, 25, 4, 4, 'planifie', FALSE, 2),
    (1096, 110, 112, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '8 days', '11:00', CURRENT_DATE + INTERVAL '8 days', '15:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (1097, 117, 122, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '8 days', '15:00', CURRENT_DATE + INTERVAL '8 days', '19:45', 285, 25, 3, 1, 'planifie', FALSE, 2),
    (1098, 114, 119, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '8 days', '15:00', CURRENT_DATE + INTERVAL '8 days', '19:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (1099, 112, 116, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '8 days', '18:00', CURRENT_DATE + INTERVAL '8 days', '22:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (1100, 111, 115, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '8 days', '18:00', CURRENT_DATE + INTERVAL '8 days', '22:45', 285, 25, 4, 1, 'planifie', FALSE, 2),
    (1101, 112, 117, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '9 days', '07:00', CURRENT_DATE + INTERVAL '9 days', '11:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (1102, 116, 121, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '9 days', '07:00', CURRENT_DATE + INTERVAL '9 days', '11:45', 285, 25, 3, 0, 'planifie', FALSE, 2),
    (1103, 114, 119, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '9 days', '11:00', CURRENT_DATE + INTERVAL '9 days', '15:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (1104, 119, 124, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '9 days', '11:00', CURRENT_DATE + INTERVAL '9 days', '15:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (1105, 105, 103, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '9 days', '15:00', CURRENT_DATE + INTERVAL '9 days', '19:45', 285, 25, 3, 1, 'planifie', TRUE, 2),
    (1106, 112, 117, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '9 days', '15:00', CURRENT_DATE + INTERVAL '9 days', '19:45', 285, 25, 3, 3, 'planifie', FALSE, 2),
    (1107, 117, 122, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '9 days', '18:00', CURRENT_DATE + INTERVAL '9 days', '22:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (1108, 114, 119, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '9 days', '18:00', CURRENT_DATE + INTERVAL '9 days', '22:45', 285, 25, 3, 0, 'planifie', FALSE, 2),
    (1109, 111, 114, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '10 days', '07:00', CURRENT_DATE + INTERVAL '10 days', '11:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (1110, 114, 119, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '10 days', '07:00', CURRENT_DATE + INTERVAL '10 days', '11:45', 285, 25, 3, 2, 'planifie', FALSE, 2),
    (1111, 120, 125, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '10 days', '11:00', CURRENT_DATE + INTERVAL '10 days', '15:45', 285, 25, 4, 3, 'planifie', FALSE, 2),
    (1112, 106, 104, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '10 days', '11:00', CURRENT_DATE + INTERVAL '10 days', '15:45', 285, 25, 3, 1, 'planifie', TRUE, 2),
    (1113, 107, 106, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '10 days', '15:00', CURRENT_DATE + INTERVAL '10 days', '19:45', 285, 25, 4, 2, 'planifie', TRUE, 2),
    (1114, 118, 123, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '10 days', '15:00', CURRENT_DATE + INTERVAL '10 days', '19:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (1115, 113, 118, 'Paris', 'Lyon', 'Gare de Lyon', 'Place Bellecour', CURRENT_DATE + INTERVAL '10 days', '18:00', CURRENT_DATE + INTERVAL '10 days', '22:45', 285, 25, 4, 2, 'planifie', FALSE, 2),
    (1116, 107, 106, 'Lyon', 'Paris', 'Place Bellecour', 'Gare de Lyon', CURRENT_DATE + INTERVAL '10 days', '18:00', CURRENT_DATE + INTERVAL '10 days', '22:45', 285, 25, 4, 4, 'planifie', TRUE, 2),
    (1117, 120, 125, 'Paris', 'Lille', 'Gare de Lyon', 'Place du General de Gaulle', CURRENT_DATE - INTERVAL '25 days', '08:00', CURRENT_DATE - INTERVAL '25 days', '10:10', 130, 15, 4, 3, 'termine', FALSE, 2),
    (1118, 115, 120, 'Paris', 'Lille', 'Gare de Lyon', 'Place du General de Gaulle', CURRENT_DATE + INTERVAL '54 days', '13:00', CURRENT_DATE + INTERVAL '54 days', '15:10', 130, 14, 4, 3, 'planifie', FALSE, 2),
    (1119, 112, 116, 'Paris', 'Lille', 'Gare de Lyon', 'Place du General de Gaulle', CURRENT_DATE + INTERVAL '32 days', '13:00', CURRENT_DATE + INTERVAL '32 days', '15:10', 130, 17, 3, 1, 'planifie', FALSE, 2),
    (1120, 115, 120, 'Lille', 'Paris', 'Place du General de Gaulle', 'Gare de Lyon', CURRENT_DATE - INTERVAL '28 days', '16:00', CURRENT_DATE - INTERVAL '28 days', '18:10', 130, 17, 4, 3, 'termine', FALSE, 2),
    (1121, 120, 125, 'Lille', 'Paris', 'Place du General de Gaulle', 'Gare de Lyon', CURRENT_DATE - INTERVAL '5 days', '13:00', CURRENT_DATE - INTERVAL '5 days', '15:10', 130, 14, 4, 4, 'termine', FALSE, 2),
    (1122, 106, 105, 'Lille', 'Paris', 'Place du General de Gaulle', 'Gare de Lyon', CURRENT_DATE - INTERVAL '24 days', '14:00', CURRENT_DATE - INTERVAL '24 days', '16:10', 130, 17, 3, 0, 'termine', TRUE, 2),
    (1123, 114, 119, 'Paris', 'Bordeaux', 'Gare de Lyon', 'Place de la Victoire', CURRENT_DATE + INTERVAL '79 days', '17:00', CURRENT_DATE + INTERVAL '79 days', '22:40', 340, 31, 3, 2, 'planifie', FALSE, 2),
    (1124, 109, 111, 'Paris', 'Bordeaux', 'Gare de Lyon', 'Place de la Victoire', CURRENT_DATE + INTERVAL '16 days', '08:00', CURRENT_DATE + INTERVAL '16 days', '13:40', 340, 28, 3, 3, 'planifie', FALSE, 2),
    (1125, 107, 106, 'Paris', 'Bordeaux', 'Gare de Lyon', 'Place de la Victoire', CURRENT_DATE + INTERVAL '36 days', '14:00', CURRENT_DATE + INTERVAL '36 days', '19:40', 340, 32, 4, 0, 'planifie', TRUE, 2),
    (1126, 120, 125, 'Bordeaux', 'Paris', 'Place de la Victoire', 'Gare de Lyon', CURRENT_DATE, '09:00', CURRENT_DATE, '14:40', 340, 30, 4, 3, 'planifie', FALSE, 2),
    (1127, 114, 119, 'Bordeaux', 'Paris', 'Place de la Victoire', 'Gare de Lyon', CURRENT_DATE + INTERVAL '69 days', '16:00', CURRENT_DATE + INTERVAL '69 days', '21:40', 340, 29, 3, 2, 'planifie', FALSE, 2),
    (1128, 110, 112, 'Bordeaux', 'Paris', 'Place de la Victoire', 'Gare de Lyon', CURRENT_DATE + INTERVAL '38 days', '18:00', CURRENT_DATE + INTERVAL '38 days', '23:40', 340, 32, 4, 2, 'planifie', FALSE, 2),
    (1129, 105, 102, 'Paris', 'Nantes', 'Gare de Lyon', 'Place du Commerce', CURRENT_DATE + INTERVAL '63 days', '08:00', CURRENT_DATE + INTERVAL '63 days', '12:00', 240, 21, 3, 2, 'planifie', TRUE, 2),
    (1130, 112, 117, 'Paris', 'Nantes', 'Gare de Lyon', 'Place du Commerce', CURRENT_DATE + INTERVAL '90 days', '08:00', CURRENT_DATE + INTERVAL '90 days', '12:00', 240, 21, 3, 1, 'planifie', FALSE, 2),
    (1131, 109, 110, 'Paris', 'Nantes', 'Gare de Lyon', 'Place du Commerce', CURRENT_DATE - INTERVAL '7 days', '06:00', CURRENT_DATE - INTERVAL '7 days', '10:00', 240, 25, 3, 3, 'termine', FALSE, 2),
    (1132, 113, 118, 'Nantes', 'Paris', 'Place du Commerce', 'Gare de Lyon', CURRENT_DATE + INTERVAL '86 days', '17:00', CURRENT_DATE + INTERVAL '86 days', '21:00', 240, 20, 4, 1, 'planifie', FALSE, 2),
    (1133, 114, 119, 'Nantes', 'Paris', 'Place du Commerce', 'Gare de Lyon', CURRENT_DATE + INTERVAL '29 days', '14:00', CURRENT_DATE + INTERVAL '29 days', '18:00', 240, 21, 3, 1, 'planifie', FALSE, 2),
    (1134, 107, 107, 'Nantes', 'Paris', 'Place du Commerce', 'Gare de Lyon', CURRENT_DATE + INTERVAL '30 days', '06:00', CURRENT_DATE + INTERVAL '30 days', '10:00', 240, 20, 3, 3, 'planifie', TRUE, 2),
    (1135, 103, 101, 'Paris', 'Strasbourg', 'Gare de Lyon', 'Place Kleber', CURRENT_DATE + INTERVAL '59 days', '10:00', CURRENT_DATE + INTERVAL '59 days', '14:50', 290, 26, 3, 1, 'planifie', TRUE, 2),
    (1136, 109, 110, 'Paris', 'Strasbourg', 'Gare de Lyon', 'Place Kleber', CURRENT_DATE + INTERVAL '24 days', '14:00', CURRENT_DATE + INTERVAL '24 days', '18:50', 290, 25, 3, 2, 'planifie', FALSE, 2),
    (1137, 117, 122, 'Paris', 'Strasbourg', 'Gare de Lyon', 'Place Kleber', CURRENT_DATE - INTERVAL '3 days', '13:00', CURRENT_DATE - INTERVAL '3 days', '17:50', 290, 25, 3, 2, 'termine', FALSE, 2),
    (1138, 118, 123, 'Strasbourg', 'Paris', 'Place Kleber', 'Gare de Lyon', CURRENT_DATE + INTERVAL '60 days', '09:00', CURRENT_DATE + INTERVAL '60 days', '13:50', 290, 26, 4, 2, 'planifie', FALSE, 2),
    (1139, 106, 105, 'Strasbourg', 'Paris', 'Place Kleber', 'Gare de Lyon', CURRENT_DATE + INTERVAL '64 days', '09:00', CURRENT_DATE + INTERVAL '64 days', '13:50', 290, 24, 3, 3, 'planifie', TRUE, 2),
    (1140, 109, 110, 'Strasbourg', 'Paris', 'Place Kleber', 'Gare de Lyon', CURRENT_DATE + INTERVAL '58 days', '08:00', CURRENT_DATE + INTERVAL '58 days', '12:50', 290, 24, 3, 1, 'planifie', FALSE, 2),
    (1141, 108, 109, 'Paris', 'Rennes', 'Gare de Lyon', 'Place de la Republique', CURRENT_DATE + INTERVAL '85 days', '14:00', CURRENT_DATE + INTERVAL '85 days', '17:35', 215, 18, 3, 2, 'planifie', TRUE, 2),
    (1142, 120, 125, 'Paris', 'Rennes', 'Gare de Lyon', 'Place de la Republique', CURRENT_DATE + INTERVAL '20 days', '06:00', CURRENT_DATE + INTERVAL '20 days', '09:35', 215, 20, 4, 3, 'planifie', FALSE, 2),
    (1143, 108, 108, 'Paris', 'Rennes', 'Gare de Lyon', 'Place de la Republique', CURRENT_DATE + INTERVAL '32 days', '08:00', CURRENT_DATE + INTERVAL '32 days', '11:35', 215, 18, 4, 4, 'planifie', TRUE, 2),
    (1144, 105, 103, 'Rennes', 'Paris', 'Place de la Republique', 'Gare de Lyon', CURRENT_DATE + INTERVAL '18 days', '18:00', CURRENT_DATE + INTERVAL '18 days', '21:35', 215, 22, 3, 3, 'planifie', TRUE, 2),
    (1145, 115, 120, 'Rennes', 'Paris', 'Place de la Republique', 'Gare de Lyon', CURRENT_DATE - INTERVAL '20 days', '16:00', CURRENT_DATE - INTERVAL '20 days', '19:35', 215, 20, 4, 2, 'termine', FALSE, 2),
    (1146, 105, 102, 'Rennes', 'Paris', 'Place de la Republique', 'Gare de Lyon', CURRENT_DATE - INTERVAL '26 days', '07:00', CURRENT_DATE - INTERVAL '26 days', '10:35', 215, 21, 3, 3, 'termine', TRUE, 2),
    (1147, 118, 123, 'Lyon', 'Marseille', 'Place Bellecour', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '42 days', '07:00', CURRENT_DATE + INTERVAL '42 days', '10:10', 190, 18, 4, 2, 'planifie', FALSE, 2),
    (1148, 103, 101, 'Lyon', 'Marseille', 'Place Bellecour', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '84 days', '13:00', CURRENT_DATE + INTERVAL '84 days', '16:10', 190, 17, 3, 1, 'planifie', TRUE, 2),
    (1149, 105, 102, 'Lyon', 'Marseille', 'Place Bellecour', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '38 days', '10:00', CURRENT_DATE + INTERVAL '38 days', '13:10', 190, 16, 3, 3, 'planifie', TRUE, 2),
    (1150, 108, 109, 'Marseille', 'Lyon', 'Gare Saint-Charles', 'Place Bellecour', CURRENT_DATE - INTERVAL '15 days', '13:00', CURRENT_DATE - INTERVAL '15 days', '16:10', 190, 20, 3, 1, 'termine', TRUE, 2),
    (1151, 111, 115, 'Marseille', 'Lyon', 'Gare Saint-Charles', 'Place Bellecour', CURRENT_DATE + INTERVAL '11 days', '16:00', CURRENT_DATE + INTERVAL '11 days', '19:10', 190, 20, 4, 3, 'planifie', FALSE, 2),
    (1152, 111, 114, 'Marseille', 'Lyon', 'Gare Saint-Charles', 'Place Bellecour', CURRENT_DATE + INTERVAL '23 days', '06:00', CURRENT_DATE + INTERVAL '23 days', '09:10', 190, 18, 3, 1, 'planifie', FALSE, 2),
    (1153, 116, 121, 'Lyon', 'Montpellier', 'Place Bellecour', 'Place de la Comedie', CURRENT_DATE + INTERVAL '45 days', '16:00', CURRENT_DATE + INTERVAL '45 days', '19:05', 185, 18, 3, 2, 'planifie', FALSE, 2),
    (1154, 105, 103, 'Lyon', 'Montpellier', 'Place Bellecour', 'Place de la Comedie', CURRENT_DATE - INTERVAL '3 days', '14:00', CURRENT_DATE - INTERVAL '3 days', '17:05', 185, 19, 3, 2, 'termine', TRUE, 2),
    (1155, 112, 117, 'Lyon', 'Montpellier', 'Place Bellecour', 'Place de la Comedie', CURRENT_DATE, '17:00', CURRENT_DATE, '20:05', 185, 17, 3, 3, 'planifie', FALSE, 2),
    (1156, 120, 125, 'Montpellier', 'Lyon', 'Place de la Comedie', 'Place Bellecour', CURRENT_DATE - INTERVAL '27 days', '13:00', CURRENT_DATE - INTERVAL '27 days', '16:05', 185, 18, 4, 0, 'termine', FALSE, 2),
    (1157, 110, 112, 'Montpellier', 'Lyon', 'Place de la Comedie', 'Place Bellecour', CURRENT_DATE + INTERVAL '42 days', '13:00', CURRENT_DATE + INTERVAL '42 days', '16:05', 185, 20, 4, 4, 'planifie', FALSE, 2),
    (1158, 107, 107, 'Montpellier', 'Lyon', 'Place de la Comedie', 'Place Bellecour', CURRENT_DATE + INTERVAL '21 days', '07:00', CURRENT_DATE + INTERVAL '21 days', '10:05', 185, 20, 3, 1, 'planifie', TRUE, 2),
    (1159, 112, 116, 'Lyon', 'Strasbourg', 'Place Bellecour', 'Place Kleber', CURRENT_DATE + INTERVAL '1 days', '09:00', CURRENT_DATE + INTERVAL '1 days', '13:50', 290, 24, 3, 2, 'planifie', FALSE, 2),
    (1160, 105, 102, 'Lyon', 'Strasbourg', 'Place Bellecour', 'Place Kleber', CURRENT_DATE - INTERVAL '20 days', '10:00', CURRENT_DATE - INTERVAL '20 days', '14:50', 290, 25, 3, 0, 'termine', TRUE, 2),
    (1161, 105, 103, 'Lyon', 'Strasbourg', 'Place Bellecour', 'Place Kleber', CURRENT_DATE + INTERVAL '85 days', '16:00', CURRENT_DATE + INTERVAL '85 days', '20:50', 290, 27, 3, 3, 'planifie', TRUE, 2),
    (1162, 105, 102, 'Strasbourg', 'Lyon', 'Place Kleber', 'Place Bellecour', CURRENT_DATE + INTERVAL '29 days', '17:00', CURRENT_DATE + INTERVAL '29 days', '21:50', 290, 28, 3, 2, 'planifie', TRUE, 2),
    (1163, 109, 110, 'Strasbourg', 'Lyon', 'Place Kleber', 'Place Bellecour', CURRENT_DATE - INTERVAL '24 days', '10:00', CURRENT_DATE - INTERVAL '24 days', '14:50', 290, 24, 3, 0, 'termine', FALSE, 2),
    (1164, 105, 103, 'Strasbourg', 'Lyon', 'Place Kleber', 'Place Bellecour', CURRENT_DATE + INTERVAL '6 days', '18:00', CURRENT_DATE + INTERVAL '6 days', '22:50', 290, 28, 3, 1, 'planifie', TRUE, 2),
    (1165, 120, 125, 'Marseille', 'Nice', 'Gare Saint-Charles', 'Promenade des Anglais', CURRENT_DATE + INTERVAL '83 days', '17:00', CURRENT_DATE + INTERVAL '83 days', '19:10', 130, 11, 4, 1, 'planifie', FALSE, 2),
    (1166, 116, 121, 'Marseille', 'Nice', 'Gare Saint-Charles', 'Promenade des Anglais', CURRENT_DATE + INTERVAL '39 days', '13:00', CURRENT_DATE + INTERVAL '39 days', '15:10', 130, 11, 3, 1, 'planifie', FALSE, 2),
    (1167, 106, 105, 'Marseille', 'Nice', 'Gare Saint-Charles', 'Promenade des Anglais', CURRENT_DATE - INTERVAL '29 days', '14:00', CURRENT_DATE - INTERVAL '29 days', '16:10', 130, 12, 3, 1, 'termine', TRUE, 2),
    (1168, 110, 113, 'Nice', 'Marseille', 'Promenade des Anglais', 'Gare Saint-Charles', CURRENT_DATE - INTERVAL '9 days', '09:00', CURRENT_DATE - INTERVAL '9 days', '11:10', 130, 11, 4, 1, 'termine', FALSE, 2),
    (1169, 115, 120, 'Nice', 'Marseille', 'Promenade des Anglais', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '29 days', '07:00', CURRENT_DATE + INTERVAL '29 days', '09:10', 130, 10, 4, 2, 'planifie', FALSE, 2),
    (1170, 120, 125, 'Nice', 'Marseille', 'Promenade des Anglais', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '90 days', '18:00', CURRENT_DATE + INTERVAL '90 days', '20:10', 130, 15, 4, 4, 'planifie', FALSE, 2),
    (1171, 114, 119, 'Marseille', 'Toulouse', 'Gare Saint-Charles', 'Place du Capitole', CURRENT_DATE + INTERVAL '81 days', '08:00', CURRENT_DATE + INTERVAL '81 days', '12:00', 240, 24, 3, 1, 'planifie', FALSE, 2),
    (1172, 116, 121, 'Marseille', 'Toulouse', 'Gare Saint-Charles', 'Place du Capitole', CURRENT_DATE - INTERVAL '13 days', '06:00', CURRENT_DATE - INTERVAL '13 days', '10:00', 240, 25, 3, 3, 'termine', FALSE, 2),
    (1173, 114, 119, 'Marseille', 'Toulouse', 'Gare Saint-Charles', 'Place du Capitole', CURRENT_DATE + INTERVAL '50 days', '14:00', CURRENT_DATE + INTERVAL '50 days', '18:00', 240, 24, 3, 3, 'planifie', FALSE, 2),
    (1174, 112, 116, 'Toulouse', 'Marseille', 'Place du Capitole', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '45 days', '06:00', CURRENT_DATE + INTERVAL '45 days', '10:00', 240, 24, 3, 1, 'planifie', FALSE, 2),
    (1175, 109, 111, 'Toulouse', 'Marseille', 'Place du Capitole', 'Gare Saint-Charles', CURRENT_DATE + INTERVAL '90 days', '10:00', CURRENT_DATE + INTERVAL '90 days', '14:00', 240, 23, 3, 1, 'planifie', FALSE, 2),
    (1176, 109, 111, 'Toulouse', 'Marseille', 'Place du Capitole', 'Gare Saint-Charles', CURRENT_DATE - INTERVAL '27 days', '13:00', CURRENT_DATE - INTERVAL '27 days', '17:00', 240, 24, 3, 1, 'termine', FALSE, 2),
    (1177, 109, 111, 'Bordeaux', 'Toulouse', 'Place de la Victoire', 'Place du Capitole', CURRENT_DATE + INTERVAL '55 days', '16:00', CURRENT_DATE + INTERVAL '55 days', '18:30', 150, 17, 3, 1, 'planifie', FALSE, 2),
    (1178, 113, 118, 'Bordeaux', 'Toulouse', 'Place de la Victoire', 'Place du Capitole', CURRENT_DATE - INTERVAL '30 days', '18:00', CURRENT_DATE - INTERVAL '30 days', '20:30', 150, 15, 4, 2, 'termine', FALSE, 2),
    (1179, 113, 118, 'Bordeaux', 'Toulouse', 'Place de la Victoire', 'Place du Capitole', CURRENT_DATE - INTERVAL '28 days', '16:00', CURRENT_DATE - INTERVAL '28 days', '18:30', 150, 15, 4, 0, 'termine', FALSE, 2),
    (1180, 107, 106, 'Toulouse', 'Bordeaux', 'Place du Capitole', 'Place de la Victoire', CURRENT_DATE + INTERVAL '26 days', '18:00', CURRENT_DATE + INTERVAL '26 days', '20:30', 150, 12, 4, 4, 'planifie', TRUE, 2),
    (1181, 116, 121, 'Toulouse', 'Bordeaux', 'Place du Capitole', 'Place de la Victoire', CURRENT_DATE + INTERVAL '73 days', '07:00', CURRENT_DATE + INTERVAL '73 days', '09:30', 150, 17, 3, 2, 'planifie', FALSE, 2),
    (1182, 118, 123, 'Toulouse', 'Bordeaux', 'Place du Capitole', 'Place de la Victoire', CURRENT_DATE + INTERVAL '63 days', '10:00', CURRENT_DATE + INTERVAL '63 days', '12:30', 150, 14, 4, 3, 'planifie', FALSE, 2),
    (1183, 103, 101, 'Bordeaux', 'Nantes', 'Place de la Victoire', 'Place du Commerce', CURRENT_DATE + INTERVAL '74 days', '08:00', CURRENT_DATE + INTERVAL '74 days', '11:20', 200, 17, 3, 3, 'planifie', TRUE, 2),
    (1184, 114, 119, 'Bordeaux', 'Nantes', 'Place de la Victoire', 'Place du Commerce', CURRENT_DATE + INTERVAL '7 days', '14:00', CURRENT_DATE + INTERVAL '7 days', '17:20', 200, 18, 3, 1, 'planifie', FALSE, 2),
    (1185, 114, 119, 'Bordeaux', 'Nantes', 'Place de la Victoire', 'Place du Commerce', CURRENT_DATE + INTERVAL '19 days', '08:00', CURRENT_DATE + INTERVAL '19 days', '11:20', 200, 20, 3, 3, 'planifie', FALSE, 2),
    (1186, 116, 121, 'Nantes', 'Bordeaux', 'Place du Commerce', 'Place de la Victoire', CURRENT_DATE + INTERVAL '8 days', '17:00', CURRENT_DATE + INTERVAL '8 days', '20:20', 200, 20, 3, 2, 'planifie', FALSE, 2),
    (1187, 113, 118, 'Nantes', 'Bordeaux', 'Place du Commerce', 'Place de la Victoire', CURRENT_DATE + INTERVAL '1 days', '08:00', CURRENT_DATE + INTERVAL '1 days', '11:20', 200, 20, 4, 2, 'planifie', FALSE, 2),
    (1188, 117, 122, 'Nantes', 'Bordeaux', 'Place du Commerce', 'Place de la Victoire', CURRENT_DATE + INTERVAL '8 days', '08:00', CURRENT_DATE + INTERVAL '8 days', '11:20', 200, 22, 3, 2, 'planifie', FALSE, 2),
    (1189, 105, 103, 'Nantes', 'Rennes', 'Place du Commerce', 'Place de la Republique', CURRENT_DATE + INTERVAL '51 days', '16:00', CURRENT_DATE + INTERVAL '51 days', '17:15', 75, 10, 3, 3, 'planifie', TRUE, 2),
    (1190, 113, 118, 'Nantes', 'Rennes', 'Place du Commerce', 'Place de la Republique', CURRENT_DATE + INTERVAL '35 days', '13:00', CURRENT_DATE + INTERVAL '35 days', '14:15', 75, 9, 4, 3, 'planifie', FALSE, 2),
    (1191, 115, 120, 'Nantes', 'Rennes', 'Place du Commerce', 'Place de la Republique', CURRENT_DATE + INTERVAL '72 days', '18:00', CURRENT_DATE + INTERVAL '72 days', '19:15', 75, 9, 4, 2, 'planifie', FALSE, 2),
    (1192, 117, 122, 'Rennes', 'Nantes', 'Place de la Republique', 'Place du Commerce', CURRENT_DATE - INTERVAL '29 days', '14:00', CURRENT_DATE - INTERVAL '29 days', '15:15', 75, 9, 3, 2, 'termine', FALSE, 2),
    (1193, 116, 121, 'Rennes', 'Nantes', 'Place de la Republique', 'Place du Commerce', CURRENT_DATE + INTERVAL '79 days', '09:00', CURRENT_DATE + INTERVAL '79 days', '10:15', 75, 9, 3, 1, 'planifie', FALSE, 2),
    (1194, 109, 111, 'Rennes', 'Nantes', 'Place de la Republique', 'Place du Commerce', CURRENT_DATE - INTERVAL '17 days', '09:00', CURRENT_DATE - INTERVAL '17 days', '10:15', 75, 7, 3, 3, 'termine', FALSE, 2),
    (1195, 120, 125, 'Montpellier', 'Toulouse', 'Place de la Comedie', 'Place du Capitole', CURRENT_DATE + INTERVAL '74 days', '08:00', CURRENT_DATE + INTERVAL '74 days', '10:30', 150, 14, 4, 1, 'planifie', FALSE, 2),
    (1196, 116, 121, 'Montpellier', 'Toulouse', 'Place de la Comedie', 'Place du Capitole', CURRENT_DATE - INTERVAL '18 days', '07:00', CURRENT_DATE - INTERVAL '18 days', '09:30', 150, 13, 3, 2, 'termine', FALSE, 2),
    (1197, 107, 107, 'Montpellier', 'Toulouse', 'Place de la Comedie', 'Place du Capitole', CURRENT_DATE + INTERVAL '51 days', '17:00', CURRENT_DATE + INTERVAL '51 days', '19:30', 150, 16, 3, 2, 'planifie', TRUE, 2),
    (1198, 106, 105, 'Toulouse', 'Montpellier', 'Place du Capitole', 'Place de la Comedie', CURRENT_DATE + INTERVAL '84 days', '06:00', CURRENT_DATE + INTERVAL '84 days', '08:30', 150, 12, 3, 2, 'planifie', TRUE, 2),
    (1199, 107, 106, 'Toulouse', 'Montpellier', 'Place du Capitole', 'Place de la Comedie', CURRENT_DATE + INTERVAL '50 days', '14:00', CURRENT_DATE + INTERVAL '50 days', '16:30', 150, 12, 4, 4, 'planifie', TRUE, 2),
    (1200, 107, 106, 'Toulouse', 'Montpellier', 'Place du Capitole', 'Place de la Comedie', CURRENT_DATE + INTERVAL '13 days', '18:00', CURRENT_DATE + INTERVAL '13 days', '20:30', 150, 13, 4, 2, 'planifie', TRUE, 2),
    (1201, 107, 107, 'Nice', 'Lyon', 'Promenade des Anglais', 'Place Bellecour', CURRENT_DATE + INTERVAL '26 days', '16:00', CURRENT_DATE + INTERVAL '26 days', '20:50', 290, 30, 3, 1, 'planifie', TRUE, 2),
    (1202, 118, 123, 'Nice', 'Lyon', 'Promenade des Anglais', 'Place Bellecour', CURRENT_DATE - INTERVAL '19 days', '06:00', CURRENT_DATE - INTERVAL '19 days', '10:50', 290, 29, 4, 0, 'termine', FALSE, 2),
    (1203, 118, 123, 'Nice', 'Lyon', 'Promenade des Anglais', 'Place Bellecour', CURRENT_DATE + INTERVAL '26 days', '16:00', CURRENT_DATE + INTERVAL '26 days', '20:50', 290, 25, 4, 1, 'planifie', FALSE, 2),
    (1204, 117, 122, 'Lyon', 'Nice', 'Place Bellecour', 'Promenade des Anglais', CURRENT_DATE - INTERVAL '24 days', '14:00', CURRENT_DATE - INTERVAL '24 days', '18:50', 290, 26, 3, 1, 'termine', FALSE, 2),
    (1205, 109, 110, 'Lyon', 'Nice', 'Place Bellecour', 'Promenade des Anglais', CURRENT_DATE + INTERVAL '24 days', '07:00', CURRENT_DATE + INTERVAL '24 days', '11:50', 290, 27, 3, 3, 'planifie', FALSE, 2),
    (1206, 117, 122, 'Lyon', 'Nice', 'Place Bellecour', 'Promenade des Anglais', CURRENT_DATE + INTERVAL '47 days', '10:00', CURRENT_DATE + INTERVAL '47 days', '14:50', 290, 27, 3, 2, 'planifie', FALSE, 2);


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
    (1001, 1025, 123, 'terminee', 25, TRUE, CURRENT_DATE, NULL, TRUE),
    (1002, 1013, 128, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '3 days', NULL, TRUE),
    (1003, 1013, 125, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '3 days', NULL, TRUE),
    (1004, 1013, 118, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '3 days', NULL, TRUE),
    (1005, 1122, 126, 'terminee', 17, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (1006, 1122, 113, 'terminee', 17, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (1007, 1122, 121, 'terminee', 17, NULL, NULL, NULL, FALSE),
    (1008, 1003, 109, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '6 days', NULL, TRUE),
    (1009, 1003, 104, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '6 days', NULL, TRUE),
    (1010, 1008, 113, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (1011, 1008, 107, 'terminee', 25, NULL, NULL, NULL, FALSE),
    (1012, 1008, 106, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (1013, 1011, 127, 'terminee', 25, FALSE, CURRENT_DATE - INTERVAL '4 days', 'Le chauffeur est arrive avec 45 minutes de retard sans prevenir.', FALSE),
    (1014, 1011, 116, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '4 days', NULL, TRUE),
    (1015, 1001, 128, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '6 days', NULL, TRUE),
    (1016, 1004, 121, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '6 days', NULL, TRUE),
    (1017, 1018, 113, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (1018, 1018, 107, 'terminee', 25, NULL, NULL, NULL, FALSE),
    (1019, 1204, 122, 'terminee', 26, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (1020, 1204, 116, 'terminee', 26, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (1021, 1145, 129, 'terminee', 20, TRUE, CURRENT_DATE - INTERVAL '19 days', NULL, TRUE),
    (1022, 1145, 107, 'terminee', 20, TRUE, CURRENT_DATE - INTERVAL '19 days', NULL, TRUE),
    (1023, 1150, 103, 'terminee', 20, TRUE, CURRENT_DATE - INTERVAL '14 days', NULL, TRUE),
    (1024, 1150, 106, 'terminee', 20, TRUE, CURRENT_DATE - INTERVAL '14 days', NULL, TRUE),
    (1025, 1192, 113, 'terminee', 9, TRUE, CURRENT_DATE - INTERVAL '28 days', NULL, TRUE),
    (1026, 1021, 130, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '1 days', NULL, TRUE),
    (1027, 1021, 121, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '1 days', NULL, TRUE),
    (1028, 1007, 125, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (1029, 1007, 107, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (1030, 1007, 116, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (1031, 1016, 121, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '3 days', NULL, TRUE),
    (1032, 1016, 115, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '3 days', NULL, TRUE),
    (1033, 1016, 110, 'terminee', 25, NULL, NULL, NULL, FALSE),
    (1034, 1010, 125, 'terminee', 25, NULL, NULL, NULL, FALSE),
    (1035, 1179, 114, 'terminee', 15, TRUE, CURRENT_DATE - INTERVAL '27 days', NULL, TRUE),
    (1036, 1179, 112, 'terminee', 15, TRUE, CURRENT_DATE - INTERVAL '27 days', NULL, TRUE),
    (1037, 1179, 107, 'terminee', 15, NULL, NULL, NULL, FALSE),
    (1038, 1137, 113, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (1039, 1009, 120, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '4 days', NULL, TRUE),
    (1040, 1163, 104, 'terminee', 24, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (1041, 1163, 115, 'terminee', 24, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (1042, 1163, 130, 'terminee', 24, TRUE, CURRENT_DATE - INTERVAL '23 days', NULL, TRUE),
    (1043, 1020, 129, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (1044, 1020, 115, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (1045, 1176, 124, 'terminee', 24, FALSE, CURRENT_DATE - INTERVAL '26 days', 'La voiture sentait tres fort la cigarette alors que l''annonce indiquait non-fumeur.', FALSE),
    (1046, 1176, 123, 'terminee', 24, TRUE, CURRENT_DATE - INTERVAL '26 days', NULL, TRUE),
    (1047, 1196, 106, 'terminee', 13, TRUE, CURRENT_DATE - INTERVAL '17 days', NULL, TRUE),
    (1048, 1154, 110, 'terminee', 19, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (1049, 1017, 114, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (1050, 1017, 108, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (1051, 1017, 115, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (1052, 1160, 110, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '19 days', NULL, TRUE),
    (1053, 1160, 123, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '19 days', NULL, TRUE),
    (1054, 1160, 121, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '19 days', NULL, TRUE),
    (1055, 1178, 129, 'terminee', 15, TRUE, CURRENT_DATE - INTERVAL '29 days', NULL, TRUE),
    (1056, 1178, 114, 'terminee', 15, TRUE, CURRENT_DATE - INTERVAL '29 days', NULL, TRUE),
    (1057, 1120, 112, 'terminee', 17, TRUE, CURRENT_DATE - INTERVAL '27 days', NULL, TRUE),
    (1058, 1023, 126, 'terminee', 25, FALSE, CURRENT_DATE - INTERVAL '1 days', 'Le chauffeur a change le lieu de depart au dernier moment, j''ai du payer un taxi.', FALSE),
    (1059, 1023, 105, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '1 days', NULL, TRUE),
    (1060, 1023, 124, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '1 days', NULL, TRUE),
    (1061, 1019, 128, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (1062, 1019, 115, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '2 days', NULL, TRUE),
    (1063, 1019, 120, 'terminee', 25, NULL, NULL, NULL, FALSE),
    (1064, 1167, 104, 'terminee', 12, TRUE, CURRENT_DATE - INTERVAL '28 days', NULL, TRUE),
    (1065, 1167, 120, 'terminee', 12, TRUE, CURRENT_DATE - INTERVAL '28 days', NULL, TRUE),
    (1066, 1156, 103, 'terminee', 18, TRUE, CURRENT_DATE - INTERVAL '26 days', NULL, TRUE),
    (1067, 1156, 125, 'terminee', 18, TRUE, CURRENT_DATE - INTERVAL '26 days', NULL, TRUE),
    (1068, 1156, 112, 'terminee', 18, TRUE, CURRENT_DATE - INTERVAL '26 days', NULL, TRUE),
    (1069, 1006, 116, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (1070, 1006, 103, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (1071, 1006, 109, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (1072, 1168, 103, 'terminee', 11, TRUE, CURRENT_DATE - INTERVAL '8 days', NULL, TRUE),
    (1073, 1168, 105, 'terminee', 11, NULL, NULL, NULL, FALSE),
    (1074, 1168, 104, 'terminee', 11, TRUE, CURRENT_DATE - INTERVAL '8 days', NULL, TRUE),
    (1075, 1117, 103, 'terminee', 15, TRUE, CURRENT_DATE - INTERVAL '24 days', NULL, TRUE),
    (1076, 1005, 122, 'terminee', 25, TRUE, CURRENT_DATE - INTERVAL '5 days', NULL, TRUE),
    (1077, 1202, 104, 'terminee', 29, TRUE, CURRENT_DATE - INTERVAL '18 days', NULL, TRUE),
    (1078, 1202, 109, 'terminee', 29, TRUE, CURRENT_DATE - INTERVAL '18 days', NULL, TRUE),
    (1079, 1202, 128, 'terminee', 29, TRUE, CURRENT_DATE - INTERVAL '18 days', NULL, TRUE),
    (1080, 1053, 104, 'confirmee', 25, NULL, NULL, NULL, FALSE);


-- --------------------------------------------
-- 8. LES AVIS (32 : 22 validés, 10 en attente)
--
-- Seuls les avis 'valide' comptent dans la note affichée (US 3).
-- Les avis 'en_attente' alimentent l'espace employé (US 12).
-- --------------------------------------------
INSERT INTO avis (avis_id, covoiturage_id, passager_id, chauffeur_id,
                  note, commentaire, statut, created_at) VALUES
    (1001, 1025, 123, 106, 5, 'Excellent covoiturage, on a bien discute.', 'valide', CURRENT_DATE),
    (1002, 1013, 128, 108, 3, 'Voiture propre et confortable.', 'valide', CURRENT_DATE - INTERVAL '3 days'),
    (1003, 1013, 125, 108, 4, 'Trajet tres agreable, chauffeur ponctuel.', 'valide', CURRENT_DATE - INTERVAL '3 days'),
    (1004, 1122, 126, 106, 5, 'Excellent covoiturage, on a bien discute.', 'valide', CURRENT_DATE - INTERVAL '23 days'),
    (1005, 1003, 104, 112, 5, 'Trajet tres agreable, chauffeur ponctuel.', 'valide', CURRENT_DATE - INTERVAL '6 days'),
    (1006, 1004, 121, 117, 5, 'Excellent covoiturage, on a bien discute.', 'valide', CURRENT_DATE - INTERVAL '6 days'),
    (1007, 1018, 113, 108, 4, 'Excellent covoiturage, on a bien discute.', 'valide', CURRENT_DATE - INTERVAL '2 days'),
    (1008, 1145, 107, 115, 3, 'Ponctuel et sympathique, rien a redire.', 'valide', CURRENT_DATE - INTERVAL '19 days'),
    (1009, 1150, 103, 108, 5, 'Trajet tres agreable, chauffeur ponctuel.', 'valide', CURRENT_DATE - INTERVAL '14 days'),
    (1010, 1150, 106, 108, 5, 'Tout s''est bien passe, merci beaucoup.', 'valide', CURRENT_DATE - INTERVAL '14 days'),
    (1011, 1021, 121, 105, 5, 'Ponctuel et sympathique, rien a redire.', 'valide', CURRENT_DATE - INTERVAL '1 days'),
    (1012, 1007, 125, 103, 5, 'Conduite souple et bonne ambiance.', 'valide', CURRENT_DATE - INTERVAL '5 days'),
    (1013, 1007, 116, 103, 3, 'Trajet tres agreable, chauffeur ponctuel.', 'valide', CURRENT_DATE - INTERVAL '5 days'),
    (1014, 1016, 115, 114, 3, 'Super voyage, je recommande !', 'valide', CURRENT_DATE - INTERVAL '3 days'),
    (1015, 1179, 112, 113, 5, 'Tout s''est bien passe, merci beaucoup.', 'valide', CURRENT_DATE - INTERVAL '27 days'),
    (1016, 1137, 113, 117, 5, 'Parfait du debut a la fin.', 'valide', CURRENT_DATE - INTERVAL '2 days'),
    (1017, 1009, 120, 112, 4, 'Tout s''est bien passe, merci beaucoup.', 'valide', CURRENT_DATE - INTERVAL '4 days'),
    (1018, 1163, 130, 109, 5, 'Voiture propre et confortable.', 'valide', CURRENT_DATE - INTERVAL '23 days'),
    (1019, 1020, 115, 116, 4, 'Trajet tres agreable, chauffeur ponctuel.', 'valide', CURRENT_DATE - INTERVAL '2 days'),
    (1020, 1176, 123, 109, 4, 'Voiture propre et confortable.', 'valide', CURRENT_DATE - INTERVAL '26 days'),
    (1021, 1196, 106, 116, 5, 'Ponctuel et sympathique, rien a redire.', 'valide', CURRENT_DATE - INTERVAL '17 days'),
    (1022, 1154, 110, 105, 4, 'Parfait du debut a la fin.', 'valide', CURRENT_DATE - INTERVAL '2 days'),
    (1023, 1017, 114, 119, 5, 'Ponctuel et sympathique, rien a redire.', 'en_attente', CURRENT_DATE - INTERVAL '2 days'),
    (1024, 1017, 108, 119, 3, 'Excellent covoiturage, on a bien discute.', 'en_attente', CURRENT_DATE - INTERVAL '2 days'),
    (1025, 1017, 115, 119, 3, 'Voiture propre et confortable.', 'en_attente', CURRENT_DATE - INTERVAL '2 days'),
    (1026, 1178, 114, 113, 3, 'Tout s''est bien passe, merci beaucoup.', 'en_attente', CURRENT_DATE - INTERVAL '29 days'),
    (1027, 1120, 112, 115, 5, 'Ponctuel et sympathique, rien a redire.', 'en_attente', CURRENT_DATE - INTERVAL '27 days'),
    (1028, 1019, 115, 118, 4, 'Ponctuel et sympathique, rien a redire.', 'en_attente', CURRENT_DATE - INTERVAL '2 days'),
    (1029, 1167, 104, 106, 5, 'Voiture propre et confortable.', 'en_attente', CURRENT_DATE - INTERVAL '28 days'),
    (1030, 1167, 120, 106, 4, 'Ponctuel et sympathique, rien a redire.', 'en_attente', CURRENT_DATE - INTERVAL '28 days'),
    (1031, 1156, 125, 120, 4, 'Super voyage, je recommande !', 'en_attente', CURRENT_DATE - INTERVAL '26 days'),
    (1032, 1156, 112, 120, 3, 'Ponctuel et sympathique, rien a redire.', 'en_attente', CURRENT_DATE - INTERVAL '26 days');


-- --------------------------------------------
-- 9. REMISE À NIVEAU DES COMPTEURS D'IDENTIFIANTS
--
-- On a imposé les identifiants à la main (1, 2, 3...).
-- Sans ces lignes, la prochaine inscription réutiliserait l'identifiant 1
-- et provoquerait une erreur de doublon.
-- --------------------------------------------
-- On prend le PLUS GRAND identifiant réellement présent dans chaque table.
-- Impossible d'écraser un de mes comptes gardés, même si son numéro est
-- plus grand que ceux du jeu de test.
SELECT setval('users_user_id_seq',          (SELECT COALESCE(MAX(user_id), 1)        FROM users));
SELECT setval('roles_role_id_seq',          (SELECT COALESCE(MAX(role_id), 1)        FROM roles));
SELECT setval('vehicules_vehicule_id_seq',  (SELECT COALESCE(MAX(vehicule_id), 1)    FROM vehicules));
SELECT setval('covoiturages_covoiturage_id_seq',   (SELECT COALESCE(MAX(covoiturage_id), 1)   FROM covoiturages));
SELECT setval('participations_participation_id_seq', (SELECT COALESCE(MAX(participation_id), 1) FROM participations));
SELECT setval('avis_avis_id_seq',           (SELECT COALESCE(MAX(avis_id), 1)        FROM avis));
SELECT setval('preferences_preference_id_seq',     (SELECT COALESCE(MAX(preference_id), 1) FROM preferences));
SELECT setval('preferences_personnalisees_preference_perso_id_seq',
              (SELECT COALESCE(MAX(preference_perso_id), 1) FROM preferences_personnalisees));


-- --------------------------------------------
-- 10. VÉRIFICATION
--
-- Attendu : 33 comptes (30 du jeu de test + mes 3 comptes gardés),
-- et la deuxième requête doit afficher mes 3 comptes avec leurs données.
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

-- Mes comptes personnels : ils doivent apparaître, avec leurs crédits d'origine.
SELECT u.user_id, u.pseudo, u.email, u.credits,
       (SELECT COUNT(*) FROM vehicules     v WHERE v.user_id = u.user_id)     AS ses_vehicules,
       (SELECT COUNT(*) FROM covoiturages  c WHERE c.chauffeur_id = u.user_id) AS ses_trajets
  FROM users u
 WHERE u.email IN ('grcdtech@gmail.com', 'gracedoure1234@gmail.com', 'grcidd25@gmail.com')
 ORDER BY u.user_id;
