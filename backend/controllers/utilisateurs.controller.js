// Gestion des utilisateurs : rôle, véhicules, préférences

import supabase from "../config/supabase.js";
import bcrypt from "bcrypt";

// ---- METTRE À JOUR LE RÔLE ----
// PATCH /api/utilisateurs/role
export const mettreAJourRole = async (req, res) => {
  try {
    const user_id = req.user.user_id;
    const { est_chauffeur, est_passager } = req.body;

    const { error } = await supabase
      .from("users")
      .update({ est_chauffeur, est_passager })
      .eq("user_id", user_id);

    if (error) throw error;

    res.status(200).json({ message: "Rôle mis à jour avec succès." });
  } catch (error) {
    console.error("Erreur rôle :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- RÉCUPÉRER LES VÉHICULES DE L'UTILISATEUR ----
// GET /api/utilisateurs/vehicules
export const getVehicules = async (req, res) => {
  try {
    const user_id = req.user.user_id;

    const { data: vehicules, error } = await supabase
      .from("vehicules")
      .select("*")
      .eq("user_id", user_id)
      .order("created_at", { ascending: false });

    if (error) throw error;

    res.status(200).json({ vehicules: vehicules || [] });
  } catch (error) {
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- AJOUTER UN VÉHICULE ----
// POST /api/utilisateurs/vehicules
export const ajouterVehicule = async (req, res) => {
  try {
    const user_id = req.user.user_id;
    const {
      marque,
      modele,
      couleur,
      immatriculation,
      energie,
      nb_places,
      date_premiere_immatriculation,
    } = req.body;

    if (!marque || !modele || !immatriculation || !energie || !nb_places) {
      return res.status(400).json({
        message: "Tous les champs obligatoires doivent être remplis.",
      });
    }

    const { error } = await supabase.from("vehicules").insert({
      user_id,
      marque,
      modele,
      couleur,
      immatriculation,
      energie,
      nb_places,
      date_premiere_immatriculation,
    });

    if (error) {
      // Immatriculation déjà existante
      if (error.code === "23505") {
        return res
          .status(400)
          .json({ message: "Cette immatriculation est déjà enregistrée." });
      }
      throw error;
    }

    // Passer automatiquement en mode chauffeur
    await supabase
      .from("users")
      .update({ est_chauffeur: true })
      .eq("user_id", user_id);

    res.status(201).json({ message: "Véhicule ajouté avec succès !" });
  } catch (error) {
    console.error("Erreur véhicule :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- SAUVEGARDER LES PRÉFÉRENCES ----
// POST /api/utilisateurs/preferences
export const sauvegarderPreferences = async (req, res) => {
  try {
    const user_id = req.user.user_id;
    const { accepte_fumeur, accepte_animaux, preference_perso } = req.body;

    // Upsert : crée si n'existe pas, met à jour si existe
    const { error } = await supabase.from("preferences").upsert(
      {
        user_id,
        accepte_fumeur,
        accepte_animaux,
        preference_perso,
      },
      { onConflict: "user_id" }
    );

    if (error) throw error;

    res.status(200).json({ message: "Préférences sauvegardées." });
  } catch (error) {
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- RÉCUPÉRER UN UTILISATEUR (pour admin) ----
// GET /api/utilisateurs
export const getTousLesUtilisateurs = async (req, res) => {
  try {
    const { data: users, error } = await supabase
      .from("users")
      .select(
        "user_id, pseudo, email, credits, role_id, est_chauffeur, est_passager, est_suspendu, created_at"
      )
      .order("created_at", { ascending: false });

    if (error) throw error;

    res.status(200).json({ users: users || [] });
  } catch (error) {
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- SUSPENDRE / RÉACTIVER UN COMPTE ----
// PATCH /api/utilisateurs/:id/suspendre
export const suspendreCompte = async (req, res) => {
  try {
    const { id } = req.params;
    const { suspendre } = req.body; // true ou false

    const { error } = await supabase
      .from("users")
      .update({ est_suspendu: suspendre })
      .eq("user_id", id);

    if (error) throw error;

    const action = suspendre ? "suspendu" : "réactivé";
    res.status(200).json({ message: `Compte ${action} avec succès.` });
  } catch (error) {
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- CRÉER UN EMPLOYÉ (admin seulement) ----
// POST /api/utilisateurs/employe
export const creerEmploye = async (req, res) => {
  try {
    const { pseudo, email, password } = req.body;

    if (!pseudo || !email || !password) {
      return res.status(400).json({ message: "Tous les champs sont requis." });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const { error } = await supabase.from("users").insert({
      pseudo,
      email,
      password: hashedPassword,
      role_id: 2, // rôle employé
    });

    if (error) throw error;

    res.status(201).json({ message: "Compte employé créé avec succès." });
  } catch (error) {
    console.error("Erreur création employé :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};
