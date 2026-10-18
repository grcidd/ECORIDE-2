// ============================================
// Middleware d'authentification et de rôles
//
// Un "middleware", c'est un contrôle qui s'exécute AVANT la route.
// Comme un videur à l'entrée : soit il laisse passer (next),
// soit il bloque (res.status(...)).
// ============================================

import jwt from "jsonwebtoken";

// Les 3 rôles, tels qu'ils sont enregistrés dans la table "roles".
// On leur donne un nom pour que le code se lise facilement :
// ROLES.ADMIN est plus clair que le chiffre 3.
export const ROLES = {
  UTILISATEUR: 1,
  EMPLOYE: 2,
  ADMIN: 3,
};

// --------------------------------------------
// CONTRÔLE 1 : "es-tu connecté ?"
// --------------------------------------------
const authMiddleware = (req, res, next) => {
  // Le navigateur envoie le jeton dans l'en-tête, sous la forme :
  // "Authorization: Bearer leJetonIci"
  // On coupe sur l'espace et on garde le 2e morceau : le jeton.
  const enTete = req.headers.authorization;

  if (!enTete) {
    return res.status(401).json({ message: "Accès refusé. Connecte-toi d'abord." });
  }

  const jeton = enTete.split(" ")[1];

  if (!jeton) {
    return res.status(401).json({ message: "Accès refusé. Connecte-toi d'abord." });
  }

  try {
    // On vérifie la signature du jeton avec notre phrase secrète.
    // Si quelqu'un a fabriqué un faux jeton, cette ligne échoue.
    const donnees = jwt.verify(jeton, process.env.JWT_SECRET);

    // On accroche les infos de l'utilisateur à la requête,
    // pour que la route qui suit sache QUI fait la demande.
    req.user = donnees;

    next(); // feu vert, on passe à la suite
  } catch (erreur) {
    return res.status(401).json({ message: "Token invalide ou expiré." });
  }
};

// --------------------------------------------
// CONTRÔLE 2 : "as-tu le bon rôle ?"
//
// À utiliser APRÈS authMiddleware, qui a déjà rempli req.user.
// On lui donne un tableau des rôles autorisés :
//   checkRole([ROLES.ADMIN])                 → admin seulement
//   checkRole([ROLES.EMPLOYE, ROLES.ADMIN])  → employé OU admin
// --------------------------------------------
export const checkRole = (rolesAutorises) => {
  // On renvoie une fonction : c'est elle qu'Express va exécuter.
  return (req, res, next) => {
    // Sécurité : si on a oublié authMiddleware avant, req.user n'existe pas.
    // On refuse, plutôt que de planter.
    if (!req.user) {
      return res.status(401).json({ message: "Accès refusé. Connecte-toi." });
    }

    // includes() répond vrai/faux : "mon rôle est-il dans la liste autorisée ?"
    if (!rolesAutorises.includes(req.user.role_id)) {
      return res.status(403).json({ message: "Accès interdit. Rôle insuffisant." });
    }

    next(); // feu vert
  };
};

export default authMiddleware;
