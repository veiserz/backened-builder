'use strict';

const { ok, created, noContent, paginated } = require('../../../http/response');

/**
 * Build a Store controller bound to the provided service.
 * The controller has zero knowledge of the DI container.
 *
 * @param {import('../service').StoreService} storeService
 */
function makeController(storeService) {
  async function create(req, res, next) {
    try {
      return created(res, await storeService.create(req.body));
    } catch (err) { next(err); }
  }

  async function getById(req, res, next) {
    try {
      return ok(res, await storeService.getById(req.params.id));
    } catch (err) { next(err); }
  }

  async function list(req, res, next) {
    try {
      const page  = Number(req.query.page  || 1);
      const limit = Number(req.query.limit || 20);
      return paginated(res, await storeService.list({ page, limit }));
    } catch (err) { next(err); }
  }

  async function update(req, res, next) {
    try {
      return ok(res, await storeService.update(req.params.id, req.body));
    } catch (err) { next(err); }
  }

  async function remove(req, res, next) {
    try {
      await storeService.delete(req.params.id);
      return noContent(res);
    } catch (err) { next(err); }
  }

  return { create, getById, list, update, remove };
}

module.exports = { makeController };
