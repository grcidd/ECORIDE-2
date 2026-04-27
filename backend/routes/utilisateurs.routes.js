import express from "express";
import {
  mettreAJourRole,
  getVehicules,
  ajouterVehicule,
  sauvegarderPreferences,
  getTousLesUtilisateurs,
  suspendreCompte,
  creerEmploye,
} from "../controllers/utilisateurs.controller.js";
import authMiddleware, { checkRole } from "../middleware/auth.middleware.js";

const router = express.Router();

// Routes utilisateur connecté
router.patch("/role", authMiddleware, mettreAJourRole);
router.get("/vehicules", authMiddleware, getVehicules);
router.post("/vehicules", authMiddleware, ajouterVehicule);
router.post("/preferences", authMiddleware, sauvegarderPreferences);

// Routes admin uniquement (role_id = 3)
router.get("/", authMiddleware, checkRole(3), getTousLesUtilisateurs);
router.patch("/:id/suspendre", authMiddleware, checkRole(3), suspendreCompte);
router.post("/employe", authMiddleware, checkRole(3), creerEmploye);

export default router;
