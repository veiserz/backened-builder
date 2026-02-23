"use strict";

const EventEmitter = require("events");
const { logger } = require("../logger");

/**
 * In-process event bus backed by Node's EventEmitter.
 *
 * The API is intentionally minimal so that `publish()` can be swapped
 * for an external broker (Redis Pub/Sub, RabbitMQ, NATS, etc.) without
 * changing any call-site in the application layer.
 *
 * Usage:
 *   bus.subscribe('user.created', handler)
 *   await bus.publish('user.created', { id })
 *   bus.unsubscribe('user.created', handler)
 */
class EventBus extends EventEmitter {
  /**
   * Publish an event to all synchronous subscribers.
   * @param {string} event
   * @param {object} [payload]
   * @returns {Promise<void>}
   */
  async publish(event, payload) {
    logger.debug("EventBus publish", { event });
    this.emit(event, payload);
  }

  /**
   * Subscribe a persistent listener to an event.
   * @param {string}   event
   * @param {Function} listener  (payload) => void
   */
  subscribe(event, listener) {
    this.on(event, listener);
  }

  /**
   * Subscribe a one-time listener that is removed after first invocation.
   * @param {string}   event
   * @param {Function} listener  (payload) => void
   */
  subscribeOnce(event, listener) {
    this.once(event, listener);
  }

  /**
   * Remove a previously registered listener.
   * @param {string}   event
   * @param {Function} listener  The exact same function reference used in subscribe()
   */
  unsubscribe(event, listener) {
    this.off(event, listener);
  }

  /**
   * Remove all listeners for an event, or all events if none specified.
   * Intended for use in tests — avoid in production code.
   * @param {string} [event]
   */
  clearAll(event) {
    if (event) {
      this.removeAllListeners(event);
    } else {
      this.removeAllListeners();
    }
  }
}

const bus = new EventBus();
bus.setMaxListeners(50);

module.exports = { bus, EventBus };
