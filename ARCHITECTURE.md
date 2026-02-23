# Architecture Documentation

> **Project:** `backend-builder` — Production-ready modular Node.js backend  
> **Runtime:** Node.js · **Framework:** Express 4  
> **Last updated:** 2026-02-22

---

## Table of Contents

1. [High-Level Overview](#1-high-level-overview)
2. [Folder Structure](#2-folder-structure)
3. [Layer Responsibilities](#3-layer-responsibilities)
4. [Request Lifecycle](#4-request-lifecycle)
5. [Dependency Injection Container](#5-dependency-injection-container)
6. [Module Anatomy](#6-module-anatomy)
7. [Infrastructure Services](#7-infrastructure-services)
8. [Error Handling](#8-error-handling)
9. [Event System](#9-event-system)
10. [Validation Strategy](#10-validation-strategy)
11. [Configuration & Environment](#11-configuration--environment)
12. [Security](#12-security)
13. [Technology Stack](#13-technology-stack)
14. [Adding a New Module](#14-adding-a-new-module)

---

## 1. High-Level Overview

The project follows a **layered, modular architecture** with clear boundaries between HTTP concerns, application logic, domain rules, and infrastructure. Each feature lives in its own isolated module under `src/modules/`, following the same internal structure.

```
┌──────────────────────────────────────────────────────────────┐
│                        HTTP Layer                            │
│   (Express · Helmet · CORS · Rate Limit · Request Context)   │
└────────────────────────┬─────────────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────────────┐
│                    Application Layer                         │
│      (DI Container · Dispatcher · Config · Policies)         │
└────────────────────────┬─────────────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────────────┐
│                      Module Layer                            │
│   Router → Controller → Service → Repository → Model/Entity  │
└────────────────────────┬─────────────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────────────┐
│                  Infrastructure Layer                        │
│      PostgreSQL · Redis · Bull Queue · EventBus · Logger     │
└──────────────────────────────────────────────────────────────┘
```

**Key design principles:**

- **Dependency flows downward only** — upper layers depend on lower layers, never the reverse.
- **No framework leakage** — `req`/`res` objects never reach Service or Repository classes.
- **Ports & Adapters** — Infrastructure implementations are swappable without touching business logic.
- **Fail-fast at startup** — environment, database, and Redis are validated before the HTTP server starts.

---

## 2. Folder Structure

```
src/
├── bootstrap/          # Application wiring & startup sequence
│   ├── server.js       # Entry point — env → DB → Redis → Container → HTTP
│   ├── app.js          # Express app factory (middlewares, routes, error handler)
│   └── router.js       # API version router (/api/v1/*)
│
├── app/                # Application-level orchestration
│   ├── index.js
│   ├── config/
│   │   ├── features.js # Feature flags (env-driven)
│   │   ├── policies.js # Authorisation policy functions
│   │   └── index.js
│   ├── container/
│   │   ├── index.js    # DI Container class + singleton instance
│   │   └── providers.js# Registers all bindings (infra → repos → services)
│   └── dispatch/
│       └── index.js    # Dispatcher class + domain event handlers
│
├── http/               # HTTP-specific cross-cutting concerns
│   ├── middlewares/
│   │   ├── auth.js         # JWT Bearer token validation → req.auth
│   │   ├── rateLimit.js    # express-rate-limit configuration
│   │   ├── requestContext.js # UUID per request, response time logging
│   │   ├── BaseMiddleware.js # Base class for module-level middleware
│   │   └── index.js
│   ├── errors/
│   │   ├── httpError.js    # HttpError class (status + message + details)
│   │   ├── mapper.js       # DomainError → HttpError translation
│   │   └── index.js        # errorHandler middleware (Express 4-arg)
│   └── response/
│       └── index.js        # ok / created / noContent / paginated / fail helpers
│
├── infrastructure/     # External system adapters
│   ├── env.js          # Zod-based environment schema validation
│   ├── logger.js       # Winston logger (JSON in prod, coloured in dev)
│   ├── index.js        # Re-exports all infrastructure
│   ├── cache/redis/
│   │   ├── connection.js   # connectRedis / disconnectRedis / getRedis
│   │   ├── client.js       # High-level typed Redis helpers
│   │   └── index.js
│   ├── database/postgresql/
│   │   ├── connection.js   # connectPostgres / getPool (pg.Pool)
│   │   ├── db.js           # db.query / db.transaction helpers
│   │   ├── index.js
│   │   └── migrations/     # Raw SQL migration files
│   ├── eventbus/
│   │   ├── bus.js          # EventBus (EventEmitter wrapper)
│   │   └── index.js
│   └── queue/
│       ├── client.js       # Bull queue factory / registry
│       ├── producer.js     # enqueue(name, data, opts)
│       ├── consumer.js     # consume(name, processor, opts)
│       └── index.js
│
├── modules/            # Feature modules (vertical slices)
│   └── store/          # Example module — each follows identical structure
│       ├── index.js
│       ├── router/         # Express routes + DTO validation middleware
│       ├── controller/     # HTTP handlers (req → service → response helper)
│       ├── DTO/            # TypeBox schemas for body / params / query
│       ├── middleware/     # Module-scoped middleware (BaseMiddleware subclass)
│       ├── service/        # Business logic (orchestrates repo + dispatcher)
│       ├── repository/     # SQL queries; returns domain entities
│       └── models/         # Domain entity class
│
└── shared/             # Framework-agnostic utilities
    ├── errors/
    │   └── domainError.js  # DomainError base class + static factories
    ├── utils/
    │   ├── id.js           # generateId (UUID v4) / isValidId
    │   └── time.js         # now() → current Date
    └── validation/
        └── validate.js     # Zod-based validate() throwing DomainError
```

---

## 3. Layer Responsibilities

### 3.1 Bootstrap (`src/bootstrap/`)

| File        | Responsibility                                                                                                                                                             |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `server.js` | Ordered startup: validate env → connect PostgreSQL → connect Redis → boot DI container → create Express app → listen. Registers SIGTERM/SIGINT graceful-shutdown handlers. |
| `app.js`    | Pure Express factory (`createApp()`). Attaches global middleware stack, mounts the versioned API router, and registers the global error handler last.                      |
| `router.js` | Maps URL prefixes (`/api/v1/*`) to module routers.                                                                                                                         |

**Startup sequence:**

```
node src/bootstrap/server.js
  │
  ├─ validateEnv()          ← Zod schema; exits with clear message on failure
  ├─ connectPostgres()      ← acquires pool + smoke-test connection
  ├─ connectRedis()         ← ioredis + PING verification
  ├─ bootContainer()        ← registers + verifies all DI singletons
  └─ app.listen(PORT)       ← HTTP server up
```

---

### 3.2 Application Layer (`src/app/`)

#### DI Container (`container/index.js`)

A minimal synchronous IoC container with three binding scopes:

| Method                                | Scope     | Behaviour                             |
| ------------------------------------- | --------- | ------------------------------------- |
| `container.instance(token, value)`    | Singleton | Registers a pre-built value           |
| `container.singleton(token, factory)` | Singleton | Constructed once on first `resolve()` |
| `container.register(token, factory)`  | Transient | New instance on every `resolve()`     |

`container.verify()` resolves all singletons at boot so misconfigured bindings surface before the first request.

#### Providers (`container/providers.js`)

Wires the entire dependency graph in a single file, in order:

```
Infrastructure (db, redis, logger, bus)
  └─ Dispatcher (wraps bus + registers domain event handlers)
       └─ Repositories (receive db)
            └─ Services (receive repository + dispatcher)
                 └─ Controllers (resolve service lazily via container.resolve())
```

#### Dispatcher (`dispatch/index.js`)

Bridges in-process domain events to the infrastructure EventBus:

```
dispatcher.dispatch('store.created', payload)
  ├─ Runs all registered in-process handlers (Promise.all)
  └─ Calls bus.publish(event, payload)  ← EventBus / external broker
```

---

### 3.3 HTTP Layer (`src/http/`)

#### Global Middleware Stack (in order)

```
helmet()              ← Security headers
cors()                ← Cross-origin policy
compression()         ← gzip response bodies
express.json()        ← Body parsing (limit: 1 MB)
requestContextMiddleware ← UUID per request, response-time logging
rateLimitMiddleware   ← 100 req / 15 min per IP (configurable)
router                ← /api/v1/* — module routes
errorHandler          ← 4-argument Express error handler (MUST be last)
```

#### Response Helpers (`http/response/index.js`)

All HTTP responses use a normalised envelope:

```json
{ "success": true,  "data": { ... }, "meta": { ... } }
{ "success": false, "error": { "message": "...", "details": [...] } }
```

| Helper                                        | Status | Use case                            |
| --------------------------------------------- | ------ | ----------------------------------- |
| `ok(res, data, meta)`                         | 200    | Single resource or generic success  |
| `created(res, data)`                          | 201    | Resource created                    |
| `noContent(res)`                              | 204    | Successful delete                   |
| `paginated(res, {items, total, page, limit})` | 200    | List endpoints with pagination meta |
| `fail(res, status, message, details)`         | any    | Manual error responses              |

---

### 3.4 Module Layer (`src/modules/<name>/`)

Each module is a vertical slice. See [Module Anatomy](#6-module-anatomy) for the full breakdown.

---

### 3.5 Infrastructure Layer (`src/infrastructure/`)

Thin adapters over external systems. No business logic here. See [Infrastructure Services](#7-infrastructure-services).

---

### 3.6 Shared Layer (`src/shared/`)

Pure utility code with **zero dependencies on Express or any module**. Safe to import from any layer.

---

## 4. Request Lifecycle

```
Client
  │
  ▼
rateLimitMiddleware          ← 429 if window exceeded
  │
  ▼
requestContextMiddleware     ← attaches req.requestId, logs on finish
  │
  ▼
[Module Router]
  │
  ├─ validate(DTO, 'body')   ← TypeBox schema check; 422 on failure
  ├─ authMiddleware          ← JWT verify; sets req.auth; 401 on failure
  │
  ▼
Controller function(req, res, next)
  │  reads req.body / req.params / req.query
  │  calls Service method
  │
  ▼
Service
  │  business logic only (no req/res)
  │  calls Repository
  │  calls dispatcher.dispatch(event, payload)
  │
  ▼
Repository
  │  issues SQL via db.query / db.transaction
  │  returns domain Entity instances
  │
  ▼
PostgreSQL / Redis
  │
  ▼ (response path)
entity.toResponse()          ← safe serialisation (no internals/passwords)
  │
response helper (ok / created / paginated / noContent)
  │
  ▼
Client ← JSON envelope { success, data, meta }


── Error path ─────────────────────────────────────────────────
Any layer throws DomainError / HttpError / Error
  │
next(err)
  │
errorHandler
  │
mapToHttpError()             ← DomainError.code → HTTP status
  │
res.status(N).json({ success: false, error: { message, details } })
```

---

## 5. Dependency Injection Container

### Token Naming Convention

| Token                | Type                                       |
| -------------------- | ------------------------------------------ |
| `"db"`               | `db` object (`db.query`, `db.transaction`) |
| `"redisClient"`      | `redisClient` object                       |
| `"logger"`           | Winston logger                             |
| `"bus"`              | EventBus instance                          |
| `"dispatcher"`       | Dispatcher instance                        |
| `"<name>Repository"` | Repository class instance                  |
| `"<name>Service"`    | Service class instance                     |

### Resolving from a Controller

Controllers **never import the service directly** to avoid circular-dependency issues. Instead they resolve lazily:

```js
// store.controller.js
const { container } = require("../../../app/container");

function getService() {
  return container.resolve("storeService"); // singleton — no overhead
}
```

---

## 6. Module Anatomy

Every feature module under `src/modules/<name>/` follows the same internal layout:

```
<name>/
├── index.js              ← Public API: re-exports router (and optionally service/repo)
├── router/
│   └── index.js          ← Express Router; stacks DTO validation + auth + controller
├── controller/
│   └── <name>.controller.js  ← Maps HTTP verbs to service calls; uses response helpers
├── DTO/
│   ├── create.dto.js     ← TypeBox schema for POST body
│   ├── update.dto.js     ← TypeBox schema for PATCH body
│   ├── param.dto.js      ← TypeBox schema for URL params (e.g. { id: UUID })
│   ├── query.dto.js      ← TypeBox schema for query string (pagination, filters)
│   ├── validate.js       ← validate(schema, source) Express middleware factory
│   └── index.js
├── middleware/
│   └── <name>.middleware.js  ← Extends BaseMiddleware; module-scoped guards
├── service/
│   └── <name>.service.js    ← Business logic; orchestrates repo + dispatcher
├── repository/
│   ├── queries.js        ← Named SQL query strings (QUERIES constant)
│   └── <name>.repository.js ← Issues queries; maps rows → domain entities
└── models/
    └── <name>.model.js   ← Domain entity: constructor, fromRecord(), toRecord(), toResponse(), applyUpdate()
```

### Data flow within a module

```
Router
  validate(CreateDto, 'body')   ← coerces + validates req.body
  authMiddleware                ← populates req.auth
  │
Controller
  req.body / req.params → service.create(dto)
  └─ response helper(res, result)
     │
Service
  new Entity(dto)               ← domain model construction
  await repo.create(entity)     ← persistence
  await dispatcher.dispatch(…)  ← domain event
  return entity.toResponse()
     │
Repository
  entity.toRecord()             ← snake_case for SQL
  db.query(QUERIES.CREATE, [...params])
  return Entity.fromRecord(row) ← hydrate from DB row
```

### Domain Entity Contract

Each entity class must implement:

| Method                           | Description                                                            |
| -------------------------------- | ---------------------------------------------------------------------- |
| `constructor({ id, ...fields })` | Builds entity; generates `id` (UUID) if absent                         |
| `static fromRecord(row)`         | Hydrates from a PostgreSQL row (snake_case → camelCase)                |
| `toRecord()`                     | Converts to a persist-ready plain object (camelCase → snake_case)      |
| `toResponse()`                   | Safe public serialisation — strips sensitive fields, ISO-formats dates |
| `applyUpdate(dto)`               | Mutates entity fields in place; updates `updatedAt`                    |

---

## 7. Infrastructure Services

### 7.1 PostgreSQL (`infrastructure/database/postgresql/`)

| Export                     | Description                                                       |
| -------------------------- | ----------------------------------------------------------------- |
| `connectPostgres()`        | Creates `pg.Pool`, verifies with a test `connect()`, logs success |
| `getPool()`                | Returns pool or throws if not initialised                         |
| `db.query(sql, params)`    | Wrapper over `pool.query()`; returns full `pg.Result`             |
| `db.transaction(async cb)` | Acquires client, `BEGIN`/`COMMIT`/`ROLLBACK`, releases client     |

**Connection config** (all via env):

| Variable      | Default |
| ------------- | ------- |
| `DB_HOST`     | —       |
| `DB_PORT`     | `5432`  |
| `DB_NAME`     | —       |
| `DB_USER`     | —       |
| `DB_PASSWORD` | —       |
| `DB_POOL_MAX` | `10`    |

---

### 7.2 Redis (`infrastructure/cache/redis/`)

| Export              | Description                                                              |
| ------------------- | ------------------------------------------------------------------------ |
| `connectRedis()`    | Creates `ioredis` instance, connects, attaches error/reconnect listeners |
| `disconnectRedis()` | Graceful `QUIT`; safe to call if not connected                           |
| `getRedis()`        | Returns raw ioredis instance                                             |
| `redisClient`       | High-level typed helpers (see below)                                     |

**`redisClient` API:**

| Category    | Methods                                                                                                                      |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------- |
| String      | `get(key)`, `set(key, value, ttl?)`, `del(keys)`, `exists(key)`, `expire(key, ttl)`, `ttl(key)`, `mget(keys[])`, `mset(map)` |
| Counter     | `incr(key)`, `incrby(key, n)`, `decr(key)`, `decrby(key, n)`                                                                 |
| Hash        | `hget(key, field)`, `hset(key, field, value)`, `hdel(key, ...fields)`, `hgetall(key)`, `hincrby(key, field, n)`              |
| Maintenance | `flush()` — disabled in production                                                                                           |

All values are automatically `JSON.stringify`/`JSON.parse`d.

**Connection config:**

| Variable         | Default     |
| ---------------- | ----------- |
| `REDIS_HOST`     | `localhost` |
| `REDIS_PORT`     | `6379`      |
| `REDIS_DB`       | `0`         |
| `REDIS_PASSWORD` | —           |

---

### 7.3 Bull Queue (`infrastructure/queue/`)

| Export                            | Description                                                           |
| --------------------------------- | --------------------------------------------------------------------- |
| `getQueue(name)`                  | Lazy-creates and caches a Bull queue; attaches error/failed listeners |
| `enqueue(name, data, opts?)`      | Adds a job with 3 exponential-backoff retries                         |
| `consume(name, processor, opts?)` | Registers a Bull `process()` handler with configurable concurrency    |

**Default job options** (overridable via `opts`):

```js
{
  attempts:  3,
  backoff:   { type: 'exponential', delay: 2000 },
  removeOnComplete: 100,
  removeOnFail:     200,
}
```

---

### 7.4 EventBus (`infrastructure/eventbus/`)

An in-process `EventEmitter` wrapper. `publish(event, payload)` calls `this.emit(event, payload)`, making it trivially replaceable with an external broker (Redis Pub/Sub, RabbitMQ) by changing only this file.

```js
// Subscribe directly
bus.subscribe("store.created", handler);

// Publish (called internally by Dispatcher)
await bus.publish("store.created", payload);
```

---

### 7.5 Logger (`infrastructure/logger.js`)

Winston logger with environment-aware transport:

| Environment   | Format               | Transports                                       |
| ------------- | -------------------- | ------------------------------------------------ |
| `development` | Coloured simple text | Console                                          |
| `production`  | JSON + timestamps    | Console + `logs/error.log` + `logs/combined.log` |

Log level is controlled by `LOG_LEVEL` env var (default: `info`).

---

## 8. Error Handling

### Error Hierarchy

```
Error (built-in)
├── DomainError               src/shared/errors/domainError.js
│     .code: NOT_FOUND | FORBIDDEN | CONFLICT | VALIDATION | UNAUTHORISED
│     .meta: any              (field details, resource info, etc.)
│     Static factories:
│       DomainError.notFound(msg, meta)
│       DomainError.conflict(msg, meta)
│       DomainError.forbidden(msg, meta)
│       DomainError.validation(msg, details)
│       DomainError.unauthorised(msg, meta)
│
└── HttpError                 src/http/errors/httpError.js
      .status: number
      .message: string
      .details: any
```

### Mapping Table (`mapToHttpError`)

| DomainError code       | HTTP status |
| ---------------------- | ----------- |
| `NOT_FOUND`            | 404         |
| `FORBIDDEN`            | 403         |
| `CONFLICT`             | 409         |
| `VALIDATION`           | 422         |
| `UNAUTHORISED`         | 401         |
| other domain codes     | 400         |
| unknown / infra errors | 500         |

### Error Response Shape

```json
{
  "success": false,
  "error": {
    "message": "Validation failed",
    "details": [
      {
        "field": "name",
        "message": "String must contain at least 1 character(s)"
      }
    ]
  }
}
```

Stack traces are included in error responses **only** in non-production environments for 5xx errors.

---

## 9. Event System

The project has two layers of eventing:

### 9.1 Dispatcher (Application Layer)

- Lives in `src/app/dispatch/index.js`
- Registered in the DI container as `"dispatcher"`
- Handlers are registered in `dispatch/handlers.js` at boot

```js
dispatcher.on("store.created", async (payload) => {
  /* e.g. send email */
});
await dispatcher.dispatch("store.created", { id, name });
// Runs all handlers in-process AND calls bus.publish()
```

### 9.2 EventBus (Infrastructure Layer)

- Lives in `src/infrastructure/eventbus/bus.js`
- Node.js `EventEmitter` — currently in-process
- `publish()` is designed to be the single replacement point for an external broker

### Adding a New Event Handler

1. Open `src/app/dispatch/index.js`
2. Add inside `registerHandlers(dispatcher)`:

```js
dispatcher.on("order.placed", async (payload) => {
  // send confirmation, update inventory, etc.
});
```

---

## 10. Validation Strategy

Two validation libraries are used for different purposes:

| Location               | Library                           | Trigger                                      |
| ---------------------- | --------------------------------- | -------------------------------------------- | -------- | -------------------- |
| HTTP boundary (router) | **TypeBox** (`@sinclair/typebox`) | `validate(Schema, 'body'                     | 'params' | 'query')` middleware |
| Service / shared layer | **Zod**                           | `validate(zodSchema, data)` utility function |
| Environment variables  | **Zod**                           | `validateEnv()` at startup                   |

### TypeBox Middleware (`modules/<name>/DTO/validate.js`)

```js
// Router usage
router.post("/", validate(CreateStoreDto, "body"), ctrl.create);

// Behaviour:
// 1. Check req[source] against schema
// 2. On failure → next(DomainError.validation('Validation failed', details))
// 3. On success → coerce/default values via Value.Cast, mutate req[source]
```

### Zod Utility (`shared/validation/validate.js`)

```js
// Service / use-case usage
const parsed = validate(myZodSchema, rawData);
// Throws DomainError.validation(...) on failure
```

---

## 11. Configuration & Environment

### Required Variables

| Variable      | Description                             |
| ------------- | --------------------------------------- |
| `NODE_ENV`    | `development` \| `test` \| `production` |
| `PORT`        | HTTP listen port (default `3000`)       |
| `DB_HOST`     | PostgreSQL host                         |
| `DB_PORT`     | PostgreSQL port (default `5432`)        |
| `DB_NAME`     | Database name                           |
| `DB_USER`     | Database user                           |
| `DB_PASSWORD` | Database password                       |
| `REDIS_HOST`  | Redis host                              |
| `REDIS_PORT`  | Redis port (default `6379`)             |
| `JWT_SECRET`  | ≥ 12-character secret for JWT signing   |

### Optional Variables

| Variable                     | Default  | Description                     |
| ---------------------------- | -------- | ------------------------------- |
| `DB_POOL_MAX`                | `10`     | Max PostgreSQL pool connections |
| `REDIS_PASSWORD`             | —        | Redis AUTH password             |
| `REDIS_DB`                   | `0`      | Redis logical database index    |
| `JWT_EXPIRES_IN`             | `1d`     | JWT expiry                      |
| `RATE_LIMIT_WINDOW_MS`       | `900000` | Rate-limit window (ms)          |
| `RATE_LIMIT_MAX`             | `100`    | Max requests per window per IP  |
| `LOG_LEVEL`                  | `info`   | Winston log level               |
| `FEATURE_EMAIL_VERIFICATION` | `false`  | Enable email verification flow  |
| `FEATURE_RATE_LIMITING`      | `true`   | Toggle rate limiting            |
| `FEATURE_AUDIT_LOG`          | `false`  | Enable audit logging            |

### Feature Flags (`src/app/config/features.js`)

Feature flags are read at startup from environment variables — no deployment required to toggle them:

```js
const { features } = require("./app/config");
if (features.emailVerification) {
  /* ... */
}
```

### Authorization Policies (`src/app/config/policies.js`)

Policy functions receive `(authPayload, resource)` and return a boolean:

```js
const { can } = require("./app/config");
if (!can(req.auth, "users:write")) throw DomainError.forbidden();
```

---

## 12. Security

| Concern          | Mechanism                                                                        |
| ---------------- | -------------------------------------------------------------------------------- |
| Security headers | `helmet` middleware                                                              |
| CORS             | `cors` middleware                                                                |
| Authentication   | JWT Bearer token — `authMiddleware` validates and attaches `req.auth`            |
| Authorisation    | Policy functions in `app/config/policies.js`                                     |
| Rate limiting    | `express-rate-limit` — 100 req / 15 min per IP by default                        |
| Input validation | TypeBox at HTTP boundary; Zod for env; DomainError on failure                    |
| Body size limit  | `express.json({ limit: '1mb' })`                                                 |
| Env validation   | Zod schema at startup — application refuses to start with missing/invalid config |
| Password hashing | `bcryptjs` (available as dependency)                                             |

---

## 13. Technology Stack

| Category                        | Package              | Version  |
| ------------------------------- | -------------------- | -------- |
| HTTP framework                  | `express`            | ^4.18    |
| Security headers                | `helmet`             | ^7.1     |
| CORS                            | `cors`               | ^2.8     |
| Compression                     | `compression`        | ^1.7     |
| Rate limiting                   | `express-rate-limit` | ^7.1     |
| Authentication                  | `jsonwebtoken`       | ^9.0     |
| Password hashing                | `bcryptjs`           | ^2.4     |
| PostgreSQL                      | `pg`                 | ^8.11    |
| Redis                           | `ioredis`            | ^5.3     |
| Job queue                       | `bull`               | ^4.12    |
| Schema validation (HTTP)        | `@sinclair/typebox`  | ^0.32    |
| Schema validation (env/service) | `zod`                | ^3.22    |
| Logging                         | `winston`            | ^3.11    |
| ID generation                   | `uuid`               | ^9.0     |
| Environment loading             | `dotenv`             | ^16.4    |
| Testing                         | `jest` + `supertest` | ^29 / ^6 |
| Dev server                      | `nodemon`            | ^3.0     |

---

## 14. Adding a New Module

Run the scaffold script:

```bash
./module.sh <name>
```

This generates the full module skeleton. Then:

**1. Register in the DI container** (`src/app/container/providers.js`):

```js
// Import
const { FooRepository } = require("../../modules/foo/repository");
const { FooService } = require("../../modules/foo/service");

// Inside register(container):
container.singleton("fooRepository", (c) => new FooRepository(c.resolve("db")));
container.singleton(
  "fooService",
  (c) => new FooService(c.resolve("fooRepository"), c.resolve("dispatcher")),
);
```

**2. Mount the router** (`src/bootstrap/router.js`):

```js
const { fooRoutes } = require("../modules/foo");
router.use("/v1/foo", fooRoutes);
```

**3. Create the migration** (`src/infrastructure/database/postgresql/migrations/`):

```sql
-- 002_create_foo.sql
CREATE TABLE IF NOT EXISTS foo (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name       VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**4. Register domain event handlers** (`src/app/dispatch/index.js`):

```js
dispatcher.on("foo.created", async (payload) => {
  /* ... */
});
```
