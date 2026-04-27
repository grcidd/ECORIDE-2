// ============================================
// Historique passager avec bouton laisser un avis
// ============================================

async function chargerHistoriquePassager() {
  const res = await apiProtegee("/covoiturages/historique");
  const data = await res.json();

  const container = document.getElementById("historique-passager");
  if (!container) return;

  if (!data.passager || data.passager.length === 0) {
    container.innerHTML = "<p>Aucun trajet pour l'instant.</p>";
    return;
  }

  const items = await Promise.all(
    data.passager.map(async (p) => {
      const trajet = p.covoiturage;
      let boutonAvis = "";

      // On vérifie si l'utilisateur peut encore noter ce trajet
      if (trajet.statut === "termine") {
        const check = await apiProtegee(
          `/avis/peux-noter/${trajet.covoiturage_id}`
        );
        const checkData = await check.json();

        if (checkData.peutNoter) {
          boutonAvis = `
              <button 
                class="btn btn--secondaire btn--petit" 
                onclick="ouvrirFormulaireAvis(${trajet.covoiturage_id})"
              >
                ⭐ Laisser un avis
              </button>`;
        } else if (checkData.raison === "deja_note") {
          boutonAvis = `<span class="badge-eco">✅ Avis envoyé</span>`;
        }
      }

      return `
          <div class="card-historique">
            <div class="card-historique__trajet">
              <strong>${trajet.ville_depart} → ${trajet.ville_arrivee}</strong>
              <span>${trajet.date_depart} | ${trajet.heure_depart}</span>
              <span class="statut statut--${trajet.statut}">${trajet.statut}</span>
            </div>
            <div class="card-historique__actions">
              <span>${p.credits_utilises} crédits dépensés</span>
              ${boutonAvis}
            </div>
          </div>`;
    })
  );

  container.innerHTML = items.join("");
}

// ============================================
// Modale pour soumettre un avis
// ============================================

function ouvrirFormulaireAvis(covoiturage_id) {
  // On crée la modale dynamiquement si elle n'existe pas
  let modale = document.getElementById("modale-avis");
  if (!modale) {
    modale = document.createElement("div");
    modale.id = "modale-avis";
    modale.className = "modale-overlay";
    document.body.appendChild(modale);
  }

  modale.innerHTML = `
      <div class="modale-contenu">
        <button class="modale-fermer" onclick="fermerModaleAvis()">✕</button>
        <h3>Laisser un avis</h3>
        <p>Ta note sera visible après validation par notre équipe.</p>
  
        <div class="etoiles" id="etoiles">
          ${[1, 2, 3, 4, 5]
            .map(
              (n) => `
            <span 
              class="etoile" 
              data-note="${n}" 
              onclick="selectionnerNote(${n})"
            >☆</span>`
            )
            .join("")}
        </div>
        <p id="note-texte" style="text-align:center; color: var(--vert-principal); font-weight:700; min-height:20px;"></p>
  
        <textarea 
          id="commentaire-avis" 
          placeholder="Un commentaire ? (facultatif)" 
          rows="4"
          style="width:100%; margin-top:12px; padding:12px; border:1px solid var(--gris-bordure); border-radius:var(--radius-petit); font-family:var(--font-corps); resize:vertical;"
        ></textarea>
  
        <button 
          class="btn btn--principal" 
          style="width:100%; margin-top:16px;"
          onclick="envoyerAvis(${covoiturage_id})"
        >
          Envoyer mon avis
        </button>
      </div>`;

  modale.style.display = "flex";
  noteSelectionnee = 0; // reset
}

let noteSelectionnee = 0;

function selectionnerNote(n) {
  noteSelectionnee = n;
  // Mise à jour visuelle des étoiles
  document.querySelectorAll(".etoile").forEach((el) => {
    el.textContent = Number(el.dataset.note) <= n ? "⭐" : "☆";
  });
  const labels = [
    "",
    "Très mauvais",
    "Mauvais",
    "Correct",
    "Bien",
    "Excellent",
  ];
  document.getElementById("note-texte").textContent = labels[n];
}

function fermerModaleAvis() {
  const modale = document.getElementById("modale-avis");
  if (modale) modale.style.display = "none";
}

async function envoyerAvis(covoiturage_id) {
  if (!noteSelectionnee) {
    alert("Merci de sélectionner une note entre 1 et 5.");
    return;
  }

  const commentaire = document.getElementById("commentaire-avis").value.trim();

  const res = await apiProtegee("/avis", {
    method: "POST",
    body: JSON.stringify({
      covoiturage_id,
      note: noteSelectionnee,
      commentaire,
    }),
  });

  const data = await res.json();

  if (res.ok) {
    fermerModaleAvis();
    alert("✅ " + data.message);
    chargerHistoriquePassager(); // rafraîchit la liste
  } else {
    alert("❌ " + data.message);
  }
}
