// src/bootstrap/server.js
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
const { db } = require("../infrastructure/database/postgresql");
const { redisClient } = require("../infrastructure/cache/redis");
const { bus } = require("../infrastructure/eventbus");

const { Container } = require("../app/container");
const { registerAll } = require("../app/container/providers");
const { createApp } = require("./app");
const { createRouter } = require("./router");

async function start() {
  // ── 1. Validate environment ────────────────────────────────────────────────
  validateEnv();

  // ── 2. Connect infrastructure ──────────────────────────────────────────────
  await connectPostgres();
  await connectRedis();

  // ── 3. Composition root — the ONLY place the container is created ──────────
  const container = new Container();

  registerAll(container, { db, redisClient, logger, bus });

  // Eagerly construct every singleton — surfaces wiring errors before the
  // server accepts traffic. Switch to verifyAsync() if any factory is async.
  container.verify();

  // ── 4. Build HTTP layer with resolved services ─────────────────────────────
  const apiRouter = createRouter(container);
  const app = createApp(apiRouter);

  const port = parseInt(process.env.PORT || "3000", 10);
  const server = app.listen(port, () => {
    logger.info(`Server listening on port ${port}`, {
      env: process.env.NODE_ENV,
    });
  });

  // ── 5. Graceful shutdown ───────────────────────────────────────────────────
  async function shutdown(signal) {
    logger.info(`${signal} received – shutting down gracefully`);
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

    setTimeout(() => {
      logger.error("Graceful shutdown timed out – forcing exit");
      process.exit(1);
    }, 10_000).unref();
  }

  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));

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
