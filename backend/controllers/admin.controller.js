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
    const { data, error } = await supabase
      .from("users")
      .select("*")
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

    const { error } = await supabase
      .from("users")
      .update({ est_suspendu: true })
      .eq("user_id", id);

    if (error) throw error;

    res.status(200).json({ message: "Utilisateur suspendu." });
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
