
#!/usr/bin/env bash
# ============================================================
# Back-end Builder – full scaffold
# Run from the project root: bash new.sh
# ============================================================
set -euo pipefail

PROJECT_NAME="${1:?Usage: bash new.sh <project-name>}"

# Validate: only lowercase letters, digits, hyphens/underscores
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
  echo "Error: project name must start with a letter and contain only letters, digits, - or _"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/$PROJECT_NAME"
SRC="$ROOT/src"

if [[ -d "$ROOT" ]]; then
  echo "Error: directory '$ROOT' already exists."
  exit 1
fi

mkdir -p "$ROOT"
echo "▶  Scaffolding project '$PROJECT_NAME' at $ROOT ..."

# ────────────────────────────────────────────────────────────
# 1. DIRECTORIES
# ────────────────────────────────────────────────────────────
mkdir -p \
  "$SRC/bootstrap" \
  "$SRC/http/middlewares" \
  "$SRC/http/response" \
  "$SRC/http/errors" \
  "$SRC/app/config" \
  "$SRC/app/container" \
  "$SRC/app/dispatch" \
  "$SRC/infrastructure/env" \
  "$SRC/infrastructure/logger" \
  "$SRC/infrastructure/database/postgresql/migrations" \
  "$SRC/infrastructure/database/postgresql/seeds" \
  "$SRC/infrastructure/cache/redis" \
  "$SRC/infrastructure/queue" \
  "$SRC/infrastructure/eventbus" \
  "$SRC/modules/users" \
  "$SRC/shared/errors" \
  "$SRC/shared/utils" \
  "$SRC/shared/validation" \
  "$ROOT/tests/unit" \
  "$ROOT/tests/integration" \
  "$ROOT/tests/e2e"

# ────────────────────────────────────────────────────────────
# 2. ROOT FILES
# ────────────────────────────────────────────────────────────
cat > "$ROOT/package.json" << 'EOF'
{
  "name": "backend-builder",
  "version": "1.0.0",
  "description": "Production-ready modular Node.js backend",
  "main": "src/bootstrap/server.js",
  "scripts": {
    "start":       "node src/bootstrap/server.js",
    "dev":         "nodemon src/bootstrap/server.js",
    "test":        "jest --runInBand",
    "test:unit":   "jest tests/unit",
    "test:int":    "jest tests/integration",
    "test:e2e":    "jest tests/e2e",
    "new:module":  "bash module.sh"
  },
  "dependencies": {
    "bcryptjs":           "^2.4.3",
    "bull":               "^4.12.2",
    "compression":        "^1.7.4",
    "cors":               "^2.8.5",
    "dotenv":             "^16.4.5",
    "express":            "^4.18.2",
    "express-rate-limit": "^7.1.5",
    "helmet":             "^7.1.0",
    "ioredis":            "^5.3.2",
    "jsonwebtoken":       "^9.0.2",
    "pg":                 "^8.11.3",
    "uuid":               "^9.0.0",
    "winston":            "^3.11.0",
    "zod":                "^3.22.4"
  },
  "devDependencies": {
    "jest":       "^29.7.0",
    "nodemon":    "^3.0.2",
    "supertest":  "^6.3.4"
  },
  "jest": {
    "testEnvironment": "node",
    "testMatch": ["**/tests/**/*.test.js"]
  }
}
EOF

cat > "$ROOT/.gitignore" << 'EOF'
node_modules/
dist/
.env
*.log
coverage/
.DS_Store
EOF

cat > "$ROOT/.env.example" << 'EOF'
# Application
NODE_ENV=development
PORT=3000
APP_SECRET=change_me_in_production

# PostgreSQL
DB_HOST=localhost
DB_PORT=5432
DB_NAME=appdb
DB_USER=postgres
DB_PASSWORD=password
DB_POOL_MAX=10

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# JWT
JWT_SECRET=super_secret_jwt_key
JWT_EXPIRES_IN=1d

# Rate Limit
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX=100

# Logging
LOG_LEVEL=info
EOF

cat > "$ROOT/README.md" << 'EOF'
# Back-end Builder

Production-ready modular Node.js backend using Express, PostgreSQL, Redis, Bull, and Winston.

## Architecture

```
bootstrap  → application startup
http       → HTTP layer (middleware, error mapping, responses)
app        → application layer (config, DI container, dispatcher)
infra      → external adapters (DB, Redis, Queue, EventBus, Logger)
modules    → feature modules (each module owns its full slice)
shared     → reusable cross-cutting utilities
```

## Quick Start

```bash
cp .env.example .env
npm install
npm run dev
```

## Generate a new module

```bash
npm run new:module <module-name>
```
EOF

# ────────────────────────────────────────────────────────────
# 3. BOOTSTRAP
# ────────────────────────────────────────────────────────────
cat > "$SRC/bootstrap/app.js" << 'EOF'
'use strict';

const express    = require('express');
const helmet     = require('helmet');
const cors       = require('cors');
const compression = require('compression');

const { requestContextMiddleware } = require('../http/middlewares');
const { rateLimitMiddleware }      = require('../http/middlewares');
const { errorHandler }             = require('../http/errors');
const router                       = require('./router');

