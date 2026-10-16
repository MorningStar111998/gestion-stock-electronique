import "dotenv/config"

import express from "express";

const app = express();
const PORT = process.env.PORT || 4000;

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "oks",
  });
});

app.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
    
})
 