'use strict';

const { ok, created, noContent, paginated } = require('../../../http/response');
const { container } = require('../../../app/container');

function getService() {
  return container.resolve('masoudService');
}

async function create(req, res, next) {
  try {
    return created(res, await getService().create(req.body));
  } catch (err) { next(err); }
}

async function getById(req, res, next) {
  try {
    return ok(res, await getService().getById(req.params.id));
  } catch (err) { next(err); }
}

async function list(req, res, next) {
  try {
    const page  = Number(req.query.page  || 1);
    const limit = Number(req.query.limit || 20);
    return paginated(res, await getService().list({ page, limit }));
  } catch (err) { next(err); }
}

async function update(req, res, next) {
  try {
    return ok(res, await getService().update(req.params.id, req.body));
  } catch (err) { next(err); }
}

async function remove(req, res, next) {
  try {
    await getService().delete(req.params.id);
    return noContent(res);
  } catch (err) { next(err); }
}

module.exports = { create, getById, list, update, remove };
