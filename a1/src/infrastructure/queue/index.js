"use strict";

/**
 * Queue infrastructure module (Bull + Redis).
 *
 * Exports:
 *   getQueue(name)                    – get or create a Bull queue by name
 *   closeQueue(name)                  – close a specific queue
 *   closeAllQueues()                  – close all queues (call on shutdown)
 *
 *   enqueue(name, data, opts?)        – add a single job
 *   enqueueBulk(name, [{data,opts}])  – add multiple jobs in one call
 *   enqueueIn(name, data, delayMs)    – schedule a delayed job
 *
 *   consume(name, processor, opts?)   – register a job processor
 *   pauseQueue(name)                  – pause processing
 *   resumeQueue(name)                 – resume processing
 */
module.exports = {
  ...require("./client"),
  ...require("./producer"),
  ...require("./consumer"),
};
