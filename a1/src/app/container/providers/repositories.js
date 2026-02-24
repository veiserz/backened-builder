// src/app/container/providers/repositories.js
"use strict";

const { UserRepository } = require("../../../modules/users/user.repository");
const { AuthRepository } = require("../../../modules/auth/repository");
const { StoreRepository } = require("../../../modules/store/repository");
const { MasoudRepository } = require("../../../modules/masoud/repository");
// [AUTO-REPO-IMPORTS]

/**
 * Repository (data-access) bindings.
 * Every repository receives its infrastructure dependency via the container,
 * keeping repositories unaware of the container itself.
 *
 * @param {import('../index').Container} c
 */
function registerRepositories(c) {
  c.singleton(
    "userRepository",
    ({ resolve }) => new UserRepository(resolve("db")),
  );
  c.singleton(
    "authRepository",
    ({ resolve }) => new AuthRepository(resolve("db")),
  );
  c.singleton(
    "storeRepository",
    ({ resolve }) => new StoreRepository(resolve("db")),
  );
  c.singleton(
    "masoudRepository",
    ({ resolve }) => new MasoudRepository(resolve("db")),
  );
  // [AUTO-REPOS]
}

module.exports = { registerRepositories };
