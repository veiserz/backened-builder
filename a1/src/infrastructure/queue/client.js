"use strict";

const Bull = require("bull");
const { logger } = require("../logger");

/** Registry of all active Bull queues, keyed by name. */
const queues = new Map();

/**
 * Return (or lazily create) a Bull queue by name.
 * All queues share the same Redis config from environment variables.
 *
 * @param {string} name
 * @returns {import('bull').Queue}
 */
function getQueue(name) {
  if (!queues.has(name)) {
    const q = new Bull(name, {
      redis: {
        host: process.env.REDIS_HOST || "localhost",
        port: parseInt(process.env.REDIS_PORT || "6379", 10),
        db: parseInt(process.env.REDIS_DB || "0", 10),
        password: process.env.REDIS_PASSWORD || undefined,
      },
    });

    q.on("error", (err) => logger.error(`Queue "${name}" error`, { err }));
    q.on("failed", (job, err) =>
      logger.warn(`Job failed in "${name}"`, { jobId: job.id, err }),
    );
    q.on("stalled", (job) =>
      logger.warn(`Job stalled in "${name}"`, { jobId: job.id }),
    );
    q.on("completed", (job) =>
      logger.debug(`Job completed in "${name}"`, { jobId: job.id }),
    );

    queues.set(name, q);
    logger.debug(`Queue "${name}" created`);
  }
  return queues.get(name);
}

/**
 * Close a specific queue and remove it from the registry.
 * @param {string} name
 * @returns {Promise<void>}
 */
async function closeQueue(name) {
  const q = queues.get(name);
  if (!q) return;
  await q.close();
  queues.delete(name);
  logger.info(`Queue "${name}" closed`);
}

/**
 * Close all active queues.
 * Should be called during application graceful shutdown.
 * @returns {Promise<void>}
 */
async function closeAllQueues() {
  await Promise.all([...queues.keys()].map(closeQueue));
  logger.info("All queues closed");
}

module.exports = { getQueue, closeQueue, closeAllQueues };
