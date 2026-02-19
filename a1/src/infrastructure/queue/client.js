'use strict';

const Bull = require('bull');
const { logger } = require('../logger');

const queues = new Map();

function getQueue(name) {
  if (!queues.has(name)) {
    const q = new Bull(name, {
      redis: {
        host:     process.env.REDIS_HOST || 'localhost',
        port:     parseInt(process.env.REDIS_PORT || '6379', 10),
        password: process.env.REDIS_PASSWORD || undefined,
      },
    });

    q.on('error',   (err) => logger.error(`Queue "${name}" error`, { err }));
    q.on('failed',  (job, err) => logger.warn(`Job failed in "${name}"`, { jobId: job.id, err }));

    queues.set(name, q);
  }
  return queues.get(name);
}

module.exports = { getQueue };
