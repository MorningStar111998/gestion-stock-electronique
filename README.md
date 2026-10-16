# Outil interne de gestion de stock, devis et factures

Application interne pour un magasin d'électronique qui vend des PC, des téléphones, des panneaux solaires et des caméras de surveillance. Projet d'apprentissage et de portfolio.

**Stack prévue** : React (interface), Node.js avec Express (API), PostgreSQL (base de données).

**Structure du dépôt**

```
gestion-stock-electronique/
├── backend/    API Node.js + Express (Phases 2 et 3)
├── frontend/   React + Vite (Phase 5)
├── docs/       schema.dbml, notes_check_et_index.md
├── .gitignore
└── README.md
```

**Ce document couvre la phase de modélisation.** Le schéma est écrit en DBML et se visualise sur dbdiagram.io (à enregistrer dans le dépôt sous `docs/schema.dbml`). Les explications détaillées sur NOT NULL, CHECK et index sont dans `docs/notes_check_et_index.md`.

---

## 1. Modèle de données en bref

| Table | Rôle |
|---|---|
| `utilisateur` | Comptes qui se connectent. Un champ `role` (employe, chef_equipe, admin) détermine les droits. |
| `client` | Fiche de données d'un client (pas de connexion, pas de droits). |
| `produit` | Table parent : champs communs à tous les produits (nom, prix, référence, catégorie, stock...). |
| `telephone`, `ordinateur`, `panneau_solaire`, `camera` | Tables filles : attributs spécifiques à chaque catégorie. Relation 1-1 avec `produit` (`produit_id` est à la fois clé primaire et clé étrangère). |
| `devis` + `ligne_devis` | Un devis et ses lignes (produit, quantité, prix figé). |
| `facture` + `ligne_facture` | Une facture et ses lignes. Peut venir d'un devis (`devis_id` unique et nullable) ou exister seule. |

**Pourquoi des tables filles ?** Elles servent à stocker des attributs spécifiques et typés (RAM d'un PC, résolution d'une caméra). Elles ne servent pas à identifier la catégorie : c'est le rôle de la colonne `produit.categorie`.

**Pourquoi une table parent ?** Pour traiter tous les produits ensemble (recherche, tri, stock) et pour que `ligne_devis` et `ligne_facture` pointent vers un seul type de clé (`produit.id`).

**Pas de colonne "total".** Le total d'un devis ou d'une facture se calcule en additionnant `quantite * prix_unitaire` sur ses lignes. Une seule source de vérité.

---

## 2. Décisions métier

