// src/bootstrap/app.js
"use strict";

const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const compression = require("compression");

const {
  requestContextMiddleware,
  rateLimitMiddleware,
} = require("../http/middlewares");
const { errorHandler } = require("../http/errors");
const { features } = require("../app/config");

/**
 * Build the Express application.
 *
 * The apiRouter is created in the composition root (server.js) and passed in,
 * keeping this factory free of any DI details.
 *
 * @param {import('express').Router} apiRouter
 * @returns {import('express').Application}
 */
function createApp(apiRouter) {
  const app = express();

  app.use(helmet());
  app.use(
    cors({
      origin: process.env.CORS_ORIGIN
        ? process.env.CORS_ORIGIN.split(",")
        : "*",
      credentials: process.env.CORS_CREDENTIALS === "true",
      methods: ["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"],
    }),
  );
  app.use(compression());
  app.use(express.json({ limit: "1mb" }));
  app.use(express.urlencoded({ extended: true }));

  app.use(requestContextMiddleware);

  if (features.rateLimiting) {
    app.use(rateLimitMiddleware);
  }

  app.get("/health", (_req, res) => {
    res.json({
      status: "ok",
      env: process.env.NODE_ENV,
      ts: Date.now(),
      uptime: Math.floor(process.uptime()),
    });
  });

  app.use("/api", apiRouter);

  app.use((_req, res) => {
    res
      .status(404)
      .json({ success: false, error: { message: "Route not found" } });
  });

  app.use(errorHandler);

  return app;
}

module.exports = { createApp };