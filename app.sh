#!/bin/bash

# 1. دریافت نام پروژه
PROJECT_NAME=$1

if [ -z "$PROJECT_NAME" ]; then
  echo "❌ Error: Project name is required."
  echo "Usage: ./app.sh <project-name>"
  exit 1
fi

echo "🚀 Building Express Architecture: $PROJECT_NAME..."

mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# ---------------------------------------------------------
# 2. فایل package.json
# ---------------------------------------------------------
echo "📦 Creating package.json..."
cat <<EOF > package.json
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "Modular Express App with Clean Architecture",
  "main": "src/bootstrap/server.js",
  "scripts": {
    "start": "node src/bootstrap/server.js",
    "dev": "nodemon src/bootstrap/server.js",
    "generate:module": "./module.sh"
  },
  "dependencies": {
    "dotenv": "^16.4.5",
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "ioredis": "^5.3.2",
    "bull": "^4.12.2",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "zod": "^3.22.4",
    "@sinclair/typebox": "^0.32.35",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "compression": "^1.7.4",
    "express-rate-limit": "^7.1.5",
    "winston": "^3.11.0",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

# ---------------------------------------------------------
# 3. ساختار پوشه‌ها
# ---------------------------------------------------------
echo "📂 Creating directories..."
mkdir -p src/bootstrap
mkdir -p src/infrastructure/database/postgresql/migrations
mkdir -p src/infrastructure/cache/redis
mkdir -p src/infrastructure/eventbus
mkdir -p src/infrastructure/queue
mkdir -p src/app/config
mkdir -p src/app/container
mkdir -p src/app/dispatch
mkdir -p src/shared/errors
mkdir -p src/shared/utils
mkdir -p src/shared/validation
mkdir -p src/http/errors
mkdir -p src/http/middlewares
mkdir -p src/http/response
mkdir -p src/modules

echo "⚙️ Config files..."
cat <<EOF > .gitignore
node_modules
.env
.DS_Store
*.log
EOF

cat <<EOF > .env
# ── Server ───────────────────────────────────────────────────────
PORT=3000
NODE_ENV=development
CORS_ORIGIN=
CORS_CREDENTIALS=false

# ── PostgreSQL ───────────────────────────────────────────────────
DB_HOST=localhost
DB_PORT=5432
DB_NAME=$PROJECT_NAME
DB_USER=postgres
DB_PASSWORD=postgres
DB_POOL_MAX=10
DB_SLOW_QUERY_MS=200

# ── Redis ────────────────────────────────────────────────────────
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=

# ── JWT ──────────────────────────────────────────────────────────
JWT_SECRET=change_me_please_very_secure_key_min12
JWT_EXPIRES_IN=7d

# ── Rate Limiting ────────────────────────────────────────────────
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX=100

# ── Feature Flags ────────────────────────────────────────────────
FEATURE_EMAIL_VERIFICATION=false
FEATURE_RATE_LIMITING=true
FEATURE_AUDIT_LOG=false

# ── Logging ──────────────────────────────────────────────────────
LOG_LEVEL=info
EOF

# ---------------------------------------------------------
# 4. Infrastructure - Env (Zod validation)
# ---------------------------------------------------------
echo "⚙️ Creating infrastructure/env.js..."
cat <<'EOF' > src/infrastructure/env.js
"use strict";

const env = {
  NODE_ENV: process.env.NODE_ENV || "development",
  PORT: process.env.PORT || "3000",
  DB_HOST: process.env.DB_HOST || null,
  DB_PORT: process.env.DB_PORT || "5432",
  DB_NAME: process.env.DB_NAME || null,
  DB_USER: process.env.DB_USER || null,
  DB_PASSWORD: process.env.DB_PASSWORD || null,
  REDIS_HOST: process.env.REDIS_HOST || null,
  REDIS_PORT: process.env.REDIS_PORT || "6379",
  JWT_SECRET: process.env.JWT_SECRET || null,
};

const required = [
  "DB_HOST",
  "DB_NAME",
  "DB_USER",
  "DB_PASSWORD",
  "REDIS_HOST",
  "JWT_SECRET",
];

function validateEnv() {
  const errors = [];

  for (const key of required) {
    if (!env[key]) {
      errors.push(`  ${key}: Required`);
    }
  }

  if (env.JWT_SECRET && env.JWT_SECRET.length < 12) {
    errors.push("  JWT_SECRET: Must be at least 12 characters");
  }

  if (errors.length > 0) {
    throw new Error(`Environment validation failed:\n${errors.join("\n")}`);
  }
}

module.exports = { env, validateEnv };

EOF

# ---------------------------------------------------------
# 5. Infrastructure - Logger (Winston)
# ---------------------------------------------------------
echo "📋 Creating infrastructure/logger.js..."
cat <<'EOF' > src/infrastructure/logger.js
"use strict";

const fs = require("fs");
const winston = require("winston");
const { env } = require("./env");

const { combine, timestamp, json, colorize, simple, errors } = winston.format;

const isProduction = env.NODE_ENV === "production";

if (isProduction && !fs.existsSync("logs")) {
  fs.mkdirSync("logs", { recursive: true });
}

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: combine(
    errors({ stack: true }),
    timestamp(),
    isProduction ? json() : combine(colorize(), simple()),
  ),
  transports: [
    new winston.transports.Console(),
    ...(isProduction
      ? [
          new winston.transports.File({
            filename: "logs/error.log",
            level: "error",
          }),
          new winston.transports.File({ filename: "logs/combined.log" }),
        ]
      : []),
  ],
  exceptionHandlers: isProduction
    ? [new winston.transports.File({ filename: "logs/exceptions.log" })]
    : [new winston.transports.Console()],
  rejectionHandlers: isProduction
    ? [new winston.transports.File({ filename: "logs/rejections.log" })]
    : [new winston.transports.Console()],
});

module.exports = { logger };

EOF

# ---------------------------------------------------------
# 6. Infrastructure - PostgreSQL
# ---------------------------------------------------------
echo "🔌 Creating infrastructure/database/postgresql/..."

cat <<'EOF' > src/infrastructure/database/postgresql/connection.js

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

EOF

cat <<'EOF' > src/infrastructure/database/postgresql/db.js
"use strict";

const { getPool } = require("./connection");
const { logger } = require("../../logger");

/** Queries slower than this threshold (ms) are logged as warnings. */
const SLOW_QUERY_MS = parseInt(process.env.DB_SLOW_QUERY_MS || "200", 10);

/**
 * Thin query helper built on the shared pg.Pool.
 *
 * API:
 *   db.query(sql, params?)              – single statement, returns pg.QueryResult
 *   db.transaction(async (client) => {}) – BEGIN / COMMIT / ROLLBACK wrapper
 */
const db = {
  /**
   * Execute a single SQL statement against the pool.
   *
   * @param {string}  sql
   * @param {any[]}   [params=[]]
   * @returns {Promise<import('pg').QueryResult>}
   *
   * @example
   * const result = await db.query('SELECT * FROM stores WHERE id = $1', [id]);
   * return result.rows;
   */
  async query(sql, params = []) {
    const pool = getPool();
    const startAt = Date.now();

    try {
      const result = await pool.query(sql, params);
      const ms = Date.now() - startAt;

      if (ms > SLOW_QUERY_MS) {
        logger.warn("Slow query detected", { ms, sql: sql.substring(0, 150) });
      }

      return result;
    } catch (err) {
      logger.error("Query error", { err, sql: sql.substring(0, 150) });
      throw err;
    }
  },

  /**
   * Run multiple statements inside a single transaction.
   * Automatically issues BEGIN, COMMIT, and ROLLBACK on error.
   * The client is always released back to the pool.
   *
   * @template T
   * @param {function(import('pg').PoolClient): Promise<T>} callback
   * @returns {Promise<T>}
   *
   * @example
   * const result = await db.transaction(async (client) => {
   *   await client.query('INSERT INTO stores (id, name) VALUES ($1, $2)', [id, name]);
   *   await client.query('INSERT INTO audit_log (action) VALUES ($1)', ['store.created']);
   *   return { id };
   * });
   */
  async transaction(callback) {
    const pool = getPool();
    const client = await pool.connect();

    try {
      await client.query("BEGIN");
      const result = await callback(client);
      await client.query("COMMIT");
      return result;
    } catch (err) {
      await client
        .query("ROLLBACK")
        .catch((rbErr) => logger.error("ROLLBACK failed", { rbErr }));
      throw err;
    } finally {
      client.release();
    }
  },
};

