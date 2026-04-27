// ============================================
// auth.js — Gestion de la session utilisateur
// Ce fichier est inclus sur toutes les pages
// ============================================

const API = "https://ecoride-2-5vty.onrender.com";

// ---- Sauvegarde de la session après connexion ----
function sauvegarderSession(token, user) {
  localStorage.setItem("token", token);
  localStorage.setItem("user", JSON.stringify(user));
}

// ---- Récupérer l'utilisateur connecté ----
function getUser() {
  const user = localStorage.getItem("user");
  return user ? JSON.parse(user) : null;
}

// ---- Récupérer le token JWT ----
function getToken() {
  return localStorage.getItem("token");
}

// ---- Déconnexion ----
function deconnecter() {
  localStorage.removeItem("token");
  localStorage.removeItem("user");
  window.location.href = "index.html";
}

// ---- Vérifier si connecté ----
function estConnecte() {
  return !!getToken();
}

// ---- Mettre à jour la navbar selon l'état de connexion ----
function mettreAJourNavbar() {
  const user = getUser();
  const navInvite = document.getElementById("nav-invite");
  const navConnecte = document.getElementById("nav-connecte");
  const navPseudo = document.getElementById("nav-pseudo");

  if (user && navConnecte) {
    // L'utilisateur est connecté
    if (navInvite) navInvite.classList.add("hidden");
    if (navConnecte) navConnecte.classList.remove("hidden");
    if (navPseudo) navPseudo.textContent = `👤 ${user.pseudo}`;
  }
}

// ---- Requête API avec token (pour les routes protégées) ----
async function apiProtegee(url, options = {}) {
  const token = getToken();
  return fetch(`${API}${url}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      ...(options.headers || {}),
    },
  });
}

// ---- Exécuté sur chaque page ----
document.addEventListener("DOMContentLoaded", () => {
  mettreAJourNavbar();
});
