// Routes d'authentification

import express from "express";
import { register, login } from "../controllers/auth.controller.js";

const router = express.Router();

router.post("/register", register); // POST /api/auth/register
router.post("/login", login); // POST /api/auth/login

export default router;
