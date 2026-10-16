import "dotenv/config"
import pool from "./database/db.js"

import express from "express";

const app = express();
const PORT = process.env.PORT || 4000;

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "OK",
    message: "YES"
  });
});

app.get("/health/db", async (req, res) => {
  try {
    const result = await pool.query("SELECT NOW() as heure_date");
    res.status(200).json({
      status: "ok",
      databaseTime: result.rows[0].heure_date,
    });
  } catch (error) {
    console.log("Database health check failed", error);

    res.status(500).json({
      status: "error",
      message: "Database connection failed",
    });
  }
});

app.listen(PORT, () => {
  console.error(`Server listening on port ${PORT}`);
  
  
    
})
 