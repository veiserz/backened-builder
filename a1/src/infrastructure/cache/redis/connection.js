'use strict';

const Redis    = require('ioredis');
const { logger } = require('../../logger');

let redisInstance;

async function connectRedis() {
  redisInstance = new Redis({
    host:           process.env.REDIS_HOST || 'localhost',
    port:           parseInt(process.env.REDIS_PORT || '6379', 10),
    password:       process.env.REDIS_PASSWORD || undefined,
    lazyConnect:    true,
    maxRetriesPerRequest: 3,
  });

  redisInstance.on('error', (err) => logger.error('Redis error', { err }));
  await redisInstance.connect();
  logger.info('Redis connected');
  return redisInstance;
}

function getRedis() {
  if (!redisInstance) throw new Error('Redis not initialised – call connectRedis() first');
  return redisInstance;
}

module.exports = { connectRedis, getRedis };
