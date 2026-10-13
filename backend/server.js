// ============================================
// ECORIDE — Serveur principal (API REST)
// C'est le "chef d'orchestre" : il démarre le serveur,
// branche les sécurités, puis distribue les requêtes aux routes.
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

// Charge les variables secrètes du fichier .env (clés, mots de passe)
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// --------------------------------------------
// SÉCURITÉ CORS
// Par défaut, un navigateur interdit à un site d'appeler une API
// hébergée ailleurs. CORS sert à dire "ce site-là a le droit".
// AVANT : cors() tout court = le monde entier avait le droit.
// MAINTENANT : uniquement mon site Netlify + mon PC pour développer.
// --------------------------------------------
const originesAutorisees = [
  process.env.FRONTEND_URL || "https://ecoride2.netlify.app",
  "http://localhost:3000",
  "http://localhost:5500",
  "http://127.0.0.1:5500", // Live Server de VS Code
];

app.use(
  cors({
    origin: (origin, callback) => {
      // Pas d'origine = appel hors navigateur (Postman, curl, tests) → autorisé
      if (!origin) return callback(null, true);

      if (originesAutorisees.includes(origin)) {
        return callback(null, true);
      }
      // Site inconnu → refusé
      return callback(new Error("Origine non autorisée par CORS : " + origin));
    },
  })
);

// Permet de lire le JSON envoyé par le front dans req.body
app.use(express.json());

// --------------------------------------------
// Connexion à MongoDB (logs + signalements)
// Si elle échoue, l'application CONTINUE de tourner :
// seules les fonctions de logs seront indisponibles.
// --------------------------------------------
connectMongo();

// --------------------------------------------
// ROUTES — chaque préfixe mène à son fichier de routes
// --------------------------------------------
app.use("/api/auth", authRoutes);
app.use("/api/covoiturages", covoituragesRoutes);
app.use("/api/utilisateurs", utilisateursRoutes);
app.use("/api/avis", avisRoutes);
app.use("/api/admin", adminRoutes);

// Route de test : permet de vérifier d'un coup d'œil que le serveur répond
app.get("/", (req, res) => {
  res.json({ message: "✅ Serveur EcoRide en ligne" });
});

// --------------------------------------------
// Adresse inconnue → message clair au lieu d'une page HTML d'erreur
// --------------------------------------------
app.use((req, res) => {
  res.status(404).json({ message: "Route introuvable : " + req.originalUrl });
});

// --------------------------------------------
// Filet de sécurité : attrape toute erreur non gérée
// pour que le serveur ne s'arrête jamais brutalement.
// --------------------------------------------
app.use((err, req, res, next) => {
  console.error("❌ Erreur non gérée :", err.message);
  res.status(500).json({ message: "Erreur serveur." });
});

app.listen(PORT, () => {
  console.log(`✅ Serveur lancé sur le port ${PORT}`);
});
