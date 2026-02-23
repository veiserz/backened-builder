"use strict";

const { getPool } = require("./connection");
const { logger } = require("../../logger");
const { env } = require("../../env");

// ─── Security Patterns ───────────────────────────────────────────────────────
const BLOCKED_PATTERNS = [
  {
    name: "file read/write",
    re:   /\b(pg_read_file|pg_write_file|lo_import|lo_export)\s*\(/i,
  },
  {
    name: "time-based DoS",
    re:   /\bpg_sleep\s*\(|WAITFOR\s+DELAY\b/i,
  },
  {
    name: "system credentials access",
    re:   /\b(pg_shadow|pg_authid|pg_hba_file_rules)\b/i,
  },
  {
    name: "OS command execution",
    re:   /\bcopy\s+\S+\s+(to|from)\s+(program|'\/|"\/)/i,
  },
];
const WARN_PATTERNS = [
  {
    name: "DDL after semicolon",
    re:   /;\s*(DROP|TRUNCATE|ALTER|CREATE|REPLACE|RENAME)\b/i,
  },
  {
    name: "stacked DML",
    re:   /;\s*(INSERT|UPDATE|DELETE|MERGE)\b/i,
  },
  {
    name: "UNION-based injection",
    re:   /\bUNION\s+(ALL\s+)?SELECT\b/i,
  },
  {
    name: "SQL comment injection",
    re:   /--[^\n]|\/\*[\s\S]*?\*\//,
  },
  {
    name: "COPY file access",
    re:   /\bCOPY\s+\S+\s+(TO|FROM)\s+'/i,
  },
  {
    name: "dynamic PL/pgSQL block",
    re:   /\bDO\s+\$\$/i,
  },
  {
    name: "privilege manipulation",
    re:   /\b(GRANT|REVOKE)\s+(ALL|SELECT|INSERT|UPDATE|DELETE|EXECUTE)\b/i,
  },
  {
    name: "role/session change",
    re:   /\bSET\s+(ROLE|SESSION\s+AUTHORIZATION)\b/i,
  },
  {
    name: "information schema probe",
    re:   /\b(information_schema|pg_catalog)\s*\.\s*(tables|columns|users|roles)\b/i,
  },
];

// ─── Helpers ─────────────────────────────────────────────────────────────────
function validateQuery(sql, params) {
  if (typeof sql !== "string" || sql.trim().length === 0) {
    throw new TypeError("db: sql must be a non-empty string");
  }
  if (sql.length > env.DB_MAX_QUERY_LENGTH) {
    throw new RangeError(`db: sql exceeds max length (${env.DB_MAX_QUERY_LENGTH})`);
  }
  if (!Array.isArray(params)) {
    throw new TypeError("db: params must be an array");
  }
  if (params.length > env.DB_MAX_PARAMS_COUNT) {
    throw new RangeError(`db: too many params (${params.length} > ${env.DB_MAX_PARAMS_COUNT})`);
  }

  // بررسی الگوهای خطرناک → throw
  for (const { name, re } of BLOCKED_PATTERNS) {
    if (re.test(sql)) {
      logger.error("db: blocked query – dangerous pattern detected", {
        pattern: name,
        sql: sql.substring(0, 150),
      });
      throw new Error(`db: query blocked due to dangerous pattern: ${name}`);
    }
  }

  // بررسی الگوهای مشکوک → فقط warn
  for (const { name, re } of WARN_PATTERNS) {
    if (re.test(sql)) {
      logger.warn("db: suspicious SQL pattern detected", {
        pattern: name,
        sql: sql.substring(0, 150),
      });
    }
  }
}
function safeLogMeta(sql, err) {
  return {
    sql: sql.substring(0, 150),
    errCode: err?.code,
    errMsg: err?.message,
  };
}

// ─── db ──────────────────────────────────────────────────────────────────────
const db = {
  async query(sql, params = []) {
    validateQuery(sql, params);

    const pool = getPool();
    const client = await pool.connect();
    const startAt = Date.now();

    try {
      await client.query(`SET statement_timeout = ${env.DB_STATEMENT_TIMEOUT}`);

      const result = await client.query(sql, params);
      const ms = Date.now() - startAt;

      if (ms > env.DB_SLOW_QUERY_MS) {
        logger.warn("db: slow query detected", {
          ms,
          sql: sql.substring(0, 150),
        });
      }

      return result;
    } catch (err) {
      logger.error("db: query error", safeLogMeta(sql, err));
      throw err;
    } finally {
      client.release();
    }
  },
  async safeQuery(sql, params = []) {
    try {
      const result = await db.query(sql, params);
      return { success: true, data: result.rows };
    } catch (err) {
      return { success: false, error: err };
    }
  },
  async transaction(callback) {
    const pool = getPool();
    const client = await pool.connect();

    try {
      await client.query("BEGIN");
      await client.query(`SET LOCAL statement_timeout = ${env.DB_STATEMENT_TIMEOUT}`);
      await client.query(`SET LOCAL lock_timeout      = ${env.DB_LOCK_TIMEOUT}`);

      const result = await callback(client);
      await client.query("COMMIT");
      return result;
    } catch (err) {
      await client
        .query("ROLLBACK")
        .catch((rbErr) =>
          logger.error("db: ROLLBACK failed", safeLogMeta("ROLLBACK", rbErr)),
        );
      throw err;
    } finally {
      client.release();
    }
  },
};

module.exports = { db };
