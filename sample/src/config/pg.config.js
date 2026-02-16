/**
 * PostgreSQL Configuration
 * Optimized for high-performance production environments
 */
module.exports = {
  connection: {
    host: process.env.PG_HOST || "localhost",
    port: parseInt(process.env.PG_PORT) || 5432,
    database: process.env.PG_DATABASE || "mydb",
    user: process.env.PG_USER || "postgres",
    password: process.env.PG_PASSWORD || "postgres",

    // SSL Configuration for production
    ssl:
      process.env.NODE_ENV === "production"
        ? {
            rejectUnauthorized: false,
          }
        : false,
  },

  pool: {
    // Connection pool settings
    max: parseInt(process.env.PG_POOL_MAX) || 20,
    min: parseInt(process.env.PG_POOL_MIN) || 5,

    // Connection timeout (30 seconds)
    connectionTimeoutMillis: parseInt(process.env.PG_CONNECT_TIMEOUT) || 30000,

    // Idle client timeout (10 minutes)
    idleTimeoutMillis: parseInt(process.env.PG_IDLE_TIMEOUT) || 600000,

    // Maximum lifetime of a connection (30 minutes)
    maxLifetimeSeconds: parseInt(process.env.PG_MAX_LIFETIME) || 1800,

    // Allow connections to be automatically evicted
    allowExitOnIdle: false,
  },

  query: {
    // Query timeout (30 seconds)
    statement_timeout: parseInt(process.env.PG_QUERY_TIMEOUT) || 30000,

    // Slow query threshold (200ms)
    slowQueryThreshold: parseInt(process.env.PG_SLOW_QUERY_THRESHOLD) || 200,
  },
};