module.exports = { db };

class Database {
  constructor() {
    this.pool = null;
  }

  async init() {
    if (this.pool) return this.pool;

    try {
      this.pool = new Pool({
        ...pgConfig.connection,
        ...pgConfig.pool,
      });

      this.pool.on("connect", (client) => {
        client.query(
          `SET statement_timeout = ${pgConfig.query.statement_timeout}`,
        );
      });

      this.pool.on("error", (err) => {
        console.error("💥 Unexpected database pool error:", err);
      });

      const client = await this.pool.connect();
      try {
        await client.query("SELECT NOW()");
        console.log("✅ PostgreSQL Pool Connected");
      } finally {
        client.release();
      }

      return this.pool;
    } catch (error) {
      console.error("❌ PostgreSQL Pool Connection Error:", error.message);
      throw normalizeError(error);
    }
  }

  async close() {
    if (this.pool) {
      await this.pool.end();
      this.pool = null;
      console.log("✅ PostgreSQL Pool Closed");
    }
  }

  ensurePool() {
    if (!this.pool) {
      throw new Error("Database pool not initialized. Call db.init() first.");
    }
  }

  /**
   * Build query object
   * @param {string} sql - SQL query template
   * @param  {...any} params - Query parameters
   * @returns {Object} Query object { text, values }
   */
  Transaction(sql, ...params) {
    return {
      text: sql,
      values:
        params.length === 1 && Array.isArray(params[0]) ? params[0] : params,
    };
  }

  /**
   * Execute simple query (for SELECT)
   * @param {Object|string} query - Query object or SQL string
   * @param {Array} args - Query arguments (if query is string)
   * @returns {Promise<Array>} Query results
   */
  async execute(query, args = []) {
    this.ensurePool();

    const sql = typeof query === "string" ? query : query.text;
    const values = typeof query === "string" ? args : query.values;

    const startTime = Date.now();

    try {
      const result = await this.pool.query(sql, values);
      const executionTime = Date.now() - startTime;

      if (executionTime > pgConfig.query.slowQueryThreshold) {
        console.warn(`🐌 Slow Query Detected (${executionTime}ms):`, {
          query: sql.substring(0, 100),
          executionTime,
          rowCount: result.rowCount,
        });
      }

      return result.rows || [];
    } catch (error) {
      const executionTime = Date.now() - startTime;

      console.error("💥 Query Execution Error:", {
        error: error.message,
        query: sql.substring(0, 100),
        executionTime,
        code: error.code,
      });

      throw normalizeError(error);
    }
  }

  /**
   * Execute transaction for complex operations with multiple queries
   * @param {Function} callback - Callback receives executeInTx(queryObj)
   * @returns {Promise<any>} Transaction result
   *
   * @example
   * await db.executeTransaction(async (executeInTx) => {
   *   const user = await executeInTx(db.Transaction(qry.findUser, userId));
   *   if (user.length === 0) throw new Error('Not found');
   *
   *   await executeInTx(db.Transaction(qry.updateBalance, userId, newBalance));
   *   await executeInTx(db.Transaction(qry.insertLog, userId, 'update'));
   *   return user[0];
   * });
   */
  async executeTransaction(callback) {
    this.ensurePool();

    const client = await this.pool.connect();
    let hasError = false;

    try {
      await client.query(
        `SET statement_timeout = ${pgConfig.query.statement_timeout}`,
      );
      await client.query("BEGIN");

      // Create executor function for transaction context
      const executeInTx = async (queryObj) => {
        const sql = typeof queryObj === "string" ? queryObj : queryObj.text;
        const values = typeof queryObj === "string" ? [] : queryObj.values;

        const startTime = Date.now();

        try {
          const result = await client.query(sql, values);
          const executionTime = Date.now() - startTime;

          if (executionTime > pgConfig.query.slowQueryThreshold) {
            console.warn(`🐌 Slow Query in TX (${executionTime}ms):`, {
              query: sql.substring(0, 100),
              executionTime,
              rowCount: result.rowCount,
            });
          }

          return result.rows || [];
        } catch (error) {
          const executionTime = Date.now() - startTime;

          console.error("💥 TX Query Error:", {
            error: error.message,
            query: sql.substring(0, 100),
            executionTime,
            code: error.code,
          });

          throw normalizeError(error);
        }
      };

      const result = await callback(executeInTx);
      await client.query("COMMIT");

      return result;
    } catch (error) {
      hasError = true;

      try {
        await client.query("ROLLBACK");
      } catch (rollbackError) {
        console.error("💥 ROLLBACK failed:", rollbackError.message);
      }

      if (error.name && error.name.endsWith("Error") && error.code) {
        throw error;
      }
      throw normalizeError(error);
    } finally {
      client.release(hasError);
    }
  }
}

module.exports = new Database();
EOF

cat <<'EOF' > src/infrastructure/database/postgresql/index.js
'use strict';

module.exports = {
  ...require('./connection'),
  ...require('./db'),
};
EOF

