'use strict';

const express    = require('express');
const helmet     = require('helmet');
const cors       = require('cors');
const compression = require('compression');

const { requestContextMiddleware } = require('../http/middlewares');
const { rateLimitMiddleware }      = require('../http/middlewares');
const { errorHandler }             = require('../http/errors');
const router                       = require('./router');

function createApp() {
  const app = express();

  // ── Security & parsing ──────────────────────────────────
  app.use(helmet());
  app.use(cors());
  app.use(compression());
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true }));

  // ── Observability ────────────────────────────────────────
  app.use(requestContextMiddleware);

  // ── Rate limiting ────────────────────────────────────────
  app.use(rateLimitMiddleware);

  // ── Routes ───────────────────────────────────────────────
  app.use('/api', router);

  // ── Health check ─────────────────────────────────────────
  app.get('/health', (_req, res) => res.json({ status: 'ok', ts: Date.now() }));

  // ── Global error handler ─────────────────────────────────
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
