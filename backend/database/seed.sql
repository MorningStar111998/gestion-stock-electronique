-- seed.sql : données de test (DEV UNIQUEMENT)
-- A exécuter APRES schema.sql, sur une base fraîchement recréée.
-- Les stocks sont posés à la main : l'API (facturation) n'y touche pas ici.
BEGIN;

-- ============================================================
-- 1. Utilisateurs (mot de passe bidon : l'auth viendra plus tard)
-- ============================================================
INSERT INTO
    utilisateur (prenom, nom, email, mot_de_passe_hash, role)
VALUES
    (
        'Amine',
        'Alaoui',
        'admin@test.ma',
        'hash_test',
        'admin'
    ),
    (
        'Sara',
        'Benali',
        'sara@test.ma',
        'hash_test',
        'employe'
    );

-- ============================================================
-- 2. Clients
-- ============================================================
INSERT INTO
    client (nom_complet, email, adresse)
VALUES
    (
        'Youssef El Idrissi',
        'youssef@example.com',
        '12 rue de l''Atlas, Marrakech'
    ),
    (
        'Salma Bennani',
        'salma@example.com',
        '45 avenue Hassan II, Casablanca'
    );

-- ============================================================
-- 3. Produits : 2 par catégorie (parent + fille en une instruction),
--    plus 1 produit "autre" sans table fille.
--    Cas utiles aux tests :
--      TEL-002 et SOL-002 : stock sous le seuil d'alerte
--      PC-002             : non disponible à la vente
--      CAM-002            : stock à 0
-- ============================================================
-- Téléphones
WITH p AS (
    INSERT INTO
        produit (
            nom,
            categorie,
            reference,
            prix,
            couleur,
            marque,
            quantite_stock,
            seuil_alerte,
            disponible_a_la_vente
        )
    VALUES
        (
            'SAMSUNG S26 Ultra',
            'telephone',
            'TEL-001',
            11400,
            'Noir',
            'Samsung',
            5,
            2,
            true
        ) RETURNING id
)
INSERT INTO
    telephone (produit_id, stockage, ram)
SELECT
    id,
    512,
    12
FROM
    p;

WITH p AS (
    INSERT INTO
        produit (
            nom,
            categorie,
            reference,
            prix,
            couleur,
            marque,
            quantite_stock,
            seuil_alerte,
            disponible_a_la_vente
        )
    VALUES
        (
            'Xiaomi Redmi Note 14',
            'telephone',
            'TEL-002',
            2800,
            'Bleu',
            'Xiaomi',
            1,
            3,
            true
        ) RETURNING id
)
INSERT INTO
    telephone (produit_id, stockage, ram)
SELECT
    id,
    256,
    8
FROM
    p;

-- Ordinateurs
WITH p AS (
    INSERT INTO
        produit (
            nom,
            categorie,
            reference,
            prix,
            couleur,
            marque,
            quantite_stock,
            seuil_alerte,
            disponible_a_la_vente
        )
    VALUES
        (
            'HP Pavilion 15',
            'ordinateur',
            'PC-001',
            7200,
            'Argent',
            'HP',
            8,
            2,
            true
        ) RETURNING id
)
INSERT INTO
    ordinateur (
        produit_id,
        ram,
        stockage,
        processeur,
        carte_graphique
    )
SELECT
    id,
    16,
    512,
    'Intel Core i5-1335U',
    'Intel Iris Xe'
FROM
    p;

WITH p AS (
    INSERT INTO
        produit (
            nom,
            categorie,
            reference,
            prix,
            couleur,
            marque,
            quantite_stock,
            seuil_alerte,
            disponible_a_la_vente
        )
    VALUES
        (
            'ASUS TUF Gaming F15',
            'ordinateur',
            'PC-002',
            11500,
            'Gris',
            'ASUS',
            3,
            1,
            false
        ) RETURNING id
)
INSERT INTO
    ordinateur (
        produit_id,
        ram,
        stockage,
        processeur,
        carte_graphique
    )
SELECT
    id,
    16,
    1024,
    'Intel Core i7-12700H',
    'NVIDIA RTX 4060'
FROM
    p;

-- Panneaux solaires
WITH p AS (
    INSERT INTO
        produit (
            nom,
            categorie,
            reference,
            prix,
            marque,
            quantite_stock,
            seuil_alerte,
            disponible_a_la_vente
        )
    VALUES
        (
            'Panneau monocristallin 550 W',
            'panneau_solaire',
            'SOL-001',
            1450,
            'Jinko',
            20,
            5,
            true
        ) RETURNING id
)
INSERT INTO
    panneau_solaire (produit_id, puissance, tension, rendement)
SELECT
    id,
    550,
    49.5,
    21.3
FROM
    p;

WITH p AS (
    INSERT INTO
        produit (
            nom,
            categorie,
            reference,
            prix,
            marque,
            quantite_stock,
            seuil_alerte,
            disponible_a_la_vente
        )
    VALUES
        (
            'Panneau monocristallin 450 W',
            'panneau_solaire',
            'SOL-002',
            1100,
            'Trina',
            2,
            5,
            true
        ) RETURNING id
)
INSERT INTO
    panneau_solaire (produit_id, puissance, tension, rendement)
SELECT
    id,
    450,
    41.5,
    20.8
FROM
    p;

-- Caméras
WITH p AS (
    INSERT INTO
        produit (
            nom,
            categorie,
            reference,
            prix,
            couleur,
            marque,
            quantite_stock,
            seuil_alerte,
            disponible_a_la_vente
        )
    VALUES
        (
            'Caméra IP 4 MP extérieure',
            'camera',
            'CAM-001',
            650,
            'Blanc',
            'Hikvision',
            15,
            4,
            true
        ) RETURNING id
)
INSERT INTO
    camera (
        produit_id,
        resolution,
        type_connexion,
        vision_nocturne
    )
SELECT
    id,
    '4 MP',
    'WiFi',
    true
FROM
    p;

WITH p AS (
    INSERT INTO
        produit (
            nom,
            categorie,
            reference,
            prix,
            couleur,
            marque,
            quantite_stock,
            seuil_alerte,
            disponible_a_la_vente
        )
    VALUES
        (
            'Caméra analogique 2 MP',
            'camera',
            'CAM-002',
            320,
            'Noir',
            'Dahua',
            0,
            2,
            true
        ) RETURNING id
)
INSERT INTO
    camera (
        produit_id,
        resolution,
        type_connexion,
        vision_nocturne
    )
SELECT
    id,
    '2 MP',
    'Câble coaxial',
    false
FROM
    p;

-- Autre (pas de table fille)
INSERT INTO
    produit (
        nom,
        categorie,
        reference,
        prix,
        marque,
        quantite_stock,
        seuil_alerte,
        disponible_a_la_vente
    )
VALUES
    (
        'Câble HDMI 2 m',
        'autre',
        'ACC-001',
        45,
        'Generic',
        100,
        20,
        true
    );

-- ============================================================
-- 4. Devis (infos client COPIEES depuis la fiche client)
--    FROM utilisateur u, client c : une ligne x une ligne = 1 ligne
--    grâce aux deux conditions WHERE.
-- ============================================================
INSERT INTO
    devis (
        numero_devis,
        utilisateur_id,
        client_id,
        nom_complet,
        email,
        adresse
    )
SELECT
    'DEV-2026-0001',
    u.id,
    c.id,
    c.nom_complet,
    c.email,
    c.adresse
FROM
    utilisateur u,
    client c
WHERE
    u.email = 'sara@test.ma'
    AND c.email = 'youssef@example.com';

INSERT INTO
    devis (
        numero_devis,
        statut,
        utilisateur_id,
        client_id,
        nom_complet,
        email,
        adresse
    )
SELECT
    'DEV-2026-0002',
    'accepte',
    u.id,
    c.id,
    c.nom_complet,
    c.email,
    c.adresse
FROM
    utilisateur u,
    client c
WHERE
    u.email = 'sara@test.ma'
    AND c.email = 'salma@example.com';

-- ============================================================
-- 5. Lignes de devis (prix_unitaire FIGE : copié depuis produit.prix)
-- ============================================================
INSERT INTO
    ligne_devis (devis_id, produit_id, prix_unitaire, quantite)
SELECT
    d.id,
    p.id,
    p.prix,
    1
FROM
    devis d,
    produit p
WHERE
    d.numero_devis = 'DEV-2026-0001'
    AND p.reference = 'TEL-001';

INSERT INTO
    ligne_devis (devis_id, produit_id, prix_unitaire, quantite)
SELECT
    d.id,
    p.id,
    p.prix,
    2
FROM
    devis d,
    produit p
WHERE
    d.numero_devis = 'DEV-2026-0001'
    AND p.reference = 'ACC-001';

INSERT INTO
    ligne_devis (devis_id, produit_id, prix_unitaire, quantite)
SELECT
    d.id,
    p.id,
    p.prix,
    1
FROM
    devis d,
    produit p
WHERE
    d.numero_devis = 'DEV-2026-0002'
    AND p.reference = 'PC-001';

INSERT INTO
    ligne_devis (devis_id, produit_id, prix_unitaire, quantite)
SELECT
    d.id,
    p.id,
    p.prix,
    2
FROM
    devis d,
    produit p
WHERE
    d.numero_devis = 'DEV-2026-0002'
    AND p.reference = 'CAM-001';

-- ============================================================
-- 6. Factures
--    FAC-2026-0001 : issue du devis DEV-2026-0002 (devis_id renseigné)
--    FAC-2026-0002 : sans devis (devis_id reste NULL)
-- ============================================================
INSERT INTO
    facture (
        numero_facture,
        statut,
        utilisateur_id,
        client_id,
        nom_complet,
        email,
        adresse,
        devis_id
    )
SELECT
    'FAC-2026-0001',
    'payee',
    d.utilisateur_id,
    d.client_id,
    d.nom_complet,
    d.email,
    d.adresse,
    d.id
FROM
    devis d
WHERE
    d.numero_devis = 'DEV-2026-0002';

INSERT INTO
    facture (
        numero_facture,
        utilisateur_id,
        client_id,
        nom_complet,
        email,
        adresse
    )
SELECT
    'FAC-2026-0002',
    u.id,
    c.id,
    c.nom_complet,
    c.email,
    c.adresse
FROM
    utilisateur u,
    client c
WHERE
    u.email = 'sara@test.ma'
    AND c.email = 'youssef@example.com';

-- ============================================================
-- 7. Lignes de facture
--    FAC-0001 : copie des lignes (et prix) du devis DEV-0002
--    FAC-0002 : une ligne, prix copié depuis le produit
-- ============================================================
INSERT INTO
    ligne_facture (facture_id, produit_id, prix_unitaire, quantite)
SELECT
    f.id,
    ld.produit_id,
    ld.prix_unitaire,
    ld.quantite
FROM
    facture f
    JOIN ligne_devis ld ON ld.devis_id = f.devis_id
WHERE
    f.numero_facture = 'FAC-2026-0001';

INSERT INTO
    ligne_facture (facture_id, produit_id, prix_unitaire, quantite)
SELECT
    f.id,
    p.id,
    p.prix,
    3
FROM
    facture f,
    produit p
WHERE
    f.numero_facture = 'FAC-2026-0002'
    AND p.reference = 'ACC-001';

COMMIT;