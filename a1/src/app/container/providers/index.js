// src/app/container/providers/index.js
"use strict";

const { registerInfrastructure } = require("./infrastructure");
const { registerRepositories } = require("./repositories");
const { registerServices } = require("./services");

/**
 * Wire the entire application graph in dependency order:
 *   Infrastructure → Repositories → Services
 *
 * @param {import('../index').Container} container
 * @param {{ db, redisClient, logger, bus }} infra  Connected infrastructure instances.
 */
function registerAll(container, infra) {
  registerInfrastructure(container, infra);
  registerRepositories(container);
  registerServices(container);
}

module.exports = { registerAll };
