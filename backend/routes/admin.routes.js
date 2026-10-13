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

// --- Gestion des comptes et statistiques (espace admin) ---
router.get("/utilisateurs", authMiddleware, checkRole(ADMIN_SEUL), getUtilisateurs);
router.patch("/utilisateurs/:id/suspendre", authMiddleware, checkRole(ADMIN_SEUL), suspendreUtilisateur);
router.get("/stats", authMiddleware, checkRole(ADMIN_SEUL), getStats);

export default router;
