// Gestion des covoiturages : recherche, détail, création, participation

import supabase from "../config/supabase.js";
import { Log, Signalement } from "../config/models.mongo.js";
import { envoyerMails, dateEnFrancais } from "../utils/mail.js";

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
// ============================================
// US 10 — LES ANNULATIONS
// ============================================

// Les codes renvoyés par les fonctions PostgreSQL, traduits pour l'utilisateur.
const MESSAGES_ANNULATION = {
  TRAJET_INTROUVABLE: { code: 404, message: "Ce trajet n'existe pas." },
  TROP_TARD: { code: 400, message: "Trop tard : ce trajet a déjà commencé ou est terminé." },
  PAS_INSCRIT: { code: 400, message: "Tu ne participes pas à ce trajet." },
  DEJA_ANNULEE: { code: 400, message: "Tu as déjà annulé cette réservation." },
  PAS_TON_TRAJET: { code: 403, message: "Ce trajet n'est pas le tien." },
};

// Petite fonction partagée : retrouve le code d'erreur dans le message
// renvoyé par PostgreSQL et le traduit.
function traduireErreur(error, res) {
  const codes = Object.keys(MESSAGES_ANNULATION);
  const trouve = codes.find((c) => error.message.includes(c));
  if (!trouve) return false; // erreur imprévue : l'appelant la gère
  const reponse = MESSAGES_ANNULATION[trouve];
  res.status(reponse.code).json({ message: reponse.message });
  return true;
}

