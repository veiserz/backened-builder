"use strict";

/**
 * Production-grade pino logger — Node.js / Express (CommonJS)
 *
 * Design decisions:
 *  - Logs to stdout only. Collection is external (Fluent Bit).
 *  - Structured JSON in production; pretty-printed in development.
 *  - Sensitive field redaction at the serializer layer (not caller responsibility).
 *  - Child loggers propagate context without mutation (request-scoped).
 *  - pino-http ships as optional middleware; can replace requestContextMiddleware.
 */

const pino = require("pino");
const pinoHttp = require("pino-http");
const { v4: uuidv4 } = require("uuid");

// ── Environment ───────────────────────────────────────────────────────────────

const NODE_ENV = process.env.NODE_ENV || "development";
const LOG_LEVEL =
  process.env.LOG_LEVEL || (NODE_ENV === "production" ? "info" : "debug");
const SERVICE_NAME = process.env.SERVICE_NAME || "api";
const SERVICE_VERSION = process.env.SERVICE_VERSION || "unknown";

const isProduction = NODE_ENV === "production";

// ── Redaction ─────────────────────────────────────────────────────────────────
// Redaction is zero-cost when keys are absent (pino uses fast-redact).
// Paths use dot-notation; wildcards match array/object children.
//
// RULE: redact at the logger level — callers should NEVER self-censor.
// This makes it safe to log `req.headers` or user objects directly.

const REDACTED_PATHS = [
  // Auth headers
  "req.headers.authorization",
  "req.headers.cookie",
  "req.headers['x-api-key']",
  "req.headers['x-auth-token']",

  // Request body sensitive fields
  "req.body.password",
  "req.body.passwordConfirmation",
  "req.body.currentPassword",
  "req.body.newPassword",
  "req.body.token",
  "req.body.refreshToken",
  "req.body.accessToken",
  "req.body.secret",
  "req.body.creditCard",
  "req.body.cardNumber",
  "req.body.cvv",
  "req.body.ssn",

  // Response sensitive headers
  "res.headers['set-cookie']",

  // Generic wildcard patterns — covers nested occurrences in any object
  "*.password",
  "*.token",
  "*.secret",
  "*.apiKey",
  "*.api_key",
  "*.privateKey",
  "*.private_key",
  "*.authorization",
];

// ── Serializers ───────────────────────────────────────────────────────────────
// Shape the req/res objects exactly as needed in Loki.
// Keeping this lean reduces log volume significantly.

const serializers = {
  req(req) {
    return {
      id: req.id || req.requestId,
      method: req.method,
      url: req.url,
      ip: req.ip || (req.socket && req.socket.remoteAddress),
      userAgent: req.headers && req.headers["user-agent"],
      contentType: req.headers && req.headers["content-type"],
    };
  },

  res(res) {
    return {
      statusCode: res.statusCode,
    };
  },

  // Serialize Error objects consistently.
  // Stack trace omitted in production to prevent info disclosure.
  err(err) {
    return {
      type: (err.constructor && err.constructor.name) || "Error",
      message: err.message,
      code: err.code,
      statusCode: err.statusCode || err.status,
      ...(isProduction ? {} : { stack: err.stack }),
    };
  },
};

// ── Base logger ───────────────────────────────────────────────────────────────

const loggerOptions = {
  level: LOG_LEVEL,

  // Static fields on every log line — low-cardinality, used as Loki label sources
  base: {
    service: SERVICE_NAME,
    version: SERVICE_VERSION,
    env: NODE_ENV,
    // pid is always 1 inside a container — omit to reduce noise
    // pid: process.pid,
  },

  // ISO-8601 timestamp — compatible with Loki's time parser
  timestamp: pino.stdTimeFunctions.isoTime,

  // Emit level as a human-readable string ("info", "warn", ...).
  // Fluent Bit extracts this field as the Loki "level" label.
  formatters: {
    level(label) {
      return { level: label };
    },
  },

  redact: {
    paths: REDACTED_PATHS,
    censor: "[REDACTED]",
  },

  serializers,

  // Development: pretty-print via pino-pretty (install as devDependency).
  // Production: raw JSON to stdout — collected externally by Fluent Bit.
  ...(isProduction
    ? {}
    : {
        transport: {
          target: "pino-pretty",
          options: {
            colorize: true,
            translateTime: "SYS:standard",
            ignore: "pid,hostname,service,version,env",
          },
        },
      }),
};