1. **Catégories limitées** aux tables filles existantes, plus la valeur `autre` (par défaut, sans table fille, utilisable pour les accessoires). Ajouter une vraie catégorie demande une nouvelle table, une migration et du code. Limite connue.
2. **Produit créé non disponible** (`disponible_a_la_vente = false`) : on peut préparer la fiche avant l'arrivée du produit, puis l'activer. Risque : un produit oublié reste invisible sans erreur. Parades prévues : un pop-up à la création qui le rappelle, et un filtre "produits non disponibles" sur la page stock.
3. **Le stock est décrémenté à l'émission de la facture**, jamais à la création du devis. Le devis ne réserve rien (voulu). Pendant la composition d'un devis, l'interface affiche le stock disponible à chaque ligne ajoutée. Le devis doit mentionner que le stock peut changer.
4. **Stock insuffisant à la facturation** : l'émission est refusée avec un avertissement.
5. **Facture annulée** : la facture n'est jamais supprimée, son statut passe à `annulee`. Une boîte de confirmation demande si le stock doit être restitué (l'annulation peut ne concerner que l'aspect financier). Le serveur applique le choix (paramètre `restituer_stock`), pas React.
6. **Prix figés** : `prix_unitaire` est copié dans chaque ligne au moment de sa création. Un changement de prix du produit ne modifie pas les anciens devis et factures.
7. **Infos client figées** : `nom_complet`, `email` et `adresse` sont copiés dans le devis et dans la facture. Si la fiche client change plus tard, les anciens documents restent tels qu'émis.
8. **Origine des infos client sur une facture** : si la facture vient d'un devis et que `devis.expire_le` n'est pas dépassée au moment de l'émission, elle copie les infos depuis le devis. Sinon, elle les copie depuis `client`.
9. **Pas de suppression des historiques** : on désactive (`actif`, `disponible_a_la_vente`) ou on annule (`annulee`), on ne supprime pas. Les clés étrangères vers `produit`, `client`, `utilisateur`, ainsi que `ligne_facture.facture_id` et `facture.devis_id`, sont en `delete: restrict`. Seule `ligne_devis.devis_id` est en `cascade`.
10. **Numéros** : `numero_devis` et `numero_facture` sont uniques et générés par le code, de façon séquentielle. Une facture annulée garde son numéro.
11. **Droits** : le rôle est vérifié par le serveur à chaque requête (JWT), et le serveur décide quelles données renvoyer selon le rôle. React peut cacher des boutons pour le confort, jamais pour la sécurité.
12. **Client : email et adresse obligatoires.** Chaque fiche client a un nom, un email et une adresse. Les copies figées dans `devis` et `facture` sont donc obligatoires aussi (une copie ne peut pas être plus stricte que sa source).
13. **Doublons interdits dans les lignes** : un produit n'apparaît qu'une fois par devis et une fois par facture (index unique composite). Si le commercial ajoute deux fois le même produit, le code additionne les quantités au lieu d'insérer une deuxième ligne. Choix fait aussi pour s'entraîner à l'index unique composite.
14. **Expiration du devis** : `devis.expire_le` est obligatoire, avec 30 jours après la création par défaut. Pas de statut `expire` : un devis est expiré quand son statut est `en_attente` et que `expire_le` est dans le passé (ça se calcule, donc une seule source de vérité). Le commercial peut modifier la durée.
15. **Pas d'index sur `produit.categorie`** : avec 5 valeurs, il servirait peu (voir `docs/notes_check_et_index.md`).

---

## 3. Contraintes CHECK (à écrire dans les migrations PostgreSQL)

Elles empêchent des valeurs absurdes directement au niveau de la base, même si le code a un bug. Explication détaillée avec exemples dans `docs/notes_check_et_index.md`. À ajouter au DBML (bloc `checks`) une fois relues et comprises. Si dbdiagram refuse la syntaxe, elles restent ici pour la phase SQL.

```sql
-- ligne_devis et ligne_facture
CHECK (quantite > 0)
CHECK (prix_unitaire >= 0)

-- produit
CHECK (quantite_stock >= 0)
CHECK (prix >= 0)

-- devis
CHECK (expire_le > cree_le)
```

Les `CHECK` ne protègent que si la colonne est aussi `NOT NULL` (une valeur `NULL` passe toujours un `CHECK`). C'est déjà le cas pour `quantite` et `quantite_stock`.

---

## 4. Règle de facturation (à implémenter dans l'API, pas dans le DBML)

Tout se passe dans **une seule transaction** : créer la facture, insérer ses lignes, décrémenter le stock. Si une seule étape échoue, tout est annulé.

```sql
-- Pour chaque ligne de la facture :
UPDATE produit
SET quantite_stock = quantite_stock - X
WHERE id = ? AND quantite_stock >= X;

-- Vérifier ensuite que 1 ligne a bien été modifiée.
-- Si 0 ligne modifiée : stock insuffisant, ROLLBACK de TOUTE la transaction
-- (pas seulement de cette ligne), et refus de l'émission avec avertissement.
```

La condition `WHERE quantite_stock >= X` est ce qui évite le stock négatif si deux personnes facturent le dernier produit en même temps.

---

## 5. Les index : à quoi ça sert et comment ça marche

**Le problème.** Quand on exécute `SELECT * FROM ligne_devis WHERE devis_id = 12`, PostgreSQL sans index lit **toutes** les lignes de la table une par une pour trouver celles qui correspondent. C'est lent quand la table grossit.