cat <<'EOF' > src/infrastructure/database/postgresql/migrations/001_create_users.sql
-- Users table
CREATE TABLE IF NOT EXISTS users (
  id          UUID PRIMARY KEY,
  email       VARCHAR(255) NOT NULL,
  password    VARCHAR(255) NOT NULL,
  role        VARCHAR(50)  NOT NULL DEFAULT 'user',
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS users_email_idx ON users (email);
EOF

# ---------------------------------------------------------
# 7. Infrastructure - Redis (ioredis)
# ---------------------------------------------------------
echo "🔌 Creating infrastructure/cache/redis/..."

cat <<'EOF' > src/infrastructure/cache/redis/connection.js
'use strict';

const Redis      = require('ioredis');
const { logger } = require('../../logger');

let redisInstance;

async function connectRedis() {
  redisInstance = new Redis({
    host:                 process.env.REDIS_HOST     || 'localhost',
    port:                 parseInt(process.env.REDIS_PORT || '6379', 10),
    db:                   parseInt(process.env.REDIS_DB   || '0',    10),
    password:             process.env.REDIS_PASSWORD || undefined,
    lazyConnect:          true,
    maxRetriesPerRequest: 3,
    enableReadyCheck:     true,
  });

  redisInstance.on('error',       (err) => logger.error('Redis error', { err }));
  redisInstance.on('reconnecting', ()   => logger.warn('Redis reconnecting…'));

  await redisInstance.connect();
  logger.info('Redis connected', {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    db:   process.env.REDIS_DB   || 0,
  });
  return redisInstance;
}

async function disconnectRedis() {
  if (!redisInstance) return;
  await redisInstance.quit();
  redisInstance = undefined;
  logger.info('Redis disconnected');
}

function getRedis() {
  if (!redisInstance) throw new Error('Redis not initialised – call connectRedis() first');
  return redisInstance;
}

module.exports = { connectRedis, disconnectRedis, getRedis };
EOF

cat <<'EOF' > src/infrastructure/cache/redis/client.js
'use strict';

const { getRedis } = require('./connection');

function serialise(value) {
  return typeof value === 'string' ? value : JSON.stringify(value);
}
function deserialise(raw) {
  if (raw === null) return null;
  try { return JSON.parse(raw); } catch { return raw; }
}

const redisClient = {
  async get(key)                    { return deserialise(await getRedis().get(key)); },
  async set(key, value, ttl = null) {
    const s = serialise(value);
    return ttl ? getRedis().set(key, s, 'EX', ttl) : getRedis().set(key, s);
  },
  async del(keys) {
    const list = Array.isArray(keys) ? keys : [keys];
    return getRedis().del(...list);
  },
  async exists(key)            { return (await getRedis().exists(key)) > 0; },
  async expire(key, ttl)       { return (await getRedis().expire(key, ttl)) === 1; },
  async ttl(key)               { return getRedis().ttl(key); },
  async mget(keys)             { return (await getRedis().mget(...keys)).map(deserialise); },
  async mset(map) {
    const args = Object.entries(map).flatMap(([k, v]) => [k, serialise(v)]);
    return getRedis().mset(...args);
  },
  async incr(key)              { return getRedis().incr(key); },
  async incrby(key, n)         { return getRedis().incrby(key, n); },
  async decr(key)              { return getRedis().decr(key); },
  async decrby(key, n)         { return getRedis().decrby(key, n); },
  async hget(key, field)       { return deserialise(await getRedis().hget(key, field)); },
  async hset(key, field, val)  { return getRedis().hset(key, field, serialise(val)); },
  async hdel(key, ...fields)   { return getRedis().hdel(key, ...fields); },
  async hgetall(key) {
    const raw = await getRedis().hgetall(key);
    if (!raw) return null;
    return Object.fromEntries(Object.entries(raw).map(([k, v]) => [k, deserialise(v)]));
  },
  async hincrby(key, field, n) { return getRedis().hincrby(key, field, n); },
  async flush() {
    if (process.env.NODE_ENV === 'production') throw new Error('flush() blocked in production');
    return getRedis().flushdb();
  },
};

module.exports = { redisClient };
EOF

cat <<'EOF' > src/infrastructure/cache/redis/index.js
'use strict';

module.exports = {
  ...require('./connection'),
  ...require('./client'),
};
EOF

# ---------------------------------------------------------
# 8. Infrastructure - EventBus
# ---------------------------------------------------------
echo "📡 Creating infrastructure/eventbus/..."

cat <<'EOF' > src/infrastructure/eventbus/bus.js
'use strict';

const EventEmitter = require('events');
const { logger }   = require('../logger');

class EventBus extends EventEmitter {
  async publish(event, payload) {
    logger.debug('EventBus publish', { event });
    this.emit(event, payload);
  }
  subscribe(event, listener)     { this.on(event, listener); }
  subscribeOnce(event, listener) { this.once(event, listener); }
  unsubscribe(event, listener)   { this.off(event, listener); }
  clearAll(event) {
    event ? this.removeAllListeners(event) : this.removeAllListeners();
  }
}

const bus = new EventBus();
bus.setMaxListeners(50);

module.exports = { bus, EventBus };
EOF

cat <<'EOF' > src/infrastructure/eventbus/index.js
'use strict';
module.exports = require('./bus');
EOF

# ---------------------------------------------------------
# 9. Infrastructure - Queue (Bull)
# ---------------------------------------------------------
echo "📨 Creating infrastructure/queue/..."

cat <<'EOF' > src/infrastructure/queue/client.js
'use strict';

const Bull       = require('bull');
const { logger } = require('../logger');

const queues = new Map();

function getQueue(name) {
  if (!queues.has(name)) {
    const q = new Bull(name, {
      redis: {
        host:     process.env.REDIS_HOST || 'localhost',
        port:     parseInt(process.env.REDIS_PORT || '6379', 10),
        db:       parseInt(process.env.REDIS_DB   || '0',    10),
        password: process.env.REDIS_PASSWORD || undefined,
      },
    });
    q.on('error',     (err) => logger.error(`Queue "${name}" error`, { err }));
    q.on('failed',    (job, err) => logger.warn(`Job failed in "${name}"`, { jobId: job.id, err }));
    q.on('stalled',   (job) => logger.warn(`Job stalled in "${name}"`, { jobId: job.id }));
    q.on('completed', (job) => logger.debug(`Job completed in "${name}"`, { jobId: job.id }));
    queues.set(name, q);
  }
  return queues.get(name);
}

async function closeQueue(name) {
  const q = queues.get(name);
  if (!q) return;
  await q.close();
  queues.delete(name);
}

async function closeAllQueues() {
  await Promise.all([...queues.keys()].map(closeQueue));
  logger.info('All queues closed');
}

module.exports = { getQueue, closeQueue, closeAllQueues };
EOF

cat <<'EOF' > src/infrastructure/queue/producer.js
'use strict';

const { getQueue } = require('./client');

const DEFAULTS = { attempts: 3, backoff: { type: 'exponential', delay: 2000 }, removeOnComplete: 100, removeOnFail: 200 };

async function enqueue(queueName, data, opts = {}) {
  const job = await getQueue(queueName).add(data, { ...DEFAULTS, ...opts });
  return job.id;
}

async function enqueueBulk(queueName, items) {
  const jobs = await getQueue(queueName).addBulk(
    items.map(({ data, opts = {} }) => ({ data, opts: { ...DEFAULTS, ...opts } }))
  );
  return jobs.map((j) => j.id);
}

async function enqueueIn(queueName, data, delayMs, opts = {}) {
  return enqueue(queueName, data, { delay: delayMs, ...opts });
}

module.exports = { enqueue, enqueueBulk, enqueueIn };
EOF

cat <<'EOF' > src/infrastructure/queue/consumer.js
'use strict';

const { getQueue } = require('./client');
const { logger }   = require('../logger');

function consume(queueName, processor, options = {}) {
  const concurrency = options.concurrency || 1;
  getQueue(queueName).process(concurrency, async (job) => {
    try {
      return await processor(job);
    } catch (err) {
      logger.error(`Job ${job.id} in "${queueName}" failed`, { err, data: job.data });
      throw err;
    }
  });
  logger.info(`Consumer registered for queue "${queueName}"`, { concurrency });
}

async function pauseQueue(queueName)  { await getQueue(queueName).pause();  logger.info(`Queue "${queueName}" paused`); }
async function resumeQueue(queueName) { await getQueue(queueName).resume(); logger.info(`Queue "${queueName}" resumed`); }

module.exports = { consume, pauseQueue, resumeQueue };
EOF

cat <<'EOF' > src/infrastructure/queue/index.js
'use strict';
module.exports = {
  ...require('./client'),
  ...require('./producer'),
  ...require('./consumer'),
};
EOF

cat <<'EOF' > src/infrastructure/index.js
'use strict';
module.exports = {
  ...require('./env'),
  ...require('./logger'),
  ...require('./database/postgresql'),
  ...require('./cache/redis'),
  ...require('./eventbus'),
  ...require('./queue'),
};
EOF

# ---------------------------------------------------------
# 10. Shared - Errors
# ---------------------------------------------------------
echo "ðŸ› ï¸ Creating shared/errors/..."

cat <<'EOF' > src/shared/errors/domainError.js
'use strict';

class DomainError extends Error {
  constructor(message, code = 'DOMAIN_ERROR', meta = null) {
    super(message);
    this.name  = 'DomainError';
    this.code  = code;
    this.meta  = meta;
    Error.captureStackTrace(this, this.constructor);
  }

  static notFound(message   = 'Resource not found',    meta = null) { return new DomainError(message, 'NOT_FOUND',    meta); }
  static conflict(message   = 'Resource already exists',meta = null) { return new DomainError(message, 'CONFLICT',     meta); }
  static forbidden(message  = 'Access denied',          meta = null) { return new DomainError(message, 'FORBIDDEN',    meta); }
  static validation(message = 'Validation failed',      meta = null) { return new DomainError(message, 'VALIDATION',   meta); }
  static unauthorised(message = 'Unauthorised',         meta = null) { return new DomainError(message, 'UNAUTHORISED', meta); }
  static badRequest(message = 'Bad request',            meta = null) { return new DomainError(message, 'BAD_REQUEST',  meta); }
  static internal(message   = 'Internal error',         meta = null) { return new DomainError(message, 'INTERNAL',     meta); }

  is(code) { return this.code === code; }
}

module.exports = { DomainError };
EOF

cat <<'EOF' > src/shared/errors/index.js
'use strict';
module.exports = { ...require('./domainError') };
EOF

# ---------------------------------------------------------
# 11. Shared - Utils
# ---------------------------------------------------------
echo "ðŸ› ï¸ Creating shared/utils/..."

cat <<'EOF' > src/shared/utils/id.js
'use strict';

const { v4: uuidv4 } = require('uuid');
const { DomainError } = require('../errors/domainError');

function generateId()  { return uuidv4(); }

function isValidId(id) {
  return typeof id === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id);
}