function createApp() {
  const app = express();

  // ── Security & parsing ──────────────────────────────────
  app.use(helmet());
  app.use(cors());
  app.use(compression());
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true }));

  // ── Observability ────────────────────────────────────────
  app.use(requestContextMiddleware);

  // ── Rate limiting ────────────────────────────────────────
  app.use(rateLimitMiddleware);

  // ── Routes ───────────────────────────────────────────────
  app.use('/api', router);

  // ── Health check ─────────────────────────────────────────
  app.get('/health', (_req, res) => res.json({ status: 'ok', ts: Date.now() }));

  // ── Global error handler ─────────────────────────────────
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
EOF

cat > "$SRC/bootstrap/server.js" << 'EOF'
'use strict';

require('dotenv').config();

const { validateEnv }   = require('../infrastructure/env');
const { connectPostgres } = require('../infrastructure/database/postgresql');
const { connectRedis }  = require('../infrastructure/cache/redis');
const { logger }        = require('../infrastructure/logger');
const { bootContainer } = require('../app/container');
const { createApp }     = require('./app');

async function start() {
  try {
    validateEnv();

    await connectPostgres();
    await connectRedis();

    bootContainer();

    const app  = createApp();
    const port = process.env.PORT || 3000;

    const server = app.listen(port, () => {
      logger.info(`Server listening on port ${port} [${process.env.NODE_ENV}]`);
    });

    // ── Graceful shutdown ────────────────────────────────
    const shutdown = (signal) => {
      logger.info(`${signal} received – shutting down gracefully`);
      server.close(() => {
        logger.info('HTTP server closed');
        process.exit(0);
      });
      setTimeout(() => process.exit(1), 10_000);
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT',  () => shutdown('SIGINT'));

  } catch (err) {
    console.error('Fatal startup error:', err);
    process.exit(1);
  }
}

start();
EOF

cat > "$SRC/bootstrap/router.js" << 'EOF'
'use strict';

const { Router } = require('express');
const usersRouter = require('../modules/users/routes');

const router = Router();

router.use('/v1/users', usersRouter);

// Register additional module routers here:
// router.use('/v1/orders', require('../modules/orders/routes'));

module.exports = router;
EOF

# ────────────────────────────────────────────────────────────
# 4. HTTP LAYER
# ────────────────────────────────────────────────────────────
cat > "$SRC/http/index.js" << 'EOF'
'use strict';

module.exports = {
  ...require('./middlewares'),
  ...require('./response'),
  ...require('./errors'),
};
EOF

cat > "$SRC/http/middlewares/index.js" << 'EOF'
'use strict';

module.exports = {
  authMiddleware:           require('./auth'),
  rateLimitMiddleware:      require('./rateLimit'),
  requestContextMiddleware: require('./requestContext'),
};
EOF

cat > "$SRC/http/middlewares/auth.js" << 'EOF'
'use strict';

const jwt = require('jsonwebtoken');
const { HttpError } = require('../errors/httpError');

/**
 * Validates a Bearer JWT and attaches `req.auth` to the request.
 */
function authMiddleware(req, _res, next) {
  const header = req.headers['authorization'] || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return next(new HttpError(401, 'Missing or malformed token'));
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.auth = payload;
    next();
  } catch {
    next(new HttpError(401, 'Invalid or expired token'));
  }
}

module.exports = authMiddleware;
EOF

cat > "$SRC/http/middlewares/rateLimit.js" << 'EOF'
'use strict';

const rateLimit = require('express-rate-limit');

const rateLimitMiddleware = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10),
  max:      parseInt(process.env.RATE_LIMIT_MAX       || '100',    10),
  standardHeaders: true,
  legacyHeaders:   false,
  message: { success: false, error: { message: 'Too many requests, please try again later.' } },
});

module.exports = rateLimitMiddleware;
EOF

cat > "$SRC/http/middlewares/requestContext.js" << 'EOF'
'use strict';

const { v4: uuidv4 } = require('uuid');
const { logger }     = require('../../infrastructure/logger');

/**
 * Attaches a unique requestId to every request and logs it.
 */
function requestContextMiddleware(req, res, next) {
  const requestId = req.headers['x-request-id'] || uuidv4();
  req.requestId   = requestId;
  res.setHeader('x-request-id', requestId);

  const startAt = Date.now();
  res.on('finish', () => {
    logger.info('HTTP request', {
      requestId,
      method:   req.method,
      url:      req.originalUrl,
      status:   res.statusCode,
      ms:       Date.now() - startAt,
    });
  });

  next();
}

module.exports = requestContextMiddleware;
EOF

cat > "$SRC/http/response/index.js" << 'EOF'
'use strict';

/**
 * Standardised JSON envelope:
 *   { success, data, error, meta }
 */

function ok(res, data = null, meta = {}) {
  return res.status(200).json({ success: true, data, meta });
}

function created(res, data = null) {
  return res.status(201).json({ success: true, data, meta: {} });
}

function noContent(res) {
  return res.status(204).send();
}

function paginated(res, { items, total, page, limit }) {
  return res.status(200).json({
    success: true,
    data:    items,
    meta:    { total, page, limit, pages: Math.ceil(total / limit) },
  });
}

function fail(res, status, message, details = null) {
  const body = { success: false, error: { message } };
  if (details) body.error.details = details;
  return res.status(status).json(body);
}

module.exports = { ok, created, noContent, paginated, fail };
EOF

cat > "$SRC/http/errors/httpError.js" << 'EOF'
'use strict';