**La solution.** Un index est une structure séparée, triée, qui garde pour une colonne la position des lignes correspondantes. PostgreSQL utilise par défaut un arbre B-tree : il descend dans l'arbre en quelques étapes, trouve directement les bonnes lignes et saute à l'endroit voulu. Comparaison : l'index à la fin d'un livre, qui évite de lire toutes les pages pour trouver un mot.

**Le coût.**
- L'index prend de la place.
- Chaque insertion, modification ou suppression doit aussi mettre à jour l'index, ce qui ralentit légèrement les écritures.
- On indexe donc les colonnes qui servent souvent aux jointures et aux filtres, pas tout.

**Ce qui est indexé automatiquement par PostgreSQL :**
- les clés primaires,
- les colonnes `unique` (`email`, `reference`, `numero_devis`, `numero_facture`, `facture.devis_id`).

**Ce qui n'est PAS indexé automatiquement :** les clés étrangères. Une jointure comme "toutes les lignes de ce devis" utilise `ligne_devis.devis_id`, donc on l'indexe à la main.

**Syntaxe DBML (celle du schéma actuel) :**

```dbml
Table ligne_devis {
  id integer [pk, increment]
  devis_id integer [not null]
  produit_id integer [not null]
  // ...

  indexes {
    (devis_id, produit_id) [unique]   // index composite unique : interdit les doublons
    produit_id                        // index simple
  }
}
```

Un index peut aussi recevoir un nom : `produit_id [name: 'idx_ligne_devis_produit']`.

**Index composite.** Un index sur `(a, b)` sert aussi aux recherches sur `a` seul (le premier champ), mais pas sur `b` seul. Si on crée `(devis_id, produit_id)`, l'index séparé sur `devis_id` devient redondant.

**Colonnes sélectives.** Un index est utile quand la valeur cherchée correspond à peu de lignes (`reference`, `client_id`). Sur une colonne avec très peu de valeurs différentes (comme `categorie`, 5 valeurs), PostgreSQL préfère souvent lire toute la table, et l'index sert peu.

**Avec peu de données**, on ne voit aucune différence de vitesse. C'est un réflexe de conception, et un sujet classique en entretien. Version détaillée, avec les exemples du schéma : `docs/notes_check_et_index.md`.

---

## 6. Points ouverts à trancher

1. **Prix d'une facture issue d'un devis.** Les `prix_unitaire` des lignes sont-ils copiés depuis le devis (le client paie le prix promis) ou relus depuis le produit (prix du jour) ? Conseil : copier depuis le devis. À décider et à écrire dans les décisions métier avant d'écrire les routes de facturation.

Résolus : doublons (décision 13), expiration du devis (décision 14), index sur `categorie` (décision 15), email et adresse du client (décision 12).

---

## 7. Limites connues (assumées, projet minimaliste)

- Catégories fixes : en ajouter une demande de modifier le code et la base.
- Rien dans la base n'empêche un produit d'avoir une ligne dans deux tables filles (ex. `telephone` et `camera`). C'est le code, via `categorie`, qui doit le garantir.
- Le devis ne réserve pas le stock.
- `facture` ne gère que `emise`, `payee`, `annulee` (pas de paiement partiel).
- Les informations client sont recopiées dans les documents, sans table d'historique des changements.
- `expire_le` prend 30 jours après `now()` par défaut, mais un défaut ne peut pas lire une autre colonne. Les deux dates sont cohérentes parce que `now()` est figé pendant une transaction. Si `cree_le` est fourni à la main (import, test), `expire_le` ne suivra pas. Le `CHECK (expire_le > cree_le)` limite les dégâts.

---

## 8. Planning (4 h par jour, lundi au vendredi, 6 et 18 novembre fériés)

Les séances du week-end sont des bonus et ne comptent pas dans le planning.

Phase 1 (schéma final) : terminée le sam 10/10, DBML validé.

