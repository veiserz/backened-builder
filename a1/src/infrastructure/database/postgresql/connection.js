"use strict";

const { Pool } = require("pg");
const { logger } = require("../../logger");

let pool;

/**
 * Create the shared pg.Pool, verify connectivity, and attach pool-level
 * event listeners. Must be called once during application bootstrap.
 * @returns {Promise<import('pg').Pool>}
 */
async function connectPostgres() {
  pool = new Pool({
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT || "5432", 10),
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    max: parseInt(process.env.DB_POOL_MAX || "10", 10),
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  });

  // Log pool-level errors (e.g. idle client errors)
  pool.on("error", (err) => logger.error("PostgreSQL pool error", { err }));

  // Log each new physical connection (debug level to avoid noise)
  pool.on("connect", () =>
    logger.debug("PostgreSQL pool: new client connected"),
  );

  // Verify connectivity on startup
  const client = await pool.connect();
  client.release();
  logger.info("PostgreSQL connected", {
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME,
  });
  return pool;
}

/**
 * Gracefully drain and close the connection pool.
 * Should be called during application shutdown.
 * @returns {Promise<void>}
 */
async function disconnectPostgres() {
  if (!pool) return;
  await pool.end();
  pool = undefined;
  logger.info("PostgreSQL disconnected");
}

function getPool() {
  if (!pool)
    throw new Error(
      "PostgreSQL pool not initialised – call connectPostgres() first",
    );
  return pool;
}

module.exports = { connectPostgres, disconnectPostgres, getPool };