class HttpError extends Error {
  /**
   * @param {number} status  HTTP status code
   * @param {string} message Human-readable message
   * @param {any}    [details] Optional structured detail
   */
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

cat > "$SRC/http/errors/mapper.js" << 'EOF'
'use strict';

const { HttpError }   = require('./httpError');
const { DomainError } = require('../../shared/errors/domainError');

/**
 * Translates any thrown error into a normalised HttpError.
 * Domain errors receive explicit status mappings; everything
 * else falls back to 500.
 */
function mapToHttpError(err) {
  if (err instanceof HttpError) return err;

  if (err instanceof DomainError) {
    const statusMap = {
      NOT_FOUND:   404,
      FORBIDDEN:   403,
      CONFLICT:    409,
      VALIDATION:  422,
      UNAUTHORISED:401,
    };
    const status = statusMap[err.code] || 400;
    return new HttpError(status, err.message, err.meta);
  }

  // Unknown / infrastructure errors → 500
  return new HttpError(500, 'Internal server error');
}

module.exports = { mapToHttpError };
EOF

cat > "$SRC/http/errors/index.js" << 'EOF'
'use strict';

const { logger }       = require('../../infrastructure/logger');
const { mapToHttpError } = require('./mapper');

/**
 * Express 4-argument error-handling middleware.
 * Must be registered LAST in app.js.
 */
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const httpErr = mapToHttpError(err);

  if (httpErr.status >= 500) {
    logger.error('Unhandled error', {
      requestId: req.requestId,
      stack:     err.stack,
    });
  }

  return res.status(httpErr.status).json({
    success: false,
    error: {
      message: httpErr.message,
      ...(httpErr.details ? { details: httpErr.details } : {}),
      ...(process.env.NODE_ENV !== 'production' && httpErr.status >= 500
        ? { stack: err.stack }
        : {}),
    },
  });
}

module.exports = { errorHandler, ...require('./httpError'), ...require('./mapper') };
EOF

# ────────────────────────────────────────────────────────────
# 5. APP LAYER
# ────────────────────────────────────────────────────────────
cat > "$SRC/app/index.js" << 'EOF'
'use strict';

module.exports = {
  ...require('./config'),
  ...require('./container'),
  ...require('./dispatch'),
};
EOF

cat > "$SRC/app/config/features.js" << 'EOF'
'use strict';

/**
 * Feature flags – read from env so they can be toggled without deploys.
 */
const features = {
  emailVerification: process.env.FEATURE_EMAIL_VERIFICATION === 'true',
  rateLimiting:      process.env.FEATURE_RATE_LIMITING      !== 'false',
  auditLog:          process.env.FEATURE_AUDIT_LOG          === 'true',
};

module.exports = { features };
EOF

cat > "$SRC/app/config/policies.js" << 'EOF'
'use strict';

/**
 * Authorisation policies.
 * Each policy receives (authPayload, resource) and returns boolean.
 */
const policies = {
  'users:read':   (auth) => !!auth,
  'users:write':  (auth) => auth && (auth.role === 'admin' || auth.sub === auth.targetId),
  'users:delete': (auth) => auth && auth.role === 'admin',
};

function can(auth, policy, resource = null) {
  const check = policies[policy];
  if (!check) return false;
  return check(auth, resource);
}

module.exports = { policies, can };
EOF

cat > "$SRC/app/config/index.js" << 'EOF'
'use strict';

module.exports = {
  ...require('./features'),
  ...require('./policies'),
};
EOF

cat > "$SRC/app/container/index.js" << 'EOF'
'use strict';

/**
 * Lightweight synchronous DI container.
 *
 *   container.register(token, factory)   – transient (new instance per resolve)
 *   container.singleton(token, factory)  – single shared instance
 *   container.instance(token, value)     – register a pre-built value
 *   container.resolve(token)             – retrieve / construct
 */
class Container {
  constructor() {
    this._bindings   = new Map();
    this._singletons = new Map();
  }

  register(token, factory) {
    this._bindings.set(token, { factory, scope: 'transient' });
    return this;
  }

  singleton(token, factory) {
    this._bindings.set(token, { factory, scope: 'singleton' });
    return this;
  }

  instance(token, value) {
    this._singletons.set(token, value);
    this._bindings.set(token, { factory: () => value, scope: 'singleton' });
    return this;
  }

  resolve(token) {
    if (!this._bindings.has(token)) {
      throw new Error(`[Container] No binding registered for token: "${token}"`);
    }

    const binding = this._bindings.get(token);

    if (binding.scope === 'singleton') {
      if (!this._singletons.has(token)) {
        this._singletons.set(token, binding.factory(this));
      }
      return this._singletons.get(token);
    }

    return binding.factory(this);
  }

  /** Verify all registered singletons can be constructed. */
  verify() {
    for (const [token, binding] of this._bindings) {
      if (binding.scope === 'singleton') {
        this.resolve(token);
      }
    }
  }
}

const container = new Container();

function bootContainer() {
  require('./providers').register(container);
  return container;
}

module.exports = { Container, container, bootContainer };
EOF

cat > "$SRC/app/container/providers.js" << 'EOF'
'use strict';

const { db }                    = require('../../infrastructure/database/postgresql');
const { redisClient }           = require('../../infrastructure/cache/redis');
const { dispatcher }            = require('../dispatch');
const { UsersService }          = require('../../modules/users/users.service');

