// ============================================
// ECORIDE — Données de test pour MongoDB
//
// MongoDB sert à deux choses dans le projet :
//   - les LOGS  : la trace des actions importantes
//   - les SIGNALEMENTS : quand un passager dit que le trajet s'est mal passé (US 11)
//
// À lancer DEPUIS LA RACINE DU PROJET, APRÈS avoir exécuté seed.sql :
//     node database/seed_mongo.js
//
// ⚠️ Les identifiants ci-dessous (covoiturage_id, passager_id, chauffeur_id)
// correspondent EXACTEMENT aux 3 participations marquées « mal passé »
// dans seed.sql. Si tu regénères seed.sql, il faut les remettre à jour.
// ============================================

import mongoose from "mongoose";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";
import { Log, Signalement } from "../backend/config/models.mongo.js";

// On vise le fichier .env par son chemin exact (même méthode que le serveur)
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.resolve(__dirname, "../backend/.env") });

// --------------------------------------------
// Les 3 signalements (US 11 et US 12)
// statut 'en_attente' = l'employé ne l'a pas encore traité,
// donc le chauffeur n'est pas encore payé.
// --------------------------------------------
const signalements = [
  {
    covoiturage_id: 11,
    passager_id: 27,
    chauffeur_id: 8,
    commentaire: "Le chauffeur est arrive avec 45 minutes de retard sans prevenir.",
    statut: "en_attente",
  },
  {
    covoiturage_id: 176,
    passager_id: 24,
    chauffeur_id: 9,
    commentaire:
      "La voiture sentait tres fort la cigarette alors que l'annonce indiquait non-fumeur.",
    statut: "en_attente",
  },
  {
    covoiturage_id: 23,
    passager_id: 26,
    chauffeur_id: 10,
    commentaire:
      "Le chauffeur a change le lieu de depart au dernier moment, j'ai du payer un taxi.",
    statut: "en_attente",
  },
];

// --------------------------------------------
// Quelques logs, pour montrer que la collection vit
// --------------------------------------------
const logs = [
  { type: "inscription", user_id: 4,  pseudo: "gracie_p",   details: "Nouveau compte créé" },
  { type: "connexion",   user_id: 4,  pseudo: "gracie_p",   details: "Connexion réussie" },
  { type: "connexion",   user_id: 3,  pseudo: "lisa_drive", details: "Connexion réussie" },
  { type: "reservation", user_id: 4,  pseudo: "gracie_p",   details: "Réservation trajet #11" },
  { type: "signalement", user_id: 27, pseudo: "adam_v",     details: "Trajet #11 signalé comme mal passé" },
];

async function remplir() {
  // 1) On vérifie que l'adresse de la base est bien configurée
  if (!process.env.MONGODB_URI) {
    console.error("❌ MONGODB_URI est absent de backend/.env — rien à faire.");
    process.exit(1);
  }

  try {
    // 2) Connexion
    await mongoose.connect(process.env.MONGODB_URI, {
      serverSelectionTimeoutMS: 8000, // on n'attend pas 30 secondes si la base ne répond pas
    });
    console.log("✅ MongoDB connecté");

    // 3) On vide les deux collections pour repartir propre
    await Signalement.deleteMany({});
    await Log.deleteMany({});
    console.log("🧹 Collections vidées");

    // 4) On insère les nouvelles données
    await Signalement.insertMany(signalements);
    await Log.insertMany(logs);

    console.log(`✅ ${signalements.length} signalements insérés`);
    console.log(`✅ ${logs.length} logs insérés`);
    console.log("");
    console.log("Pour vérifier dans MongoDB Atlas :");
    console.log("  base « ecoride » > collections « signalements » et « logs »");
  } catch (erreur) {
    console.error("❌ Erreur :", erreur.message);
    process.exit(1);
  } finally {
    // 5) On ferme proprement, sinon le script ne se termine jamais
    await mongoose.connection.close();
  }
}

remplir();
