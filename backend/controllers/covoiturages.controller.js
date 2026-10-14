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
        // maybeSingle() = "0 ou 1 résultat, et 0 n'est pas une erreur".
        // Avec single(), ne rien trouver déclenchait une erreur inutile.
        .maybeSingle();

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

    // On ne demande QUE les colonnes nécessaires pour les tables liées.
    // La plaque d'immatriculation est une donnée personnelle : elle n'a
    // aucune raison d'être envoyée au navigateur de la passagère.
    const { data: trajet, error } = await supabase
      .from("covoiturages")
      .select(
        `
                *,
                chauffeur:users(pseudo, photo),
                vehicule:vehicules(marque, modele, couleur, energie)
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

    // Préférences du chauffeur : fumeur / animaux
    // maybeSingle() car un chauffeur peut très bien n'avoir rien renseigné :
    // avec single(), ce cas normal déclenchait une erreur.
    const { data: preferences } = await supabase
      .from("preferences")
      .select("*")
      .eq("user_id", trajet.chauffeur_id)
      .maybeSingle();

    // US 5 : les préférences personnalisées, écrites librement par le chauffeur
    // (« Pas de nourriture dans la voiture », « Pause toutes les 2h »...).
    // Elles vivent dans leur propre table : un chauffeur peut en avoir plusieurs.
    const { data: preferencesPerso } = await supabase
      .from("preferences_personnalisees")
      .select("libelle")
      .eq("user_id", trajet.chauffeur_id)
      .order("preference_perso_id", { ascending: true });

    // Note moyenne
    const moyenne =
      avis && avis.length > 0
        ? (avis.reduce((sum, a) => sum + a.note, 0) / avis.length).toFixed(1)
        : null;

    res.status(200).json({
      trajet,
      avis: avis || [],
      preferences: preferences || null,
      preferences_perso: preferencesPerso || [],
      note_moyenne: moyenne,
    });
  } catch (error) {
    console.error("Erreur détail :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- PARTICIPER A UN TRAJET (US 6) ----
// POST /api/covoiturages/:id/participer   (protégé : il faut être connecté)
//
// Tout le travail est fait par la fonction PostgreSQL "reserver_covoiturage"
// (voir database/fonction_reserver.sql), appelée ici avec supabase.rpc().
//
// Pourquoi ? Parce qu'une réservation, c'est 3 écritures qui vont ensemble :
//   1. créer la participation
//   2. débiter les crédits de la passagère
//   3. enlever une place au trajet
// Avant, ces 3 écritures étaient faites l'une après l'autre depuis Node.
// Si le serveur tombait entre la 2 et la 3, la passagère était débitée
// SANS que sa place soit réservée. Dans une fonction PostgreSQL, les 3
// écritures sont dans une seule transaction : tout passe, ou rien ne passe.

// Les codes renvoyés par la fonction, traduits en message pour la passagère.
const MESSAGES_RESERVATION = {
  TRAJET_INTROUVABLE: { code: 404, message: "Ce trajet n'existe pas." },
  TRAJET_NON_RESERVABLE: { code: 400, message: "Ce trajet n'est plus réservable." },
  PROPRE_TRAJET: { code: 400, message: "Tu ne peux pas réserver ton propre trajet." },
  COMPLET: { code: 400, message: "Plus de places disponibles." },
  DEJA_INSCRIT: { code: 400, message: "Tu participes déjà à ce trajet." },
  CREDITS_INSUFFISANTS: { code: 400, message: "Crédits insuffisants." },
  UTILISATEUR_INTROUVABLE: { code: 404, message: "Compte introuvable." },
};

export const participer = async (req, res) => {
  try {
    const { id } = req.params;
    const user_id = req.user.user_id; // vient du jeton, jamais du navigateur

    // Un seul appel : la fonction vérifie TOUT puis écrit TOUT, d'un bloc.
    const { data, error } = await supabase.rpc("reserver_covoiturage", {
      p_covoiturage_id: Number(id),
      p_passager_id: user_id,
    });

    if (error) {
      // La fonction a refusé. Son message contient un code court,
      // par exemple "COMPLET". On cherche lequel.
      const codes = Object.keys(MESSAGES_RESERVATION);
      const trouve = codes.find((c) => error.message.includes(c));

      if (trouve) {
        const reponse = MESSAGES_RESERVATION[trouve];
        return res.status(reponse.code).json({ message: reponse.message });
      }

      // Erreur qu'on n'avait pas prévue : on la laisse remonter
      throw error;
    }

    // À partir d'ici, la réservation est enregistrée pour de bon.
    // Le log MongoDB est un BONUS : s'il échoue, la réservation reste valable.
    // (Avant, une panne de MongoDB faisait répondre "Erreur serveur" alors
    //  que la passagère avait bien été débitée et sa place réservée.)
    try {
      await Log.create({
        type: "reservation",
        user_id,
        pseudo: req.user.pseudo,
        details: `Réservation trajet #${id}`,
      });
    } catch (erreurMongo) {
      console.log("Log Mongo non enregistré :", erreurMongo.message);
    }

    res.status(200).json({
      message: "Participation confirmée !",
      credits_utilises: data.credits_utilises,
      credits_restants: data.credits_restants,
      places_restantes: data.places_restantes,
    });
  } catch (error) {
    console.error("Erreur participation :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- CRÉER UN TRAJET (US 9) ----
// POST /api/covoiturages   (protégé : il faut être connecté ET chauffeur)

// La commission que la plateforme prend sur CHAQUE passager.
// Elle est enregistrée sur le trajet au moment de sa création : si le tarif
// de la plateforme change un jour, les anciens trajets gardent le leur et
// les statistiques de l'administrateur restent justes.
const CREDITS_PLATEFORME = 2;

export const creer = async (req, res) => {
  try {
    const chauffeur_id = req.user.user_id; // vient du jeton, jamais du navigateur
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
      prix_par_personne,
      nb_places_total,
    } = req.body;

    // --- 1. Tous les champs obligatoires sont-ils là ? ---
    // Attention : en JavaScript, le nombre 0 est considéré comme "faux".
    // Avec "!prix_par_personne", saisir 0 aurait dit "champ non rempli"
    // alors que le champ EST rempli. On teste donc le vide explicitement
    // pour les deux champs numériques, et on vérifie leur valeur plus bas.
    const vide = (v) => v === undefined || v === null || v === "";

    if (
      !vehicule_id || !ville_depart || !ville_arrivee ||
      !date_depart || !heure_depart || !date_arrivee || !heure_arrivee ||
      vide(prix_par_personne) || vide(nb_places_total)
    ) {
      return res.status(400).json({
        message: "Merci de remplir tous les champs obligatoires.",
      });
    }

    // --- 2. Est-elle bien chauffeur ? ---
    const { data: user } = await supabase
      .from("users")
      .select("est_chauffeur")
      .eq("user_id", chauffeur_id)
      .maybeSingle();

    if (!user || !user.est_chauffeur) {
      return res.status(403).json({
        message: "Tu dois être chauffeur pour proposer un trajet.",
      });
    }

    // --- 3. Le véhicule lui appartient-il ? ---
    // ⚠️ SÉCURITÉ : le .eq("user_id", chauffeur_id) est indispensable.
    // Sans lui, on pouvait créer un trajet avec la voiture de quelqu'un
    // d'autre en envoyant simplement son numéro.
    const { data: vehicule } = await supabase
      .from("vehicules")
      .select("vehicule_id, energie, nb_places")
      .eq("vehicule_id", vehicule_id)
      .eq("user_id", chauffeur_id)
      .maybeSingle();

    if (!vehicule) {
      return res.status(400).json({
        message: "Ce véhicule n'existe pas ou ne t'appartient pas.",
      });
    }

    // --- 4. Le prix ---
    const prix = Number(prix_par_personne);
    if (!Number.isInteger(prix) || prix < 1) {
      return res.status(400).json({
        message: "Le prix doit être un nombre entier d'au moins 1 crédit.",
      });
    }

    // --- 5. Le nombre de places ---
    // Le chauffeur occupe une place : il ne peut en proposer que les autres.
    const placesMax = vehicule.nb_places - 1;
    const places = Number(nb_places_total);

    if (!Number.isInteger(places) || places < 1 || places > placesMax) {
      return res.status(400).json({
        message:
          "Avec ce véhicule tu peux proposer entre 1 et " + placesMax +
          " place(s).",
      });
    }

    // --- 6. Les dates et heures ---
    const depart = new Date(date_depart + "T" + heure_depart);
    const arrivee = new Date(date_arrivee + "T" + heure_arrivee);

    if (isNaN(depart.getTime()) || isNaN(arrivee.getTime())) {
      return res.status(400).json({ message: "Les dates ne sont pas valides." });
    }

    // On ne propose pas un trajet déjà passé.
    if (depart < new Date()) {
      return res.status(400).json({
        message: "Le départ doit être dans le futur.",
      });
    }

    // L'arrivée doit venir après le départ.
    if (arrivee <= depart) {
      return res.status(400).json({
        message: "L'arrivée doit être après le départ.",
      });
    }

    // --- 7. La durée, calculée par le serveur ---
    // On ne la demande PAS au navigateur : il pourrait envoyer n'importe quoi,
    // alors que la durée doit toujours correspondre aux heures affichées (US 4).
    // Soustraire deux dates JavaScript donne un écart en millisecondes.
    // On divise par 60000 pour obtenir des minutes.
    // Cette seule ligne gère tous les cas : même jour, lendemain, ou plus.
    const duree_minutes = Math.round((arrivee - depart) / 60000);

    // --- 8. Écologique ? ---
    // C'est le serveur qui le détermine, à partir de l'énergie du véhicule.
    const est_ecologique = vehicule.energie === "electrique";

    const { data: nouveau, error } = await supabase
      .from("covoiturages")
      .insert({
        chauffeur_id,
        vehicule_id: vehicule.vehicule_id,
        ville_depart: ville_depart.trim(),
        ville_arrivee: ville_arrivee.trim(),
        adresse_depart: adresse_depart ? adresse_depart.trim() : null,
        adresse_arrivee: adresse_arrivee ? adresse_arrivee.trim() : null,
        date_depart,
        heure_depart,
        date_arrivee,
        heure_arrivee,
        duree_minutes,
        prix_par_personne: prix,
        nb_places_total: places,
        nb_places_restantes: places, // au départ, toutes les places sont libres
        est_ecologique,
        credits_plateforme: CREDITS_PLATEFORME,
      })
      .select()
      .single();

    if (error) throw error;

    res.status(201).json({
      message: "Trajet créé !",
      trajet: nouveau,
      // US 9 : on dit clairement au chauffeur ce qu'il touchera.
      credits_plateforme: CREDITS_PLATEFORME,
      gain_par_passager: prix - CREDITS_PLATEFORME,
      gain_maximum: (prix - CREDITS_PLATEFORME) * places,
    });
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
