# La base de données

## 1. Ce que ça fait, en 2 phrases

EcoRide utilise **deux** bases : PostgreSQL (via Supabase) pour tout ce qui est structuré
et relié — comptes, véhicules, trajets, réservations, avis — et MongoDB pour deux choses
peu structurées : les journaux d'activité et les signalements de trajets mal passés.
Trois fichiers SQL permettent de reconstruire la base : `schema.sql` crée les tables,
`migration_v2.sql` met à jour une base déjà existante, et `seed.sql` la remplit de données de test.

---

## 2. Les 8 tables et leurs liens

```
roles ──< users ──< vehicules ──< covoiturages ──< participations
                │                      │                 │
                ├──< preferences        └──────────< avis >┘
                └──< preferences_personnalisees
```

| Table | À quoi elle sert | US |
|---|---|---|
| `roles` | les 3 rôles : utilisateur, employé, administrateur | 12, 13 |
| `users` | tous les comptes + leurs crédits | 7, 8, 13 |
| `vehicules` | plaque, date de 1re immatriculation, couleur, énergie | 8 |
| `preferences` | fumeur / animaux (une ligne par chauffeur) | 8 |
| `preferences_personnalisees` | préférences libres, autant qu'on veut | 8 |
| `covoiturages` | les trajets + la commission de la plateforme | 3, 9, 13 |
| `participations` | qui a réservé quoi, validation, annulation | 6, 10, 11 |
| `avis` | note + commentaire, à valider par un employé | 11, 12 |

### Les colonnes ajoutées pour les US 8 à 13

| Colonne | Table | Pourquoi |
|---|---|---|
| `credits_plateforme` | covoiturages | US 9 : les 2 crédits prélevés, figés à la création du trajet |
| `annule_le` | covoiturages | US 10 : date d'annulation par le chauffeur |
| `valide_le` | participations | US 11 : quand le passager a validé |
| `credits_verses` | participations | US 11 : évite de payer le chauffeur deux fois |
| `annule_le` | participations | US 10 : date d'annulation par le passager |
| *(table entière)* | preferences_personnalisees | US 8 : préférences libres |

---

## 3. Les points importants, expliqués

### Les dates sont RELATIVES

```sql
CURRENT_DATE - INTERVAL '7 days'   -- il y a une semaine
CURRENT_DATE + INTERVAL '12 days'  -- dans douze jours
```
Si j'avais écrit `'2025-07-15'`, tous mes trajets seraient périmés le jour de la soutenance.
Avec `CURRENT_DATE`, la base se recale toute seule : il y a **toujours** des trajets à venir,
quel que soit le jour où j'exécute le fichier.

### Les clés étrangères (`REFERENCES`)

```sql
chauffeur_id INTEGER NOT NULL REFERENCES users(user_id)
```
Cette ligne veut dire : « ce numéro doit forcément correspondre à un compte existant ».
La base refuse de créer un trajet pour un chauffeur qui n'existe pas. C'est elle qui garantit
la cohérence, même si le code se trompe.

```sql
user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE
```
`ON DELETE CASCADE` sur les véhicules : si on supprime un compte, ses véhicules partent avec lui.
Je ne l'ai **pas** mis sur les trajets : supprimer un compte ne doit pas faire disparaître
l'historique des trajets des autres passagers.

### Les contraintes `CHECK` : la base se défend toute seule

```sql
CONSTRAINT vehicules_energie_valide
    CHECK (energie IN ('electrique', 'hybride', 'essence', 'diesel', 'gpl'))
```
Sans ça, on pouvait enregistrer `'Electrique'` avec une majuscule. Et comme le code teste
`energie === "electrique"`, le badge écologique n'apparaissait pas, **sans aucune erreur visible**.
La contrainte transforme un bug silencieux en refus immédiat.

```sql
CONSTRAINT covoiturages_places_coherentes
    CHECK (nb_places_restantes >= 0 AND nb_places_restantes <= nb_places_total)
```
Impossible d'avoir -1 place, ou 5 places restantes sur un trajet qui n'en propose que 3.

### La contrainte `UNIQUE` qui corrige un vrai bug

```sql
CONSTRAINT preferences_user_id_unique UNIQUE (user_id)
```
Le code enregistre les préférences avec un `upsert` (« mets à jour si ça existe, sinon crée »).
PostgreSQL **refuse** un upsert si la colonne visée n'a pas de contrainte UNIQUE.
Sans cette ligne, sauvegarder ses préférences renvoyait une erreur 500. Je l'ai vérifié :
sur une base sans la contrainte l'upsert échoue, et il fonctionne une fois la contrainte posée.

