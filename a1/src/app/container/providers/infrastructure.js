// src/app/container/providers/infrastructure.js
"use strict";

const { Dispatcher } = require("../../dispatch");
const { registerHandlers } = require("../../dispatch/handlers");

/**
 * Infrastructure layer bindings.
 *
 * All values here are pre-built (already connected) instances passed in
 * by the composition root — no connection logic happens here.
 *
 * @param {import('../index').Container} c
 * @param {{ db, redisClient, logger, bus }} infra
 */
function registerInfrastructure(c, { db, redisClient, logger, bus }) {
  c.instance("db", db);
  c.instance("redisClient", redisClient);
  c.instance("logger", logger);
  c.instance("bus", bus);

  c.singleton("dispatcher", ({ resolve }) => {
    const dispatcher = new Dispatcher(resolve("bus"));
    registerHandlers(dispatcher);
    return dispatcher;
  });
}

module.exports = { registerInfrastructure };