/**
 * Register all application bindings here.
 * Order matters only when a factory depends on a prior singleton.
 */
function register(container) {
  // ── Infrastructure ────────────────────────────────────────
  container.instance('db',          db);
  container.instance('redisClient', redisClient);
  container.instance('dispatcher',  dispatcher);

  // ── Repositories ─────────────────────────────────────────
  container.singleton('userRepository', (c) =>
    new UserPgRepository(c.resolve('db')));

  // ── Services ─────────────────────────────────────────────
  container.singleton('usersService', (c) =>
    new UsersService(c.resolve('userRepository'), c.resolve('dispatcher')));
}

module.exports = { register };
EOF

cat > "$SRC/app/dispatch/handlers.js" << 'EOF'
'use strict';

/**
 * Register application-level event handlers.
 * Called once during bootstrap.
 *
 * @param {import('./index').Dispatcher} dispatcher
 */
function registerHandlers(dispatcher) {
  dispatcher.on('user.created', async (payload) => {
    // e.g. send welcome email, seed onboarding data …
    const { logger } = require('../../infrastructure/logger');
    logger.info('Event: user.created', { userId: payload.id });
  });

  dispatcher.on('user.deleted', async (payload) => {
    const { logger } = require('../../infrastructure/logger');
    logger.info('Event: user.deleted', { userId: payload.id });
  });
}

module.exports = { registerHandlers };
EOF

cat > "$SRC/app/dispatch/index.js" << 'EOF'
'use strict';

const { bus }               = require('../../infrastructure/eventbus');
const { registerHandlers }  = require('./handlers');

/**
 * Application-level event dispatcher.
 *
 *   dispatcher.on(event, asyncHandler)
 *   await dispatcher.dispatch(event, payload)
 *
 * Dispatching runs all in-process handlers AND publishes
 * to the infrastructure event bus for cross-service fanout.
 */
class Dispatcher {
  constructor(eventBus) {
    this._handlers = new Map();
    this._bus      = eventBus;
  }

  on(event, handler) {
    if (!this._handlers.has(event)) this._handlers.set(event, []);
    this._handlers.get(event).push(handler);
    return this;
  }

  async dispatch(event, payload) {
    const handlers = this._handlers.get(event) || [];
    await Promise.all(handlers.map((h) => h(payload)));
    await this._bus.publish(event, payload);
  }
}

const dispatcher = new Dispatcher(bus);
registerHandlers(dispatcher);

module.exports = { Dispatcher, dispatcher };
EOF

# ────────────────────────────────────────────────────────────
# 6. INFRASTRUCTURE
# ────────────────────────────────────────────────────────────
cat > "$SRC/infrastructure/index.js" << 'EOF'
'use strict';

module.exports = {
  ...require('./env'),
  ...require('./logger'),
  ...require('./database/postgresql'),
  ...require('./cache/redis'),
  ...require('./queue'),
  ...require('./eventbus'),
};
EOF

cat > "$SRC/infrastructure/env/validateEnv.js" << 'EOF'
'use strict';

const { z } = require('zod');

const envSchema = z.object({
  NODE_ENV:   z.enum(['development', 'test', 'production']).default('development'),
  PORT:       z.string().regex(/^\d+$/).default('3000'),
  DB_HOST:    z.string().min(1),
  DB_PORT:    z.string().regex(/^\d+$/).default('5432'),
  DB_NAME:    z.string().min(1),
  DB_USER:    z.string().min(1),
  DB_PASSWORD:z.string(),
  REDIS_HOST: z.string().min(1),
  REDIS_PORT: z.string().regex(/^\d+$/).default('6379'),
  JWT_SECRET: z.string().min(12),
});

function validateEnv() {
  const result = envSchema.safeParse(process.env);
  if (!result.success) {
    const formatted = result.error.errors
      .map((e) => `  ${e.path.join('.')}: ${e.message}`)
      .join('\n');
    throw new Error(`Environment validation failed:\n${formatted}`);
  }
}

module.exports = { validateEnv };
EOF

cat > "$SRC/infrastructure/env/index.js" << 'EOF'
'use strict';

module.exports = require('./validateEnv');
EOF

cat > "$SRC/infrastructure/logger/index.js" << 'EOF'
'use strict';

const winston = require('winston');

const { combine, timestamp, json, colorize, simple, errors } = winston.format;

const isProduction = process.env.NODE_ENV === 'production';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: combine(
    errors({ stack: true }),
    timestamp(),
    isProduction ? json() : combine(colorize(), simple()),
  ),
  transports: [
    new winston.transports.Console(),
    ...(isProduction
      ? [new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
         new winston.transports.File({ filename: 'logs/combined.log' })]
      : []),
  ],
});

module.exports = { logger };
EOF

cat > "$SRC/infrastructure/database/postgresql/connection.js" << 'EOF'
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
EOF

cat > "$SRC/infrastructure/database/postgresql/db.js" << 'EOF'
'use strict';

const { getPool } = require('./connection');

/**
 * Thin query helper. Exposes:
 *   db.query(sql, params)
 *   db.transaction(async (client) => { … })
 */
const db = {
  async query(sql, params = []) {
    const pool   = getPool();
    const result = await pool.query(sql, params);
    return result;
  },

  async transaction(callback) {
    const pool   = getPool();
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  },
};

module.exports = { db };
EOF

cat > "$SRC/infrastructure/database/postgresql/index.js" << 'EOF'
'use strict';

