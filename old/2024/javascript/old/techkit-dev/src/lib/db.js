import pg from "pg";
const { Pool } = pg;

// Connection pooling for better performance
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20, // Maximum pool size
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Prepare statements once
const preparedStatements = {
  insertSubscriber: {
    name: "newsletter",
    text: "INSERT INTO techkit.newsletter (email) VALUES ($1)",
  },
};

export { pool, preparedStatements };
