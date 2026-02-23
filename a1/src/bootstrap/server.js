"use strict";

require("dotenv").config();

const { validateEnv } = require("../infrastructure/env");
const {
  connectPostgres,
  disconnectPostgres,
} = require("../infrastructure/database/postgresql");
const {
  connectRedis,
  disconnectRedis,
} = require("../infrastructure/cache/redis");
const { closeAllQueues } = require("../infrastructure/queue");
const { logger } = require("../infrastructure/logger");
const { bootContainer } = require("../app/container");
const { createApp } = require("./app");

async function start() {
  // ── 1. Validate environment ──────────────────────────────────────────────
  validateEnv();

  // ── 2. Connect infrastructure ────────────────────────────────────────────
  await connectPostgres();
  await connectRedis();

  // ── 3. Wire DI container ─────────────────────────────────────────────────
  bootContainer();

  // ── 4. Start HTTP server ─────────────────────────────────────────────────
  const app = createApp();
  const port = parseInt(process.env.PORT || "3000", 10);
  const server = app.listen(port, () => {
    logger.info(`Server listening on port ${port}`, {
      env: process.env.NODE_ENV,
    });
  });

  // ── 5. Graceful shutdown ─────────────────────────────────────────────────
  async function shutdown(signal) {
    logger.info(`${signal} received – shutting down gracefully`);

    // Stop accepting new connections
    server.close(async () => {
      logger.info("HTTP server closed");
      try {
        await disconnectPostgres();
        await disconnectRedis();
        await closeAllQueues();
        logger.info("Infrastructure connections closed");
        process.exit(0);
      } catch (err) {
        logger.error("Error during shutdown", { err });
        process.exit(1);
      }
    });

    // Force-kill if graceful shutdown exceeds 10 s
    setTimeout(() => {
      logger.error("Graceful shutdown timed out – forcing exit");
      process.exit(1);
    }, 10_000).unref();
  }

  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));

  // ── 6. Safety nets ───────────────────────────────────────────────────────
  process.on("unhandledRejection", (reason) => {
    logger.error("Unhandled promise rejection", { reason });
  });

  process.on("uncaughtException", (err) => {
    logger.error("Uncaught exception – shutting down", { err });
    shutdown("uncaughtException");
  });
}

start().catch((err) => {
  console.error("Fatal startup error:", err);
  process.exit(1);
});
