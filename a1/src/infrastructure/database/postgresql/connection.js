'use strict';

const { Pool } = require('pg');
const { logger } = require('../../logger');

let pool;

async function connectPostgres() {
  pool = new Pool({
    host:     process.env.DB_HOST,
    port:     parseInt(process.env.DB_PORT || '5432', 10),
    database: process.env.DB_NAME,
    user:     process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    max:      parseInt(process.env.DB_POOL_MAX || '10', 10),
    idleTimeoutMillis:    30_000,
    connectionTimeoutMillis: 5_000,
  });

  // Verify connectivity on startup
  const client = await pool.connect();
  client.release();
  logger.info('PostgreSQL connected');
  return pool;
}

function getPool() {
  if (!pool) throw new Error('PostgreSQL pool not initialised – call connectPostgres() first');
  return pool;
}

module.exports = { connectPostgres, getPool };
