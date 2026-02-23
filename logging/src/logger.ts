/**
 * Production-grade pino logger for Node.js (TypeScript / Express)
 *
 * Design decisions:
 *  - Logs to stdout only. Collection is external (Fluent Bit).
 *  - Structured JSON in production; pretty-printed in development.
 *  - Sensitive field redaction at the serializer layer (not caller responsibility).
 *  - Child loggers propagate context without mutation (request-scoped).
 *  - pino-http auto-instruments Express requests (access log + timing).
 */

import pino, { type Logger, type LoggerOptions } from "pino";
import pinoHttp, { type Options as PinoHttpOptions } from "pino-http";
import type { Request, Response } from "express";

// ── Environment ───────────────────────────────────────────────────────────────

const NODE_ENV = process.env.NODE_ENV ?? "development";
const LOG_LEVEL = process.env.LOG_LEVEL ?? (NODE_ENV === "production" ? "info" : "debug");
const SERVICE_NAME = process.env.SERVICE_NAME ?? "api";
const SERVICE_VERSION = process.env.SERVICE_VERSION ?? "unknown";

const isProduction = NODE_ENV === "production";

// ── Redaction ─────────────────────────────────────────────────────────────────
// Redaction is zero-cost when keys are absent (pino uses fast-redact).
// Paths use dot-notation; wildcards match array/object children.
//
// RULE: redact at the logger level — callers should NEVER self-censor.
// This makes it safe to log `req.headers` or user objects directly.