module.exports = {
  ...require('./connection'),
  ...require('./db'),
};
EOF

cat > "$SRC/infrastructure/cache/redis/connection.js" << 'EOF'
'use strict';

const Redis    = require('ioredis');
const { logger } = require('../../logger');

let redisInstance;

async function connectRedis() {
  redisInstance = new Redis({
    host:           process.env.REDIS_HOST || 'localhost',
    port:           parseInt(process.env.REDIS_PORT || '6379', 10),
    password:       process.env.REDIS_PASSWORD || undefined,
    lazyConnect:    true,
    maxRetriesPerRequest: 3,
  });

  redisInstance.on('error', (err) => logger.error('Redis error', { err }));
  await redisInstance.connect();
  logger.info('Redis connected');
  return redisInstance;
}

function getRedis() {
  if (!redisInstance) throw new Error('Redis not initialised – call connectRedis() first');
  return redisInstance;
}

module.exports = { connectRedis, getRedis };
EOF

cat > "$SRC/infrastructure/cache/redis/client.js" << 'EOF'
'use strict';

const { getRedis } = require('./connection');

/**
 * High-level Redis client with typed helpers.
 */
const redisClient = {
  async get(key) {
    const raw = await getRedis().get(key);
    if (!raw) return null;
    try { return JSON.parse(raw); } catch { return raw; }
  },

  async set(key, value, ttlSeconds = null) {
    const serialised = typeof value === 'string' ? value : JSON.stringify(value);
    if (ttlSeconds) {
      return getRedis().set(key, serialised, 'EX', ttlSeconds);
    }
    return getRedis().set(key, serialised);
  },

  async del(key) {
    return getRedis().del(key);
  },

  async exists(key) {
    const count = await getRedis().exists(key);
    return count > 0;
  },
};

module.exports = { redisClient };
EOF

cat > "$SRC/infrastructure/cache/redis/index.js" << 'EOF'
'use strict';

module.exports = {
  ...require('./connection'),
  ...require('./client'),
};
EOF

cat > "$SRC/infrastructure/queue/client.js" << 'EOF'
'use strict';

const Bull = require('bull');
const { logger } = require('../logger');

const queues = new Map();

function getQueue(name) {
  if (!queues.has(name)) {
    const q = new Bull(name, {
      redis: {
        host:     process.env.REDIS_HOST || 'localhost',
        port:     parseInt(process.env.REDIS_PORT || '6379', 10),
        password: process.env.REDIS_PASSWORD || undefined,
      },
    });

    q.on('error',   (err) => logger.error(`Queue "${name}" error`, { err }));
    q.on('failed',  (job, err) => logger.warn(`Job failed in "${name}"`, { jobId: job.id, err }));

    queues.set(name, q);
  }
  return queues.get(name);
}

module.exports = { getQueue };
EOF

cat > "$SRC/infrastructure/queue/producer.js" << 'EOF'
'use strict';

const { getQueue } = require('./client');

/**
 * @param {string} queueName
 * @param {object} data
 * @param {import('bull').JobOptions} [opts]
 */
async function enqueue(queueName, data, opts = {}) {
  const queue = getQueue(queueName);
  const job   = await queue.add(data, {
    attempts:  3,
    backoff:   { type: 'exponential', delay: 2000 },
    removeOnComplete: 100,
    removeOnFail:     200,
    ...opts,
  });
  return job.id;
}

module.exports = { enqueue };
EOF

cat > "$SRC/infrastructure/queue/consumer.js" << 'EOF'
'use strict';

const { getQueue } = require('./client');
const { logger }   = require('../logger');

/**
 * Register a processor for a named queue.
 *
 * @param {string}   queueName
 * @param {function} processor  async (job) => any
 * @param {object}   [options]
 */
function consume(queueName, processor, options = {}) {
  const queue = getQueue(queueName);
  queue.process(options.concurrency || 1, async (job) => {
    logger.debug(`Processing job ${job.id} in "${queueName}"`);
    return processor(job);
  });
  logger.info(`Consumer registered for queue "${queueName}"`);
}

module.exports = { consume };
EOF

cat > "$SRC/infrastructure/queue/index.js" << 'EOF'
'use strict';

module.exports = {
  ...require('./client'),
  ...require('./producer'),
  ...require('./consumer'),
};
EOF

cat > "$SRC/infrastructure/eventbus/bus.js" << 'EOF'
'use strict';

const EventEmitter = require('events');
const { logger }   = require('../logger');

/**
 * In-process event bus backed by Node's EventEmitter.
 * Swap publish() for an external broker (Redis pub/sub, RabbitMQ, etc.)
 * without changing any call-site.
 */
class EventBus extends EventEmitter {
  async publish(event, payload) {
    logger.debug('EventBus publish', { event, payload });
    this.emit(event, payload);
  }

  subscribe(event, listener) {
    this.on(event, listener);
  }
}

const bus = new EventBus();
bus.setMaxListeners(50);

module.exports = { bus, EventBus };
EOF

cat > "$SRC/infrastructure/eventbus/index.js" << 'EOF'
'use strict';

module.exports = require('./bus');
EOF

# ────────────────────────────────────────────────────────────
# 7. SHARED
# ────────────────────────────────────────────────────────────
cat > "$SRC/shared/errors/domainError.js" << 'EOF'
'use strict';