function assertValidId(id, label = 'id') {
  if (!isValidId(id)) throw DomainError.badRequest(`Invalid ${label}: "${id}" is not a valid UUID`);
  return id;
}

module.exports = { generateId, isValidId, assertValidId };
EOF

cat <<'EOF' > src/shared/utils/time.js
'use strict';

function now()                    { return new Date(); }
function toISOString(d = new Date()) { return d instanceof Date ? d.toISOString() : new Date(d).toISOString(); }
function addSeconds(d, n)         { return new Date(d.getTime() + n * 1_000); }
function addMinutes(d, n)         { return new Date(d.getTime() + n * 60_000); }
function addDays(d, n)            { return new Date(d.getTime() + n * 86_400_000); }
function isExpired(d)             { return new Date(d).getTime() < Date.now(); }
function diffSeconds(a, b)        { return Math.floor((new Date(a).getTime() - new Date(b).getTime()) / 1_000); }

module.exports = { now, toISOString, addSeconds, addMinutes, addDays, isExpired, diffSeconds };
EOF

cat <<'EOF' > src/shared/utils/index.js
'use strict';
module.exports = { ...require('./id'), ...require('./time') };
EOF

# ---------------------------------------------------------
# 12. Shared - Validation
# ---------------------------------------------------------
echo "Creating shared/validation/..."

cat <<'EOF' > src/shared/validation/validate.js
'use strict';

const { DomainError } = require('../errors/domainError');

function validate(schema, data) {
  const result = schema.safeParse(data);
  if (!result.success) {
    const details = result.error.errors.map((e) => ({ field: e.path.join('.'), message: e.message }));
    throw DomainError.validation('Validation failed', details);
  }
  return result.data;
}

module.exports = { validate };
EOF

cat <<'EOF' > src/shared/validation/index.js
'use strict';
module.exports = { ...require('./validate') };
EOF

cat <<'EOF' > src/shared/index.js
'use strict';
module.exports = {
  ...require('./errors'),
  ...require('./utils'),
  ...require('./validation'),
};
EOF

# ---------------------------------------------------------
# 13. HTTP - Errors
# ---------------------------------------------------------
echo "ðŸ›¡ï¸ Creating http/errors/..."

cat <<'EOF' > src/http/errors/httpError.js
'use strict';

class HttpError extends Error {
  constructor(status, message, details = null) {
    super(message);
    this.name    = 'HttpError';
    this.status  = status;
    this.details = details;
    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = { HttpError };
EOF

cat <<'EOF' > src/http/errors/mapper.js
'use strict';

const { HttpError }   = require('./httpError');
const { DomainError } = require('../../shared/errors/domainError');

function mapToHttpError(err) {
  if (err instanceof HttpError)  return err;
  if (err instanceof DomainError) {
    const statusMap = {
      NOT_FOUND: 404, FORBIDDEN: 403, CONFLICT: 409,
      VALIDATION: 422, UNAUTHORISED: 401, BAD_REQUEST: 400, INTERNAL: 500,
    };
    return new HttpError(statusMap[err.code] ?? 400, err.message, err.meta);
  }
  return new HttpError(500, 'Internal server error');
}

module.exports = { mapToHttpError };
EOF

cat <<'EOF' > src/http/errors/index.js
'use strict';

const { logger }       = require('../../infrastructure/logger');
const { mapToHttpError } = require('./mapper');

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const httpErr = mapToHttpError(err);
  if (httpErr.status >= 500) logger.error('Unhandled error', { requestId: req.requestId, stack: err.stack });
  return res.status(httpErr.status).json({
    success: false,
    error: {
      message: httpErr.message,
      ...(httpErr.details ? { details: httpErr.details } : {}),
      ...(process.env.NODE_ENV !== 'production' && httpErr.status >= 500 ? { stack: err.stack } : {}),
    },
  });
}

module.exports = {
  errorHandler,
  HttpError:    require('./httpError').HttpError,
  mapToHttpError: require('./mapper').mapToHttpError,
};
EOF

# ---------------------------------------------------------
# 14. HTTP - Middlewares
# ---------------------------------------------------------
echo "ðŸ›¡ï¸ Creating http/middlewares/..."

cat <<'EOF' > src/http/middlewares/auth.js
'use strict';

const jwt           = require('jsonwebtoken');
const { HttpError } = require('../errors/httpError');

function authMiddleware(req, _res, next) {
  const header = req.headers['authorization'] || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) return next(new HttpError(401, 'Missing or malformed token'));
  try {
    req.auth = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    next(new HttpError(401, 'Invalid or expired token'));
  }
}

module.exports = authMiddleware;
EOF

cat <<'EOF' > src/http/middlewares/rateLimit.js
'use strict';

const rateLimit = require('express-rate-limit');

const rateLimitMiddleware = rateLimit({
  windowMs:       parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10),
  max:            parseInt(process.env.RATE_LIMIT_MAX       || '100',    10),
  standardHeaders: true,
  legacyHeaders:   false,
  message: { success: false, error: { message: 'Too many requests, please try again later.' } },
});

module.exports = rateLimitMiddleware;
EOF

cat <<'EOF' > src/http/middlewares/requestContext.js
'use strict';

const { v4: uuidv4 } = require('uuid');
const { logger }     = require('../../infrastructure/logger');

function requestContextMiddleware(req, res, next) {
  const requestId = req.headers['x-request-id'] || uuidv4();
  req.requestId   = requestId;
  res.setHeader('x-request-id', requestId);
  const startAt = Date.now();
  res.on('finish', () => logger.info('HTTP request', {
    requestId, method: req.method, url: req.originalUrl, status: res.statusCode, ms: Date.now() - startAt,
  }));
  next();
}

module.exports = requestContextMiddleware;
EOF

cat <<'EOF' > src/http/middlewares/BaseMiddleware.js
'use strict';

const { HttpError } = require('../errors/httpError');

