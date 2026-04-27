// controllers/avis.controller.js
// Soumettre un avis sur un chauffeur après un trajet

import supabase from "../config/supabase.js";

// POST /api/avis
// Accessible uniquement à un passager connecté qui a participé au trajet
export const soumettreAvis = async (req, res) => {
  try {
    const passager_id = req.user.user_id;
    const { covoiturage_id, note, commentaire } = req.body;

    // Validation de la note (obligatoire, entre 1 et 5)
    if (!note || note < 1 || note > 5) {
      return res.status(400).json({
        message: "La note doit être comprise entre 1 et 5.",
      });
    }

    if (!covoiturage_id) {
      return res.status(400).json({ message: "covoiturage_id est requis." });
    }

    // Vérifier que le passager a bien participé à ce trajet
    const { data: participation } = await supabase
      .from("participations")
      .select("participation_id, statut")
      .eq("covoiturage_id", covoiturage_id)
      .eq("passager_id", passager_id)
      .single();

    if (!participation) {
      return res.status(403).json({
        message: "Tu n'as pas participé à ce trajet.",
      });
    }

    // Vérifier que le trajet est bien terminé
    const { data: trajet } = await supabase
      .from("covoiturages")
      .select("statut, chauffeur_id")
      .eq("covoiturage_id", covoiturage_id)
      .single();

    if (!trajet || trajet.statut !== "termine") {
      return res.status(400).json({
        message: "Tu ne peux laisser un avis qu'après la fin du trajet.",
      });
    }

    // Vérifier qu'il n'a pas déjà laissé un avis sur ce trajet
    const { data: avisExistant } = await supabase
      .from("avis")
      .select("avis_id")
      .eq("covoiturage_id", covoiturage_id)
      .eq("passager_id", passager_id)
      .single();

    if (avisExistant) {
      return res.status(400).json({
        message: "Tu as déjà laissé un avis pour ce trajet.",
      });
    }

    // Insertion de l'avis — statut "en_attente" par défaut (validation par employé)
    const { error } = await supabase.from("avis").insert({
      covoiturage_id,
      passager_id,
      chauffeur_id: trajet.chauffeur_id,
      note,
      commentaire: commentaire || null,
      statut: "en_attente",
    });

    if (error) throw error;

    res.status(201).json({
      message: "Avis soumis avec succès. Il sera visible après validation.",
    });
  } catch (error) {
    console.error("Erreur soumettreAvis :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// GET /api/avis/chauffeur/:id
// Récupère les avis validés d'un chauffeur (public)
export const getAvisChauffeur = async (req, res) => {
  try {
    const { id } = req.params;

    const { data: avis, error } = await supabase
      .from("avis")
      .select("note, commentaire, created_at, passager:users(pseudo)")
      .eq("chauffeur_id", id)
      .eq("statut", "valide")
      .order("created_at", { ascending: false });

    if (error) throw error;

    // Calcul de la note moyenne
    const moyenne =
      avis && avis.length > 0
        ? (avis.reduce((sum, a) => sum + a.note, 0) / avis.length).toFixed(1)
        : null;

    res.status(200).json({ avis: avis || [], moyenne });
  } catch (error) {
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// GET /api/avis/peux-noter/:covoiturage_id
// Vérifie si l'utilisateur connecté peut encore laisser un avis
export const peutNoter = async (req, res) => {
  try {
    const passager_id = req.user.user_id;
    const { covoiturage_id } = req.params;

    // A-t-il participé ?
    const { data: participation } = await supabase
      .from("participations")
      .select("participation_id")
      .eq("covoiturage_id", covoiturage_id)
      .eq("passager_id", passager_id)
      .single();

    if (!participation) {
      return res
        .status(200)
        .json({ peutNoter: false, raison: "non_participant" });
    }

    // Le trajet est-il terminé ?
    const { data: trajet } = await supabase
      .from("covoiturages")
      .select("statut")
      .eq("covoiturage_id", covoiturage_id)
      .single();

    if (trajet?.statut !== "termine") {
      return res
        .status(200)
        .json({ peutNoter: false, raison: "trajet_non_termine" });
    }

    // A-t-il déjà noté ?
    const { data: avisExistant } = await supabase
      .from("avis")
      .select("avis_id")
      .eq("covoiturage_id", covoiturage_id)
      .eq("passager_id", passager_id)
      .single();

    if (avisExistant) {
      return res.status(200).json({ peutNoter: false, raison: "deja_note" });
    }

    res.status(200).json({ peutNoter: true });
  } catch (error) {
    res.status(500).json({ message: "Erreur serveur." });
  }
};
