import express from "express";
import {
  getAvisEnAttente,
  validerAvis,
  refuserAvis,
  getUtilisateurs,
  suspendreUtilisateur,
  getStats,
} from "../controllers/admin.controller.js";

const router = express.Router();

router.get("/avis", getAvisEnAttente);
router.patch("/avis/:id/valider", validerAvis);
router.patch("/avis/:id/refuser", refuserAvis);
router.get("/utilisateurs", getUtilisateurs);
router.patch("/utilisateurs/:id/suspendre", suspendreUtilisateur);
router.get("/stats", getStats);

export default router;
