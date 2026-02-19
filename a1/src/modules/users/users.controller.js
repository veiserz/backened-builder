'use strict';

const { ok, created, noContent, paginated } = require('../../../http/response');
const { container } = require('../../../app/container');

function getUsersService() {
  return container.resolve('usersService');
}

async function createUser(req, res, next) {
  try {
    const user = await getUsersService().createUser(req.body);
    return created(res, user);
  } catch (err) { next(err); }
}

async function getUser(req, res, next) {
  try {
    const user = await getUsersService().getUserById(req.params.id);
    return ok(res, user);
  } catch (err) { next(err); }
}

async function listUsers(req, res, next) {
  try {
    const page  = parseInt(req.query.page  || '1',  10);
    const limit = parseInt(req.query.limit || '20', 10);
    const result = await getUsersService().listUsers({ page, limit });
    return paginated(res, result);
  } catch (err) { next(err); }
}

async function updateUser(req, res, next) {
  try {
    const user = await getUsersService().updateUser(req.params.id, req.body);
    return ok(res, user);
  } catch (err) { next(err); }
}

async function deleteUser(req, res, next) {
  try {
    await getUsersService().deleteUser(req.params.id);
    return noContent(res);
  } catch (err) { next(err); }
}

module.exports = { createUser, getUser, listUsers, updateUser, deleteUser };
