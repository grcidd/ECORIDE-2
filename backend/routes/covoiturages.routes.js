import express from "express";
import {
  rechercher,
  getDetail,
  participer,
  creer,
  historique,
  demarrer,
  terminer,
} from "../controllers/covoiturages.controller.js";
import authMiddleware from "../middleware/auth.middleware.js";

const router = express.Router();

// Routes publiques (pas besoin d'être connecté)
router.get("/", rechercher); // recherche de trajets
router.get("/historique", authMiddleware, historique); // historique perso
router.get("/:id", getDetail); // détail d'un trajet

// Routes protégées (faut être connecté)
router.post("/", authMiddleware, creer); // créer un trajet
router.post("/:id/participer", authMiddleware, participer); // réserver
router.patch("/:id/demarrer", authMiddleware, demarrer); // démarrer
router.patch("/:id/terminer", authMiddleware, terminer); // terminer

export default router;
