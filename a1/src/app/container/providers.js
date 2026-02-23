"use strict";

const { db } = require("../../infrastructure/database/postgresql");
const { redisClient } = require("../../infrastructure/cache/redis");
const { logger } = require("../../infrastructure/logger");
const { bus } = require("../../infrastructure/eventbus");
const { Dispatcher } = require("../dispatch");
const { registerHandlers } = require("../dispatch/handlers");
const { UserRepository } = require("../../modules/users/user.repository");
const { UsersService } = require("../../modules/users/users.service");
const { AuthRepository } = require("../../modules/auth/repository");
const { AuthService } = require("../../modules/auth/service");
const { StoreRepository } = require("../../modules/store/repository");
const { StoreService } = require("../../modules/store/service");
const { MasoudRepository } = require('../../modules/masoud/repository');
const { MasoudService }    = require('../../modules/masoud/service');
// [AUTO-IMPORTS]

/**
 * Register all application bindings here.
 * Order matters only when a factory depends on a prior singleton.
 */
function register(container) {
  // ── Infrastructure ────────────────────────────────────────
  container.instance("db", db);
  container.instance("redisClient", redisClient);
  container.instance("logger", logger);
  container.instance("bus", bus);

  container.singleton("dispatcher", (c) => {
    const d = new Dispatcher(c.resolve("bus"));
    registerHandlers(d);
    return d;
  });

  // ── Repositories ─────────────────────────────────────────
  container.singleton(
    "userRepository",
    (c) => new UserRepository(c.resolve("db")),
  );
  container.singleton(
    "authRepository",
    (c) => new AuthRepository(c.resolve("db")),
  );
  container.singleton(
    "storeRepository",
    (c) => new StoreRepository(c.resolve("db")),
  );
  container.singleton(
    'masoudRepository',
    (c) => new MasoudRepository(c.resolve('db')),
  );
  // [AUTO-REPOS]

  // ── Services ─────────────────────────────────────────────
  container.singleton(
    "usersService",
    (c) =>
      new UsersService(c.resolve("userRepository"), c.resolve("dispatcher")),
  );
  container.singleton(
    "authService",
    (c) =>
      new AuthService(c.resolve("authRepository"), c.resolve("dispatcher")),
  );
  container.singleton(
    "storeService",
    (c) =>
      new StoreService(c.resolve("storeRepository"), c.resolve("dispatcher")),
  );
  container.singleton(
    'masoudService',
    (c) => new MasoudService(c.resolve('masoudRepository'), c.resolve('dispatcher')),
  );
  // [AUTO-SERVICES]
}

module.exports = { register };
