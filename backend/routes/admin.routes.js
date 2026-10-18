// ============================================
// Routes de l'espace employé / administrateur
//
// ⚠️ RÈGLE DE SÉCURITÉ : aucune route ici n'est publique.
// Chaque ligne passe par 2 contrôles, dans cet ordre :
//   1) authMiddleware  → "es-tu connecté ?"
//   2) checkRole([...]) → "as-tu le bon rôle ?"
// ============================================

import express from "express";
import {
  getAvisEnAttente,
  validerAvis,
  refuserAvis,
  getSignalements,
  traiterSignalement,
  getUtilisateurs,
  suspendreUtilisateur,
  getStats,
} from "../controllers/admin.controller.js";
import authMiddleware, { checkRole, ROLES } from "../middleware/auth.middleware.js";

const router = express.Router();

// Qui a le droit de modérer les avis : l'employé, et l'admin aussi.
const EMPLOYE_OU_ADMIN = [ROLES.EMPLOYE, ROLES.ADMIN];
// Qui a le droit de gérer les comptes et voir les statistiques : l'admin seul.
const ADMIN_SEUL = [ROLES.ADMIN];

// --- Modération des avis (espace employé) ---
router.get("/avis", authMiddleware, checkRole(EMPLOYE_OU_ADMIN), getAvisEnAttente);
router.patch("/avis/:id/valider", authMiddleware, checkRole(EMPLOYE_OU_ADMIN), validerAvis);
router.patch("/avis/:id/refuser", authMiddleware, checkRole(EMPLOYE_OU_ADMIN), refuserAvis);

// --- US 12 : signalements (espace employé) ---
// La liste vient de PostgreSQL : c'est là que vit l'argent du chauffeur.
router.get("/signalements", authMiddleware, checkRole(EMPLOYE_OU_ADMIN), getSignalements);
// Trancher : { crediter: true } paie le chauffeur, { crediter: false } ne le paie pas.
router.patch("/signalements/:id", authMiddleware, checkRole(EMPLOYE_OU_ADMIN), traiterSignalement);

// --- Gestion des comptes et statistiques (espace admin) ---
router.get("/utilisateurs", authMiddleware, checkRole(ADMIN_SEUL), getUtilisateurs);
router.patch("/utilisateurs/:id/suspendre", authMiddleware, checkRole(ADMIN_SEUL), suspendreUtilisateur);
router.get("/stats", authMiddleware, checkRole(ADMIN_SEUL), getStats);

export default router;
