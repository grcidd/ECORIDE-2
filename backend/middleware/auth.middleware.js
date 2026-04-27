// Middleware d'authentification
// Vérifie que l'utilisateur est bien connecté avant d'accéder à certaines routes

import jwt from "jsonwebtoken";

const authMiddleware = (req, res, next) => {
  // On récupère le token dans le header de la requête
  const token = req.headers.authorization?.split(" ")[1];

  // Si pas de token → accès refusé
  if (!token) {
    return res
      .status(401)
      .json({ message: "Accès refusé. Connecte-toi d'abord." });
  }

  try {
    // On vérifie que le token est valide
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // on attache les infos utilisateur à la requête
    next(); // on continue vers la route
  } catch (error) {
    return res.status(401).json({ message: "Token invalide ou expiré." });
  }
};

// Middleware pour vérifier le rôle (admin, employé)
export const checkRole = (roleId) => {
  return (req, res, next) => {
    if (req.user.role_id !== roleId) {
      return res
        .status(403)
        .json({ message: "Accès interdit. Rôle insuffisant." });
    }
    next();
  };
};

export default authMiddleware;
