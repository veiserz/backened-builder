'use strict';

const EventEmitter = require('events');
const { logger }   = require('../logger');

/**
 * In-process event bus backed by Node's EventEmitter.
 * Swap publish() for an external broker (Redis pub/sub, RabbitMQ, etc.)
 * without changing any call-site.
 */
class EventBus extends EventEmitter {
  async publish(event, payload) {
    logger.debug('EventBus publish', { event, payload });
    this.emit(event, payload);
  }

  subscribe(event, listener) {
    this.on(event, listener);
  }
}

const bus = new EventBus();
bus.setMaxListeners(50);

module.exports = { bus, EventBus };
