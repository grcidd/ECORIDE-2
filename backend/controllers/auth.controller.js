import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import supabase from "../config/supabase.js";
import { Log } from "../config/models.mongo.js";

// INSCRIPTION
export const register = async (req, res) => {
  try {
    const { pseudo, email, password } = req.body;

    if (!pseudo || !email || !password) {
      return res.status(400).json({
        message: "Tous les champs sont obligatoires.",
      });
    }

    const passwordRegex = /^(?=.*[A-Z])(?=.*\d).{8,}$/;
    if (!passwordRegex.test(password)) {
      return res.status(400).json({
        message:
          "Le mot de passe doit contenir au moins 8 caractères, une majuscule et un chiffre.",
      });
    }

    const { data: existingUser } = await supabase
      .from("users")
      .select("user_id")
      .eq("email", email)
      .maybeSingle();

    if (existingUser) {
      return res.status(400).json({
        message: "Cet email est déjà utilisé.",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const { data: newUser, error } = await supabase
      .from("users")
      .insert({
        pseudo,
        email,
        password: hashedPassword,
      })
      .select()
      .single();

    if (error) {
      throw error;
    }

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
    });
  } catch (error) {
    console.error("Erreur inscription :", error);
    res.status(500).json({
      message: "Erreur serveur.",
    });
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

    const { data: user, error } = await supabase
      .from("users")
      .select("*")
      .eq("email", email)
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
