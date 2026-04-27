// ============================================
// ECORIDE — Serveur principal
// ============================================

import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import connectMongo from "./config/mongodb.js";
import authRoutes from "./routes/auth.routes.js";
import covoituragesRoutes from "./routes/covoiturages.routes.js";
import utilisateursRoutes from "./routes/utilisateurs.routes.js";
import adminRoutes from "./routes/admin.routes.js";
import avisRoutes from "./routes/avis.routes.js";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// ---- Middlewares globaux ----
app.use(cors());
app.use(express.json());
app.use("/api/avis", avisRoutes);

// ---- Connexion MongoDB ----
connectMongo();

// ---- Routes ----
app.use("/api/auth", authRoutes);
app.use("/api/covoiturages", covoituragesRoutes);
app.use("/api/utilisateurs", utilisateursRoutes);
app.use("/api/admin", adminRoutes);

// Route de test
app.get("/", (req, res) => {
  res.json({ message: "✅ Serveur EcoRide en ligne" });
});

// ---- Démarrage ----
app.listen(PORT, () => {
  console.log(`✅ Serveur lancé sur http://localhost:${PORT}`);
});
