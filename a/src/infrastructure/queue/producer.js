'use strict';

const { getQueue } = require('./client');

/**
 * @param {string} queueName
 * @param {object} data
 * @param {import('bull').JobOptions} [opts]
 */
async function enqueue(queueName, data, opts = {}) {
  const queue = getQueue(queueName);
  const job   = await queue.add(data, {
    attempts:  3,
    backoff:   { type: 'exponential', delay: 2000 },
    removeOnComplete: 100,
    removeOnFail:     200,
    ...opts,
  });
  return job.id;
}

module.exports = { enqueue };
