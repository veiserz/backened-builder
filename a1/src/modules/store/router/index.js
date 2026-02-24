'use strict';

const { Router }           = require('express');
const { makeController }   = require('../controller');
const { validate }         = require('../DTO/validate');
const { authMiddleware }   = require('../../../http/middlewares');
const {
  CreateStoreDto,
  UpdateStoreDto,
  StoreParamDto,
  StoreListQueryDto,
} = require('../DTO');

/**
 * Create the Store Express router.
 *
 * @param {import('../service').StoreService} storeService
 * @returns {import('express').Router}
 */
function createRouter(storeService) {
  const ctrl   = makeController(storeService);
  const router = Router();

  // ── Public ───────────────────────────────────────────────────
  router.post('/',
    validate(CreateStoreDto, 'body'),
    ctrl.create);

  // ── Protected ────────────────────────────────────────────────
  router.use(authMiddleware);

  router.get('/',
    validate(StoreListQueryDto, 'query'),
    ctrl.list);

  router.get('/:id',
    validate(StoreParamDto, 'params'),
    ctrl.getById);

  router.patch('/:id',
    validate(StoreParamDto, 'params'),
    validate(UpdateStoreDto, 'body'),
    ctrl.update);

  router.delete('/:id',
    validate(StoreParamDto, 'params'),
    ctrl.remove);

  return router;
}

module.exports = { createRouter };
