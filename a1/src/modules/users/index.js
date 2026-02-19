"use strict";

/**
 * Public API of the users module.
 * Only these exports should be consumed by other modules.
 * Direct access to internals breaks encapsulation.
 */
module.exports = {
  UsersService: require("./users.service").UsersService,
  UserRepository: require("./user.repository").UserRepository,
  UserModel: require("./user.models").User,
  usersRoutes: require("./user.router"),
};
