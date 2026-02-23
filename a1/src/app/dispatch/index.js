"use strict";

const { bus } = require("../../infrastructure/eventbus");
const { registerHandlers } = require("./handlers");

/**
 * Application-level event dispatcher.
 *
 * Usage:
 *   dispatcher.on(event, asyncHandler)       – register an in-process handler
 *   await dispatcher.dispatch(event, payload) – run handlers + publish to EventBus
 *
 * Dispatching runs ALL registered in-process handlers concurrently,
 * then publishes to the infrastructure EventBus for cross-service fanout.
 */
class Dispatcher {
  /** @param {import('../../infrastructure/eventbus').EventBus} eventBus */
  constructor(eventBus) {
    this._handlers = new Map();
    this._bus = eventBus;
  }

  /**
   * Register an async handler for the given event.
   * Multiple handlers per event are supported.
   * @param {string}   event
   * @param {Function} handler  async (payload) => void
   * @returns {this}
   */
  on(event, handler) {
    if (!this._handlers.has(event)) this._handlers.set(event, []);
    this._handlers.get(event).push(handler);
    return this;
  }

  /**
   * Dispatch an event: runs all in-process handlers in parallel,
   * then forwards to the infrastructure EventBus.
   * @param {string} event
   * @param {object} payload
   */
  async dispatch(event, payload) {
    const handlers = this._handlers.get(event) ?? [];
    await Promise.all(handlers.map((h) => h(payload)));
    await this._bus.publish(event, payload);
  }

  /** List all events that have at least one registered handler. */
  registeredEvents() {
    return [...this._handlers.keys()];
  }
}

// Module-level singleton wired to the shared bus (used outside the DI container).
const dispatcher = new Dispatcher(bus);
registerHandlers(dispatcher);

module.exports = { Dispatcher, dispatcher, registerHandlers };