// ---- ANNULER SA PARTICIPATION (passager) ----
// DELETE /api/covoiturages/:id/participer
//
// Tout se passe dans la fonction PostgreSQL annuler_participation :
// rembourser, libérer la place et marquer la participation annulée
// forment UNE SEULE transaction.
export const annulerParticipation = async (req, res) => {
  try {
    const { id } = req.params;
    const user_id = req.user.user_id; // vient du jeton

    const { data, error } = await supabase.rpc("annuler_participation", {
      p_covoiturage_id: Number(id),
      p_passager_id: user_id,
    });

    if (error) {
      if (traduireErreur(error, res)) return;
      throw error;
    }

    try {
      await Log.create({
        type: "annulation_participation",
        user_id,
        pseudo: req.user.pseudo,
        details: `Annulation de la réservation du trajet #${id}`,
      });
    } catch (erreurMongo) {
      console.log("Log Mongo non enregistré :", erreurMongo.message);
    }

    res.status(200).json({
      message: "Réservation annulée. Tes crédits ont été remboursés.",
      credits_rembourses: data.credits_rembourses,
      places_restantes: data.places_restantes,
    });
  } catch (error) {
    console.error("Erreur annulation participation :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- ANNULER SON TRAJET (chauffeur) ----
// DELETE /api/covoiturages/:id
//
// La fonction PostgreSQL rembourse TOUS les passagers d'un coup et renvoie
// leur liste. On s'en sert ensuite pour leur envoyer un mail.
export const annulerTrajet = async (req, res) => {
  try {
    const { id } = req.params;
    const chauffeur_id = req.user.user_id;

    const { data, error } = await supabase.rpc("annuler_trajet", {
      p_covoiturage_id: Number(id),
      p_chauffeur_id: chauffeur_id,
    });

    if (error) {
      if (traduireErreur(error, res)) return;
      throw error;
    }

    // --- Les mails aux passagers (US 10) ---
    // On les prépare à partir de la liste renvoyée par la base.
    const trajetTexte = data.ville_depart + " → " + data.ville_arrivee;
    const mails = (data.passagers || []).map((p) => ({
      destinataire: p.email,
      sujet: "EcoRide — Ton covoiturage " + trajetTexte + " a été annulé",
      texte:
        "Bonjour " + p.pseudo + ",\n\n" +
        "Le chauffeur a annulé le covoiturage " + trajetTexte +
        " prévu le " + dateEnFrancais(data.date_depart) + ".\n\n" +
        "Tes " + p.credits_rembourses + " crédits t'ont été remboursés automatiquement.\n\n" +
        "Tu peux chercher un autre trajet sur EcoRide.\n\n" +
        "L'équipe EcoRide",
    }));

    // ⚠️ L'annulation est DÉJÀ enregistrée à ce stade.
    // Si l'envoi des mails échoue, on ne doit pas répondre "erreur" :
    // envoyerMails() n'échoue jamais et renvoie les liens d'aperçu.
    const apercus = await envoyerMails(mails);

    res.status(200).json({
      message:
        "Trajet annulé. " + data.passagers_rembourses +
        " passager(s) ont été remboursés et prévenus par mail.",
      passagers_rembourses: data.passagers_rembourses,
      // En mode test (Ethereal), on renvoie les liens pour lire les mails.
      apercus_mails: apercus,
    });
  } catch (error) {
    console.error("Erreur annulation trajet :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ============================================
// US 11 — DÉMARRER, ARRIVER, VALIDER
//
// LA RÈGLE CENTRALE : le chauffeur n'est payé QUE lorsqu'un passager
// confirme que tout s'est bien passé. Ni au départ, ni à l'arrivée.
// ============================================

const MESSAGES_TRAJET = {
  TRAJET_INTROUVABLE: { code: 404, message: "Ce trajet n'existe pas." },
  PAS_TON_TRAJET: { code: 403, message: "Ce trajet n'est pas le tien." },
  MAUVAIS_STATUT: { code: 400, message: "Cette action n'est pas possible à ce stade du trajet." },
  TRAJET_NON_TERMINE: { code: 400, message: "Ce trajet n'est pas encore terminé." },
  PAS_INSCRIT: { code: 403, message: "Tu n'as pas participé à ce trajet." },
  PARTICIPATION_ANNULEE: { code: 400, message: "Tu avais annulé cette réservation." },
  DEJA_VALIDE: { code: 400, message: "Tu as déjà donné ton avis sur ce trajet." },
  COMMENTAIRE_REQUIS: { code: 400, message: "Merci d'expliquer ce qui s'est mal passé." },
};

function traduireErreurTrajet(error, res) {
  const codes = Object.keys(MESSAGES_TRAJET);
  const trouve = codes.find((c) => error.message.includes(c));
  if (!trouve) return false;
  const reponse = MESSAGES_TRAJET[trouve];
  res.status(reponse.code).json({ message: reponse.message });
  return true;
}

// ---- DÉMARRER ----
// PATCH /api/covoiturages/:id/demarrer
export const demarrer = async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabase.rpc("demarrer_trajet", {
      p_covoiturage_id: Number(id),
      p_chauffeur_id: req.user.user_id,
    });

    if (error) {
      if (traduireErreurTrajet(error, res)) return;
      throw error;
    }

    res.status(200).json({ message: "Trajet démarré ! Bonne route." });
  } catch (error) {
    console.error("Erreur démarrage :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- ARRIVÉE À DESTINATION ----
// PATCH /api/covoiturages/:id/terminer
//
// ⚠️ Cette route NE PAIE PERSONNE.
// Avant, elle créditait le chauffeur tout de suite, et sans vérifier le
// statut : terminer deux fois le payait deux fois. Maintenant elle se
// contente de marquer le trajet terminé et d'inviter les passagers à valider.
export const terminer = async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabase.rpc("terminer_trajet", {
      p_covoiturage_id: Number(id),
      p_chauffeur_id: req.user.user_id,
    });

    if (error) {
      if (traduireErreurTrajet(error, res)) return;
      throw error;
    }

    // Le mail qui invite chaque passager à valider le trajet (US 11)
    const trajetTexte = data.ville_depart + " → " + data.ville_arrivee;
    const mails = (data.passagers || []).map((p) => ({
      destinataire: p.email,
      sujet: "EcoRide — Comment s'est passé ton trajet " + trajetTexte + " ?",
      texte:
        "Bonjour " + p.pseudo + ",\n\n" +
        "Ton covoiturage " + trajetTexte + " du " +
        dateEnFrancais(data.date_depart) + " est terminé.\n\n" +
        "Rends-toi dans ton espace EcoRide pour confirmer que tout s'est " +
        "bien passé. C'est seulement à ce moment-là que le chauffeur " +
        "recevra ses crédits.\n\n" +
        "Tu pourras aussi laisser une note et un avis.\n\n" +
        "L'équipe EcoRide",
    }));

    // L'arrivée est déjà enregistrée : un mail en échec ne doit pas
    // faire croire au chauffeur que rien ne s'est passé.
    const apercus = await envoyerMails(mails);

    res.status(200).json({
      message:
        "Trajet terminé ! " + (data.passagers || []).length +
        " passager(s) ont été invités à valider. " +
        "Tes crédits te seront versés après leur confirmation.",
      apercus_mails: apercus,
    });
  } catch (error) {
    console.error("Erreur arrivée :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- LE PASSAGER VALIDE (ou signale un problème) ----
// POST /api/covoiturages/:id/valider
// Corps : { tout_ok: true }  ou  { tout_ok: false, commentaire: "..." }
export const validerTrajet = async (req, res) => {
  try {
    const { id } = req.params;
    const passager_id = req.user.user_id;
    const { tout_ok, commentaire } = req.body;

    if (typeof tout_ok !== "boolean") {
      return res.status(400).json({
        message: "Indique si le trajet s'est bien passé ou non.",
      });
    }

    // C'est la base qui décide : elle vérifie tout et paie le chauffeur
    // (ou pas) dans une seule transaction.
    const { data, error } = await supabase.rpc("valider_trajet", {
      p_covoiturage_id: Number(id),
      p_passager_id: passager_id,
      p_tout_ok: tout_ok,
      p_commentaire: commentaire || null,
    });

    if (error) {
      if (traduireErreurTrajet(error, res)) return;
      throw error;
    }

    // --- Tout s'est bien passé ---
    if (data.valide) {
      return res.status(200).json({
        message:
          "Merci ! Le chauffeur a reçu " + data.credits_verses_au_chauffeur +
          " crédits. Tu peux maintenant laisser un avis.",
        credits_verses_au_chauffeur: data.credits_verses_au_chauffeur,
      });
    }

    // --- Un problème a été signalé ---
    // Le chauffeur N'EST PAS payé : c'est déjà garanti par la base
    // (credits_verses reste à false). On enregistre en plus le signalement
    // dans MongoDB. Attention : l'espace employé (US 12) ne lit PAS cette
    // copie, il lit PostgreSQL — c'est là que vit l'argent. MongoDB sert
    // d'historique NoSQL, il peut tomber sans bloquer quoi que ce soit.
    let signalementEnregistre = false;
    try {
      await Signalement.create({
        covoiturage_id: Number(id),
        passager_id,
        chauffeur_id: data.chauffeur_id,
        commentaire: data.commentaire,
        statut: "en_attente",
      });
      signalementEnregistre = true;
    } catch (erreurMongo) {
      // Si MongoDB est injoignable, le chauffeur reste quand même non payé :
      // c'est la base PostgreSQL qui porte cette information, pas MongoDB.
      console.error("⚠️ Signalement non enregistré dans MongoDB :", erreurMongo.message);
    }

    res.status(200).json({
      message:
        "Ton signalement a été transmis. Le chauffeur ne sera pas payé " +
        "tant qu'un employé n'aura pas examiné la situation.",
      credits_verses_au_chauffeur: 0,
      signalement_enregistre: signalementEnregistre,
    });
  } catch (error) {
    console.error("Erreur validation :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};
