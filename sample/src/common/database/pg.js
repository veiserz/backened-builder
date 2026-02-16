/**
 * High-Performance PostgreSQL Database Wrapper
 * Simple API: db.execute() and db.Transaction()
 */

const { Pool } = require("pg");
const pgConfig = require("../../config/pg.config");
const { normalizeError } = require("./errors");

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
