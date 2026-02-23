"use strict";

/**
 * EventBus infrastructure module.
 *
 * Exports:
 *   bus        – shared EventBus singleton
 *   EventBus   – class (useful for testing with isolated instances)
 *
 * Methods on bus:
 *   await bus.publish(event, payload)       – emit to all subscribers
 *   bus.subscribe(event, listener)          – persistent listener
 *   bus.subscribeOnce(event, listener)      – one-time listener
 *   bus.unsubscribe(event, listener)        – remove a listener
 *   bus.clearAll(event?)                    – remove all listeners (tests only)
 */
module.exports = require("./bus");
