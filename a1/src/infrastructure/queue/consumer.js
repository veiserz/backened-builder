"use strict";

const { getQueue } = require("./client");
const { logger } = require("../logger");

/**
 * Register a processor for a named queue.
 * The processor is wrapped with error logging so unhandled rejections
 * inside a job are always recorded before Bull marks the job as failed.
 *
 * @param {string}   queueName
 * @param {Function} processor      async (job: Bull.Job) => any
 * @param {object}   [options]
 * @param {number}   [options.concurrency=1]  Number of jobs processed in parallel
 */
function consume(queueName, processor, options = {}) {
  const queue = getQueue(queueName);
  const concurrency = options.concurrency || 1;

  queue.process(concurrency, async (job) => {
    logger.debug(`Processing job ${job.id} in "${queueName}"`, {
      data: job.data,
    });
    try {
      const result = await processor(job);
      logger.debug(`Job ${job.id} in "${queueName}" completed`);
      return result;
    } catch (err) {
      logger.error(`Job ${job.id} in "${queueName}" failed`, {
        err,
        data: job.data,
      });
      throw err; // re-throw so Bull marks the job as failed and retries
    }
  });

  logger.info(`Consumer registered for queue "${queueName}"`, { concurrency });
}

/**
 * Pause a queue — new jobs will be queued but not processed.
 * @param {string} queueName
 * @returns {Promise<void>}
 */
async function pauseQueue(queueName) {
  await getQueue(queueName).pause();
  logger.info(`Queue "${queueName}" paused`);
}

/**
 * Resume a previously paused queue.
 * @param {string} queueName
 * @returns {Promise<void>}
 */
async function resumeQueue(queueName) {
  await getQueue(queueName).resume();
  logger.info(`Queue "${queueName}" resumed`);
}

module.exports = { consume, pauseQueue, resumeQueue };
