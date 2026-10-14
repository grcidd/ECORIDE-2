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

// Garde-fou n°2 : on vérifie QUELLE clé est utilisée.
// Supabase fournit deux clés : "anon" (pour les navigateurs, publique) et
// "service_role" (pour un serveur de confiance, secrète).
// Notre API vérifie elle-même le JWT et le rôle : c'est la clé "service_role"
// qu'il lui faut. Avec la clé "anon", le pare-feu RLS de PostgreSQL bloque
// certaines écritures SANS message clair (ex : impossible d'enregistrer un avis).
try {
  // Une clé Supabase est un jeton JWT : sa partie du milieu contient le rôle.
  const milieu = process.env.SUPABASE_KEY.split(".")[1];
  const contenu = JSON.parse(Buffer.from(milieu, "base64").toString());

  if (contenu.role !== "service_role") {
    console.warn(
      "⚠️ SUPABASE_KEY est une clé « " + contenu.role + " ». " +
        "Le serveur a besoin de la clé « service_role » " +
        "(Supabase > Project Settings > API), sinon certaines écritures " +
        "seront refusées par le RLS."
    );
  }
} catch {
  // Format de clé inconnu (nouvelles clés sb_secret_... par exemple) :
  // on ne bloque rien, ce n'est qu'un avertissement.
}

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_KEY
);

export default supabase;