const REDACTED_PATHS: string[] = [
    // Auth headers
    "req.headers.authorization",
    "req.headers.cookie",
    "req.headers['x-api-key']",
    "req.headers['x-auth-token']",

    // Request body sensitive fields (adjust to your domain)
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

    // Response body (if you ever serialize it — avoid logging response bodies)
    "res.headers['set-cookie']",

    // Generic patterns — covers nested occurrences
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
// Shape the req/res fields exactly as you want them in Loki.
// Keeping this lean reduces log volume significantly.

const serializers: LoggerOptions["serializers"] = {
    req(req: Request) {
        return {
            id: req.id,                      // pino-http assigns this
            method: req.method,
            url: req.url,
            // Omit full query string if it can contain tokens (?token=...)
            // path: req.path,
            ip: req.ip ?? req.socket?.remoteAddress,
            userAgent: req.headers["user-agent"],
            // Only include content-type, not full headers (reduces volume)
            contentType: req.headers["content-type"],
        };
    },

    res(res: Response) {
        return {
            statusCode: res.statusCode,
        };
    },

    // Serialize errors consistently — always include stack in non-production
    err(err: Error & { code?: string; statusCode?: number }) {
        return {
            type: err.constructor?.name ?? "Error",
            message: err.message,
            code: err.code,
            statusCode: err.statusCode,
            // Only include stack trace in non-production (avoid info disclosure)
            ...(isProduction ? {} : { stack: err.stack }),
        };
    },
};

// ── Base logger ───────────────────────────────────────────────────────────────

const loggerOptions: LoggerOptions = {
    level: LOG_LEVEL,

    // Static fields on every log line — used as Loki label candidates
    base: {
        service: SERVICE_NAME,
        version: SERVICE_VERSION,
        env: NODE_ENV,
        // pid is noisy in containers (always 1); omit unless debugging
        // pid: process.pid,
    },

    // ISO timestamp: compatible with Loki's time_key parser
    timestamp: pino.stdTimeFunctions.isoTime,

    // Format pino numeric level to string ("info", "warn", etc.)
    // Fluent Bit extracts this as the Loki "level" label
    formatters: {
        level(label: string) {
            return { level: label };
        },
        // Uncomment to add hostname to each log line:
        // bindings(bindings) {
        //   return { host: bindings.hostname, pid: bindings.pid };
        // },
    },

    redact: {
        paths: REDACTED_PATHS,
        censor: "[REDACTED]",
    },

    serializers,

    // In development: pretty-print to stderr via pino-pretty subprocess
    // In production: raw JSON to stdout (collected by Fluent Bit)
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

export const logger: Logger = pino(loggerOptions);

// ── HTTP request logger middleware ────────────────────────────────────────────
// Auto-logs every request on completion (not on start = no duplicate lines).
// Skips health-check and readiness paths to reduce noise.

export const httpLogger = pinoHttp({
    logger,
    // Use "info" for successful requests, "warn" for 4xx, "error" for 5xx
    customLogLevel(_req: Request, res: Response, err?: Error) {
        if (err || res.statusCode >= 500) return "error";
        if (res.statusCode >= 400) return "warn";
        return "info";
    },

    // Skip logging for health probes and metrics — these are high-frequency noise
    autoLogging: {
        ignore(req: Request) {
            const noisy = ["/health", "/healthz", "/ready", "/ping", "/metrics", "/favicon.ico"];
            return noisy.some((path) => req.url?.startsWith(path));
        },
    },

    // Custom message format for access logs
    customSuccessMessage(_req: Request, res: Response) {
        return `${res.statusCode} ${(_req as Request).method} ${(_req as Request).url}`;
    },
    customErrorMessage(_req: Request, res: Response, err: Error) {
        return `${res.statusCode} ${(_req as Request).method} ${(_req as Request).url} — ${err.message}`;
    },

    // Emit response time in milliseconds (used by SlowP95Latency alert rule)
    customProps(_req: Request, res: Response) {
        return {
            responseTime: res.getHeader("x-response-time"),
        };
    },

    // Assign a unique request ID — propagate as X-Request-Id header
    genReqId(req: Request) {
        const existing = req.headers["x-request-id"] as string | undefined;
        return existing ?? crypto.randomUUID();
    },

    // Shape the request object logged (mirrors serializers.req above)
    serializers: {
        req: serializers.req!,
        res: serializers.res!,
    },
} satisfies PinoHttpOptions);

// ── Child logger factory ───────────────────────────────────────────────────────
// Create a bound child logger for a specific module/subsystem.
// Child loggers inherit all parent settings including redaction.
//
// Usage:
//   const log = createLogger("UserService");
//   log.info({ userId }, "user.created");

export function createLogger(module: string, bindings?: Record<string, unknown>): Logger {
    return logger.child({ module, ...bindings });
}

// ── Request-scoped logger ─────────────────────────────────────────────────────
// Attach to req in a middleware so all logs within a request share the same
// requestId, userId, etc. without passing the logger explicitly.
//
// Usage in middleware:
//   req.log = getRequestLogger(req);
//   req.log.info("doing something in handler");

export function getRequestLogger(req: Request & { log?: Logger }): Logger {
    // pino-http already attaches req.log; enrich it with app-level context
    const base = req.log ?? logger;
    return base.child({
        requestId: req.headers["x-request-id"] ?? req.id,
        // Only include userId if present — never log undefined/null
        ...(req.user ? { userId: (req.user as { id: string }).id } : {}),
    });
}

/**
 * ── Log Level Guidelines ───────────────────────────────────────────────────
 *
 *  fatal  — Unrecoverable error. Process will exit.
 *           log.fatal({ err }, "database connection pool exhausted");
 *
 *  error  — Error that needs attention but process continues.
 *           log.error({ err, userId }, "failed to process payment");
 *
 *  warn   — Something unexpected but handled. Watch for patterns.
 *           log.warn({ retries }, "external API retried successfully");
 *
 *  info   — Normal operational events (domain events, lifecycle hooks).
 *           log.info({ orderId }, "order.shipped");
 *
 *  debug  — Detailed flow tracing. Disabled in production (LOG_LEVEL=info).
 *           log.debug({ query, params }, "db.query.execute");
 *
 *  trace  — Extremely verbose. Use only during local development.
 *           log.trace({ payload }, "raw.kafka.message.received");
 *
 * ── Structured Log Message Convention ────────────────────────────────────
 *
 *  Always use dot-namespaced action strings as the `msg`:
 *    "user.created", "order.payment.failed", "cache.miss"
 *
 *  Put all variable data in the first argument (mergingObject):
 *    log.info({ userId, orderId, amount }, "order.created");  ✅
 *    log.info(`Order ${orderId} created for user ${userId}`); ❌
 *
 *  This makes logs filterable in LogQL without regex:
 *    {app="api"} | json | msg="order.created" | userId="abc"
 */
