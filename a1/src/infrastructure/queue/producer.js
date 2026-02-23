"use strict";

const { getQueue } = require("./client");

/**
 * Add a single job to a named queue.
 *
 * @param {string}                    queueName
 * @param {object}                    data
 * @param {import('bull').JobOptions} [opts]
 * @returns {Promise<string>} The job ID
 */
async function enqueue(queueName, data, opts = {}) {
  const queue = getQueue(queueName);
  const job = await queue.add(data, {
    attempts: 3,
    backoff: { type: "exponential", delay: 2000 },
    removeOnComplete: 100,
    removeOnFail: 200,
    ...opts,
  });
  return job.id;
}

/**
 * Add multiple jobs to a named queue in a single call.
 *
 * @param {string}   queueName
 * @param {object[]} items       Array of { data, opts? } objects
 * @returns {Promise<string[]>}  Array of job IDs in the same order
 */
async function enqueueBulk(queueName, items) {
  const queue = getQueue(queueName);
  const jobs = await queue.addBulk(
    items.map(({ data, opts = {} }) => ({
      data,
      opts: {
        attempts: 3,
        backoff: { type: "exponential", delay: 2000 },
        removeOnComplete: 100,
        removeOnFail: 200,
        ...opts,
      },
    })),
  );
  return jobs.map((j) => j.id);
}

/**
 * Schedule a job to run after a delay.
 *
 * @param {string} queueName
 * @param {object} data
 * @param {number} delayMs        Milliseconds to wait before processing
 * @param {import('bull').JobOptions} [opts]
 * @returns {Promise<string>} The job ID
 */
async function enqueueIn(queueName, data, delayMs, opts = {}) {
  return enqueue(queueName, data, { delay: delayMs, ...opts });
}

module.exports = { enqueue, enqueueBulk, enqueueIn };
