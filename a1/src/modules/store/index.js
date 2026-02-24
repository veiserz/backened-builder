'use strict';

/**
 * Public API of the store module.
 * Only these exports should be consumed by other modules.
 * Direct access to internals breaks encapsulation.
 */
module.exports = {
  StoreService:    require('./service').StoreService,
  StoreRepository: require('./repository').StoreRepository,
  StoreModel:      require('./models').Store,
  createRouter:        require('./router').createRouter,
};
