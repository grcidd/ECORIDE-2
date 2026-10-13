// ============================================
// api.js — Le point central pour parler au serveur
//
// ⚠️ Ce fichier doit être chargé AVANT tous les autres scripts.
// Toute l'application passe par ici pour appeler l'API :
// l'adresse du serveur n'est donc écrite qu'à UN SEUL endroit.
// ============================================

// --------------------------------------------
// Adresse de l'API
// On la devine automatiquement :
//  - si j'ouvre le site depuis mon PC → serveur local
//  - sinon (site en ligne sur Netlify) → serveur Render
// Comme ça, plus besoin de modifier le code entre le développement et la mise en ligne.
// --------------------------------------------
const EN_LOCAL =
  window.location.hostname === "localhost" ||
  window.location.hostname === "127.0.0.1";

const API = EN_LOCAL
  ? "http://localhost:3000/api"
  : "https://ecoride-2-5vty.onrender.com/api";

// --------------------------------------------
// PROTECTION ANTI-XSS
// Une faille XSS, c'est quand un utilisateur met du code HTML dans son pseudo
// (par exemple <img src=x onerror="...">) et que ce code s'exécute chez les autres.
// Cette fonction remplace les caractères dangereux par leur version "texte".
// À utiliser DÈS QU'ON affiche une donnée venant de la base.
// --------------------------------------------
function echapper(valeur) {
  if (valeur === null || valeur === undefined) return "";
  return String(valeur)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

// --------------------------------------------
// Appel SIMPLE (pages publiques : recherche, détail d'un trajet...)
// --------------------------------------------
async function apiPublique(chemin, options = {}) {
  return fetch(`${API}${chemin}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });
}

// --------------------------------------------
// Appel PROTÉGÉ (il faut être connecté)
// On ajoute automatiquement le jeton JWT dans l'en-tête,
// c'est lui qui prouve au serveur qui nous sommes.
// --------------------------------------------
async function apiProtegee(chemin, options = {}) {
  const token = localStorage.getItem("token");

  const reponse = await fetch(`${API}${chemin}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      ...(options.headers || {}),
    },
  });

  // Jeton expiré ou invalide → on nettoie et on renvoie vers la connexion.
  if (reponse.status === 401) {
    localStorage.removeItem("token");
    localStorage.removeItem("user");
    window.location.href = "connexion.html";
  }

  return reponse;
}