/**
 * Base class for all domain / application errors.
 * The HTTP mapper translates these via their `code`.
 */
class DomainError extends Error {
  /**
   * @param {string} message  Human-readable description
   * @param {string} code     Machine-readable code (NOT_FOUND, CONFLICT, …)
   * @param {any}    [meta]   Optional context data
   */
  constructor(message, code = 'DOMAIN_ERROR', meta = null) {
    super(message);
    this.name = 'DomainError';
    this.code = code;
    this.meta = meta;
    Error.captureStackTrace(this, this.constructor);
  }

  static notFound(message = 'Resource not found', meta = null) {
    return new DomainError(message, 'NOT_FOUND', meta);
  }

  static conflict(message = 'Resource already exists', meta = null) {
    return new DomainError(message, 'CONFLICT', meta);
  }

  static forbidden(message = 'Access denied', meta = null) {
    return new DomainError(message, 'FORBIDDEN', meta);
  }

  static validation(message = 'Validation failed', meta = null) {
    return new DomainError(message, 'VALIDATION', meta);
  }

  static unauthorised(message = 'Unauthorised', meta = null) {
    return new DomainError(message, 'UNAUTHORISED', meta);
  }
}

module.exports = { DomainError };
EOF

cat > "$SRC/shared/errors/index.js" << 'EOF'
'use strict';

module.exports = require('./domainError');
EOF

cat > "$SRC/shared/utils/id.js" << 'EOF'
'use strict';

const { v4: uuidv4 } = require('uuid');

function generateId() {
  return uuidv4();
}

function isValidId(id) {
  return typeof id === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id);
}

module.exports = { generateId, isValidId };
EOF

cat > "$SRC/shared/utils/time.js" << 'EOF'
'use strict';

function now() {
  return new Date();
}

function toISOString(date = new Date()) {
  return date instanceof Date ? date.toISOString() : new Date(date).toISOString();
}

function addSeconds(date, seconds) {
  return new Date(date.getTime() + seconds * 1000);
}

module.exports = { now, toISOString, addSeconds };
EOF

cat > "$SRC/shared/utils/index.js" << 'EOF'
'use strict';

module.exports = {
  ...require('./id'),
  ...require('./time'),
};
EOF

cat > "$SRC/shared/validation/validate.js" << 'EOF'
'use strict';

const { DomainError } = require('../errors/domainError');

/**
 * Validates data against a Zod schema.
 * Throws DomainError(VALIDATION) on failure.
 *
 * @template T
 * @param {import('zod').ZodType<T>} schema
 * @param {unknown} data
 * @returns {T}
 */
function validate(schema, data) {
  const result = schema.safeParse(data);
  if (!result.success) {
    const details = result.error.errors.map((e) => ({
      field:   e.path.join('.'),
      message: e.message,
    }));
    throw DomainError.validation('Validation failed', details);
  }
  return result.data;
}

module.exports = { validate };
EOF

cat > "$SRC/shared/validation/index.js" << 'EOF'
'use strict';

module.exports = require('./validate');
EOF

cat > "$SRC/shared/index.js" << 'EOF'
'use strict';

module.exports = {
  ...require('./errors'),
  ...require('./utils'),
  ...require('./validation'),
};
EOF

# ────────────────────────────────────────────────────────────
# 8. USERS MODULE
# ────────────────────────────────────────────────────────────

cat > "$SRC/modules/users/user.repository.js" << 'EOF'
'use strict';

/**
 * Port (interface) – defines the contract every
 * user-repository adapter must fulfil.
 *
 * All implementations live in ../infrastructure/.
 */
class UserRepository {
  // eslint-disable-next-line no-unused-vars
  async findById(id)                { throw new Error('Not implemented'); }
  // eslint-disable-next-line no-unused-vars
  async findByEmail(email)          { throw new Error('Not implemented'); }
  // eslint-disable-next-line no-unused-vars
  async findAll({ limit, offset })  { throw new Error('Not implemented'); }
  // eslint-disable-next-line no-unused-vars
  async count()                     { throw new Error('Not implemented'); }
  // eslint-disable-next-line no-unused-vars
  async create(user)                { throw new Error('Not implemented'); }
  // eslint-disable-next-line no-unused-vars
  async update(id, data)            { throw new Error('Not implemented'); }
  // eslint-disable-next-line no-unused-vars
  async delete(id)                  { throw new Error('Not implemented'); }
}

module.exports = { UserRepository };
EOF

# Initial migration
cat > "$SRC/infrastructure/database/postgresql/migrations/001_create_users.sql" << 'EOF'
-- Migration: 001_create_users
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name          VARCHAR(255) NOT NULL,
  email         VARCHAR(320) NOT NULL UNIQUE,
  password_hash TEXT         NOT NULL,
  role          VARCHAR(50)  NOT NULL DEFAULT 'user',
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
EOF

cat > "$SRC/modules/users/user.dto.js" << 'EOF'
'use strict';

/**
 * Shape guaranteed to callers of the users public API.
 * Strips sensitive fields (passwordHash) before leaving the layer.
 */
