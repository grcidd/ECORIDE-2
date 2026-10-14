// ============================================
// ENVOI D'E-MAILS (US 10 et US 11)
//
// Deux cas de figure :
//
//  1. Un vrai serveur d'envoi est configuré dans le .env (MAIL_HOST,
//     MAIL_USER, MAIL_PASS) → on l'utilise, les mails partent pour de vrai.
//
//  2. Rien n'est configuré → on crée automatiquement un compte de test
//     chez Ethereal. Les mails ne partent chez personne, mais Nodemailer
//     renvoie un LIEN pour les lire dans le navigateur.
//     C'est ce lien qui s'affiche dans la console du serveur : parfait
//     pour montrer les mails pendant la soutenance.
// ============================================

import nodemailer from "nodemailer";

// Transforme "2026-10-28" en "28 octobre 2026", plus agréable dans un mail.
export function dateEnFrancais(date) {
  if (!date) return "";
  return new Date(date).toLocaleDateString("fr-FR", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

// Le "transporteur", c'est l'objet qui sait envoyer les mails.
// On le crée UNE SEULE FOIS et on le réutilise : créer un compte Ethereal
// à chaque envoi serait lent et donnerait une boîte différente à chaque fois.
let transporteur = null;
let modeTest = false;

async function getTransporteur() {
  if (transporteur) return transporteur;

  // Cas 1 : un vrai serveur est configuré
  if (process.env.MAIL_HOST && process.env.MAIL_USER && process.env.MAIL_PASS) {
    transporteur = nodemailer.createTransport({
      host: process.env.MAIL_HOST,
      port: Number(process.env.MAIL_PORT) || 587,
      secure: Number(process.env.MAIL_PORT) === 465,
      auth: {
        user: process.env.MAIL_USER,
        pass: process.env.MAIL_PASS,
      },
    });
    console.log("📧 Mails : serveur réel (" + process.env.MAIL_HOST + ")");
    return transporteur;
  }

  // Cas 2 : compte de test Ethereal, créé automatiquement
  const compte = await nodemailer.createTestAccount();
  transporteur = nodemailer.createTransport({
    host: compte.smtp.host,
    port: compte.smtp.port,
    secure: compte.smtp.secure,
    auth: { user: compte.user, pass: compte.pass },
  });
  modeTest = true;
  console.log("📧 Mails : compte de TEST Ethereal (aucun mail ne part vraiment)");
  return transporteur;
}

// ---- Envoyer un mail ----
// Renvoie { envoye: true/false, apercu: "lien ou null" }.
// ⚠️ Cette fonction ne lève JAMAIS d'erreur : un mail qui échoue ne doit
// pas faire échouer l'annulation d'un trajet, qui est déjà enregistrée.
export async function envoyerMail({ destinataire, sujet, texte, html }) {
  try {
    const envoyeur = await getTransporteur();

    const info = await envoyeur.sendMail({
      from: '"EcoRide" <' + (process.env.MAIL_USER || "no-reply@ecoride.fr") + ">",
      to: destinataire,
      subject: sujet,
      text: texte,
      // Si on ne fournit pas de version HTML, on fabrique la version HTML
      // à partir du texte. replaceAll("\n", "<br>") est indispensable :
      // en HTML, un retour à la ligne du texte ne s'affiche PAS, tout
      // apparaîtrait collé sur une seule ligne.
      html: html || "<p>" + texte.replaceAll("\n", "<br>") + "</p>",
    });

    // En mode test, Nodemailer fournit un lien pour LIRE le mail
    const apercu = modeTest ? nodemailer.getTestMessageUrl(info) : null;

    if (apercu) {
      console.log("📧 Mail pour " + destinataire + " → " + apercu);
    } else {
      console.log("📧 Mail envoyé à " + destinataire);
    }

    return { envoye: true, apercu };
  } catch (erreur) {
    console.error("❌ Mail non envoyé à " + destinataire + " :", erreur.message);
    return { envoye: false, apercu: null };
  }
}

// ---- Envoyer le même mail à plusieurs personnes ----
// On les envoie en parallèle avec Promise.all, c'est plus rapide
// que d'attendre chaque mail l'un après l'autre.
export async function envoyerMails(liste) {
  const resultats = await Promise.all(liste.map((m) => envoyerMail(m)));
  return resultats.filter((r) => r.apercu).map((r) => r.apercu);
}
