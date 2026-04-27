// Gestion des covoiturages : recherche, détail, création, participation

import supabase from "../config/supabase.js";
import { Log } from "../config/models.mongo.js";

// ---- RECHERCHE DE TRAJETS ----
// GET /api/covoiturages?depart=Lyon&arrivee=Paris&date=2025-07-15
export const rechercher = async (req, res) => {
  try {
    const { depart, arrivee, date } = req.query;

    if (!depart || !arrivee || !date) {
      return res
        .status(400)
        .json({ message: "Départ, arrivée et date sont requis." });
    }

    let query = supabase
      .from("covoiturages")
      .select(
        `
                *,
                chauffeur:users(pseudo, photo, credits),
                vehicule:vehicules(marque, modele, energie)
            `
      )
      .ilike("ville_depart", `%${depart}%`)
      .ilike("ville_arrivee", `%${arrivee}%`)
      .eq("date_depart", date)
      .eq("statut", "planifie")
      .gt("nb_places_restantes", 0); // uniquement les trajets avec places dispo

    const { data: trajets, error } = await query;

    if (error) throw error;

    // Si aucun trajet trouvé, on cherche le prochain disponible
    if (trajets.length === 0) {
      const { data: prochain } = await supabase
        .from("covoiturages")
        .select("date_depart")
        .ilike("ville_depart", `%${depart}%`)
        .ilike("ville_arrivee", `%${arrivee}%`)
        .gt("date_depart", date)
        .eq("statut", "planifie")
        .gt("nb_places_restantes", 0)
        .order("date_depart", { ascending: true })
        .limit(1)
        .single();

      return res.status(200).json({
        trajets: [],
        prochain_dispo: prochain?.date_depart || null,
      });
    }

    // On calcule la note moyenne de chaque chauffeur
    const trajetsAvecNote = await Promise.all(
      trajets.map(async (trajet) => {
        const { data: avis } = await supabase
          .from("avis")
          .select("note")
          .eq("chauffeur_id", trajet.chauffeur_id)
          .eq("statut", "valide");

        const moyenne =
          avis && avis.length > 0
            ? (avis.reduce((sum, a) => sum + a.note, 0) / avis.length).toFixed(
                1
              )
            : null;

        return { ...trajet, note_chauffeur: moyenne };
      })
    );

    res.status(200).json({ trajets: trajetsAvecNote, prochain_dispo: null });
  } catch (error) {
    console.error("Erreur recherche :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- DETAIL D'UN TRAJET ----
// GET /api/covoiturages/:id
export const getDetail = async (req, res) => {
  try {
    const { id } = req.params;

    const { data: trajet, error } = await supabase
      .from("covoiturages")
      .select(
        `
                *,
                chauffeur:users(pseudo, photo),
                vehicule:vehicules(marque, modele, couleur, energie, immatriculation)
            `
      )
      .eq("covoiturage_id", id)
      .single();

    if (error || !trajet) {
      return res.status(404).json({ message: "Trajet introuvable." });
    }

    // Avis validés du chauffeur
    const { data: avis } = await supabase
      .from("avis")
      .select("note, commentaire, created_at, passager:users(pseudo)")
      .eq("chauffeur_id", trajet.chauffeur_id)
      .eq("statut", "valide")
      .order("created_at", { ascending: false });

    // Préférences du chauffeur
    const { data: preferences } = await supabase
      .from("preferences")
      .select("*")
      .eq("user_id", trajet.chauffeur_id)
      .single();

    // Note moyenne
    const moyenne =
      avis && avis.length > 0
        ? (avis.reduce((sum, a) => sum + a.note, 0) / avis.length).toFixed(1)
        : null;

    res.status(200).json({
      trajet,
      avis: avis || [],
      preferences: preferences || null,
      note_moyenne: moyenne,
    });
  } catch (error) {
    console.error("Erreur détail :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- PARTICIPER A UN TRAJET ----
// POST /api/covoiturages/:id/participer  (protégé — faut être connecté)
export const participer = async (req, res) => {
  try {
    const { id } = req.params;
    const user_id = req.user.user_id;

    // On récupère le trajet
    const { data: trajet, error: trajetError } = await supabase
      .from("covoiturages")
      .select("*")
      .eq("covoiturage_id", id)
      .single();

    if (trajetError || !trajet) {
      return res.status(404).json({ message: "Trajet introuvable." });
    }

    // Vérifications
    if (trajet.nb_places_restantes <= 0) {
      return res.status(400).json({ message: "Plus de places disponibles." });
    }
    if (trajet.chauffeur_id === user_id) {
      return res
        .status(400)
        .json({ message: "Tu ne peux pas réserver ton propre trajet." });
    }

    // Vérifier les crédits du passager
    const { data: passager } = await supabase
      .from("users")
      .select("credits")
      .eq("user_id", user_id)
      .single();

    if (passager.credits < trajet.prix_par_personne) {
      return res.status(400).json({ message: "Crédits insuffisants." });
    }

    // Vérifier qu'il ne participe pas déjà
    const { data: dejaInscrit } = await supabase
      .from("participations")
      .select("participation_id")
      .eq("covoiturage_id", id)
      .eq("passager_id", user_id)
      .single();

    if (dejaInscrit) {
      return res
        .status(400)
        .json({ message: "Tu participes déjà à ce trajet." });
    }

    // Création de la participation
    await supabase.from("participations").insert({
      covoiturage_id: id,
      passager_id: user_id,
      credits_utilises: trajet.prix_par_personne,
    });

    // Débit des crédits du passager
    await supabase
      .from("users")
      .update({ credits: passager.credits - trajet.prix_par_personne })
      .eq("user_id", user_id);

    // Mise à jour des places restantes
    await supabase
      .from("covoiturages")
      .update({ nb_places_restantes: trajet.nb_places_restantes - 1 })
      .eq("covoiturage_id", id);

    // Log MongoDB
    await Log.create({
      type: "reservation",
      user_id,
      details: `Réservation trajet #${id}`,
    });

    res.status(200).json({ message: "Participation confirmée !" });
  } catch (error) {
    console.error("Erreur participation :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- CREER UN TRAJET (chauffeur) ----
// POST /api/covoiturages
export const creer = async (req, res) => {
  try {
    const chauffeur_id = req.user.user_id;
    const {
      vehicule_id,
      ville_depart,
      ville_arrivee,
      adresse_depart,
      adresse_arrivee,
      date_depart,
      heure_depart,
      date_arrivee,
      heure_arrivee,
      duree_minutes,
      prix_par_personne,
      nb_places_total,
    } = req.body;

    // Vérification que l'utilisateur est bien chauffeur
    const { data: user } = await supabase
      .from("users")
      .select("est_chauffeur")
      .eq("user_id", chauffeur_id)
      .single();

    if (!user.est_chauffeur) {
      return res
        .status(403)
        .json({ message: "Tu dois être chauffeur pour proposer un trajet." });
    }

    // Récupérer le véhicule pour savoir si électrique
    const { data: vehicule } = await supabase
      .from("vehicules")
      .select("energie")
      .eq("vehicule_id", vehicule_id)
      .single();

    const est_ecologique = vehicule?.energie === "electrique";

    const { data: nouveau, error } = await supabase
      .from("covoiturages")
      .insert({
        chauffeur_id,
        vehicule_id,
        ville_depart,
        ville_arrivee,
        adresse_depart,
        adresse_arrivee,
        date_depart,
        heure_depart,
        date_arrivee,
        heure_arrivee,
        duree_minutes,
        prix_par_personne,
        nb_places_total,
        nb_places_restantes: nb_places_total,
        est_ecologique,
      })
      .select()
      .single();

    if (error) throw error;

    res.status(201).json({ message: "Trajet créé !", trajet: nouveau });
  } catch (error) {
    console.error("Erreur création trajet :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- HISTORIQUE ----
// GET /api/covoiturages/historique
export const historique = async (req, res) => {
  try {
    const user_id = req.user.user_id;

    const { data: enTantQueChauffeur, error: chauffeurError } = await supabase
      .from("covoiturages")
      .select("*")
      .eq("chauffeur_id", user_id)
      .order("date_depart", { ascending: false });

    if (chauffeurError) throw chauffeurError;

    const { data: enTantQuePassager, error: passagerError } = await supabase
      .from("participations")
      .select(
        `
        *,
        covoiturage:covoiturages(*)
      `
      )
      .eq("passager_id", user_id)
      .order("created_at", { ascending: false });

    if (passagerError) throw passagerError;

    res.status(200).json({
      chauffeur: enTantQueChauffeur || [],
      passager: enTantQuePassager || [],
    });
  } catch (error) {
    console.error("Erreur historique :", error);
    res.status(500).json({
      message: "Erreur serveur.",
      erreur: error.message,
    });
  }
};
// ---- DEMARRER UN TRAJET ----
// PATCH /api/covoiturages/:id/demarrer
export const demarrer = async (req, res) => {
  try {
    const { id } = req.params;
    const user_id = req.user.user_id;

    const { error } = await supabase
      .from("covoiturages")
      .update({ statut: "en_cours" })
      .eq("covoiturage_id", id)
      .eq("chauffeur_id", user_id); // sécurité : seul le chauffeur peut démarrer

    if (error) throw error;

    res.status(200).json({ message: "Trajet démarré !" });
  } catch (error) {
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- TERMINER UN TRAJET ----
// PATCH /api/covoiturages/:id/terminer
export const terminer = async (req, res) => {
  try {
    const { id } = req.params;
    const user_id = req.user.user_id;

    const { error } = await supabase
      .from("covoiturages")
      .update({ statut: "termine" })
      .eq("covoiturage_id", id)
      .eq("chauffeur_id", user_id);

    if (error) throw error;

    // Crédits du chauffeur : prix * nb participants - 2 crédits plateforme par passager
    const { data: participations } = await supabase
      .from("participations")
      .select("credits_utilises")
      .eq("covoiturage_id", id)
      .eq("statut", "confirmee");

    const { data: trajet } = await supabase
      .from("covoiturages")
      .select("prix_par_personne")
      .eq("covoiturage_id", id)
      .single();

    const nbPassagers = participations?.length || 0;
    const creditsGagnes = nbPassagers * (trajet.prix_par_personne - 2);

    const { data: chauffeur } = await supabase
      .from("users")
      .select("credits")
      .eq("user_id", user_id)
      .single();

    await supabase
      .from("users")
      .update({ credits: chauffeur.credits + creditsGagnes })
      .eq("user_id", user_id);

    res.status(200).json({ message: "Trajet terminé ! Crédits mis à jour." });
  } catch (error) {
    res.status(500).json({ message: "Erreur serveur." });
  }
};
