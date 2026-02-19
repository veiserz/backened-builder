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