class BaseMiddleware {
  static wrap(fn) { return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next); }

  requireAuth() {
    return BaseMiddleware.wrap(async (req, _res, next) => {
      if (!req.auth) return next(new HttpError(401, 'Authentication required'));
      next();
    });
  }

  requireRole(...roles) {
    return BaseMiddleware.wrap(async (req, _res, next) => {
      if (!req.auth || !roles.includes(req.auth.role)) return next(new HttpError(403, 'Insufficient permissions'));
      next();
    });
  }

  // eslint-disable-next-line no-unused-vars
  async resolveOwnerId(_req) { return null; }

  requireOwnership() {
    return BaseMiddleware.wrap(async (req, _res, next) => {
      const ownerId = await this.resolveOwnerId(req);
      const subject = req.auth?.sub;
      if (!subject || subject !== (ownerId ?? req.params?.id)) return next(new HttpError(403, 'Access denied'));
      next();
    });
  }
}

module.exports = { BaseMiddleware };
EOF

cat <<'EOF' > src/http/middlewares/index.js
'use strict';
module.exports = {
  authMiddleware:         require('./auth'),
  rateLimitMiddleware:    require('./rateLimit'),
  requestContextMiddleware: require('./requestContext'),
  BaseMiddleware:         require('./BaseMiddleware').BaseMiddleware,
};
EOF

# ---------------------------------------------------------
# 15. HTTP - Response
# ---------------------------------------------------------
echo "ðŸ›¡ï¸ Creating http/response/..."

cat <<'EOF' > src/http/response/index.js
'use strict';

function ok(res, data = null, meta = {})  { return res.status(200).json({ success: true, data, meta }); }
function created(res, data = null)        { return res.status(201).json({ success: true, data, meta: {} }); }
function noContent(res)                   { return res.status(204).send(); }
function paginated(res, { items, total, page, limit }) {
  return res.status(200).json({ success: true, data: items, meta: { total, page, limit, pages: Math.ceil(total / limit) } });
}
function fail(res, status, message, details = null) {
  const body = { success: false, error: { message } };
  if (details) body.error.details = details;
  return res.status(status).json(body);
}

module.exports = { ok, created, noContent, paginated, fail };
EOF

cat <<'EOF' > src/http/index.js
'use strict';
module.exports = {
  ...require('./errors'),
  ...require('./middlewares'),
  response: require('./response'),
};
EOF

# ---------------------------------------------------------
# 16. App - Config
# ---------------------------------------------------------
echo "ðŸ§© Creating app/config/..."

cat <<'EOF' > src/app/config/features.js
'use strict';

const features = {
  emailVerification: process.env.FEATURE_EMAIL_VERIFICATION === 'true',
  rateLimiting:      process.env.FEATURE_RATE_LIMITING      !== 'false',
  auditLog:          process.env.FEATURE_AUDIT_LOG          === 'true',
};

module.exports = { features };
EOF

cat <<'EOF' > src/app/config/policies.js
'use strict';

const policies = {
  'users:read':   (auth) => !!auth,
  'users:write':  (auth) => auth && (auth.role === 'admin' || auth.sub === auth.targetId),
  'users:delete': (auth) => auth && auth.role === 'admin',
  'store:read':   (auth) => !!auth,
  'store:write':  (auth) => auth && (auth.role === 'admin' || auth.role === 'store_owner'),
  'store:delete': (auth) => auth && auth.role === 'admin',
  'auth:manage':  (auth) => auth && auth.role === 'admin',
};

function can(auth, policy, resource = null) {
  const check = policies[policy];
  if (!check) return false;
  return !!check(auth, resource);
}

module.exports = { policies, can };
EOF

cat <<'EOF' > src/app/config/index.js
'use strict';
module.exports = { ...require('./features'), ...require('./policies') };
EOF

# ---------------------------------------------------------
# 17. App - Container
# ---------------------------------------------------------
echo "ðŸ§© Creating app/container/..."

cat <<'EOF' > src/app/container/index.js
'use strict';

class Container {
  constructor() { this._bindings = new Map(); this._singletons = new Map(); }

  register(token, factory) { this._bindings.set(token, { factory, scope: 'transient' }); return this; }
  singleton(token, factory){ this._bindings.set(token, { factory, scope: 'singleton' }); return this; }
  instance(token, value)   {
    this._singletons.set(token, value);
    this._bindings.set(token, { factory: () => value, scope: 'singleton' });
    return this;
  }

  resolve(token) {
    if (!this._bindings.has(token)) throw new Error(`[Container] No binding for token: "${token}"`);
    const binding = this._bindings.get(token);
    if (binding.scope === 'singleton') {
      if (!this._singletons.has(token)) this._singletons.set(token, binding.factory(this));
      return this._singletons.get(token);
    }
    return binding.factory(this);
  }

  verify() {
    for (const [token, b] of this._bindings) {
      if (b.scope === 'singleton') this.resolve(token);
    }
  }
}

const container = new Container();

function bootContainer() {
  require('./providers').register(container);
  container.verify();
  return container;
}

module.exports = { Container, container, bootContainer };
EOF

cat <<'EOF' > src/app/container/providers.js
'use strict';

const { db }          = require('../../infrastructure/database/postgresql');
const { redisClient } = require('../../infrastructure/cache/redis');
const { logger }      = require('../../infrastructure/logger');
const { bus }         = require('../../infrastructure/eventbus');
const { Dispatcher }  = require('../dispatch');
const { registerHandlers } = require('../dispatch/handlers');
// [AUTO-IMPORTS]

function register(container) {
  // â”€â”€ Infrastructure â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  container.instance('db',          db);
  container.instance('redisClient', redisClient);
  container.instance('logger',      logger);
  container.instance('bus',         bus);

  container.singleton('dispatcher', (c) => {
    const d = new Dispatcher(c.resolve('bus'));
    registerHandlers(d);
    return d;
  });

  // â”€â”€ Repositories â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // [AUTO-REPOS]

  // â”€â”€ Services â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // [AUTO-SERVICES]
}

module.exports = { register };
EOF

# ---------------------------------------------------------
# 18. App - Dispatch
# ---------------------------------------------------------
echo "ðŸ§© Creating app/dispatch/..."

cat <<'EOF' > src/app/dispatch/index.js
'use strict';

const { bus }              = require('../../infrastructure/eventbus');
const { registerHandlers } = require('./handlers');

class Dispatcher {
  constructor(eventBus) { this._handlers = new Map(); this._bus = eventBus; }

  on(event, handler) {
    if (!this._handlers.has(event)) this._handlers.set(event, []);
    this._handlers.get(event).push(handler);
    return this;
  }

  async dispatch(event, payload) {
    const handlers = this._handlers.get(event) ?? [];
    await Promise.all(handlers.map((h) => h(payload)));
    await this._bus.publish(event, payload);
  }

  registeredEvents() { return [...this._handlers.keys()]; }
}

const dispatcher = new Dispatcher(bus);
registerHandlers(dispatcher);

module.exports = { Dispatcher, dispatcher, registerHandlers };
EOF

cat <<'EOF' > src/app/dispatch/handlers.js
'use strict';

const { logger } = require('../../infrastructure/logger');

/**
 * Register all application-level domain event handlers.
 * Add new handlers here as the application grows.
 * @param {import('./index').Dispatcher} dispatcher
 */
function registerHandlers(dispatcher) {
  // â”€â”€ Add module event handlers below â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // dispatcher.on('user.created', async (payload) => { ... });
  void dispatcher; // remove when first handler is added
}

module.exports = { registerHandlers };
EOF

cat <<'EOF' > src/app/index.js
'use strict';
module.exports = {
  ...require('./config'),
  ...require('./container'),
  ...require('./dispatch'),
};
EOF

# 17. Bootstrap - Router
# ---------------------------------------------------------
echo "🌟 Creating bootstrap/router.js..."
cat <<'EOF' > src/bootstrap/router.js
'use strict';

