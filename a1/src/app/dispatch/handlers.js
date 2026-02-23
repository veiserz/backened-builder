"use strict";

const { logger } = require("../../infrastructure/logger");

/**
 * Register all application-level domain event handlers onto a Dispatcher.
 *
 * Add new handlers here as the application grows.
 * Each handler receives the event payload emitted by a Service.
 *
 * @param {import('./index').Dispatcher} dispatcher
 */
function registerHandlers(dispatcher) {
  // ── User events ───────────────────────────────────────────────────────────

  dispatcher.on("user.created", async (payload) => {
    logger.info("Event: user.created", { userId: payload.id });
    // TODO: send welcome e-mail, initialise onboarding data, etc.
  });

  dispatcher.on("user.updated", async (payload) => {
    logger.info("Event: user.updated", { userId: payload.id });
  });

  dispatcher.on("user.deleted", async (payload) => {
    logger.info("Event: user.deleted", { userId: payload.id });
    // TODO: purge user data, revoke sessions, etc.
  });

  // ── Auth events ───────────────────────────────────────────────────────────

  dispatcher.on("auth.login", async (payload) => {
    logger.info("Event: auth.login", { userId: payload.userId });
  });

  dispatcher.on("auth.logout", async (payload) => {
    logger.info("Event: auth.logout", { userId: payload.userId });
  });

  dispatcher.on("auth.password_changed", async (payload) => {
    logger.info("Event: auth.password_changed", { userId: payload.userId });
    // TODO: send security-alert e-mail, revoke old refresh tokens, etc.
  });

  // ── Store events ──────────────────────────────────────────────────────────

  dispatcher.on("store.created", async (payload) => {
    logger.info("Event: store.created", { storeId: payload.id });
  });

  dispatcher.on("store.updated", async (payload) => {
    logger.info("Event: store.updated", { storeId: payload.id });
  });

  dispatcher.on("store.deleted", async (payload) => {
    logger.info("Event: store.deleted", { storeId: payload.id });
  });
}

module.exports = { registerHandlers };
