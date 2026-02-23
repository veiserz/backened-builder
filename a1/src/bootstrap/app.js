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
const router = require("./router");

function createApp() {
  const app = express();

  // ── Security & parsing ──────────────────────────────────────────────────
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

  // ── Observability ───────────────────────────────────────────────────────
  app.use(requestContextMiddleware);

  // ── Rate limiting (feature-flag controlled) ─────────────────────────────
  if (features.rateLimiting) {
    app.use(rateLimitMiddleware);
  }

  // ── Health check ────────────────────────────────────────────────────────
  app.get("/health", (_req, res) => {
    res.json({
      status: "ok",
      env: process.env.NODE_ENV,
      ts: Date.now(),
      uptime: Math.floor(process.uptime()),
    });
  });

  // ── API routes ──────────────────────────────────────────────────────────
  app.use("/api", router);

  // ── 404 – unknown routes ────────────────────────────────────────────────
  app.use((_req, res) => {
    res
      .status(404)
      .json({ success: false, error: { message: "Route not found" } });
  });

  // ── Global error handler (must be last) ─────────────────────────────────
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