const { Router } = require('express');
// [AUTO-ROUTES]

const router = Router();

// [AUTO-USE]

// 404 - unmatched API route
router.use((_req, res) => {
  res.status(404).json({ success: false, error: { message: 'API endpoint not found' } });
});

module.exports = router;
EOF

# ---------------------------------------------------------
# 18. Bootstrap - App.js
# ---------------------------------------------------------
echo "🔌 Creating bootstrap/app.js..."
cat <<EOF > src/bootstrap/app.js
"use strict";

const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const compression = require("compression");

const {
  requestContextMiddleware,
  rateLimitMiddleware,
} = require("../http/middlewares");
const { errorHandler } = require("../http/errors");
const { features } = require("../app/config");
const router = require("./router");

function createApp() {
  const app = express();

  // ── Security & parsing ──────────────────────────────────────────────────
  app.use(helmet());
  app.use(
    cors({
      origin: process.env.CORS_ORIGIN
        ? process.env.CORS_ORIGIN.split(",")
        : "*",
      credentials: process.env.CORS_CREDENTIALS === "true",
      methods: ["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"],
    }),
  );
  app.use(compression());
  app.use(express.json({ limit: "1mb" }));
  app.use(express.urlencoded({ extended: true }));

  // ── Observability ───────────────────────────────────────────────────────
  app.use(requestContextMiddleware);

  // ── Rate limiting (feature-flag controlled) ─────────────────────────────
  if (features.rateLimiting) {
    app.use(rateLimitMiddleware);
  }

  // ── Health check ────────────────────────────────────────────────────────
  app.get("/health", (_req, res) => {
    res.json({
      status: "ok",
      env: process.env.NODE_ENV,
      ts: Date.now(),
      uptime: Math.floor(process.uptime()),
    });
  });

  // ── API routes ──────────────────────────────────────────────────────────
  app.use("/api", router);

  // ── 404 – unknown routes ────────────────────────────────────────────────
  app.use((_req, res) => {
    res
      .status(404)
      .json({ success: false, error: { message: "Route not found" } });
  });

  // ── Global error handler (must be last) ─────────────────────────────────
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
EOF

# ---------------------------------------------------------
# 19. Bootstrap - Server.js
# ---------------------------------------------------------
echo "🚀 Creating bootstrap/server.js..."
cat <<EOF > src/bootstrap/server.js
"use strict";

require("dotenv").config();

const { validateEnv } = require("../infrastructure/env");
const {
  connectPostgres,
  disconnectPostgres,
} = require("../infrastructure/database/postgresql");
const {
  connectRedis,
  disconnectRedis,
} = require("../infrastructure/cache/redis");
const { closeAllQueues } = require("../infrastructure/queue");
const { logger } = require("../infrastructure/logger");
const { bootContainer } = require("../app/container");
const { createApp } = require("./app");

async function start() {
  // ── 1. Validate environment ──────────────────────────────────────────────
  validateEnv();

  // ── 2. Connect infrastructure ────────────────────────────────────────────
  await connectPostgres();
  await connectRedis();

  // ── 3. Wire DI container ─────────────────────────────────────────────────
  bootContainer();

  // ── 4. Start HTTP server ─────────────────────────────────────────────────
  const app = createApp();
  const port = parseInt(process.env.PORT || "3000", 10);
  const server = app.listen(port, () => {
    logger.info(`Server listening on port ${port}`, {
      env: process.env.NODE_ENV,
    });
  });

  // ── 5. Graceful shutdown ─────────────────────────────────────────────────
  async function shutdown(signal) {
    logger.info(`${signal} received – shutting down gracefully`);

    // Stop accepting new connections
    server.close(async () => {
      logger.info("HTTP server closed");
      try {
        await disconnectPostgres();
        await disconnectRedis();
        await closeAllQueues();
        logger.info("Infrastructure connections closed");
        process.exit(0);
      } catch (err) {
        logger.error("Error during shutdown", { err });
        process.exit(1);
      }
    });

    // Force-kill if graceful shutdown exceeds 10 s
    setTimeout(() => {
      logger.error("Graceful shutdown timed out – forcing exit");
      process.exit(1);
    }, 10_000).unref();
  }

  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));

  // ── 6. Safety nets ───────────────────────────────────────────────────────
  process.on("unhandledRejection", (reason) => {
    logger.error("Unhandled promise rejection", { reason });
  });

  process.on("uncaughtException", (err) => {
    logger.error("Uncaught exception – shutting down", { err });
    shutdown("uncaughtException");
  });
}

start().catch((err) => {
  console.error("Fatal startup error:", err);
  process.exit(1);
});
EOF

# =========================================================
# 20. تولید فایل module.sh
# =========================================================
echo "🔨 Creating module.sh tool..."

cat <<'MAKER_EOF' > module.sh
#!/usr/bin/env bash
# =============================================================
#  Usage:  bash module.sh <module-name> [route-prefix]
#  Creates a full module scaffold under src/modules/<name>/
#  and auto-registers the route in src/bootstrap/router.js
# =============================================================
set -euo pipefail

MODULE="${1:?Usage: bash module.sh <module-name> [route-prefix]}"
ROUTE="${2:-$1}"

# ── Name derivations ─────────────────────────────────────────
LOWER="$(echo "$MODULE" | tr '[:upper:] -' '[:lower:]_')"
PASCAL="$(echo "$LOWER" | awk -F_ '{r=""; for(i=1;i<=NF;i++) r=r toupper(substr($i,1,1)) substr($i,2); print r}')"
ROUTE_PREFIX="$(echo "$ROUTE" | tr '[:upper:]' '[:lower:]')"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/src"
DEST="$SRC/modules/$LOWER"
ROUTER_FILE="$SRC/bootstrap/router.js"

[[ -d "$DEST" ]] && { echo "❌  Module '$LOWER' already exists."; exit 1; }
echo "⚙  Scaffolding '$LOWER' → /v1/$ROUTE_PREFIX …"

mkdir -p "$DEST" "$DEST/DTO" "$DEST/models" "$DEST/repository" \
         "$DEST/service" "$DEST/controller" "$DEST/middleware" "$DEST/router"

# ── index.js ─────────────────────────────────────────────────
cat > "$DEST/index.js" << EOF
'use strict';

/**
 * Public API of the ${LOWER} module.
 * Only these exports should be consumed by other modules.
 * Direct access to internals breaks encapsulation.
 */
module.exports = {
  ${PASCAL}Service:    require('./service').${PASCAL}Service,
  ${PASCAL}Repository: require('./repository').${PASCAL}Repository,
  ${PASCAL}Model:      require('./models').${PASCAL},
  createRouter:        require('./router').createRouter,
};
EOF

# ── Auto-register in bootstrap/router.js ─────────────────────
# The refactored router.js exports createRouter(container) and uses
# [AUTO-ROUTES-IMPORT] and [AUTO-USE] markers.
IMPORT_LINE="const { createRouter: create${PASCAL}Router } = require('../modules/${LOWER}');"
MOUNT_LINE="  router.use('/v1/${ROUTE_PREFIX}', create${PASCAL}Router(container.resolve('${LOWER}Service')));"

if grep -qF "create${PASCAL}Router" "$ROUTER_FILE"; then
  echo "⚠   Route already registered in router.js — skipped."
