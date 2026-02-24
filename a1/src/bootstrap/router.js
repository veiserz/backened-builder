// src/bootstrap/router.js
"use strict";

const { Router } = require("express");
const { createRouter: createMasoudRouter } = require("../modules/masoud");
const { createRouter: createStoreRouter } = require('../modules/store');
// [AUTO-ROUTES-IMPORT]

/**
 * Build the API router.
 *
 * Services are resolved ONCE here at startup and injected into each module
 * router factory. No module ever touches the container.
 *
 * @param {import('../app/container').Container} container
 * @returns {import('express').Router}
 */
function createRouter(container) {
  const router = Router();

  // ── Mount module routers ───────────────────────────────────────────────────
  router.use(
    "/v1/masoud",
    createMasoudRouter(container.resolve("masoudService")),
  );
  router.use('/v1/store', createStoreRouter(container.resolve('storeService')));
  // [AUTO-USE]

  // ── 404 – unmatched API route ──────────────────────────────────────────────
  router.use((_req, res) => {
    res
      .status(404)
      .json({ success: false, error: { message: "API endpoint not found" } });
  });

  return router;
}

module.exports = { createRouter };
