const express = require("express");
const mysql = require("mysql2/promise");

const app = express();
app.disable("x-powered-by");
app.use(express.json({ limit: "32kb" }));

const required = ["DB_HOST", "DB_USER", "DB_PASSWORD", "DB_NAME"];
for (const key of required) {
  if (!process.env[key]) {
    console.error(`Missing required environment variable: ${key}`);
    process.exit(1);
  }
}

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

async function initializeDatabase() {
  const attempts = Number(process.env.DB_CONNECT_ATTEMPTS || 30);
  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      await pool.execute(`
        CREATE TABLE IF NOT EXISTS products (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(150) NOT NULL,
          price DECIMAL(10,2) NOT NULL,
          description VARCHAR(500) NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log("Database connection and products table are ready.");
      return;
    } catch (error) {
      console.error(`Database not ready (attempt ${attempt}/${attempts}): ${error.message}`);
      if (attempt === attempts) throw error;
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  }
}

app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.status(200).json({ status: "healthy", database: "connected" });
  } catch (_error) {
    res.status(503).json({ status: "unhealthy", database: "disconnected" });
  }
});

app.get("/api/products", async (_req, res) => {
  try {
    const [rows] = await pool.execute(
      "SELECT id, name, price, description, created_at FROM products ORDER BY id DESC"
    );
    res.json(rows);
  } catch (error) {
    console.error("GET /api/products failed:", error);
    res.status(500).json({ message: "Could not retrieve products." });
  }
});

app.get("/api/products/:id", async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) {
    return res.status(400).json({ message: "A valid product ID is required." });
  }
  try {
    const [rows] = await pool.execute(
      "SELECT id, name, price, description, created_at FROM products WHERE id = ?",
      [id]
    );
    if (!rows.length) return res.status(404).json({ message: "Product not found." });
    res.json(rows[0]);
  } catch (error) {
    console.error("GET /api/products/:id failed:", error);
    res.status(500).json({ message: "Could not retrieve product." });
  }
});

app.post("/api/products", async (req, res) => {
  const { name, price, description = "" } = req.body || {};
  const numericPrice = Number(price);

  if (typeof name !== "string" || !name.trim() || name.trim().length > 150) {
    return res.status(400).json({ message: "Product name is required (maximum 150 characters)." });
  }
  if (!Number.isFinite(numericPrice) || numericPrice <= 0 || numericPrice > 99999999.99) {
    return res.status(400).json({ message: "Price must be a positive number." });
  }
  if (typeof description !== "string" || description.length > 500) {
    return res.status(400).json({ message: "Description must be 500 characters or fewer." });
  }

  try {
    const [result] = await pool.execute(
      "INSERT INTO products (name, price, description) VALUES (?, ?, ?)",
      [name.trim(), numericPrice.toFixed(2), description.trim()]
    );
    res.status(201).json({
      id: result.insertId,
      name: name.trim(),
      price: numericPrice.toFixed(2),
      description: description.trim(),
      message: "Product created."
    });
  } catch (error) {
    console.error("POST /api/products failed:", error);
    res.status(500).json({ message: "Could not add product." });
  }
});

const port = Number(process.env.PORT || 3000);

async function start() {
  await initializeDatabase();
  app.listen(port, "0.0.0.0", () => {
    console.log(`ShopLite API listening on 0.0.0.0:${port}`);
  });
}

start().catch(async error => {
  console.error("Backend startup failed:", error);
  await pool.end().catch(() => {});
  process.exit(1);
});

process.on("SIGTERM", async () => {
  console.log("Shutting down...");
  await pool.end().catch(() => {});
  process.exit(0);
});