else
  sed -i "s|// \[AUTO-ROUTES-IMPORT\]|${IMPORT_LINE}\n// [AUTO-ROUTES-IMPORT]|" "$ROUTER_FILE"
  sed -i "s|  // \[AUTO-USE\]|${MOUNT_LINE}\n  // [AUTO-USE]|" "$ROUTER_FILE"
  echo "✔   Registered /v1/${ROUTE_PREFIX} in bootstrap/router.js"
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "✅  Module '${LOWER}' scaffolded at src/modules/${LOWER}/"
echo ""
echo "   Files created:"
echo "   ├── index.js"
echo "   ├── DTO/           (create · update · param · query · validate)"
echo "   ├── models/        (${LOWER}.model.js)"
echo "   ├── repository/    (${LOWER}.repository.js · queries.js)"
echo "   ├── service/       (${LOWER}.service.js)"
echo "   ├── controller/    (${LOWER}.controller.js)"
echo "   ├── middleware/    (${LOWER}.middleware.js)"
echo "   └── router/        (index.js)"
echo ""

# ── Auto-register in app/container/providers/ ────────────────
# The refactored structure splits providers into three files.
# We patch repositories.js and services.js independently.
REPOS_FILE="$SRC/app/container/providers/repositories.js"
SERVICES_FILE="$SRC/app/container/providers/services.js"

if [[ -f "$REPOS_FILE" && -f "$SERVICES_FILE" ]]; then
  if grep -qF "${LOWER}Repository" "$REPOS_FILE"; then
    echo "⚠   ${PASCAL} already registered in providers — skipped."
  else
    TMP_SCRIPT="$(mktemp)"
    cat > "$TMP_SCRIPT" << 'NODEJS'
const fs     = require('fs');
const lower  = process.argv[2];
const pascal = process.argv[3];
const reposFile    = process.argv[4];
const servicesFile = process.argv[5];

// ── repositories.js ──────────────────────────────────────────
let reposSrc = fs.readFileSync(reposFile, 'utf8');

const repoImport =
  `const { ${pascal}Repository } = require('../../../modules/${lower}/repository');\n`;

const repoBinding =
  `  c.singleton('${lower}Repository', ({ resolve }) => new ${pascal}Repository(resolve('db')));\n`;

reposSrc = reposSrc.replace('// [AUTO-REPO-IMPORTS]', repoImport + '// [AUTO-REPO-IMPORTS]');
reposSrc = reposSrc.replace('  // [AUTO-REPOS]',      repoBinding + '  // [AUTO-REPOS]');

fs.writeFileSync(reposFile, reposSrc, 'utf8');

// ── services.js ──────────────────────────────────────────────
let servicesSrc = fs.readFileSync(servicesFile, 'utf8');

const serviceImport =
  `const { ${pascal}Service } = require('../../../modules/${lower}/service');\n`;

const serviceBinding =
  `  c.singleton('${lower}Service', ({ resolve }) => new ${pascal}Service(resolve('${lower}Repository'), resolve('dispatcher')));\n`;

servicesSrc = servicesSrc.replace('// [AUTO-SERVICE-IMPORTS]', serviceImport + '// [AUTO-SERVICE-IMPORTS]');
servicesSrc = servicesSrc.replace('  // [AUTO-SERVICES]',      serviceBinding + '  // [AUTO-SERVICES]');

fs.writeFileSync(servicesFile, servicesSrc, 'utf8');
NODEJS
    node "$TMP_SCRIPT" "$LOWER" "$PASCAL" "$REPOS_FILE" "$SERVICES_FILE"
    rm -f "$TMP_SCRIPT"
    echo "✔   Registered ${LOWER}Repository in providers/repositories.js"
    echo "✔   Registered ${LOWER}Service    in providers/services.js"
  fi
else
  echo "⚠   providers/repositories.js or providers/services.js not found — add manually:"
  echo "      // in providers/repositories.js:"
  echo "      c.singleton('${LOWER}Repository', ({ resolve }) => new ${PASCAL}Repository(resolve('db')));"
  echo "      // in providers/services.js:"
  echo "      c.singleton('${LOWER}Service', ({ resolve }) => new ${PASCAL}Service(resolve('${LOWER}Repository'), resolve('dispatcher')));"
fi

echo "   Next steps:"
echo "   1. Edit DTO fields   → src/modules/${LOWER}/DTO/create.dto.js"
echo "   2. Edit model fields → src/modules/${LOWER}/models/${LOWER}.model.js"
echo "   3. Edit SQL queries  → src/modules/${LOWER}/repository/queries.js"
echo ""

# ── DTO/index.js ─────────────────────────────────────────────
cat > "$DEST/DTO/index.js" << EOF

// src/modules/store/DTO/index.js
"use strict";

const { Type } = require("@sinclair/typebox");

// ── Create ────────────────────────────────────────────────────────────────────

const CreateStoreDto = Type.Object({
  name: Type.String({
    minLength: 1,
    maxLength: 255,
    description: "Store display name",
  }),
});

// ── Update ────────────────────────────────────────────────────────────────────

const UpdateStoreDto = Type.Object({
  name: Type.Optional(Type.String({ minLength: 1, maxLength: 255 })),
});

// ── URL Params ────────────────────────────────────────────────────────────────

const StoreParamDto = Type.Object({
  id: Type.String({ format: "uuid" }),
});

// ── List Query ────────────────────────────────────────────────────────────────

const StoreListQueryDto = Type.Object({
  page: Type.Optional(Type.Integer({ minimum: 1, default: 1 })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100, default: 20 })),
});

// ── Response (for JSDoc typing only — not used for validation) ────────────────

const StoreResponseDto = Type.Object({
  id: Type.String({ format: "uuid" }),
  name: Type.String(),
  createdAt: Type.String({ format: "date-time" }),
  updatedAt: Type.String({ format: "date-time" }),
});

// ── Exports ───────────────────────────────────────────────────────────────────

module.exports = {
  CreateStoreDto,
  UpdateStoreDto,
  StoreParamDto,
  StoreListQueryDto,
  StoreResponseDto,
};

EOF

# ── models/<name>.model.js ───────────────────────────────────
cat > "$DEST/models/${LOWER}.model.js" << EOF
'use strict';

const { generateId } = require('../../../shared/utils/id');
const { now }        = require('../../../shared/utils/time');

class ${PASCAL} {
  constructor({ id, name, createdAt, updatedAt }) {
    this.id        = id        || generateId();
    this.name      = ${PASCAL}._normaliseName(name);
    this.createdAt = createdAt || now();
    this.updatedAt = updatedAt || now();
  }

  // ── Normalisation ──────────────────────────────────────────
  static _normaliseName(v) {
    return typeof v === 'string' ? v.trim().replace(/\s+/g, ' ') : v;
  }

  // ── Factories ─────────────────────────────────────────────

  /** Reconstruct entity from a PostgreSQL row (snake_case → camelCase). */
  static fromRecord(row) {
    return new ${PASCAL}({
      id:        row.id,
      name:      row.name,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    });
  }

  // ── Domain behaviour ──────────────────────────────────────

  /** Apply a validated update DTO onto this entity in-place. */
  applyUpdate(dto) {
    if (dto.name !== undefined) this.name = ${PASCAL}._normaliseName(dto.name);
    this.updatedAt = now();
  }

  // ── Serialisation ─────────────────────────────────────────

  /** Persist-ready record (camelCase → snake_case). */
  toRecord() {
    return {
      id:         this.id,
      name:       this.name,
      created_at: this.createdAt,
      updated_at: this.updatedAt,
    };
  }

  /** Safe public serialisation — no internal/sensitive fields. */
  toResponse() {
    return {
      id:        this.id,
      name:      this.name,
      createdAt: this.createdAt instanceof Date ? this.createdAt.toISOString() : this.createdAt,
      updatedAt: this.updatedAt instanceof Date ? this.updatedAt.toISOString() : this.updatedAt,
    };
  }
}

