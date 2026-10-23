import "dotenv/config";
import express from "express";
import pool from "./database/db.js";

const PORT = process.env.PORT || 4000;

const app = express();
app.use(express.json());

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "ok",
    message: "functional route",
  });
});

app.get("/health/db", async (req, res) => {
  try {
    const results = await pool.query("SELECT NOW() as heure_date");
    res.status(200).json({
      status: "ok",
      message: "database connection validated",
      databaseTime: results.rows[0].heure_date,
    });
  } catch (error) {
    res.status(500).json({
      status: "error",
      message: "database connection failed",
    });

    console.error("database connection failed", error);
  }
});

// Renvoie tous les produits
app.get("/api/produits", async (req, res) => {
  try {
    const allProducts = await pool.query(
      "SELECT id, nom, categorie, reference, prix, quantite_stock, disponible_a_la_vente FROM produit ORDER BY nom ASC",
    );

    res.status(200).json({
      status: "ok",
      data: allProducts.rows,
    });

    console.log("all products successfully retrieved from database");
  } catch (error) {
    res.status(500).json({
      status: "error",
      message: "could not retrieve data from database",
    });
    console.error("could not retrieve data from database", error);
  }
});

// Renvoie un seul produit et des champs supplémentaires si telephone ou ordinateur
app.get("/api/produits/:id", async (req, res) => {
  try {
    const productId = Number(req.params.id);
    if (!Number.isInteger(productId) || productId <= 0) {
      return res.status(400).json({
        status: "error",
        message: "Invalid product ID. Must be a positive integer.",
      });
    }
    const product = await pool.query(
      `SELECT id, nom, categorie, reference, prix, quantite_stock, disponible_a_la_vente FROM produit WHERE id = $1`,
      [productId],
    );

    // Vérifier que le produit existe
    if (product.rows.length === 0) {
      return res.status(404).json({
        status: "error",
        message: "product not found",
      });
    }

    let productData = product.rows[0];
    const productCategorie = product.rows[0].categorie;
    if (productCategorie == "telephone" || productCategorie == "ordinateur") {
      const additionalFields = await pool.query(
        `SELECT * from ${productCategorie} WHERE produit_id = ${productId}`,
      );

      // Vérifier que le produit a une ligne dans la catégorie
      if (additionalFields.rows.length === 0) {
        return res.status(404).json({
          status: "error",
          message: `No data in ${productCategorie} for product ${product.rows[0].nom}`,
        });
      }
      const { produit_id, ...specs } = additionalFields.rows[0];
      productData = { ...productData, ...specs };
    }
    res.status(200).json({
      status: "ok",
      data: productData,
    });

    console.log("single product successfully retrieved from database");
  } catch (error) {
    res.status(500).json({
      status: "error",
      message: "database connection failed",
    });

    console.error("could not retrieve data from database", error);
  }
});

app.post("/api/produits", async (req, res) => {
  const {
    nom,
    categorie,
    reference,
    prix,
    marque,
    couleur,
    quantite_stock,
    seuil_alerte,
    disponible_a_la_vente,
    ...specs
  } = req.body;
  const createProductQuery = `INSERT INTO produit (nom,
      categorie,
      reference,
      prix,
      marque,
      couleur,
      quantite_stock,
      seuil_alerte,
      disponible_a_la_vente) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING ID`;
  const productValues = [
    nom,
    categorie,
    reference,
    prix,
    marque,
    couleur,
    quantite_stock,
    seuil_alerte,
    disponible_a_la_vente,
  ];
  if (
    ![
      "telephone",
      "ordinateur",
      "autres",
      "camera",
      "panneau_solaire",
    ].includes(categorie)
  ) {
    return res
      .status(400)
      .json({ status: "error", message: "Catégorie invalide" });
  }

  let client;
  try {
    client = await pool.connect();

    await client.query("BEGIN");
    const productResults = await client.query(
      createProductQuery,
      productValues,
    );
    const newProductID = productResults.rows[0].id;

    const keys = Object.keys(specs);
    const productCategorieValues = Object.values(specs);
    if (keys.length > 0) {
      const productCategorieColumns = keys.join(", ");
      console.log(keys);
      console.log(productCategorieColumns);
    }

    await client.query(
      `INSERT INTO ${categorie} (produit_id, ${productCategorieColumns}) VALUES (${newProductID},$1)`,
      productCategorieValues,
    );

    // Query

    await client.query("COMMIT");

    res.status(201).json({
      status: "ok",
      data: {
        nom,
        categorie,
        reference,
        prix,
        marque,
        couleur,
        quantite_stock,
        seuil_alerte,
        disponible_a_la_vente,
        ...specs,
      },
    });
  } catch (error) {
    await client.query("ROLLBACK");
    res.status(500).json({
      status: "error",
      message: "Could not insert data into database",
    });
    console.error("Could not insert data into database", error);
  } finally {
    if (client) client.release();
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
