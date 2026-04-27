// Connexion à MongoDB Atlas (NoSQL)
// Utilisé pour les logs et les signalements

import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config();

const connectMongo = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log("✅ MongoDB connecté");
  } catch (error) {
    console.error("❌ Erreur MongoDB :", error.message);
  }
};

export default connectMongo;
