'use strict';

const { db }                    = require('../../infrastructure/database/postgresql');
const { redisClient }           = require('../../infrastructure/cache/redis');
const { dispatcher }            = require('../dispatch');
const { UsersService }          = require('../../modules/users/users.service');

/**
 * Register all application bindings here.
 * Order matters only when a factory depends on a prior singleton.
 */
function register(container) {
  // ── Infrastructure ────────────────────────────────────────
  container.instance('db',          db);
  container.instance('redisClient', redisClient);
  container.instance('dispatcher',  dispatcher);

  // ── Repositories ─────────────────────────────────────────
  container.singleton('userRepository', (c) =>
    new UserPgRepository(c.resolve('db')));

  // ── Services ─────────────────────────────────────────────
  container.singleton('usersService', (c) =>
    new UsersService(c.resolve('userRepository'), c.resolve('dispatcher')));
}

module.exports = { register };