### Les index

```sql
CREATE INDEX idx_covoiturages_recherche
    ON covoiturages (ville_depart, ville_arrivee, date_depart);
```
Un index, c'est l'index d'un livre : au lieu de lire les 206 lignes une par une, la base
saute directement aux bonnes. Les trois colonnes sont dans le même index parce que la
recherche de l'US 3 les utilise **ensemble**.

### Pourquoi deux bases ?

PostgreSQL est fait pour des données **reliées entre elles** : un trajet appartient à un
chauffeur, qui a des véhicules, etc. Les clés étrangères garantissent cette cohérence.
MongoDB stocke des documents **indépendants** les uns des autres, sans schéma fixe : un log
ou un signalement n'a pas besoin d'être relié à quoi que ce soit, et sa forme peut changer.

---

## 4. Cinq questions du jury, et les réponses

**Q1 — Pourquoi des dates relatives dans le jeu de données ?**
Parce qu'un jeu de données avec des dates écrites en dur devient périmé. Mon ancien fichier
ne contenait qu'un trajet au 15 juillet 2025 : le jour de la soutenance, une recherche à la
date du jour n'aurait rien donné. Avec `CURRENT_DATE + INTERVAL '12 days'`, les dates se
recalculent au moment où j'exécute le fichier, donc il y a toujours des trajets à venir.

**Q2 — Quelle est la différence entre `schema.sql` et `migration_v2.sql` ?**
`schema.sql` part d'une base **vide** et crée tout. `migration_v2.sql` s'applique sur une base
qui contient **déjà des données** : il ajoute seulement ce qui manque, sans rien supprimer.
Il est aussi idempotent, c'est-à-dire qu'on peut le relancer plusieurs fois sans erreur,
grâce aux `IF NOT EXISTS` et aux `DROP CONSTRAINT IF EXISTS` avant chaque ajout.

**Q3 — Pourquoi avoir changé le prix de DECIMAL à INTEGER ?**
Parce que le prix est exprimé en crédits, et que les crédits sont des nombres entiers partout
ailleurs dans l'application. Avec `DECIMAL(6,2)`, j'avais un trajet à 24,48 crédits, ce qui
n'a aucun sens et provoquait des arrondis bizarres dans les calculs de paiement du chauffeur.
La migration convertit les valeurs existantes avec `ROUND()`.

**Q4 — Comment garantissez-vous que le chauffeur n'est pas payé deux fois ?**
Par la colonne `credits_verses` sur `participations`. Elle vaut `FALSE` au départ, et passe à
`TRUE` au moment où le chauffeur est crédité. Avant de payer, le code vérifie qu'elle est
encore à `FALSE`. C'est aussi ce qui permet de **ne pas** payer tant qu'un signalement n'a pas
été traité par un employé (US 11 et 12).

**Q5 — Pourquoi stocker la commission sur le trajet plutôt que de l'écrire dans le code ?**
Parce que si demain la plateforme passe de 2 à 3 crédits, les anciens trajets doivent garder
leur commission d'origine, sinon les statistiques de l'administrateur deviennent fausses
rétroactivement. La valeur est donc figée à la création du trajet, dans
`covoiturages.credits_plateforme`.

---

## 5. Ce qui a été vérifié

Les trois fichiers ont été testés dans un **schéma séparé** de la base Supabase, sans jamais
toucher aux données réelles :

| Vérification | Résultat |
|---|---|
| `schema.sql` crée les 8 tables | ✅ |
| Le vrai SQL de `seed.sql` s'insère | ✅ |
| Énergie inventée refusée | ✅ |
| Places incohérentes refusées | ✅ |
| Prix à zéro refusé | ✅ |
| Note hors 1–5 refusée | ✅ |
| Double avis refusé | ✅ |
| Doublon de préférences refusé | ✅ |
| **Upsert des préférences (bug corrigé)** | ✅ |
| Crédits négatifs refusés | ✅ |
| `migration_v2.sql` sur l'ancienne structure | ✅ données conservées |
| Doublon de préférences nettoyé | ✅ 2 lignes → 1 |
| Prix 24,48 converti en entier | ✅ 24 |
| Migration rejouée une 2e fois | ✅ aucune erreur |
| Intégrité des 206 trajets (clés, contraintes) | ✅ 0 erreur |
