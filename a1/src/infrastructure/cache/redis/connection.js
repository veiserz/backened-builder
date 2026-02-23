'use strict';

const Redis      = require('ioredis');
const { logger } = require('../../logger');

let redisInstance;

/**
 * Create and connect the shared Redis instance.
 * Must be called once during application bootstrap before any cache usage.
 * @returns {Promise<import('ioredis').Redis>}
 */
async function connectRedis() {
  redisInstance = new Redis({
    host:                 process.env.REDIS_HOST     || 'localhost',
    port:                 parseInt(process.env.REDIS_PORT || '6379', 10),
    db:                   parseInt(process.env.REDIS_DB   || '0',    10),
    password:             process.env.REDIS_PASSWORD || undefined,
    lazyConnect:          true,
    maxRetriesPerRequest: 3,
    enableReadyCheck:     true,
  });

  redisInstance.on('error', (err) => logger.error('Redis error', { err }));
  redisInstance.on('reconnecting', () => logger.warn('Redis reconnecting…'));

  await redisInstance.connect();
  logger.info('Redis connected', {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    db:   process.env.REDIS_DB   || 0,
  });
  return redisInstance;
}

/**
 * Gracefully close the Redis connection.
 * Should be called during application shutdown.
 * @returns {Promise<void>}
 */
async function disconnectRedis() {
  if (!redisInstance) return;
  await redisInstance.quit();
  redisInstance = undefined;
  logger.info('Redis disconnected');
}

/**
 * Return the active Redis instance.
 * Throws if connectRedis() has not been called yet.
 * @returns {import('ioredis').Redis}
 */
function getRedis() {
  if (!redisInstance) throw new Error('Redis not initialised – call connectRedis() first');
  return redisInstance;
}

module.exports = { connectRedis, disconnectRedis, getRedis };