module.exports = { ${PASCAL} };
EOF

cat > "$DEST/models/index.js" << EOF
'use strict';
module.exports = require('./${LOWER}.model');
EOF

# ── repository/queries.js ────────────────────────────────────
cat > "$DEST/repository/queries.js" << EOF
'use strict';

// TODO: verify TABLE matches your migration file
const TABLE = '${LOWER}s';

const QUERIES = {
  FIND_BY_ID: 'SELECT * FROM ' + TABLE + ' WHERE id = \$1 LIMIT 1',
  FIND_ALL:   'SELECT * FROM ' + TABLE + ' ORDER BY created_at DESC LIMIT \$1 OFFSET \$2',
  COUNT:      'SELECT COUNT(*)::int AS total FROM ' + TABLE,
  CREATE:     'INSERT INTO ' + TABLE + ' (id, name, created_at, updated_at) VALUES (\$1, \$2, \$3, \$4) RETURNING *',
  UPDATE:     'UPDATE '     + TABLE + ' SET name = COALESCE(\$1, name), updated_at = \$2 WHERE id = \$3 RETURNING *',
  DELETE:     'DELETE FROM ' + TABLE + ' WHERE id = \$1',
};

module.exports = { QUERIES };
EOF

cat > "$DEST/repository/index.js" << EOF
'use strict';
module.exports = {
  QUERIES: require('./queries').QUERIES,
};
EOF

# ── service/<name>.service.js ────────────────────────────────
cat > "$DEST/service/${LOWER}.service.js" << EOF
'use strict';

const { ${PASCAL} } = require('../models');

class ${PASCAL}Service {
  /**
   * @param {import('../repository').${PASCAL}Repository} repository
   * @param {import('../../../app/dispatch').Dispatcher}  dispatcher
   */
  constructor(repository, dispatcher) {
    this._repo       = repository;
    this._dispatcher = dispatcher;
  }

  async create(dto) {
    const entity  = new ${PASCAL}(dto);
    const created = await this._repo.create(entity);
    await this._dispatcher.dispatch('${LOWER}.created', created.toResponse());
    return created.toResponse();
  }

  async getById(id) {
    const entity = await this._repo.findById(id);
    return entity.toResponse();
  }

  async list({ page = 1, limit = 20 } = {}) {
    const offset = (page - 1) * limit;
    const [items, total] = await Promise.all([
      this._repo.findAll({ limit, offset }),
      this._repo.count(),
    ]);
    return { items: items.map((e) => e.toResponse()), total, page, limit };
  }

  async update(id, dto) {
    const entity  = await this._repo.findById(id);
    entity.applyUpdate(dto);
    const updated = await this._repo.update(id, { name: entity.name });
    return updated.toResponse();
  }

  async delete(id) {
    await this._repo.delete(id);
    await this._dispatcher.dispatch('${LOWER}.deleted', { id });
  }
}

module.exports = { ${PASCAL}Service };
EOF

cat > "$DEST/service/index.js" << EOF
'use strict';
module.exports = require('./${LOWER}.service');
EOF

# ── controller/<name>.controller.js ─────────────────────────
# No container import — service is injected by the router factory.
cat > "$DEST/controller/${LOWER}.controller.js" << EOF
'use strict';

const { ok, created, noContent, paginated } = require('../../../http/response');

/**
 * Build a ${PASCAL} controller bound to the provided service.
 * The controller has zero knowledge of the DI container.
 *
 * @param {import('../service').${PASCAL}Service} ${LOWER}Service
 */
function makeController(${LOWER}Service) {
  async function create(req, res, next) {
    try {
      return created(res, await ${LOWER}Service.create(req.body));
    } catch (err) { next(err); }
  }

  async function getById(req, res, next) {
    try {
      return ok(res, await ${LOWER}Service.getById(req.params.id));
    } catch (err) { next(err); }
  }

  async function list(req, res, next) {
    try {
      const page  = Number(req.query.page  || 1);
      const limit = Number(req.query.limit || 20);
      return paginated(res, await ${LOWER}Service.list({ page, limit }));
    } catch (err) { next(err); }
  }

  async function update(req, res, next) {
    try {
      return ok(res, await ${LOWER}Service.update(req.params.id, req.body));
    } catch (err) { next(err); }
  }

  async function remove(req, res, next) {
    try {
      await ${LOWER}Service.delete(req.params.id);
      return noContent(res);
    } catch (err) { next(err); }
  }

  return { create, getById, list, update, remove };
}

module.exports = { makeController };
EOF

cat > "$DEST/controller/index.js" << EOF
'use strict';
module.exports = require('./${LOWER}.controller');
EOF

# ── middleware/<name>.middleware.js ──────────────────────────
cat > "$DEST/middleware/${LOWER}.middleware.js" << EOF
'use strict';

const { BaseMiddleware } = require('../../../http/middlewares/BaseMiddleware');
const { HttpError }      = require('../../../http/errors/httpError');

class ${PASCAL}Middleware extends BaseMiddleware {
  /**
   * Ensure the authenticated user owns the requested resource.
   * Default: compares req.params.id to req.auth.sub.
   * Override resolveOwnerId() for custom ownership logic.
   */
  requireOwner() {
    return BaseMiddleware.wrap(async (req, _res, next) => {
      if (req.params.id !== req.auth?.sub) {
        return next(new HttpError(403, 'Access denied'));
      }
      next();
    });
  }
}

/** Singleton instance for direct use in the router. */
const ${LOWER}Middleware = new ${PASCAL}Middleware();

module.exports = { ${PASCAL}Middleware, ${LOWER}Middleware };
EOF

cat > "$DEST/middleware/index.js" << EOF
'use strict';
module.exports = require('./${LOWER}.middleware');
EOF

# ── router/index.js ──────────────────────────────────────────
# Exports createRouter(service) — a factory, not a pre-wired instance.
# The composition root (bootstrap/router.js) calls it with the resolved service.
cat > "$DEST/router/index.js" << EOF
'use strict';

const { Router }           = require('express');
const { makeController }   = require('../controller');
const { validate }         = require('../DTO/validate');
const { authMiddleware }   = require('../../../http/middlewares');
const {
  Create${PASCAL}Dto,
  Update${PASCAL}Dto,
  ${PASCAL}ParamDto,
  ${PASCAL}ListQueryDto,
} = require('../DTO');

/**
 * Create the ${PASCAL} Express router.
 *
 * @param {import('../service').${PASCAL}Service} ${LOWER}Service
 * @returns {import('express').Router}
 */
function createRouter(${LOWER}Service) {
  const ctrl   = makeController(${LOWER}Service);
  const router = Router();

  // ── Public ───────────────────────────────────────────────────
  router.post('/',
    validate(Create${PASCAL}Dto, 'body'),
    ctrl.create);

  // ── Protected ────────────────────────────────────────────────
  router.use(authMiddleware);

  router.get('/',
    validate(${PASCAL}ListQueryDto, 'query'),
    ctrl.list);

  router.get('/:id',
    validate(${PASCAL}ParamDto, 'params'),
    ctrl.getById);

  router.patch('/:id',
    validate(${PASCAL}ParamDto, 'params'),
    validate(Update${PASCAL}Dto, 'body'),
    ctrl.update);

  router.delete('/:id',
    validate(${PASCAL}ParamDto, 'params'),
    ctrl.remove);

  return router;
}

module.exports = { createRouter };
EOF
MAKER_EOF

chmod +x module.sh

# ---------------------------------------------------------
# 21. نصب پکیج‌ها
# ---------------------------------------------------------
echo ""
echo "📥 Installing dependencies..."
npm install
