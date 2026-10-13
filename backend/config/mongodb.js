// ============================================
// Connexion à MongoDB Atlas (base NoSQL)
// Sert UNIQUEMENT aux logs et aux signalements.
// ============================================

import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config();

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
