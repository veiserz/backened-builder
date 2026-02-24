// src/app/container/providers/services.js
"use strict";

const { UsersService } = require("../../../modules/users/users.service");
const { AuthService } = require("../../../modules/auth/service");
const { StoreService } = require("../../../modules/store/service");
const { MasoudService } = require("../../../modules/masoud/service");
// [AUTO-SERVICE-IMPORTS]

/**
 * Application service bindings.
 * Services receive only repository and dispatcher interfaces — no DB/Redis awareness.
 *
 * @param {import('../index').Container} c
 */
function registerServices(c) {
  c.singleton(
    "usersService",
    ({ resolve }) =>
      new UsersService(resolve("userRepository"), resolve("dispatcher")),
  );
  c.singleton(
    "authService",
    ({ resolve }) =>
      new AuthService(resolve("authRepository"), resolve("dispatcher")),
  );
  c.singleton(
    "storeService",
    ({ resolve }) =>
      new StoreService(resolve("storeRepository"), resolve("dispatcher")),
  );
  c.singleton(
    "masoudService",
    ({ resolve }) =>
      new MasoudService(resolve("masoudRepository"), resolve("dispatcher")),
  );
  // [AUTO-SERVICES]
}

module.exports = { registerServices };
