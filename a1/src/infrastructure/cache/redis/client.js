"use strict";

const { getRedis } = require("./connection");

/** @param {unknown} value @returns {string} */
function serialise(value) {
  return typeof value === "string" ? value : JSON.stringify(value);
}

/** @param {string|null} raw @returns {unknown} */
function deserialise(raw) {
  if (raw === null) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return raw;
  }
}

/**
 * High-level Redis client with typed helpers.
 *
 * String / generic helpers
 *   get, set, del, exists, expire, ttl, mget, mset
 *
 * Counter helpers
 *   incr, incrby, decr, decrby
 *
 * Hash helpers
 *   hget, hset, hdel, hgetall, hincrby
 *
 * Maintenance (use in non-production only)
 *   flush
 */
const redisClient = {
  // ─── String / Generic ────────────────────────────────────────────────────

  /** @returns {Promise<unknown>} parsed value or null */
  async get(key) {
    return deserialise(await getRedis().get(key));
  },

  /**
   * @param {string}        key
   * @param {unknown}       value
   * @param {number|null}   ttlSeconds
   */
  async set(key, value, ttlSeconds = null) {
    const s = serialise(value);
    return ttlSeconds
      ? getRedis().set(key, s, "EX", ttlSeconds)
      : getRedis().set(key, s);
  },

  /** @param {string|string[]} keys */
  async del(keys) {
    const list = Array.isArray(keys) ? keys : [keys];
    return getRedis().del(...list);
  },

  /** @returns {Promise<boolean>} */
  async exists(key) {
    const count = await getRedis().exists(key);
    return count > 0;
  },

  /**
   * Set / update TTL on an existing key.
   * @param {string} key
   * @param {number} ttlSeconds
   * @returns {Promise<boolean>} true if the timeout was set
   */
  async expire(key, ttlSeconds) {
    const result = await getRedis().expire(key, ttlSeconds);
    return result === 1;
  },

  /**
   * Get remaining TTL in seconds.
   * Returns -2 if the key does not exist, -1 if it has no expiry.
   * @returns {Promise<number>}
   */
  async ttl(key) {
    return getRedis().ttl(key);
  },

  /**
   * Fetch multiple keys in one round-trip.
   * @param {string[]} keys
   * @returns {Promise<Array<unknown>>} values in the same order as keys
   */
  async mget(keys) {
    const raws = await getRedis().mget(...keys);
    return raws.map(deserialise);
  },

  /**
   * Set multiple key/value pairs atomically (no TTL support).
   * @param {Record<string, unknown>} map  – { key: value, … }
   */
  async mset(map) {
    const args = Object.entries(map).flatMap(([k, v]) => [k, serialise(v)]);
    return getRedis().mset(...args);
  },

  // ─── Counters ─────────────────────────────────────────────────────────────

  /** Increment by 1 and return the new value. */
  async incr(key) {
    return getRedis().incr(key);
  },

  /** Increment by `amount` and return the new value. */
  async incrby(key, amount) {
    return getRedis().incrby(key, amount);
  },

  /** Decrement by 1 and return the new value. */
  async decr(key) {
    return getRedis().decr(key);
  },

  /** Decrement by `amount` and return the new value. */
  async decrby(key, amount) {
    return getRedis().decrby(key, amount);
  },

  // ─── Hashes ───────────────────────────────────────────────────────────────

  /** @returns {Promise<unknown>} parsed field value or null */
  async hget(key, field) {
    return deserialise(await getRedis().hget(key, field));
  },

  /** Set a single field on a hash. */
  async hset(key, field, value) {
    return getRedis().hset(key, field, serialise(value));
  },

  /** Delete one or more fields from a hash. */
  async hdel(key, ...fields) {
    return getRedis().hdel(key, ...fields);
  },

  /**
   * Return the entire hash as a plain object with parsed values.
   * @returns {Promise<Record<string, unknown>|null>}
   */
  async hgetall(key) {
    const raw = await getRedis().hgetall(key);
    if (!raw) return null;
    return Object.fromEntries(
      Object.entries(raw).map(([f, v]) => [f, deserialise(v)]),
    );
  },

  /** Increment integer hash field by `amount` and return new value. */
  async hincrby(key, field, amount) {
    return getRedis().hincrby(key, field, amount);
  },

  // ─── Maintenance ─────────────────────────────────────────────────────────

  /**
   * Flush the current database.
   * @throws {Error} in production to prevent accidental data loss.
   */
  async flush() {
    if (process.env.NODE_ENV === "production") {
      throw new Error("redisClient.flush() is disabled in production");
    }
    return getRedis().flushdb();
  },
};

module.exports = { redisClient };
