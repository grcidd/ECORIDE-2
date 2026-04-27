// routes/avis.routes.js

import express from "express";
import {
  soumettreAvis,
  getAvisChauffeur,
  peutNoter,
} from "../controllers/avis.controller.js";
import authMiddleware from "../middleware/auth.middleware.js";

const router = express.Router();

// Public
router.get("/chauffeur/:id", getAvisChauffeur);

// Connecté uniquement
router.post("/", authMiddleware, soumettreAvis);
router.get("/peux-noter/:covoiturage_id", authMiddleware, peutNoter);

export default router;