function toUserResponseDto(user) {
  return {
    id:        user.id,
    name:      user.name,
    email:     user.email,
    role:      user.role,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

module.exports = { toUserResponseDto };
EOF
cat > "$SRC/modules/users/users.service.js" << 'EOF'
'use strict';

const { validate }        = require('../../../shared/validation/validate');
const { DomainError }     = require('../../../shared/errors/domainError');
const { UserCreateSchema }= require('../dtos/user.create.dto');
const { dtoToEntity, entityToResponse } = require('../mappers/user.mapper');

class UsersService {
  /**
   * @param {import('../user.repository').UserRepository} userRepository
   * @param {import('../../../app/dispatch').Dispatcher} dispatcher
   */
  constructor(userRepository, dispatcher) {
    this._repo       = userRepository;
    this._dispatcher = dispatcher;
  }

  async createUser(rawDto) {
    const dto = validate(UserCreateSchema, rawDto);

    const existing = await this._repo.findByEmail(dto.email);
    if (existing) throw DomainError.conflict('Email is already registered');

    const user    = await dtoToEntity(dto);
    const created = await this._repo.create(user);

    await this._dispatcher.dispatch('user.created', entityToResponse(created));

    return entityToResponse(created);
  }

  async getUserById(id) {
    const user = await this._repo.findById(id);
    return entityToResponse(user);
  }

  async listUsers({ page = 1, limit = 20 } = {}) {
    const offset = (page - 1) * limit;
    const [users, total] = await Promise.all([
      this._repo.findAll({ limit, offset }),
      this._repo.count(),
    ]);
    return {
      items: users.map(entityToResponse),
      total,
      page,
      limit,
    };
  }

  async updateUser(id, rawData) {
    // Fetch to ensure it exists (throws NOT_FOUND otherwise)
    await this._repo.findById(id);
    const updated = await this._repo.update(id, rawData);
    return entityToResponse(updated);
  }

  async deleteUser(id) {
    await this._repo.delete(id);
    await this._dispatcher.dispatch('user.deleted', { id });
  }
}

module.exports = { UsersService };
EOF

cat > "$SRC/modules/users/users.controller.js" << 'EOF'
'use strict';

const { ok, created, noContent, paginated } = require('../../../http/response');
const { container } = require('../../../app/container');

function getUsersService() {
  return container.resolve('usersService');
}

async function createUser(req, res, next) {
  try {
    const user = await getUsersService().createUser(req.body);
    return created(res, user);
  } catch (err) { next(err); }
}

async function getUser(req, res, next) {
  try {
    const user = await getUsersService().getUserById(req.params.id);
    return ok(res, user);
  } catch (err) { next(err); }
}

async function listUsers(req, res, next) {
  try {
    const page  = parseInt(req.query.page  || '1',  10);
    const limit = parseInt(req.query.limit || '20', 10);
    const result = await getUsersService().listUsers({ page, limit });
    return paginated(res, result);
  } catch (err) { next(err); }
}

async function updateUser(req, res, next) {
  try {
    const user = await getUsersService().updateUser(req.params.id, req.body);
    return ok(res, user);
  } catch (err) { next(err); }
}

async function deleteUser(req, res, next) {
  try {
    await getUsersService().deleteUser(req.params.id);
    return noContent(res);
  } catch (err) { next(err); }
}

module.exports = { createUser, getUser, listUsers, updateUser, deleteUser };
EOF

cat > "$SRC/modules/users/users.middleware.js" << 'EOF'
'use strict';

const { HttpError } = require('../../../http/errors/httpError');
const { isValidId } = require('../../../shared/utils/id');

/**
 * Validates that :id route params are valid UUIDs.
 */
function validateUserId(req, _res, next) {
  if (!isValidId(req.params.id)) {
    return next(new HttpError(400, 'Invalid user ID format'));
  }
  next();
}

module.exports = { validateUserId };
EOF

cat > "$SRC/modules/users/user.router.js" << 'EOF'
'use strict';

const { Router }        = require('express');
const ctrl              = require('../controllers/users.controller');
const { validateUserId }= require('../middlewares/users.middleware');
const authMiddleware    = require('../../../http/middlewares/auth');

const router = Router();

// Public
router.post('/',    ctrl.createUser);

// Protected
router.use(authMiddleware);
router.get('/',              ctrl.listUsers);
router.get('/:id',  validateUserId, ctrl.getUser);
router.patch('/:id',validateUserId, ctrl.updateUser);
router.delete('/:id',validateUserId, ctrl.deleteUser);

module.exports = router;
EOF

cat > "$SRC/modules/users/index.js" << 'EOF'
'use strict';

/**
 * Public API of the users module.
 * Only these exports should be consumed by other modules.
 * Direct access to internals breaks encapsulation.
 */
module.exports = {
  UsersService:    require('./services/users.service').UsersService,
  UserRepository:  require('./user.repository').UserRepository,
  UserEntity:      require('./user.entity').User,
  UserModel:       require('./user.models').User,
};
EOF

cat > "$SRC/modules/users/user.models.js" << 'EOF'
'use strict';

const { generateId } = require('../../shared/utils/id');
const { now }        = require('../../shared/utils/time');

/**
 * User domain entity.
 * Represents the core business logic and invariants of a user.
 * Never exposed directly to HTTP clients – always mapped via DTO.
 */
class User {
    constructor({
        id,
        name,
        email,
        passwordHash,
        role = 'user',
        createdAt,
        updatedAt,
    }) {
        this.id           = id           || generateId();
        this.name         = name;
        this.email        = email;
        this.passwordHash = passwordHash;
        this.role         = role;
        this.createdAt    = createdAt    || now();
        this.updatedAt    = updatedAt    || now();
    }

    /**
     * Factory: construct from a creation DTO.
     * Hashing happens here to keep domain logic centralised.
     */
    static async fromCreateDto(dto, hashPassword) {
        const passwordHash = await hashPassword(dto.password);
        return new User({
            name:  dto.name,
            email: dto.email,
            passwordHash,
            role:  dto.role || 'user',
        });
    }

    /**
     * Verify a plaintext password against the stored hash.
     */
    async verifyPassword(passwordString, comparePassword) {
        return comparePassword(passwordString, this.passwordHash);
    }

    /**
     * Update allowed fields. Mutates updatedAt.
     */
    update(changes) {
        if (changes.name !== undefined)  this.name  = changes.name;
        if (changes.email !== undefined) this.email = changes.email;
        if (changes.role !== undefined)  this.role  = changes.role;
        this.updatedAt = now();
    }

    /**
     * Convert to plain object for persistence.
     */
    toRecord() {
        return {
            id:           this.id,
            name:         this.name,
            email:        this.email,
            password_hash:this.passwordHash,
            role:         this.role,
            created_at:   this.createdAt,
            updated_at:   this.updatedAt,
        };
    }

    /**
     * Reconstruct from database record (snake_case columns).
     */
    static fromRecord(row) {
        return new User({
            id:           row.id,
            name:         row.name,
            email:        row.email,
            passwordHash: row.password_hash,
            role:         row.role,
            createdAt:    new Date(row.created_at),
            updatedAt:    new Date(row.updated_at),
        });
    }
}

module.exports = { User };
EOF
# ────────────────────────────────────────────────────────────
# 9. MODULE GENERATOR (module.sh)
# ────────────────────────────────────────────────────────────
cat > "$ROOT/module.sh" << 'MODULEEOF'
#!/usr/bin/env bash
# Usage: bash module.sh <module-name>
# Generates a new module following the standard template.
set -euo pipefail

MODULE="${1:?Usage: bash module.sh <module-name>}"
LOWER="$(echo "$MODULE" | tr '[:upper:]' '[:lower:]')"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/src"
DEST="$SRC/modules/$LOWER"

if [[ -d "$DEST" ]]; then
  echo "Module '$LOWER' already exists at $DEST"
  exit 1
fi

mkdir -p \
  "$DEST/routes" \
  "$DEST/controllers" \
  "$DEST/services" \
  "$DEST/repositories" \
  "$DEST/dtos" \
  "$DEST/middlewares" \

echo "// Public API of the ${LOWER} module" > "$DEST/index.js"
echo "// TODO: export service, repository interface, entity" >> "$DEST/index.js"

echo "✔  Module '$LOWER' scaffolded at $DEST"
echo "   Next steps:"
echo "   1. Define the domain entity in /${LOWER}.entity.js"
echo "   2. Define the repository interface in repositories/${LOWER}.repository.js"
echo "   3. Implement the adapter in infrastructure/${LOWER}.pg.repository.js"
echo "   4. Register in app/container/providers.js"
echo "   5. Mount routes in bootstrap/router.js"
MODULEEOF
chmod +x "$ROOT/module.sh"

# ────────────────────────────────────────────────────────────
# 10. TEST STUBS
# ────────────────────────────────────────────────────────────
cat > "$ROOT/tests/unit/users.service.test.js" << 'EOF'
'use strict';

const { UsersService }    = require('../../src/modules/users/users.service');
const { DomainError }     = require('../../src/shared/errors/domainError');

const makeRepo = (overrides = {}) => ({
  findByEmail: jest.fn().mockResolvedValue(null),
  create:      jest.fn().mockImplementation(async (u) => u),
  findById:    jest.fn(),
  findAll:     jest.fn().mockResolvedValue([]),
  count:       jest.fn().mockResolvedValue(0),
  update:      jest.fn(),
  delete:      jest.fn(),
  ...overrides,
});

const makeDispatcher = () => ({
  dispatch: jest.fn().mockResolvedValue(undefined),
});

describe('UsersService', () => {
  describe('createUser()', () => {
    it('creates a user with valid data', async () => {
      const svc = new UsersService(makeRepo(), makeDispatcher());
      const res = await svc.createUser({ name: 'Alice', email: 'alice@example.com', password: 'Passw0rd!' });
      expect(res).toHaveProperty('email', 'alice@example.com');
      expect(res).not.toHaveProperty('passwordHash');
    });

    it('throws CONFLICT when email already taken', async () => {
      const repo = makeRepo({ findByEmail: jest.fn().mockResolvedValue({ id: 'x' }) });
      const svc  = new UsersService(repo, makeDispatcher());
      await expect(
        svc.createUser({ name: 'Bob', email: 'taken@example.com', password: 'Passw0rd!' })
      ).rejects.toMatchObject({ code: 'CONFLICT' });
    });

    it('throws VALIDATION with invalid email', async () => {
      const svc = new UsersService(makeRepo(), makeDispatcher());
      await expect(
        svc.createUser({ name: 'Eve', email: 'not-an-email', password: 'Passw0rd!' })
      ).rejects.toMatchObject({ code: 'VALIDATION' });
    });
  });
});
EOF

cat > "$ROOT/tests/integration/.gitkeep" << 'EOF'
EOF

cat > "$ROOT/tests/e2e/.gitkeep" << 'EOF'
EOF

