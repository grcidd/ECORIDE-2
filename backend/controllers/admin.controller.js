import supabase from "../config/supabase.js";

// Récupérer les avis en attente
export const getAvisEnAttente = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("avis")
      .select("*")
      .eq("statut", "en_attente")
      .order("created_at", { ascending: false });

    if (error) throw error;

    res.status(200).json(data || []);
  } catch (error) {
    console.error("Erreur getAvisEnAttente :", error);
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
