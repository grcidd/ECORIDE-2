-- ============================================
-- ECORIDE — migration_v5.sql
-- Fermer la base aux accès directs (sécurité)
--
-- ⚠️ ORDRE OBLIGATOIRE — à faire DANS CET ORDRE, sinon le site tombe :
--   1. Mettre la clé "service_role" dans SUPABASE_KEY (.env en local ET Render)
--   2. Redémarrer / redéployer le serveur
--   3. Vérifier que le site fonctionne encore
--   4. SEULEMENT APRÈS : exécuter ce fichier dans Supabase > SQL Editor
--
-- ============================================
-- POURQUOI ? (explication pour le jury)
--
-- Supabase donne deux clés :
--   • la clé "anon"         → faite pour les NAVIGATEURS, donc publique ;
--   • la clé "service_role" → faite pour un SERVEUR de confiance, donc secrète.
--
-- EcoRide n'appelle jamais Supabase depuis le navigateur : le front parle
-- uniquement à notre API Express, qui vérifie elle-même le jeton JWT et le
-- rôle de l'utilisateur. La clé "anon" n'a donc aucune raison d'exister ici.
--
-- Le RLS (Row Level Security) est le pare-feu de PostgreSQL : si aucune règle
-- n'autorise une action, elle est refusée. La clé "service_role" passe
-- volontairement au-dessus du RLS : c'est prévu pour ça.
--
-- Résultat : plus aucune règle ouverte. Même si la clé publique se retrouve
-- dans du code visible, elle ne permet plus RIEN : ni lire les comptes,
-- ni modifier un trajet, ni écrire un faux avis.
-- ============================================


-- --------------------------------------------
-- 1. Supprimer les règles "tout le monde peut tout faire"
--    (elles disaient toutes USING (true) : aucune protection)
-- --------------------------------------------
DROP POLICY IF EXISTS "Allow select for everyone"              ON users;
DROP POLICY IF EXISTS "Allow insert for everyone"              ON users;

DROP POLICY IF EXISTS "Allow select for everyone on vehicules" ON vehicules;
DROP POLICY IF EXISTS "Allow insert for everyone on vehicules" ON vehicules;

DROP POLICY IF EXISTS "Allow select on covoiturages"           ON covoiturages;
DROP POLICY IF EXISTS "Allow insert on covoiturages"           ON covoiturages;
DROP POLICY IF EXISTS "Allow update on covoiturages"           ON covoiturages;

DROP POLICY IF EXISTS "Allow select on participations"         ON participations;
DROP POLICY IF EXISTS "Allow insert on participations"         ON participations;
DROP POLICY IF EXISTS "Allow update on participations"         ON participations;

DROP POLICY IF EXISTS "Allow select on preferences"            ON preferences;
DROP POLICY IF EXISTS "Allow insert on preferences"            ON preferences;
DROP POLICY IF EXISTS "Allow update on preferences"            ON preferences;


-- --------------------------------------------
-- 2. Activer le RLS sur TOUTES les tables, sans exception
--    (avis, roles, users... l'avaient déjà ;
--     preferences_personnalisees était restée sans protection)
-- --------------------------------------------
ALTER TABLE roles                      ENABLE ROW LEVEL SECURITY;
ALTER TABLE users                      ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicules                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE preferences                ENABLE ROW LEVEL SECURITY;
ALTER TABLE preferences_personnalisees ENABLE ROW LEVEL SECURITY;
ALTER TABLE covoiturages               ENABLE ROW LEVEL SECURITY;
ALTER TABLE participations             ENABLE ROW LEVEL SECURITY;
ALTER TABLE avis                       ENABLE ROW LEVEL SECURITY;

-- On ne crée AUCUNE règle : aucune action n'est autorisée pour la clé publique.
-- Seul notre serveur, avec la clé "service_role", peut encore travailler.


-- --------------------------------------------
-- 3. Vérification — à lancer après coup.
--    Attendu : rls_active = true partout, nb_regles = 0 partout.
-- --------------------------------------------
-- SELECT c.relname AS table_name,
--        c.relrowsecurity AS rls_active,
--        (SELECT count(*) FROM pg_policies p
--          WHERE p.schemaname = 'public' AND p.tablename = c.relname) AS nb_regles
--   FROM pg_class c
--   JOIN pg_namespace n ON n.oid = c.relnamespace
--  WHERE n.nspname = 'public' AND c.relkind = 'r'
--  ORDER BY c.relname;
