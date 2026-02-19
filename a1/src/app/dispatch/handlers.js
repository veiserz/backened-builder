'use strict';

/**
 * Register application-level event handlers.
 * Called once during bootstrap.
 *
 * @param {import('./index').Dispatcher} dispatcher
 */
function registerHandlers(dispatcher) {
  dispatcher.on('user.created', async (payload) => {
    // e.g. send welcome email, seed onboarding data …
    const { logger } = require('../../infrastructure/logger');
    logger.info('Event: user.created', { userId: payload.id });
  });

  dispatcher.on('user.deleted', async (payload) => {
    const { logger } = require('../../infrastructure/logger');
    logger.info('Event: user.deleted', { userId: payload.id });
  });
}

module.exports = { registerHandlers };
