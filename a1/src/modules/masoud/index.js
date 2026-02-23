'use strict';

/**
 * Public API of the masoud module.
 * Only these exports should be consumed by other modules.
 * Direct access to internals breaks encapsulation.
 */
module.exports = {
  MasoudService:    require('./service').MasoudService,
  MasoudRepository: require('./repository').MasoudRepository,
  MasoudModel:      require('./models').Masoud,
  masoudRoutes:      require('./router'),
};