| Jour | Date | Phase | Travail | Livrable de fin de journée |
|---|---|---|---|---|
| J1 | lun 12/10 | 2. Setup | Projet Node/Express, `pg` et `dotenv`, base PostgreSQL créée. Choix : SQL pur ou Prisma | `GET /health` répond |
| J2 | mar 13/10 | 2. Setup | Script SQL de création (export dbdiagram + CHECK), données de test, tentative volontaire de violer chaque CHECK | Tables créées, erreurs de contraintes provoquées et comprises |
| J3 | mer 14/10 | 3. API | Produits : liste, lecture d'un produit, création (parent + fille dans une transaction) pour téléphone et ordinateur | 2 catégories créées et lues |
| J4 | jeu 15/10 | 3. API | Produits : modification, désactivation (pas de suppression), panneau solaire et caméra | 4 catégories fonctionnelles |
| J5 | ven 16/10 | 3. API | Filtres (catégorie, marque, disponibilité), stock : ajustement et liste des produits sous le seuil | Alerte de stock bas fonctionnelle |
| J6 | lun 19/10 | 3. API | Authentification : hash bcrypt, création de compte, connexion | Connexion possible, mot de passe jamais en clair |
| J7 | mar 20/10 | 3. API | JWT, middleware token + rôle, matrice des permissions, `/api/me` | Une route refuse un rôle non autorisé (403) |
| J8 | mer 21/10 | 3. API | Devis : création avec lignes (prix copiés, doublons fusionnés, infos client copiées, `expire_le`) | Un devis complet créé, total calculé |
| J9 | jeu 22/10 | 3. API | Devis : lecture, liste, changement de statut, détection d'expiration | Cycle de vie d'un devis |
| J10 | ven 23/10 | 3. API | Factures : émission en transaction (stock décrémenté), depuis un devis ou seule | Le dernier produit se facture, le suivant est refusé proprement |
| J11 | lun 26/10 | 3. API | Factures : annulation avec `restituer_stock`, nettoyage, relecture du code | API complète |
| J12 | mar 27/10 | 4. Postman | Collection Postman : toutes les routes, tous les rôles | Collection exportée, tests verts |
| J13 | mer 28/10 | 4. Postman | Correction des bugs trouvés, exercice `EXPLAIN` avec des dizaines de milliers de lignes | Bugs corrigés, comparaison avec et sans index notée |
| J14 | jeu 29/10 | 5. React | Vite + React Router, mise en page, client API (token ajouté aux requêtes) | Navigation en place |
| J15 | ven 30/10 | 5. React | Page de connexion, stockage du token, routes protégées | Connexion de bout en bout |
| J16 | lun 02/11 | 5. React | Affichage selon le rôle (via `/api/me`), onglet Accueil | Interface différente selon le rôle |
| J17 | mar 03/11 | 5. React | Onglet produits : liste et filtres | Catalogue visible |
| J18 | mer 04/11 | 5. React | Formulaires produit (champs de la catégorie), pop-up "produit non disponible" | Produit créé depuis l'interface |
| J19 | jeu 05/11 | 5. React | Onglet stock : alertes et produits non disponibles | Page stock complète |
| J20 | lun 09/11 | 5. React | Onglet devis : création, stock affiché à chaque ligne, total | Devis créé depuis l'interface |
| J21 | mar 10/11 | 5. React | Factures : émission, annulation avec boîte de confirmation | Interface branchée sur l'API |
| J22 | mer 11/11 | 6. Tests | Jest + Supertest : tests de l'authentification | Tests auth verts |
| J23 | jeu 12/11 | 6. Tests | Tests produits et stock | Tests verts |
| J24 | ven 13/11 | 6. Tests | Tests devis et factures (dont l'annulation de la transaction si stock insuffisant) | Suite complète verte |
| J25 | lun 16/11 | 7. Docker | Dockerfile du backend | L'image démarre |
| J26 | mar 17/11 | 7. Docker | docker-compose : backend + PostgreSQL | Tout démarre avec une commande |
| J27 | jeu 19/11 | 7. Docker | README final, décisions métier, nettoyage | Projet présentable |

La Phase 3 est la plus dense (les factures y ont été ajoutées par rapport au plan initial). Les séances du week-end servent de marge.