const logger = pino(loggerOptions);

// ── HTTP request logger middleware (optional) ─────────────────────────────────
// Drop-in replacement for requestContextMiddleware when you want pino-http's
// automatic access-log instrumentation.
//
// NOTE: Do NOT mount httpLogger alongside requestContextMiddleware —
// it will produce duplicate access log entries per request.
//
// Usage in app.js:
//   const { httpLogger } = require('../infrastructure/logger');
//   app.use(httpLogger);

const httpLogger = pinoHttp({
  logger,

  // Log level per response status
  customLogLevel(_req, res, err) {
    if (err || res.statusCode >= 500) return "error";
    if (res.statusCode >= 400) return "warn";
    return "info";
  },

  // Suppress high-frequency health / readiness probe noise
  autoLogging: {
    ignore(req) {
      const noisy = [
        "/health",
        "/healthz",
        "/ready",
        "/ping",
        "/metrics",
        "/favicon.ico",
      ];
      return noisy.some((p) => req.url && req.url.startsWith(p));
    },
  },

  // Access log message format
  customSuccessMessage(req, res) {
    return `${res.statusCode} ${req.method} ${req.url}`;
  },
  customErrorMessage(req, res, err) {
    return `${res.statusCode} ${req.method} ${req.url} — ${err.message}`;
  },

  // Emit responseTime for the SlowP95Latency alert rule in Loki
  customProps(_req, res) {
    return {
      responseTime: res.getHeader("x-response-time"),
    };
  },

  // Re-use existing X-Request-Id header or generate a new UUID
  genReqId(req) {
    return req.headers["x-request-id"] || uuidv4();
  },

  serializers: {
    req: serializers.req,
    res: serializers.res,
  },
});

// ── Child logger factory ───────────────────────────────────────────────────────
// Returns a bound child logger for a specific module/subsystem.
// Inherits all parent settings including redaction.
//
// Usage:
//   const log = createLogger("UserService");
//   log.info({ userId }, "user.created");

function createLogger(module, bindings) {
  return logger.child({ module, ...bindings });
}

// ── Request-scoped logger ─────────────────────────────────────────────────────
// Enriches req.log (set by pino-http) or falls back to the base logger,
// binding requestId and userId so every handler log line is correlated.
//
// Usage in a handler or service:
//   const log = getRequestLogger(req);
//   log.info({ orderId }, "order.created");

function getRequestLogger(req) {
  const base = req.log || logger;
  return base.child({
    requestId: req.headers["x-request-id"] || req.requestId || req.id,
    ...(req.user ? { userId: req.user.id } : {}),
  });
}

// ── Exports ───────────────────────────────────────────────────────────────────
// infrastructure/index.js spreads this module, so every key is available as a
// named export at the infrastructure level:
//   const { logger, createLogger, getRequestLogger } = require('../infrastructure');

module.exports = {
  logger,
  httpLogger,
  createLogger,
  getRequestLogger,
};

/**
 * ── Log Level Guidelines ───────────────────────────────────────────────────
 *
 *  fatal  — Unrecoverable; process will exit.
 *           logger.fatal({ err }, "database.pool.exhausted");
 *
 *  error  — Needs attention; process continues.
 *           logger.error({ err, userId }, "payment.failed");
 *
 *  warn   — Unexpected but handled; watch for patterns.
 *           logger.warn({ retries }, "external.api.retried");
 *
 *  info   — Normal operational events (domain lifecycle).
 *           logger.info({ orderId }, "order.shipped");
 *
 *  debug  — Detailed flow tracing. Disabled in production.
 *           logger.debug({ query, params }, "db.query.execute");
 *
 *  trace  — Extremely verbose; local development only.
 *           logger.trace({ payload }, "kafka.message.received");
 *
 * ── Structured Log Convention ─────────────────────────────────────────────
 *
 *  Always pass data as the FIRST argument (mergingObject), message SECOND:
 *    logger.info({ userId, orderId }, "order.created");   ✅
 *    logger.info(`Order ${orderId} created`);             ❌ (not filterable)
 *
 *  Use dot-namespaced event strings as the message:
 *    "user.created"  "order.payment.failed"  "cache.miss"
 *
 *  This makes logs directly filterable in LogQL without regex:
 *    {app="api"} | json | msg="order.created" | userId="abc"
 */
