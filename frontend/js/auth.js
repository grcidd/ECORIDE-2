// ============================================
// auth.js — Gestion de la session utilisateur
// (qui est connecté, son jeton, la barre de navigation)
//
// ⚠️ Nécessite que js/api.js soit chargé AVANT.
// L'adresse de l'API et les fonctions d'appel vivent dans api.js.
// ============================================

// ---- Sauvegarder la session après une connexion réussie ----
function sauvegarderSession(token, user) {
  localStorage.setItem("token", token);
  localStorage.setItem("user", JSON.stringify(user));
}

// ---- Récupérer l'utilisateur connecté (ou null) ----
function getUser() {
  const user = localStorage.getItem("user");
  return user ? JSON.parse(user) : null;
}

// ---- Récupérer le jeton JWT ----
function getToken() {
  return localStorage.getItem("token");
}

// ---- Se déconnecter : on efface tout et on retourne à l'accueil ----
function deconnecter() {
  localStorage.removeItem("token");
  localStorage.removeItem("user");
  window.location.href = "index.html";
}

// ---- Suis-je connecté ? ----
function estConnecte() {
  return !!getToken();
}

// ---- Afficher le bon menu selon que l'on soit connecté ou non ----
function mettreAJourNavbar() {
  const user = getUser();
  const navInvite = document.getElementById("nav-invite");
  const navConnecte = document.getElementById("nav-connecte");
  const navPseudo = document.getElementById("nav-pseudo");

  if (user && navConnecte) {
    if (navInvite) navInvite.classList.add("hidden");
    navConnecte.classList.remove("hidden");
    // textContent (et pas innerHTML) : si le pseudo contient du HTML,
    // il s'affiche comme du texte au lieu d'être exécuté. C'est la protection anti-XSS.
    if (navPseudo) navPseudo.textContent = `👤 ${user.pseudo}`;
  }
}

// ---- S'exécute au chargement de chaque page ----
document.addEventListener("DOMContentLoaded", () => {
  mettreAJourNavbar();
});
