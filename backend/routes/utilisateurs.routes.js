import express from "express";
import {
  mettreAJourRole,
  getVehicules,
  ajouterVehicule,
  sauvegarderPreferences,
  getPreferences,
  ajouterPreferencePerso,
  supprimerPreferencePerso,
  getTousLesUtilisateurs,
  suspendreCompte,
  creerEmploye,
} from "../controllers/utilisateurs.controller.js";
import authMiddleware, { checkRole, ROLES } from "../middleware/auth.middleware.js";

const router = express.Router();

// Routes utilisateur connecté
router.patch("/role", authMiddleware, mettreAJourRole);
router.get("/vehicules", authMiddleware, getVehicules);
router.post("/vehicules", authMiddleware, ajouterVehicule);
router.get("/preferences", authMiddleware, getPreferences);
router.post("/preferences", authMiddleware, sauvegarderPreferences);

// US 8 : les préférences personnalisées (autant qu'on veut, table dédiée)
router.post("/preferences-perso", authMiddleware, ajouterPreferencePerso);
router.delete("/preferences-perso/:id", authMiddleware, supprimerPreferencePerso);

// Routes réservées à l'administrateur
router.get("/", authMiddleware, checkRole([ROLES.ADMIN]), getTousLesUtilisateurs);
router.patch("/:id/suspendre", authMiddleware, checkRole([ROLES.ADMIN]), suspendreCompte);
router.post("/employe", authMiddleware, checkRole([ROLES.ADMIN]), creerEmploye);

export default router;
