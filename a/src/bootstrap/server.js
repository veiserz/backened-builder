'use strict';

require('dotenv').config();

const { validateEnv }   = require('../infrastructure/env');
const { connectPostgres } = require('../infrastructure/database/postgresql');
const { connectRedis }  = require('../infrastructure/cache/redis');
const { logger }        = require('../infrastructure/logger');
const { bootContainer } = require('../app/container');
const { createApp }     = require('./app');

async function start() {
  try {
    validateEnv();

    await connectPostgres();
    await connectRedis();

    bootContainer();

    const app  = createApp();
    const port = process.env.PORT || 3000;

    const server = app.listen(port, () => {
      logger.info(`Server listening on port ${port} [${process.env.NODE_ENV}]`);
    });

    // ── Graceful shutdown ────────────────────────────────
    const shutdown = (signal) => {
      logger.info(`${signal} received – shutting down gracefully`);
      server.close(() => {
        logger.info('HTTP server closed');
        process.exit(0);
      });
      setTimeout(() => process.exit(1), 10_000);
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT',  () => shutdown('SIGINT'));

  } catch (err) {
    console.error('Fatal startup error:', err);
    process.exit(1);
  }
}

start();
