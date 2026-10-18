// ============================================
// Connexion à MongoDB Atlas (base NoSQL)
// Sert UNIQUEMENT aux logs et aux signalements.
// ============================================

import mongoose from "mongoose";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

// Même précaution que dans supabase.js : on vise le fichier .env par son chemin exact.
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.resolve(__dirname, "../.env") });

// Par défaut, si MongoDB est injoignable, Mongoose MET EN ATTENTE les
// opérations pendant 10 secondes avant d'abandonner. Résultat : chaque
// connexion et chaque réservation prenait 10 secondes de plus, alors que
// le log n'est qu'un bonus.
// Avec bufferCommands à false, l'opération échoue tout de suite, le
// try/catch de l'appelant l'attrape, et la réponse part sans attendre.
mongoose.set("bufferCommands", false);

const connectMongo = async () => {
  // Pas d'adresse configurée → on ne tente même pas, et on le dit clairement.
  if (!process.env.MONGODB_URI) {
    console.warn("⚠️ MONGODB_URI absent : logs et signalements désactivés.");
    return;
  }

  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      // Au lieu d'attendre 30 secondes, on abandonne après 5 secondes.
      // Important : sans ça, une base en panne ralentissait tout le site.
      serverSelectionTimeoutMS: 5000,
    });
    console.log("✅ MongoDB connecté");
  } catch (error) {
    // On N'ARRÊTE PAS le serveur : le site doit continuer à fonctionner
    // même si seuls les logs sont indisponibles.
    console.error("❌ MongoDB indisponible :", error.message);
  }
};

export default connectMongo;
