// Schémas MongoDB — définit la structure des documents

import mongoose from "mongoose";

// --- Collection LOGS ---
// Trace toutes les actions importantes de l'application
const logSchema = new mongoose.Schema({
  type: String, // ex: 'connexion', 'inscription', 'reservation'
  user_id: Number, // l'id de l'utilisateur concerné
  pseudo: String,
  details: String, // description de l'action
  date: { type: Date, default: Date.now },
});

// --- Collection SIGNALEMENTS ---
// Quand un passager indique que le trajet s'est mal passé
const signalementSchema = new mongoose.Schema({
  covoiturage_id: Number,
  passager_id: Number,
  chauffeur_id: Number,
  commentaire: String,
  statut: { type: String, default: "en_attente" }, // 'en_attente', 'traite'
  date: { type: Date, default: Date.now },
});

export const Log = mongoose.model("Log", logSchema);
export const Signalement = mongoose.model("Signalement", signalementSchema);
