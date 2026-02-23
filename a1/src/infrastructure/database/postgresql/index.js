"use strict";

/**
 * PostgreSQL infrastructure module.
 *
 * Exports:
 *   connectPostgres()    – create pool + verify connectivity (call once at bootstrap)
 *   disconnectPostgres() – gracefully drain and close the pool (call at shutdown)
 *   getPool()            – return the raw pg.Pool instance
 *   db                   – high-level helpers:
 *                           db.query(sql, params?)          – single statement
 *                           db.transaction(async (client)) – BEGIN/COMMIT/ROLLBACK
 */
module.exports = {
  ...require("./connection"),
  ...require("./db"),
};
