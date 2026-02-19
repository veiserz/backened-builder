'use strict';

const { bus }               = require('../../infrastructure/eventbus');
const { registerHandlers }  = require('./handlers');

/**
 * Application-level event dispatcher.
 *
 *   dispatcher.on(event, asyncHandler)
 *   await dispatcher.dispatch(event, payload)
 *
 * Dispatching runs all in-process handlers AND publishes
 * to the infrastructure event bus for cross-service fanout.
 */
class Dispatcher {
  constructor(eventBus) {
    this._handlers = new Map();
    this._bus      = eventBus;
  }

  on(event, handler) {
    if (!this._handlers.has(event)) this._handlers.set(event, []);
    this._handlers.get(event).push(handler);
    return this;
  }

  async dispatch(event, payload) {
    const handlers = this._handlers.get(event) || [];
    await Promise.all(handlers.map((h) => h(payload)));
    await this._bus.publish(event, payload);
  }
}

const dispatcher = new Dispatcher(bus);
registerHandlers(dispatcher);

module.exports = { Dispatcher, dispatcher };
