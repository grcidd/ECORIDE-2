// Gestion des utilisateurs : rôle, véhicules, préférences

import supabase from "../config/supabase.js";
import bcrypt from "bcrypt";

// Les seules énergies acceptées. La même liste existe dans la base
// (contrainte CHECK sur vehicules.energie) : on la répète ici pour pouvoir
// renvoyer un message clair au lieu de laisser la base provoquer une erreur.
// ⚠️ "electrique" en minuscules : c'est cette valeur exacte qui déclenche
// le badge écologique (US 3).
const ENERGIES_AUTORISEES = [
  "electrique",
  "hybride",
  "essence",
  "diesel",
  "gpl",
];

// ---- METTRE À JOUR LE RÔLE ----
// PATCH /api/utilisateurs/role
export const mettreAJourRole = async (req, res) => {
  try {
    const user_id = req.user.user_id;
    const { est_chauffeur, est_passager } = req.body;

    // US 8 : on peut être chauffeur, passager, ou les deux.
    // Mais pas "ni l'un ni l'autre" : le compte ne servirait plus à rien.
    if (!est_chauffeur && !est_passager) {
      return res.status(400).json({
        message: "Choisis au moins un rôle : chauffeur ou passager.",
      });
    }

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

    // Attention : en JavaScript, le nombre 0 est considéré comme "faux".
    // On ne peut donc pas écrire "!nb_places" : saisir 0 place dirait
    // "champ non rempli" alors que le champ EST rempli.
    const nbPlacesVide =
      nb_places === undefined || nb_places === null || nb_places === "";

    if (!marque || !modele || !immatriculation || !energie || nbPlacesVide) {
      return res.status(400).json({
        message: "Tous les champs obligatoires doivent être remplis.",
      });
    }

    // L'énergie doit faire partie de la liste autorisée.
    // La base a la même règle (contrainte CHECK), mais sans cette
    // vérification elle répondait par un "Erreur serveur" incompréhensible.
    if (!ENERGIES_AUTORISEES.includes(energie)) {
      return res.status(400).json({
        message:
          "L'énergie doit être : " + ENERGIES_AUTORISEES.join(", ") + ".",
      });
    }

    // Le nombre de places doit être un entier entre 1 et 8.
    const places = Number(nb_places);
    if (!Number.isInteger(places) || places < 1 || places > 8) {
      return res.status(400).json({
        message: "Le nombre de places doit être un nombre entier entre 1 et 8.",
      });
    }

    const { error } = await supabase.from("vehicules").insert({
      user_id,
      marque,
      modele,
      couleur,
      immatriculation,
      energie,
      nb_places: places,
      date_premiere_immatriculation: date_premiere_immatriculation || null,
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

// ============================================
// US 8 — LES PRÉFÉRENCES
// ============================================

// ---- LIRE ses préférences ----
// GET /api/utilisateurs/preferences
// Sans cette route, la page de profil ne pouvait pas afficher ce qui était
// déjà enregistré : les cases repartaient vides à chaque visite.
export const getPreferences = async (req, res) => {
  try {
    const user_id = req.user.user_id;

    // Les 2 préférences fixes (fumeur / animaux).
    // maybeSingle() : ne rien avoir enregistré est un cas normal.
    const { data: preferences } = await supabase
      .from("preferences")
      .select("accepte_fumeur, accepte_animaux, preference_perso")
      .eq("user_id", user_id)
      .maybeSingle();

    // Les préférences libres, dans leur table dédiée.
    const { data: perso } = await supabase
      .from("preferences_personnalisees")
      .select("preference_perso_id, libelle")
      .eq("user_id", user_id)
      .order("preference_perso_id", { ascending: true });

    res.status(200).json({
      preferences: preferences || null,
      preferences_perso: perso || [],
    });
  } catch (error) {
    console.error("Erreur getPreferences :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- AJOUTER une préférence personnalisée ----
// POST /api/utilisateurs/preferences-perso
// Exemples : "Pas de nourriture dans la voiture", "Pause toutes les 2h".
// Chaque préférence est une ligne : on peut en ajouter autant qu'on veut,
// et en supprimer une seule sans toucher aux autres.
export const ajouterPreferencePerso = async (req, res) => {
  try {
    const user_id = req.user.user_id;
    const { libelle } = req.body;

    if (!libelle || !libelle.trim()) {
      return res.status(400).json({ message: "Écris ta préférence." });
    }

    const texte = libelle.trim();

    if (texte.length > 100) {
      return res.status(400).json({
        message: "Une préférence ne peut pas dépasser 100 caractères.",
      });
    }

    const { error } = await supabase
      .from("preferences_personnalisees")
      .insert({ user_id, libelle: texte });

    if (error) {
      // 23505 = la base refuse un doublon (contrainte UNIQUE user_id + libelle)
      if (error.code === "23505") {
        return res
          .status(400)
          .json({ message: "Tu as déjà ajouté cette préférence." });
      }
      throw error;
    }

    res.status(201).json({ message: "Préférence ajoutée." });
  } catch (error) {
    console.error("Erreur ajouterPreferencePerso :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- SUPPRIMER une préférence personnalisée ----
// DELETE /api/utilisateurs/preferences-perso/:id
export const supprimerPreferencePerso = async (req, res) => {
  try {
    const user_id = req.user.user_id;
    const { id } = req.params;

    // ⚠️ SÉCURITÉ : le .eq("user_id", user_id) est indispensable.
    // Sans lui, n'importe qui pourrait supprimer les préférences des autres
    // en changeant simplement le numéro dans l'adresse.
    const { data, error } = await supabase
      .from("preferences_personnalisees")
      .delete()
      .eq("preference_perso_id", id)
      .eq("user_id", user_id)
      .select();

    if (error) throw error;

    // Rien supprimé = soit elle n'existe pas, soit elle est à quelqu'un d'autre.
    // On répond la même chose dans les deux cas, pour ne pas révéler
    // quelles préférences existent chez les autres.
    if (!data || data.length === 0) {
      return res.status(404).json({ message: "Préférence introuvable." });
    }

    res.status(200).json({ message: "Préférence supprimée." });
  } catch (error) {
    console.error("Erreur supprimerPreferencePerso :", error);
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
