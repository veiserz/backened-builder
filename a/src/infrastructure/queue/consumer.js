'use strict';

const { getQueue } = require('./client');
const { logger }   = require('../logger');

/**
 * Register a processor for a named queue.
 *
 * @param {string}   queueName
 * @param {function} processor  async (job) => any
 * @param {object}   [options]
 */
function consume(queueName, processor, options = {}) {
  const queue = getQueue(queueName);
  queue.process(options.concurrency || 1, async (job) => {
    logger.debug(`Processing job ${job.id} in "${queueName}"`);
    return processor(job);
  });
  logger.info(`Consumer registered for queue "${queueName}"`);
}

module.exports = { consume };
