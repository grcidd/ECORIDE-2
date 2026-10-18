import supabase from "../config/supabase.js";

// ============================================
// Traduction des codes d'erreur de la base en phrases françaises.
// La fonction PostgreSQL lève par exemple 'DEJA_TRAITE' ; ici on
// transforme ça en message lisible + le bon code HTTP.
// (Même principe que MESSAGES_TRAJET dans covoiturages.controller.js)
// ============================================
const MESSAGES_SIGNALEMENT = {
  SIGNALEMENT_INTROUVABLE: { code: 404, message: "Ce signalement n'existe pas." },
  PAS_UN_SIGNALEMENT: { code: 400, message: "Ce trajet n'a pas été signalé." },
  DEJA_TRAITE: { code: 400, message: "Ce signalement a déjà été traité." },
  TRAJET_INTROUVABLE: { code: 404, message: "Le trajet lié n'existe plus." },
};

function traduireErreurSignalement(error, res) {
  const codes = Object.keys(MESSAGES_SIGNALEMENT);
  const trouve = codes.find((c) => error.message.includes(c));
  if (!trouve) return false;
  const reponse = MESSAGES_SIGNALEMENT[trouve];
  res.status(reponse.code).json({ message: reponse.message });
  return true;
}

// ---- Récupérer les avis en attente de modération ----
// GET /api/admin/avis
export const getAvisEnAttente = async (req, res) => {
  try {
    // On va chercher en une seule requête le pseudo de la passagère,
    // celui du chauffeur et les villes du trajet.
    // Deux colonnes de la table "avis" pointent vers la table "users"
    // (passager_id ET chauffeur_id) : il faut donc préciser le nom exact
    // de la clé étrangère, sinon la base ne sait pas laquelle utiliser.
    const { data, error } = await supabase
      .from("avis")
      .select(
        `
        avis_id, note, commentaire, created_at,
        passager:users!avis_passager_id_fkey (pseudo),
        chauffeur:users!avis_chauffeur_id_fkey (pseudo),
        covoiturage:covoiturages (ville_depart, ville_arrivee, date_depart)
      `
      )
      .eq("statut", "en_attente")
      .order("created_at", { ascending: false });

    if (error) throw error;

    // Le front attend { avis: [...] }, pas un tableau tout nu.
    res.status(200).json({ avis: data || [] });
  } catch (error) {
    console.error("Erreur getAvisEnAttente :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- US 12 : la liste des signalements à traiter ----
// GET /api/admin/signalements
//
// D'OÙ VIENNENT CES DONNÉES ?
// De PostgreSQL, pas de MongoDB. C'est important : c'est dans PostgreSQL
// que vit l'argent (la colonne credits_verses). MongoDB ne sert qu'à
// garder une copie pour les journaux.
//
// Un signalement, c'est une participation où :
//   trajet_valide = false        → la passagère a dit « ça s'est mal passé »
//   signalement_traite_le = null → aucun employé n'a encore tranché
export const getSignalements = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("participations")
      .select(
        `
        participation_id, commentaire_probleme, valide_le, credits_verses,
        passager:users!participations_passager_id_fkey (pseudo, email),
        covoiturage:covoiturages (
          covoiturage_id, ville_depart, ville_arrivee, date_depart,
          prix_par_personne, credits_plateforme,
          chauffeur:users!covoiturages_chauffeur_id_fkey (user_id, pseudo, email)
        )
      `
      )
      .eq("trajet_valide", false)
      .is("signalement_traite_le", null)
      .order("valide_le", { ascending: false });

    if (error) throw error;

    res.status(200).json({ signalements: data || [] });
  } catch (error) {
    console.error("Erreur getSignalements :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// ---- US 12 : l'employé tranche un signalement ----
// PATCH /api/admin/signalements/:id
// body : { crediter: true }  → l'employé donne raison au chauffeur, il est payé
//        { crediter: false } → l'employé donne raison à la passagère, pas de paiement
export const traiterSignalement = async (req, res) => {
  try {
    const { id } = req.params;
    const { crediter } = req.body || {};

    if (typeof crediter !== "boolean") {
      return res.status(400).json({
        message: "Indique si le chauffeur doit être payé ou non.",
      });
    }

    // C'est la base qui fait tout le travail : elle vérifie, paie (ou pas)
    // et note la décision, le tout dans une seule transaction.
    const { data, error } = await supabase.rpc("traiter_signalement", {
      p_participation_id: Number(id),
      p_employe_id: req.user.user_id, // vient du jeton JWT, jamais du navigateur
      p_crediter: crediter,
    });

    if (error) {
      if (traduireErreurSignalement(error, res)) return;
      throw error;
    }

    if (data.decision === "credite") {
      return res.status(200).json({
        message:
          "Signalement classé sans suite. Le chauffeur a reçu " +
          data.credits_verses_au_chauffeur +
          " crédits.",
        decision: data.decision,
        credits_verses_au_chauffeur: data.credits_verses_au_chauffeur,
      });
    }

    res.status(200).json({
      message:
        "Signalement confirmé. Le chauffeur ne sera pas payé pour ce trajet.",
      decision: data.decision,
      credits_verses_au_chauffeur: 0,
    });
  } catch (error) {
    console.error("Erreur traiterSignalement :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

export const validerAvis = async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabase
      .from("avis")
      .update({ statut: "valide" })
      .eq("avis_id", id);

    if (error) throw error;

    res.status(200).json({ message: "Avis validé." });
  } catch (error) {
    console.error("Erreur validerAvis :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

export const refuserAvis = async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabase
      .from("avis")
      .update({ statut: "refuse" })
      .eq("avis_id", id);

    if (error) throw error;

    res.status(200).json({ message: "Avis refusé." });
  } catch (error) {
    console.error("Erreur refuserAvis :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

export const getUtilisateurs = async (req, res) => {
  try {
    // ⚠️ SÉCURITÉ : on liste les colonnes une par une.
    // Surtout PAS select("*") : ça renverrait aussi la colonne "password"
    // (le mot de passe chiffré), qui ne doit jamais sortir de l'API.
    const { data, error } = await supabase
      .from("users")
      .select(
        "user_id, pseudo, email, credits, role_id, est_chauffeur, est_passager, est_suspendu, created_at"
      )
      .order("created_at", { ascending: false });

    if (error) throw error;

    res.status(200).json(data || []);
  } catch (error) {
    console.error("Erreur getUtilisateurs :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

export const suspendreUtilisateur = async (req, res) => {
  try {
    const { id } = req.params;

    // Le front envoie { suspendre: true } pour bloquer, { suspendre: false } pour réactiver.
    // Si rien n'est envoyé, on suspend par défaut.
    let suspendre = true;
    if (req.body && req.body.suspendre === false) {
      suspendre = false;
    }

    // Garde-fou : un admin ne doit pas pouvoir se bloquer lui-même,
    // sinon plus personne ne peut administrer le site.
    if (Number(id) === req.user.user_id) {
      return res
        .status(400)
        .json({ message: "Tu ne peux pas suspendre ton propre compte." });
    }

    const { error } = await supabase
      .from("users")
      .update({ est_suspendu: suspendre })
      .eq("user_id", id);

    if (error) throw error;

    if (suspendre) {
      res.status(200).json({ message: "Utilisateur suspendu." });
    } else {
      res.status(200).json({ message: "Utilisateur réactivé." });
    }
  } catch (error) {
    console.error("Erreur suspendreUtilisateur :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

export const getStats = async (req, res) => {
  try {
    const { count: totalUsers } = await supabase
      .from("users")
      .select("*", { count: "exact", head: true });

    const { count: totalTrajets } = await supabase
      .from("covoiturages")
      .select("*", { count: "exact", head: true });

    const { count: totalAvis } = await supabase
      .from("avis")
      .select("*", { count: "exact", head: true });

    res.status(200).json({
      totalUsers: totalUsers || 0,
      totalTrajets: totalTrajets || 0,
      totalAvis: totalAvis || 0,
    });
  } catch (error) {
    console.error("Erreur getStats :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};
