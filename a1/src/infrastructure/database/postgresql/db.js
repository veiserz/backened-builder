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
