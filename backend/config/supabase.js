// ============================================
// Connexion à Supabase (notre base PostgreSQL)
// Ce fichier crée UN SEUL client, réutilisé partout dans l'application.
// ============================================

import { createClient } from "@supabase/supabase-js";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

// Astuce : en mode "module", __dirname n'existe pas.
// Ces 2 lignes le recréent pour pouvoir viser le .env à coup sûr.
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, "../.env") });

// Garde-fou : si les clés manquent, on prévient TOUT DE SUITE avec un message clair.
// Sans ça, l'erreur n'apparaissait qu'au premier appel, sous la forme d'un "500" mystérieux.
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_KEY) {
  console.error(
    "❌ SUPABASE_URL ou SUPABASE_KEY est absent du fichier .env — la base ne répondra pas."
  );
}

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_KEY
);

export default supabase;
