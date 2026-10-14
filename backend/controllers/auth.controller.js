import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import supabase from "../config/supabase.js";
import { Log } from "../config/models.mongo.js";

// ============================================
// US 7 — INSCRIPTION
// Pseudo + email + mot de passe sécurisé, et 20 crédits offerts.
// ============================================

// --- Les règles de validation, écrites une seule fois ---

// Le mot de passe doit contenir :
//   (?=.*[a-z])   au moins une minuscule
//   (?=.*[A-Z])   au moins une majuscule
//   (?=.*\d)      au moins un chiffre
//   (?=.*[^\w\s]) au moins un caractère spécial (!, ?, @, #...)
//   .{8,}         et faire 8 caractères minimum
// Les (?=...) s'appellent des "vérifications en avant" : chacune regarde
// tout le texte sans le consommer. Elles doivent TOUTES être satisfaites.
const REGLE_MOT_DE_PASSE = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,}$/;
const AIDE_MOT_DE_PASSE =
  "Le mot de passe doit contenir au moins 8 caractères, une minuscule, " +
  "une majuscule, un chiffre et un caractère spécial.";

// Format d'email : du texte, un @, du texte, un point, au moins 2 lettres.
// Ce n'est pas une vérification parfaite (seul un email envoyé le prouve),
// mais ça écarte les saisies manifestement fausses comme "pas-un-email".
const REGLE_EMAIL = /^[^\s@]+@[^\s@]+\.[a-z]{2,}$/i;

export const register = async (req, res) => {
  try {
    const { pseudo, email, password } = req.body;

    // --- 1. Tous les champs sont-ils là ? ---
    if (!pseudo || !email || !password) {
      return res.status(400).json({ message: "Tous les champs sont obligatoires." });
    }

    // --- 2. On met au propre avant de vérifier ---
    // trim() enlève les espaces au début et à la fin.
    // toLowerCase() sur l'email : sinon "Gracie@test.fr" et "gracie@test.fr"
    // créeraient DEUX comptes différents, alors que c'est la même adresse.
    const pseudoPropre = pseudo.trim();
    const emailPropre = email.trim().toLowerCase();

    // --- 3. Le pseudo ---
    if (pseudoPropre.length < 3 || pseudoPropre.length > 50) {
      return res.status(400).json({
        message: "Le pseudo doit faire entre 3 et 50 caractères.",
      });
    }

    // --- 4. L'email ---
    if (!REGLE_EMAIL.test(emailPropre)) {
      return res.status(400).json({ message: "Cet email n'est pas valide." });
    }

    // --- 5. Le mot de passe ---
    if (!REGLE_MOT_DE_PASSE.test(password)) {
      return res.status(400).json({ message: AIDE_MOT_DE_PASSE });
    }

    // --- 6. L'email est-il déjà pris ? ---
    const { data: emailExistant } = await supabase
      .from("users")
      .select("user_id")
      .eq("email", emailPropre)
      .maybeSingle();

    if (emailExistant) {
      return res.status(400).json({ message: "Cet email est déjà utilisé." });
    }

    // --- 7. Le pseudo est-il déjà pris ? ---
    // Sans cette vérification, la base refusait l'enregistrement (le pseudo
    // est UNIQUE) et la personne recevait un "Erreur serveur" incompréhensible.
    // ilike compare sans tenir compte des majuscules.
    const { data: pseudoExistant } = await supabase
      .from("users")
      .select("user_id")
      .ilike("pseudo", pseudoPropre)
      .maybeSingle();

    if (pseudoExistant) {
      return res.status(400).json({ message: "Ce pseudo est déjà pris." });
    }

    // --- 8. On chiffre le mot de passe ---
    // bcrypt transforme le mot de passe en une empreinte impossible à
    // inverser. Le 10 est le "coût" : plus il est élevé, plus le calcul est
    // lent, donc plus une attaque par essais successifs est coûteuse.
    const hashedPassword = await bcrypt.hash(password, 10);

    // --- 9. On crée le compte ---
    // credits (20) et role_id (1) ne sont pas envoyés ici : ce sont les
    // valeurs par défaut définies dans la base. Comme ça, personne ne peut
    // s'inscrire en se donnant 999 crédits ou le rôle administrateur.
    const { data: newUser, error } = await supabase
      .from("users")
      .insert({
        pseudo: pseudoPropre,
        email: emailPropre,
        password: hashedPassword,
      })
      .select()
      .single();

    if (error) {
      // Filet de sécurité : si deux personnes s'inscrivent au même instant
      // avec le même pseudo, les vérifications 6 et 7 peuvent toutes les deux
      // passer. C'est alors la base qui refuse, avec le code 23505.
      if (error.code === "23505") {
        return res.status(400).json({
          message: "Ce pseudo ou cet email vient d'être pris.",
        });
      }
      throw error;
    }

    // Le log est un bonus : s'il échoue, le compte reste créé.
    try {
      await Log.create({
        type: "inscription",
        user_id: newUser.user_id,
        pseudo: newUser.pseudo,
        details: "Nouveau compte créé",
      });
    } catch (mongoError) {
      console.log("Log Mongo non enregistré :", mongoError.message);
    }

    res.status(201).json({
      message: "Compte créé avec succès.",
      credits: newUser.credits, // les 20 crédits offerts (US 7)
    });
  } catch (error) {
    console.error("Erreur inscription :", error);
    res.status(500).json({ message: "Erreur serveur." });
  }
};

// CONNEXION
export const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        message: "Email et mot de passe requis.",
      });
    }

    // Même mise au propre qu'à l'inscription : les emails sont enregistrés
    // en minuscules, donc on cherche en minuscules. Sans ça, taper
    // "Gracie@Test.fr" ne retrouverait pas le compte "gracie@test.fr".
    const emailPropre = email.trim().toLowerCase();

    const { data: user, error } = await supabase
      .from("users")
      .select("*")
      .eq("email", emailPropre)
      .maybeSingle();

    if (error || !user) {
      return res.status(401).json({
        message: "Email ou mot de passe incorrect.",
      });
    }

    if (user.est_suspendu) {
      return res.status(403).json({
        message: "Ton compte a été suspendu.",
      });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);

    if (!isPasswordValid) {
      return res.status(401).json({
        message: "Email ou mot de passe incorrect.",
      });
    }

    const token = jwt.sign(
      {
        user_id: user.user_id,
        pseudo: user.pseudo,
        role_id: user.role_id,
      },
      process.env.JWT_SECRET,
      { expiresIn: "24h" }
    );

    try {
      await Log.create({
        type: "connexion",
        user_id: user.user_id,
        pseudo: user.pseudo,
        details: "Connexion réussie",
      });
    } catch (mongoError) {
      console.log("Log Mongo non enregistré :", mongoError.message);
    }

    res.status(200).json({
      token,
      user: {
        user_id: user.user_id,
        pseudo: user.pseudo,
        email: user.email,
        credits: user.credits,
        role_id: user.role_id,
        est_chauffeur: user.est_chauffeur,
        est_passager: user.est_passager,
      },
    });
  } catch (error) {
    console.error("Erreur connexion :", error);
    res.status(500).json({
      message: "Erreur serveur.",
    });
  }
};
